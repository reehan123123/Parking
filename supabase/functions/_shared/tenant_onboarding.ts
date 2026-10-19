import {
  createClient,
  type SupabaseClient,
  type User,
} from "npm:@supabase/supabase-js@2.118.0";

export const temporaryPasswordResetFlag =
  "parking_temporary_password_reset_required";
export const tenantOwnerOnboardingPendingFlag =
  "parking_tenant_owner_onboarding_pending";
export const tenantOwnerOnboardingRequestId =
  "parking_tenant_owner_onboarding_request_id";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

export type EdgeSupabaseClient = SupabaseClient;

export interface TenantOwnerAccountState {
  userId: string;
  temporaryPasswordResetRequired: boolean;
  onboardingPending: boolean;
  onboardingRequestId: string | null;
}

export class EdgeFunctionError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
  ) {
    super(code);
  }
}

export function preflightResponse(req: Request): Response | null {
  if (req.method !== "OPTIONS") {
    return null;
  }

  return new Response("ok", { headers: corsHeaders });
}

export function jsonResponse(
  value: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: corsHeaders,
  });
}

export function errorResponse(error: unknown): Response {
  if (error instanceof EdgeFunctionError) {
    return jsonResponse({ code: error.code }, error.status);
  }

  return jsonResponse({ code: "internal_error" }, 500);
}

export async function createAuthenticatedClients(req: Request): Promise<{
  caller: EdgeSupabaseClient;
  admin: EdgeSupabaseClient;
  user: User;
}> {
  const authorization = req.headers.get("Authorization");
  if (authorization === null || !authorization.startsWith("Bearer ")) {
    throw new EdgeFunctionError(401, "authentication_required");
  }

  const projectUrl = requiredEnvironmentValue("SUPABASE_URL");
  const publishableKey = defaultApiKey(
    "SUPABASE_PUBLISHABLE_KEYS",
    "SUPABASE_ANON_KEY",
  );
  const secretKey = defaultApiKey(
    "SUPABASE_SECRET_KEYS",
    "SUPABASE_SERVICE_ROLE_KEY",
  );

  const caller = createClient(projectUrl, publishableKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
    global: { headers: { Authorization: authorization } },
  });
  const admin = createClient(projectUrl, secretKey, {
    auth: {
      autoRefreshToken: false,
      detectSessionInUrl: false,
      persistSession: false,
    },
  });

  const { data, error } = await caller.auth.getUser();
  if (error !== null || data.user === null) {
    throw new EdgeFunctionError(401, "authentication_required");
  }

  return { caller, admin, user: data.user };
}

export async function requireSuperAdmin(
  caller: EdgeSupabaseClient,
): Promise<void> {
  const { data, error } = await caller.rpc("is_super_admin");
  if (error !== null) {
    throw new EdgeFunctionError(503, "tenant_setup_incomplete");
  }
  if (data !== true) {
    throw new EdgeFunctionError(403, "super_admin_required");
  }
}

export async function loadTenantOwnerAccountState(
  admin: EdgeSupabaseClient,
  email: string,
): Promise<TenantOwnerAccountState | null> {
  const { data, error } = await admin.rpc(
    "tenant_owner_onboarding_state",
    { p_email: email },
  );
  if (error !== null || !Array.isArray(data)) {
    throw new EdgeFunctionError(503, "tenant_setup_incomplete");
  }
  if (data.length === 0) {
    return null;
  }

  const row = data[0];
  if (
    typeof row !== "object" ||
    row === null ||
    typeof row.user_id !== "string"
  ) {
    throw new EdgeFunctionError(503, "tenant_setup_incomplete");
  }

  return {
    userId: row.user_id,
    temporaryPasswordResetRequired:
      row.temporary_password_reset_required === true,
    onboardingPending: row.tenant_owner_onboarding_pending === true,
    onboardingRequestId:
      typeof row.tenant_owner_onboarding_request_id === "string"
        ? row.tenant_owner_onboarding_request_id
        : null,
  };
}

export function generateTemporaryPassword(): string {
  const lowerCase = "abcdefghijkmnopqrstuvwxyz";
  const upperCase = "ABCDEFGHJKLMNPQRSTUVWXYZ";
  const digits = "23456789";
  const symbols = "!@#$%*-_=+?";
  const allCharacters = lowerCase + upperCase + digits + symbols;
  const passwordCharacters = [
    randomCharacter(lowerCase),
    randomCharacter(upperCase),
    randomCharacter(digits),
    randomCharacter(symbols),
  ];

  while (passwordCharacters.length < 24) {
    passwordCharacters.push(randomCharacter(allCharacters));
  }

  for (let index = passwordCharacters.length - 1; index > 0; index--) {
    const swapIndex = randomInteger(index + 1);
    [passwordCharacters[index], passwordCharacters[swapIndex]] = [
      passwordCharacters[swapIndex],
      passwordCharacters[index],
    ];
  }

  return passwordCharacters.join("");
}

function randomCharacter(characters: string): string {
  return characters[randomInteger(characters.length)];
}

function randomInteger(maximum: number): number {
  const range = 0x1_0000_0000;
  const limit = Math.floor(range / maximum) * maximum;
  const value = new Uint32Array(1);

  do {
    crypto.getRandomValues(value);
  } while (value[0] >= limit);

  return value[0] % maximum;
}

function defaultApiKey(environmentName: string, legacyName: string): string {
  const namedKeys = Deno.env.get(environmentName);
  if (namedKeys !== undefined) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(namedKeys);
    } catch {
      throw new EdgeFunctionError(500, "server_configuration_error");
    }

    if (typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)) {
      const defaultKey = (parsed as Record<string, unknown>).default;
      if (typeof defaultKey === "string" && defaultKey.length > 0) {
        return defaultKey;
      }
    }
  }

  const legacyKey = Deno.env.get(legacyName);
  if (legacyKey !== undefined && legacyKey.length > 0) {
    return legacyKey;
  }

  throw new EdgeFunctionError(500, "server_configuration_error");
}

function requiredEnvironmentValue(name: string): string {
  const value = Deno.env.get(name);
  if (value === undefined || value.length === 0) {
    throw new EdgeFunctionError(500, "server_configuration_error");
  }

  return value;
}
