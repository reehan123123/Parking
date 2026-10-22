import { createClient, type SupabaseClient } from "@supabase/supabase-js";
// @deno-types="npm:@types/web-push@3.6.4"
import webPush from "web-push";

import { defaultApiKey } from "../_shared/tenant_onboarding.ts";
import {
  buildParkingNotificationPayload,
  type ParkingNotificationType,
} from "./payload.ts";

interface NotificationDelivery {
  delivery_id: string;
  subscription_id: string;
  session_id: string;
  tenant_id: string;
  notification_type: ParkingNotificationType;
  endpoint: string;
  p256dh_key: string;
  auth_key: string;
  locale: string;
  remaining_balance: number | string;
}

const requestHeader = "x-parking-notification-secret";
const maximumConcurrentDeliveries = 10;

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
    const projectUrl = requiredEnvironmentValue("SUPABASE_URL");
    const serviceRoleKey = defaultApiKey(
      "SUPABASE_SECRET_KEYS",
      "SUPABASE_SERVICE_ROLE_KEY",
    );
    const vapidPublicKey = requiredEnvironmentValue(
      "PARKING_VAPID_PUBLIC_KEY",
    );
    const vapidPrivateKey = requiredEnvironmentValue(
      "PARKING_VAPID_PRIVATE_KEY",
    );
    const vapidSubject = requiredEnvironmentValue("PARKING_VAPID_SUBJECT");

    webPush.setVapidDetails(
      vapidSubject,
      vapidPublicKey,
      vapidPrivateKey,
    );

    const admin = createClient(projectUrl, serviceRoleKey, {
      auth: {
        autoRefreshToken: false,
        detectSessionInUrl: false,
        persistSession: false,
      },
    });
    const { data, error } = await admin.rpc(
      "claim_due_parking_notification_deliveries",
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

    const deliveries = data as NotificationDelivery[];
    let delivered = 0;
    let failed = 0;
    let removedSubscriptions = 0;

    for (
      let offset = 0;
      offset < deliveries.length;
      offset += maximumConcurrentDeliveries
    ) {
      const batch = deliveries.slice(
        offset,
        offset + maximumConcurrentDeliveries,
      );
      const results = await Promise.allSettled(
        batch.map((delivery) => dispatchDelivery(admin, delivery)),
      );
      for (const result of results) {
        if (result.status === "rejected") {
          failed++;
        } else if (result.value === "delivered") {
          delivered++;
        } else if (result.value === "removed") {
          removedSubscriptions++;
        } else {
          failed++;
        }
      }
    }

    return jsonResponse({
      claimed: deliveries.length,
      delivered,
      failed,
      removedSubscriptions,
    });
  } catch (error) {
    console.error(
      "Parking notification dispatch failed",
      error instanceof Error ? error.name : "unknown_error",
    );
    return jsonResponse({ code: "notification_dispatch_failed" }, 500);
  }
});

async function dispatchDelivery(
  admin: SupabaseClient,
  delivery: NotificationDelivery,
): Promise<"delivered" | "failed" | "removed"> {
  const remainingBalance = Number(delivery.remaining_balance);
  if (
    !Number.isFinite(remainingBalance) ||
    remainingBalance <= 0 ||
    !isUuid(delivery.session_id) ||
    !isUuid(delivery.tenant_id) ||
    !isAllowedPushEndpoint(delivery.endpoint)
  ) {
    await updateDeliveryStatus(
      admin,
      delivery.delivery_id,
      "failed",
      "invalid_notification_data",
    );
    return "failed";
  }

  const payload = buildParkingNotificationPayload({
    notificationType: delivery.notification_type,
    sessionId: delivery.session_id,
    tenantId: delivery.tenant_id,
    remainingBalance,
    locale: delivery.locale,
  });

  try {
    await webPush.sendNotification(
      {
        endpoint: delivery.endpoint,
        keys: {
          p256dh: delivery.p256dh_key,
          auth: delivery.auth_key,
        },
      },
      JSON.stringify(payload),
      { TTL: 120, urgency: "normal" },
    );
  } catch (error) {
    const statusCode = readStatusCode(error);
    if (statusCode === 404 || statusCode === 410) {
      const { error: deleteError } = await admin
        .from("parking_push_subscriptions")
        .delete()
        .eq("id", delivery.subscription_id);
      if (deleteError !== null) {
        throw new Error("push_subscription_cleanup_failed");
      }
      return "removed";
    }

    await updateDeliveryStatus(
      admin,
      delivery.delivery_id,
      "failed",
      statusCode === null ? "push_delivery_failed" : `push_http_${statusCode}`,
    );
    return "failed";
  }

  await updateDeliveryStatus(
    admin,
    delivery.delivery_id,
    "sent",
    null,
  );
  return "delivered";
}

async function updateDeliveryStatus(
  admin: SupabaseClient,
  deliveryId: string,
  status: "sent" | "failed",
  errorCode: string | null,
): Promise<void> {
  const { error } = await admin
    .from("parking_notification_deliveries")
    .update({
      status,
      error_code: errorCode,
      delivered_at: status === "sent" ? new Date().toISOString() : null,
    })
    .eq("id", deliveryId)
    .eq("status", "sending");

  if (error !== null) {
    throw new Error("notification_delivery_status_update_failed");
  }
}

function readStatusCode(error: unknown): number | null {
  if (typeof error !== "object" || error === null || !("statusCode" in error)) {
    return null;
  }

  const statusCode = Number(error.statusCode);
  return Number.isInteger(statusCode) ? statusCode : null;
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function isAllowedPushEndpoint(endpoint: string): boolean {
  try {
    const url = new URL(endpoint);
    const host = url.hostname.toLowerCase();
    return url.protocol === "https:" &&
      url.port === "" &&
      url.username === "" &&
      url.password === "" &&
      (
        host === "fcm.googleapis.com" ||
        host === "updates.push.services.mozilla.com" ||
        host === "web.push.apple.com" ||
        host.endsWith(".notify.windows.com")
      );
  } catch {
    return false;
  }
}

function requiredEnvironmentValue(name: string): string {
  const value = Deno.env.get(name);
  if (value === undefined || value.trim().length === 0) {
    throw new Error("server_configuration_error");
  }
  return value;
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
