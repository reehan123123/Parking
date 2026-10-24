import { sendParkingNotification } from "./onesignal_sender.ts";

const appId = "11111111-1111-4111-8111-111111111111";
const sessionId = "22222222-2222-4222-8222-222222222222";
const userId = "33333333-3333-4333-8333-333333333333";
const idempotencyKey = "44444444-4444-4444-8444-444444444444";
const messageId = "55555555-5555-4555-8555-555555555555";

Deno.test("targets only external IDs with a generic session link", async () => {
  let requestUrl = "";
  let requestInit: RequestInit | undefined;

  const result = await sendParkingNotification(
    {
      appId,
      apiKey: "server-only-test-key",
      recipientExternalIds: [userId],
      sessionId,
      plateNumber: "REMINDER-PARTIAL",
      idempotencyKey,
      applicationOrigin: "https://parking-85u.pages.dev",
    },
    {
      fetcher: async (input, init) => {
        requestUrl = String(input);
        requestInit = init;
        return Response.json({ id: messageId });
      },
      now: () => 0,
      wait: async () => {},
    },
  );

  const requestBody = JSON.parse(String(requestInit?.body));
  assert(result.delivered, "the OneSignal request should succeed");
  assertEquals(requestUrl, "https://api.onesignal.com/notifications");
  assertEquals(requestInit?.method, "POST");
  assertEquals(
    new Headers(requestInit?.headers).get("Authorization"),
    "Key server-only-test-key",
  );
  assertEquals(requestBody.app_id, appId);
  assertEquals(requestBody.target_channel, "push");
  assertEquals(requestBody.include_aliases.external_id, [userId]);
  assertEquals(
    requestBody.url,
    `https://parking-85u.pages.dev/?parkingSessionId=${sessionId}`,
  );
  assertEquals(requestBody.idempotency_key, idempotencyKey);
  assertEquals(requestBody.headings.en, "Parking Expired - REMINDE...");
  assertEquals(requestBody.contents.en, "Full-Amount Not Paid");
  assert(
    requestInit?.signal instanceof AbortSignal,
    "the OneSignal request should have a bounded timeout",
  );
  assert(
    !JSON.stringify(requestBody).includes("server-only-test-key"),
    "the API key must not be included in the request payload",
  );
  assert(!("tenant_id" in requestBody), "the push must not contain a tenant id");
  assert(!("amount" in requestBody), "the push must not contain payment data");
  assert(
    !JSON.stringify(requestBody).includes("REMINDER-PARTIAL"),
    "the push must include only the first seven registration characters",
  );
});

Deno.test("honors a long Retry-After without retrying early", async () => {
  let requestCount = 0;

  const result = await sendParkingNotification(
    validInput(),
    {
      fetcher: async () => {
        requestCount++;
        return new Response(null, {
          status: 429,
          headers: { "Retry-After": "30" },
        });
      },
      now: () => Date.parse("2026-10-25T10:00:00.000Z"),
      wait: async () => {},
    },
  );

  assertEquals(requestCount, 1);
  assertEquals(result.errorCode, "rate_limited");
  assertEquals(result.retryAfter, "2026-10-25T10:00:30.000Z");
});

Deno.test("retries transient failures with the same idempotency key", async () => {
  let requestCount = 0;
  const idempotencyKeys: string[] = [];

  const result = await sendParkingNotification(
    validInput(),
    {
      fetcher: async (_input, init) => {
        requestCount++;
        idempotencyKeys.push(
          JSON.parse(String(init?.body)).idempotency_key,
        );
        return requestCount < 3
          ? new Response(null, { status: 503 })
          : Response.json({ id: messageId });
      },
      now: () => 0,
      wait: async () => {},
    },
  );

  assert(result.delivered, "a transient failure should be retried");
  assertEquals(requestCount, 3);
  assertEquals(idempotencyKeys, [idempotencyKey, idempotencyKey, idempotencyKey]);
});

Deno.test("does not retry permanent client errors", async () => {
  let requestCount = 0;

  const result = await sendParkingNotification(
    validInput(),
    {
      fetcher: async () => {
        requestCount++;
        return new Response(null, { status: 401 });
      },
      now: () => 0,
      wait: async () => {},
    },
  );

  assertEquals(requestCount, 1);
  assertEquals(result.errorCode, "upstream_4xx");
  assertEquals(result.httpStatus, 401);
});

Deno.test("rejects recipient lists beyond OneSignal's alias limit", async () => {
  let requestCount = 0;
  const recipientExternalIds = Array.from(
    { length: 20_001 },
    () => userId,
  );

  const result = await sendParkingNotification(
    { ...validInput(), recipientExternalIds },
    {
      fetcher: async () => {
        requestCount++;
        return Response.json({ id: messageId });
      },
      now: () => 0,
      wait: async () => {},
    },
  );

  assertEquals(requestCount, 0);
  assertEquals(result.errorCode, "recipient_limit");
});

function validInput() {
  return {
    appId,
    apiKey: "server-only-test-key",
    recipientExternalIds: [userId],
    sessionId,
    plateNumber: "REMINDER-PARTIAL",
    idempotencyKey,
    applicationOrigin: "https://parking-85u.pages.dev",
  };
}

function assert(condition: boolean, message: string): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

function assertEquals(actual: unknown, expected: unknown): void {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`Expected ${expectedJson}; got ${actualJson}.`);
  }
}
