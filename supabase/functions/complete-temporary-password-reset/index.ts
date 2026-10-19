import {
  createAuthenticatedClients,
  errorResponse,
  jsonResponse,
  preflightResponse,
  temporaryPasswordResetFlag,
  tenantOwnerOnboardingPendingFlag,
  tenantOwnerOnboardingRequestId,
  EdgeFunctionError,
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

  const newPassword =
    typeof (body as Record<string, unknown>).newPassword === "string"
      ? (body as Record<string, string>).newPassword
      : "";
  if (newPassword.length < 12 || newPassword.length > 128) {
    return jsonResponse({ code: "invalid_password" }, 400);
  }

  try {
    const { data, error } = await clients.admin.auth.admin.getUserById(
      clients.user.id,
    );
    if (error !== null || data.user === null) {
      return jsonResponse({ code: "user_lookup_failed" }, 503);
    }

    if (data.user.app_metadata[temporaryPasswordResetFlag] !== true) {
      return jsonResponse({ code: "password_change_not_required" }, 409);
    }

    const appMetadata = {
      ...data.user.app_metadata,
      [temporaryPasswordResetFlag]: false,
      [tenantOwnerOnboardingPendingFlag]: false,
      [tenantOwnerOnboardingRequestId]: null,
    };
    const { error: updateError } =
      await clients.admin.auth.admin.updateUserById(clients.user.id, {
        password: newPassword,
        app_metadata: appMetadata,
      });
    if (updateError !== null) {
      throw new EdgeFunctionError(503, "password_update_failed");
    }

    return jsonResponse({ success: true });
  } catch (error) {
    return errorResponse(error);
  }
});
