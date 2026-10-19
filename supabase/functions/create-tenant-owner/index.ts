import {
  createAuthenticatedClients,
  EdgeFunctionError,
  errorResponse,
  generateTemporaryPassword,
  jsonResponse,
  loadTenantOwnerAccountState,
  preflightResponse,
  requireSuperAdmin,
  tenantOwnerOnboardingPendingFlag,
  tenantOwnerOnboardingRequestId,
  temporaryPasswordResetFlag,
} from "../_shared/tenant_onboarding.ts";

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
    await requireSuperAdmin(clients.caller);
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
  const name = typeof request.name === "string" ? request.name.trim() : "";
  const email =
    typeof request.ownerEmail === "string"
      ? request.ownerEmail.trim().toLowerCase()
      : "";
  const requestId =
    typeof request.requestId === "string" ? request.requestId : "";

  if (
    name.length < 1 ||
    name.length > 120 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(requestId)
  ) {
    return jsonResponse({ code: "invalid_request" }, 400);
  }

  let passwordForRecovery: string | null = null;
  try {
    let account = await loadTenantOwnerAccountState(clients.admin, email);
    let temporaryPassword: string | null = null;
    let rotateTemporaryPassword = false;

    if (account === null) {
      const generatedPassword = generateTemporaryPassword();
      const { data, error } = await clients.admin.auth.admin.createUser({
        email,
        password: generatedPassword,
        email_confirm: true,
        app_metadata: {
          [temporaryPasswordResetFlag]: true,
          [tenantOwnerOnboardingPendingFlag]: true,
          [tenantOwnerOnboardingRequestId]: requestId,
        },
      });

      if (error === null && data.user !== null) {
        account = {
          userId: data.user.id,
          temporaryPasswordResetRequired: true,
          onboardingPending: true,
          onboardingRequestId: requestId,
        };
        temporaryPassword = generatedPassword;
        passwordForRecovery = generatedPassword;
      } else {
        account = await loadTenantOwnerAccountState(clients.admin, email);
        if (account === null) {
          return jsonResponse(
            { code: "owner_account_creation_failed" },
            409,
          );
        }
      }
    }

    let effectiveRequestId = requestId;
    if (
      account.temporaryPasswordResetRequired &&
      account.onboardingPending
    ) {
      if (
        account.onboardingRequestId === null ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
          .test(account.onboardingRequestId)
      ) {
        throw new EdgeFunctionError(409, "owner_onboarding_state_invalid");
      }

      effectiveRequestId = account.onboardingRequestId;
      if (temporaryPassword === null) {
        rotateTemporaryPassword = true;
      }
    }

    const { data: tenant, error: tenantError } = await clients.caller.rpc(
      "create_tenant_for_request",
      {
        p_name: name,
        p_owner_email: email,
        p_request_id: effectiveRequestId,
      },
    );
    if (tenantError !== null) {
      if (temporaryPassword !== null) {
        return jsonResponse(
          {
            code: "tenant_creation_incomplete",
            temporaryPassword,
          },
          502,
        );
      }

      const code =
        tenantError.code === "42501"
          ? "super_admin_required"
          : tenantError.code === "P0002"
            ? "owner_account_not_found"
            : tenantError.code === "22023"
              ? "invalid_request"
              : tenantError.code === "PGRST202" ||
                  tenantError.code === "PGRST203"
                ? "tenant_setup_incomplete"
                : "tenant_creation_failed";
      const status =
        code === "super_admin_required"
          ? 403
          : code === "owner_account_not_found"
            ? 404
            : code === "invalid_request"
              ? 400
              : code === "tenant_setup_incomplete"
                ? 503
                : 502;
      return jsonResponse({ code }, status);
    }

    if (
      typeof tenant !== "object" ||
      tenant === null ||
      typeof tenant.id !== "string" ||
      typeof tenant.name !== "string" ||
      typeof tenant.slug !== "string"
    ) {
      if (temporaryPassword !== null) {
        return jsonResponse(
          {
            code: "tenant_creation_incomplete",
            temporaryPassword,
          },
          502,
        );
      }
      return jsonResponse({ code: "tenant_creation_failed" }, 502);
    }

    if (rotateTemporaryPassword) {
      const generatedPassword = generateTemporaryPassword();
      const { error } = await clients.admin.auth.admin.updateUserById(
        account.userId,
        { password: generatedPassword },
      );
      if (error !== null) {
        return jsonResponse(
          { code: "temporary_password_rotation_failed" },
          503,
        );
      }
      temporaryPassword = generatedPassword;
      passwordForRecovery = generatedPassword;
    }

    return jsonResponse({
      success: true,
      tenant: { id: tenant.id, name: tenant.name, slug: tenant.slug },
      ...(temporaryPassword === null ? {} : { temporaryPassword }),
    });
  } catch (error) {
    if (passwordForRecovery !== null) {
      return jsonResponse(
        {
          code: "tenant_creation_incomplete",
          temporaryPassword: passwordForRecovery,
        },
        502,
      );
    }
    return errorResponse(error);
  }
});
