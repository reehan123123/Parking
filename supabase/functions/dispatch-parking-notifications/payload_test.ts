import { buildParkingNotificationPayload } from "./payload.ts";

Deno.test("builds an English 90-percent reminder with the unpaid amount", () => {
  const payload = buildParkingNotificationPayload({
    notificationType: "ninety_percent",
    sessionId: "11111111-1111-4111-8111-111111111111",
    tenantId: "22222222-2222-4222-8222-222222222222",
    remainingBalance: 1234.5,
    locale: "en",
  });

  assertEqual(payload.title, "Parking is nearing expiry");
  assertIncludes(payload.body, "Outstanding amount:");
  assertIncludes(
    payload.body,
    new Intl.NumberFormat("en-IN", {
      style: "currency",
      currency: "INR",
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    }).format(1234.5),
  );
  assertEqual(payload.requireInteraction, false);
  assertEqual("canMarkPaid" in payload, false);
  assertEqual("fullPaidAction" in payload, false);
  assertEqual(
    JSON.stringify(payload.data),
    JSON.stringify({
      sessionId: "11111111-1111-4111-8111-111111111111",
      tenantId: "22222222-2222-4222-8222-222222222222",
      notificationType: "ninety_percent",
    }),
  );
});

Deno.test("uses the requested English text for expired notices", () => {
  const payload = buildParkingNotificationPayload({
    notificationType: "expired",
    sessionId: "33333333-3333-4333-8333-333333333333",
    tenantId: "44444444-4444-4444-8444-444444444444",
    remainingBalance: 25,
    locale: "en",
  });

  assertEqual(payload.title, "Parking Expired");
  assertEqual(payload.body, "Full-Amount Not Paid");
  assertEqual(payload.requireInteraction, true);
  assertEqual("canMarkPaid" in payload, false);
  assertEqual("fullPaidAction" in payload, false);
});

Deno.test("localizes Hindi expiry notices without a payment action", () => {
  const payload = buildParkingNotificationPayload({
    notificationType: "expired",
    sessionId: "33333333-3333-4333-8333-333333333333",
    tenantId: "44444444-4444-4444-8444-444444444444",
    remainingBalance: 25,
    locale: "hi",
  });

  assertEqual(payload.title, "पार्किंग का समय समाप्त हो गया");
  assertEqual(payload.body, "पूरा भुगतान नहीं हुआ।");
  assertEqual(payload.languageCode, "hi");
  assertEqual(payload.requireInteraction, true);
});

Deno.test("rejects an empty or invalid unpaid balance", () => {
  let didThrow = false;
  try {
    buildParkingNotificationPayload({
      notificationType: "expired",
      sessionId: "11111111-1111-4111-8111-111111111111",
      tenantId: "22222222-2222-4222-8222-222222222222",
      remainingBalance: 0,
      locale: "en",
    });
  } catch (error) {
    didThrow = error instanceof RangeError;
  }
  assertEqual(didThrow, true);
});

function assertEqual<T>(actual: T, expected: T): void {
  if (actual !== expected) {
    throw new Error(`Expected ${String(expected)}, got ${String(actual)}.`);
  }
}

function assertIncludes(actual: string, expected: string): void {
  if (!actual.includes(expected)) {
    throw new Error(`Expected "${actual}" to include "${expected}".`);
  }
}
