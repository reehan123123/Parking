import { createClient, type SupabaseClient } from "@supabase/supabase-js";

import { defaultApiKey } from "../_shared/tenant_onboarding.ts";
import {
  sendParkingNotification,
  type OneSignalSendResult,
} from "./onesignal_sender.ts";

interface ClaimedNotificationEvent {
  event_id: string;
  session_id: string;
  tenant_id: string;
  claim_token: string;
  idempotency_key: string;
  attempt_count: number;
}

interface NotificationDispatchTarget {
  event_id: string;
  session_id: string;
  tenant_id: string;
  idempotency_key: string;
  recipient_external_ids: string[];
}

interface DispatchConfiguration {
  appId: string;
  apiKey: string;
  projectUrl: string;
  serviceRoleKey: string;
}

const requestHeader = "x-parking-notification-secret";
const maximumConcurrentEvents = 20;
const applicationOrigin = "https://parking-85u.pages.dev";

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") {
    return jsonResponse({ code: "method_not_allowed" }, 405);
  }

  const configuredSecret = Deno.env.get("PARKING_NOTIFICATION_CRON_SECRET");
  const suppliedSecret = request.headers.get(requestHeader);
  if (
    configuredSecret === undefined ||
    configuredSecret.length < 32 ||
    !secretsMatch(suppliedSecret, configuredSecret)
  ) {
    return jsonResponse({ code: "authentication_required" }, 401);
  }

  try {
    const configuration = loadConfiguration();

    const admin = createClient(
      configuration.projectUrl,
      configuration.serviceRoleKey,
      {
        auth: {
          autoRefreshToken: false,
          detectSessionInUrl: false,
          persistSession: false,
        },
      },
    );
    const { data, error } = await admin.rpc(
      "claim_due_parking_notification_events",
    );
    if (error !== null) {
      console.error(
        "Parking notification claim failed",
        error.code ?? "database_error",
      );
      return jsonResponse({ code: "notification_claim_failed" }, 503);
    }
    if (!Array.isArray(data)) {
      console.error("Parking notification claim returned invalid data");
      return jsonResponse({ code: "notification_claim_failed" }, 503);
    }

    const events = data as ClaimedNotificationEvent[];
    let sent = 0;
    let failed = 0;
    let skipped = 0;

    for (
      let offset = 0;
      offset < events.length;
      offset += maximumConcurrentEvents
    ) {
      const batch = events.slice(
        offset,
        offset + maximumConcurrentEvents,
      );
      const results = await Promise.allSettled(
        batch.map((event) => dispatchEvent(admin, configuration, event)),
      );
      for (const result of results) {
        if (result.status === "rejected") {
          failed++;
        } else if (result.value === "sent") {
          sent++;
        } else if (result.value === "skipped") {
          skipped++;
        } else {
          failed++;
        }
      }
    }

    return jsonResponse({
      claimed: events.length,
      sent,
      failed,
      skipped,
    });
  } catch (error) {
    console.error(
      "Parking notification dispatch failed",
      error instanceof Error ? error.name : "unknown_error",
    );
    return jsonResponse({ code: "notification_dispatch_failed" }, 500);
  }
});

async function dispatchEvent(
  admin: SupabaseClient,
  configuration: DispatchConfiguration,
  event: ClaimedNotificationEvent,
): Promise<"sent" | "failed" | "skipped"> {
  if (
    !isUuid(event.event_id) ||
    !isUuid(event.session_id) ||
    !isUuid(event.tenant_id) ||
    !isUuid(event.claim_token) ||
    !isUuid(event.idempotency_key)
  ) {
    await completeDispatch(
      admin,
      event,
      {
        delivered: false,
        httpStatus: null,
        messageId: null,
        errorCode: "delivery_failed",
        retryAfter: null,
      },
    );
    return "failed";
  }

  const { data, error } = await admin.rpc(
    "get_parking_notification_dispatch_target",
    {
      p_event_id: event.event_id,
      p_claim_token: event.claim_token,
    },
  );
  if (error !== null) {
    console.error(
      "Parking notification target lookup failed",
      error.code ?? "database_error",
    );
    return "failed";
  }

  if (!Array.isArray(data) || data.length === 0) {
    return "skipped";
  }
  const target = data[0] as NotificationDispatchTarget;
  if (
    target.event_id !== event.event_id ||
    target.session_id !== event.session_id ||
    target.tenant_id !== event.tenant_id ||
    target.idempotency_key !== event.idempotency_key ||
    !Array.isArray(target.recipient_external_ids) ||
    target.recipient_external_ids.length === 0 ||
    target.recipient_external_ids.length > 20_000 ||
    target.recipient_external_ids.some((userId) => !isUuid(userId))
  ) {
    await completeDispatch(
      admin,
      event,
      {
        delivered: false,
        httpStatus: null,
        messageId: null,
        errorCode: "recipient_limit",
        retryAfter: null,
      },
    );
    return "failed";
  }

  const result: OneSignalSendResult = await sendParkingNotification(
    {
      appId: configuration.appId,
      apiKey: configuration.apiKey,
      recipientExternalIds: target.recipient_external_ids,
      sessionId: target.session_id,
      idempotencyKey: target.idempotency_key,
      applicationOrigin,
    },
    {
      fetcher: fetch,
      now: Date.now,
      wait: delay,
    },
  );

  await completeDispatch(admin, event, {
    delivered: result.delivered,
    httpStatus: result.httpStatus,
    messageId: result.messageId,
    errorCode: result.errorCode,
    retryAfter: result.retryAfter,
  });
  return result.delivered ? "sent" : "failed";
}

async function completeDispatch(
  admin: SupabaseClient,
  event: ClaimedNotificationEvent,
  result: OneSignalSendResult,
): Promise<void> {
  const { data, error } = await admin.rpc(
    "complete_parking_notification_dispatch",
    {
      p_event_id: event.event_id,
      p_claim_token: event.claim_token,
      p_delivered: result.delivered,
      p_http_status: result.httpStatus,
      p_message_id: result.messageId,
      p_error_code: result.errorCode,
      p_retry_after: result.retryAfter,
    },
  );
  if (error !== null || data !== true) {
    throw new Error("notification_dispatch_result_update_failed");
  }
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function loadConfiguration(): DispatchConfiguration {
  const projectUrl = requiredEnvironmentValue("SUPABASE_URL");
  const serviceRoleKey = defaultApiKey(
    "SUPABASE_SECRET_KEYS",
    "SUPABASE_SERVICE_ROLE_KEY",
  );
  const appId = requiredEnvironmentValue("ONE_SIGNAL_APP_ID");
  const apiKey = requiredEnvironmentValue("ONE_SIGNAL_API_KEY");

  if (!isUuid(appId)) {
    throw new Error("server_configuration_error");
  }

  return { appId, apiKey, projectUrl, serviceRoleKey };
}

function requiredEnvironmentValue(name: string): string {
  const value = Deno.env.get(name);
  if (value === undefined || value.trim().length === 0) {
    throw new Error("server_configuration_error");
  }
  return value;
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

function secretsMatch(supplied: string | null, expected: string): boolean {
  if (supplied === null || supplied.length !== expected.length) {
    return false;
  }

  let difference = 0;
  for (let index = 0; index < expected.length; index++) {
    difference |= supplied.charCodeAt(index) ^ expected.charCodeAt(index);
  }
  return difference === 0;
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
