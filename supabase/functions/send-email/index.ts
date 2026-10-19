// Supabase Auth "Send Email" hook.
//
// When enabled (see supabase/config.toml [auth.hook.send_email]), Supabase
// Auth calls this function instead of its own rate-limited built-in email
// sender for every outgoing auth email (signup, invite, magic link,
// recovery, email change, reauthentication, and account notifications).
// This function verifies the request came from Supabase (Standard Webhooks
// signature), builds an appropriate message, and sends it through Brevo's
// free-tier transactional email API.
//
// For the "recovery" action specifically, it also enforces an
// application-level cap of 6 recovery emails per account per UTC day via
// record_password_reset_attempt(), independent of Supabase's own built-in
// email rate limits.
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import {
  createClient,
} from "npm:@supabase/supabase-js@2.118.0";

const BREVO_API_URL = "https://api.brevo.com/v3/smtp/email";
const DAILY_RECOVERY_EMAIL_LIMIT = 6;

const rawHookSecret = Deno.env.get("SEND_EMAIL_HOOK_SECRET") ?? "";
const hookSecret = rawHookSecret.startsWith("v1,whsec_")
  ? rawHookSecret.slice("v1,whsec_".length)
  : rawHookSecret.startsWith("whsec_")
    ? rawHookSecret.slice("whsec_".length)
    : rawHookSecret;

const brevoApiKey = Deno.env.get("BREVO_API_KEY") ?? "";
const senderEmail = Deno.env.get("EMAIL_SENDER_ADDRESS") ?? "";
const senderName = Deno.env.get("EMAIL_SENDER_NAME") ?? "Parking Management";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
// Auto-injected by Supabase for every Edge Function. Required as the
// `apikey` query param on hand-built /auth/v1/verify links: Supabase's API
// gateway rejects any request to *.supabase.co (including user-clicked
// email links) that lacks an apikey, even though GoTrue's own default
// email templates handle this transparently.
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

interface EmailData {
  token: string;
  token_hash: string;
  redirect_to: string;
  email_action_type: string;
  site_url: string;
  token_new?: string;
  token_hash_new?: string;
}

interface HookUser {
  email: string;
  new_email?: string;
}

interface HookPayload {
  user: HookUser;
  email_data: EmailData;
}

interface ComposedMessage {
  to: string;
  subject: string;
  html: string;
  text: string;
}

function jsonError(
  status: number,
  message: string,
  cause?: unknown,
): Response {
  if (cause !== undefined) {
    // Never log tokens/secrets: log only the error message/shape.
    console.error(message, cause instanceof Error ? cause.message : cause);
  }
  return new Response(
    JSON.stringify({ error: { http_code: status, message } }),
    { status, headers: { "Content-Type": "application/json" } },
  );
}

function verifyLink(
  base: string,
  tokenHash: string,
  actionType: string,
  redirectTo: string,
): string {
  // Defensive: the hook payload's `site_url` field has been observed to
  // already be GoTrue's internal API base (ending in `/auth/v1`) rather than
  // the dashboard "Site URL". Strip any such suffix so we never build a
  // doubled `/auth/v1/auth/v1/verify` path regardless of which base is
  // passed in.
  const normalizedBase = base.replace(/\/+$/, "").replace(/\/auth\/v1$/, "");
  const url = new URL(`${normalizedBase}/auth/v1/verify`);
  url.searchParams.set("token", tokenHash);
  url.searchParams.set("type", actionType);
  url.searchParams.set("redirect_to", redirectTo);
  if (supabaseAnonKey.length > 0) {
    url.searchParams.set("apikey", supabaseAnonKey);
  }
  return url.toString();
}

function wrapHtml(title: string, bodyHtml: string): string {
  return `<!DOCTYPE html>
<html>
  <body style="font-family: Arial, sans-serif; color: #1f2933; line-height: 1.5;">
    <h2 style="margin-bottom: 16px;">${title}</h2>
    ${bodyHtml}
    <p style="margin-top: 24px; font-size: 12px; color: #6b7280;">
      Parking Management
    </p>
  </body>
</html>`;
}

function buildEmailMessage(
  user: HookUser,
  data: EmailData,
  baseUrl: string,
): ComposedMessage {
  const actionType = data.email_action_type;

  switch (actionType) {
    case "recovery": {
      const link = verifyLink(baseUrl, data.token_hash, actionType, data.redirect_to);
      return {
        to: user.email,
        subject: "Reset your Parking Management password",
        html: wrapHtml(
          "Reset your password",
          `<p>We received a request to reset your password. Click the button below to choose a new one.</p>
           <p><a href="${link}" style="display:inline-block;padding:10px 18px;background:#2563eb;color:#fff;border-radius:6px;text-decoration:none;">Reset password</a></p>
           <p>If you didn't request this, you can safely ignore this email. This link will expire and can only be used once.</p>`,
        ),
        text: `Reset your password: ${link}\n\nIf you didn't request this, you can safely ignore this email.`,
      };
    }
    case "signup": {
      const link = verifyLink(baseUrl, data.token_hash, actionType, data.redirect_to);
      return {
        to: user.email,
        subject: "Confirm your Parking Management account",
        html: wrapHtml(
          "Confirm your account",
          `<p>Click the button below to confirm your email address and activate your account.</p>
           <p><a href="${link}" style="display:inline-block;padding:10px 18px;background:#2563eb;color:#fff;border-radius:6px;text-decoration:none;">Confirm account</a></p>`,
        ),
        text: `Confirm your account: ${link}`,
      };
    }
    case "invite": {
      const link = verifyLink(baseUrl, data.token_hash, actionType, data.redirect_to);
      return {
        to: user.email,
        subject: "You've been invited to Parking Management",
        html: wrapHtml(
          "You're invited",
          `<p>You've been invited to join Parking Management. Click below to accept and set up your account.</p>
           <p><a href="${link}" style="display:inline-block;padding:10px 18px;background:#2563eb;color:#fff;border-radius:6px;text-decoration:none;">Accept invite</a></p>`,
        ),
        text: `Accept your invite: ${link}`,
      };
    }
    case "magiclink": {
      const link = verifyLink(baseUrl, data.token_hash, actionType, data.redirect_to);
      return {
        to: user.email,
        subject: "Your Parking Management sign-in link",
        html: wrapHtml(
          "Sign in",
          `<p>Click the button below to sign in.</p>
           <p><a href="${link}" style="display:inline-block;padding:10px 18px;background:#2563eb;color:#fff;border-radius:6px;text-decoration:none;">Sign in</a></p>
           <p>If you didn't request this, you can safely ignore this email.</p>`,
        ),
        text: `Sign in: ${link}\n\nIf you didn't request this, you can safely ignore this email.`,
      };
    }
    case "email_change": {
      // Field names are swapped for backward compatibility: token_hash_new
      // pairs with the *current* email, token_hash pairs with the *new*
      // email.
      const currentEmailLink = verifyLink(
        baseUrl,
        data.token_hash_new ?? "",
        actionType,
        data.redirect_to,
      );
      return {
        to: user.email,
        subject: "Confirm your Parking Management email change",
        html: wrapHtml(
          "Confirm email change",
          `<p>Click below to confirm changing your account email.</p>
           <p><a href="${currentEmailLink}" style="display:inline-block;padding:10px 18px;background:#2563eb;color:#fff;border-radius:6px;text-decoration:none;">Confirm change</a></p>
           <p>If you didn't request this, please secure your account.</p>`,
        ),
        text: `Confirm your email change: ${currentEmailLink}`,
      };
    }
    case "reauthentication": {
      return {
        to: user.email,
        subject: "Your Parking Management confirmation code",
        html: wrapHtml(
          "Confirmation code",
          `<p>Use this code to confirm your action:</p>
           <p style="font-size:24px;font-weight:bold;letter-spacing:2px;">${data.token}</p>`,
        ),
        text: `Your confirmation code: ${data.token}`,
      };
    }
    default: {
      // Account-activity notification types (password_changed_notification,
      // email_changed_notification, identity_linked_notification, etc.)
      // carry no actionable link, just inform the user.
      return {
        to: user.email,
        subject: "Parking Management account notification",
        html: wrapHtml(
          "Account notification",
          `<p>There was a change on your Parking Management account (${actionType.replaceAll("_", " ")}).</p>
           <p>If this wasn't you, please contact your administrator.</p>`,
        ),
        text: `Account notification: ${actionType.replaceAll("_", " ")}. If this wasn't you, please contact your administrator.`,
      };
    }
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return jsonError(405, "method_not_allowed");
  }

  if (
    hookSecret.length === 0 ||
    brevoApiKey.length === 0 ||
    senderEmail.length === 0 ||
    supabaseUrl.length === 0
  ) {
    return jsonError(500, "server_configuration_error");
  }

  const rawBody = await req.text();
  const headers = Object.fromEntries(req.headers);

  let payload: HookPayload;
  try {
    const webhook = new Webhook(hookSecret);
    payload = webhook.verify(rawBody, headers) as unknown as HookPayload;
  } catch (error) {
    return jsonError(401, "invalid_signature", error);
  }

  const { user, email_data: emailData } = payload;
  if (
    typeof user?.email !== "string" ||
    user.email.length === 0 ||
    typeof emailData?.email_action_type !== "string"
  ) {
    return jsonError(400, "invalid_payload");
  }

  if (emailData.email_action_type === "recovery" && serviceRoleKey.length > 0) {
    try {
      const admin = createClient(supabaseUrl, serviceRoleKey, {
        auth: {
          autoRefreshToken: false,
          detectSessionInUrl: false,
          persistSession: false,
        },
      });
      const { data: attemptCount, error: attemptError } = await admin.rpc(
        "record_password_reset_attempt",
        { p_email: user.email },
      );
      if (attemptError === null && typeof attemptCount === "number") {
        if (attemptCount > DAILY_RECOVERY_EMAIL_LIMIT) {
          return jsonError(429, "too_many_requests");
        }
      }
      // If the RPC call itself fails (e.g. migration not yet applied), fail
      // open rather than blocking all recovery emails on an infra gap.
    } catch (error) {
      console.error("password_reset_rate_limit_check_failed", error);
    }
  }

  let message: ComposedMessage;
  try {
    // Always build the verify link from the project's API base (SUPABASE_URL),
    // not emailData.site_url: that hook field has been observed to already
    // contain GoTrue's internal "/auth/v1" base rather than the dashboard
    // Site URL, which produced a doubled "/auth/v1/auth/v1/verify" path.
    message = buildEmailMessage(user, emailData, supabaseUrl);
  } catch (error) {
    return jsonError(400, "unsupported_email_action_type", error);
  }

  let brevoResponse: Response;
  try {
    brevoResponse = await fetch(BREVO_API_URL, {
      method: "POST",
      headers: {
        "api-key": brevoApiKey,
        "content-type": "application/json",
        accept: "application/json",
      },
      body: JSON.stringify({
        sender: { email: senderEmail, name: senderName },
        to: [{ email: message.to }],
        subject: message.subject,
        htmlContent: message.html,
        textContent: message.text,
      }),
    });
  } catch (error) {
    return jsonError(502, "email_provider_unreachable", error);
  }

  if (!brevoResponse.ok) {
    let detail = "";
    try {
      detail = await brevoResponse.text();
    } catch {
      detail = "";
    }
    return jsonError(502, "email_provider_error", detail);
  }

  return new Response(JSON.stringify({}), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
