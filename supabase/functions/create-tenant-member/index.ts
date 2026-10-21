import type { User } from "npm:@supabase/supabase-js@2.118.0";
import {
  createAuthenticatedClients,
  EdgeFunctionError,
  errorResponse,
  generateTemporaryPassword,
  jsonResponse,
  loadTenantOwnerAccountState,
  preflightResponse,
  tenantMemberOnboardingPendingFlag,
  tenantMemberOnboardingRequestId,
  tenantMemberOnboardingTenantId,
  temporaryPasswordResetFlag,
} from "../_shared/tenant_onboarding.ts";

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const requestIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

interface MemberCapacity {
  memberLimit: number;
  activeMemberCount: number;
  remainingMemberCount: number;
}

interface RpcError {
  code?: string;
  details?: string;
  message?: string;
}

Deno.serve(async (req: Request): Promise<Response> => {
  const preflight = preflightResponse(req);
  if (preflight !== null) {
    return preflight;
  }
  if (req.method !== "POST") {
    return jsonResponse({ code: "method_not_allowed" }, 405);
  }

  let clients: Awaited<ReturnType<typeof createAuthenticatedClients>>;
  try {
    clients = await createAuthenticatedClients(req);
  } catch (error) {
    return errorResponse(error);
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ code: "invalid_request" }, 400);
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return jsonResponse({ code: "invalid_request" }, 400);
  }

  const request = body as Record<string, unknown>;
  const tenantId = typeof request.tenantId === "string"
    ? request.tenantId.trim()
    : "";
  const email = typeof request.email === "string"
    ? request.email.trim().toLowerCase()
    : "";
  const requestId = typeof request.requestId === "string"
    ? request.requestId
    : "";
  const role = typeof request.role === "string" ? request.role : "";
  if (
    !isUuid(tenantId) ||
    !emailPattern.test(email) ||
    email.length > 254 ||
    !requestIdPattern.test(requestId) ||
    (role !== "member" && role !== "owner")
  ) {
    return jsonResponse({ code: "invalid_request" }, 400);
  }

  let createdUserId: string | null = null;
  try {
    const capacityResult = await clients.caller.rpc(
      "get_tenant_member_capacity",
      { p_tenant_id: tenantId },
    );
    if (capacityResult.error !== null) {
      return rpcErrorResponse(capacityResult.error);
    }
    const capacity = readCapacity(capacityResult.data);
    if (capacity === null) {
      return jsonResponse({ code: "tenant_setup_incomplete" }, 503);
    }

    let account = await loadTenantOwnerAccountState(clients.admin, email);
    let accountCreated = false;
    let temporaryPassword: string | null = null;
    let accountUser: User | null = null;

    if (account === null) {
      if (role !== "member") {
        return jsonResponse({ code: "member_account_not_found" }, 404);
      }
      if (capacity.remainingMemberCount === 0) {
        return jsonResponse(
          {
            code: "MEMBER_LIMIT_REACHED",
            details: {
              memberLimit: capacity.memberLimit,
              activeMemberCount: capacity.activeMemberCount,
              remainingMemberCount: capacity.remainingMemberCount,
            },
          },
          409,
        );
      }

      const generatedPassword = generateTemporaryPassword();
      const { data, error } = await clients.admin.auth.admin.createUser({
        email,
        password: generatedPassword,
        email_confirm: true,
        app_metadata: {
          [temporaryPasswordResetFlag]: true,
          [tenantMemberOnboardingPendingFlag]: true,
          [tenantMemberOnboardingTenantId]: tenantId,
          [tenantMemberOnboardingRequestId]: requestId,
        },
      });

      if (error === null && data.user !== null) {
        account = {
          userId: data.user.id,
          temporaryPasswordResetRequired: true,
          onboardingPending: false,
          onboardingRequestId: null,
        };
        accountUser = data.user;
        createdUserId = data.user.id;
        accountCreated = true;
        temporaryPassword = generatedPassword;
      } else {
        account = await loadTenantOwnerAccountState(clients.admin, email);
        if (account === null) {
          return jsonResponse(
            { code: "member_account_creation_failed" },
            409,
          );
        }
      }
    }

    if (account === null) {
      return jsonResponse({ code: "member_account_creation_failed" }, 409);
    }

    if (accountUser === null) {
      const { data, error } = await clients.admin.auth.admin.getUserById(
        account.userId,
      );
      if (error !== null || data.user === null) {
        return jsonResponse({ code: "member_account_lookup_failed" }, 503);
      }
      accountUser = data.user;
    }

    const metadata = accountUser.app_metadata;
    const isPendingForTenant =
      metadata[tenantMemberOnboardingPendingFlag] === true &&
      metadata[tenantMemberOnboardingTenantId] === tenantId;
    if (isPendingForTenant && account.temporaryPasswordResetRequired) {
      const savedRequestId = metadata[tenantMemberOnboardingRequestId];
      if (
        typeof savedRequestId !== "string" ||
        !requestIdPattern.test(savedRequestId)
      ) {
        return jsonResponse(
          { code: "member_onboarding_state_invalid" },
          409,
        );
      }

      if (temporaryPassword === null) {
        temporaryPassword = generateTemporaryPassword();
        const { error } = await clients.admin.auth.admin.updateUserById(
          account.userId,
          { password: temporaryPassword },
        );
        if (error !== null) {
          return jsonResponse(
            { code: "temporary_password_rotation_failed" },
            503,
          );
        }
      }
      accountCreated = true;
    }

    let membership: unknown;
    try {
      const result = await clients.caller.rpc("add_tenant_member", {
        p_tenant_id: tenantId,
        p_email: email,
        p_role: role,
      });
      if (result.error !== null) {
        if (createdUserId !== null) {
          const cleanupResult = await cleanupCreatedUser(
            clients.admin,
            createdUserId,
          );
          if (cleanupResult === "failed") {
            return jsonResponse({ code: "member_setup_incomplete" }, 502);
          }
        }
        return rpcErrorResponse(result.error);
      }
      membership = result.data;
    } catch {
      if (createdUserId !== null) {
        const cleanupResult = await cleanupCreatedUser(
          clients.admin,
          createdUserId,
        );
        if (cleanupResult === "failed") {
          return jsonResponse({ code: "member_setup_incomplete" }, 502);
        }
      }
      return jsonResponse({ code: "member_setup_incomplete" }, 502);
    }

    if (
      typeof membership !== "object" ||
      membership === null ||
      Array.isArray(membership) ||
      !("user_id" in membership) ||
      membership.user_id !== account.userId
    ) {
      return jsonResponse({ code: "member_setup_incomplete" }, 502);
    }

    return jsonResponse({
      success: true,
      userId: account.userId,
      email,
      role,
      accountCreated,
      ...(temporaryPassword === null ? {} : { temporaryPassword }),
    });
  } catch (error) {
    if (createdUserId !== null) {
      const cleanupResult = await cleanupCreatedUser(
        clients.admin,
        createdUserId,
      );
      if (cleanupResult === "failed") {
        return jsonResponse({ code: "member_setup_incomplete" }, 502);
      }
    }
    if (error instanceof EdgeFunctionError) {
      return errorResponse(error);
    }
    return jsonResponse({ code: "member_setup_incomplete" }, 502);
  }
});

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function readCapacity(value: unknown): MemberCapacity | null {
  const row = Array.isArray(value) ? value[0] : value;
  if (typeof row !== "object" || row === null || Array.isArray(row)) {
    return null;
  }

  const record = row as Record<string, unknown>;
  const memberLimit = Number(record.member_limit);
  const activeMemberCount = Number(record.active_member_count);
  const remainingMemberCount = Number(record.remaining_member_count);
  if (
    !Number.isInteger(memberLimit) ||
    !Number.isInteger(activeMemberCount) ||
    !Number.isInteger(remainingMemberCount) ||
    memberLimit < 1 ||
    activeMemberCount < 0 ||
    remainingMemberCount < 0
  ) {
    return null;
  }

  return { memberLimit, activeMemberCount, remainingMemberCount };
}

async function cleanupCreatedUser(
  admin: Awaited<ReturnType<typeof createAuthenticatedClients>>["admin"],
  userId: string,
): Promise<"deleted" | "linked" | "failed"> {
  try {
    const { data, error } = await admin
      .from("tenant_memberships")
      .select("tenant_id")
      .eq("user_id", userId)
      .limit(1);
    if (error !== null || !Array.isArray(data)) {
      return "failed";
    }
    if (data.length > 0) {
      return "linked";
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(userId);
    return deleteError === null ? "deleted" : "failed";
  } catch {
    return "failed";
  }
}

function rpcErrorResponse(error: RpcError): Response {
  if (error.code === "P0001" && error.message === "MEMBER_LIMIT_REACHED") {
    return jsonResponse(
      {
        code: "MEMBER_LIMIT_REACHED",
        details: readMemberLimitDetails(error.details),
      },
      409,
    );
  }
  if (error.code === "42501") {
    return jsonResponse({ code: "tenant_management_required" }, 403);
  }
  if (error.code === "P0002") {
    return jsonResponse({ code: "member_account_not_found" }, 404);
  }
  if (error.code === "55000") {
    return jsonResponse({ code: "tenant_archived" }, 409);
  }
  if (error.code === "22023") {
    return jsonResponse({ code: "invalid_request" }, 400);
  }
  if (error.code === "PGRST202" || error.code === "PGRST203") {
    return jsonResponse({ code: "tenant_setup_incomplete" }, 503);
  }
  return jsonResponse({ code: "member_creation_failed" }, 502);
}

function readMemberLimitDetails(value: string | undefined): {
  memberLimit: number;
  activeMemberCount: number;
  remainingMemberCount: number;
} | null {
  if (value === undefined) {
    return null;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(value);
  } catch {
    return null;
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    return null;
  }

  const details = parsed as Record<string, unknown>;
  const memberLimit = Number(details.memberLimit);
  const activeMemberCount = Number(details.activeMemberCount);
  const remainingMemberCount = Number(details.remainingMemberCount);
  if (
    !Number.isInteger(memberLimit) ||
    !Number.isInteger(activeMemberCount) ||
    !Number.isInteger(remainingMemberCount)
  ) {
    return null;
  }
  return { memberLimit, activeMemberCount, remainingMemberCount };
}
