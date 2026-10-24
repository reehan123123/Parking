const oneSignalNotificationsUrl =
  "https://api.onesignal.com/notifications";
const maximumRecipientCount = 20_000;
const maximumAttempts = 3;
const maximumInlineRetryDelayMilliseconds = 1_000;
const requestTimeoutMilliseconds = 10_000;

const sessionIdPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export interface OneSignalNotificationInput {
  appId: string;
  apiKey: string;
  recipientExternalIds: string[];
  sessionId: string;
  idempotencyKey: string;
  applicationOrigin: string;
}

export interface OneSignalSenderDependencies {
  fetcher: typeof fetch;
  now: () => number;
  wait: (milliseconds: number) => Promise<void>;
}

export interface OneSignalSendResult {
  delivered: boolean;
  httpStatus: number | null;
  messageId: string | null;
  errorCode: OneSignalErrorCode | null;
  retryAfter: string | null;
}

type OneSignalErrorCode =
  | "rate_limited"
  | "upstream_5xx"
  | "upstream_4xx"
  | "invalid_response"
  | "network_error"
  | "recipient_limit"
  | "configuration_error"
  | "delivery_failed";

interface OneSignalResponse {
  id?: unknown;
}

export async function sendParkingNotification(
  input: OneSignalNotificationInput,
  dependencies: OneSignalSenderDependencies,
): Promise<OneSignalSendResult> {
  if (input.recipientExternalIds.length > maximumRecipientCount) {
    return failedResult(null, "recipient_limit", null);
  }

  if (
    !sessionIdPattern.test(input.appId) ||
    !sessionIdPattern.test(input.sessionId) ||
    !sessionIdPattern.test(input.idempotencyKey) ||
    input.apiKey.trim().length === 0 ||
    input.recipientExternalIds.length === 0 ||
    input.recipientExternalIds.some((userId) => !sessionIdPattern.test(userId))
  ) {
    return failedResult(null, "configuration_error", null);
  }

  const applicationUrl = createSessionUrl(
    input.applicationOrigin,
    input.sessionId,
  );
  if (applicationUrl === null) {
    return failedResult(null, "configuration_error", null);
  }

  const payload = {
    app_id: input.appId,
    target_channel: "push",
    include_aliases: {
      external_id: input.recipientExternalIds,
    },
    headings: {
      en: "Parking Expired",
      hi: "पार्किंग का समय समाप्त हो गया",
    },
    contents: {
      en: "Full-Amount Not Paid",
      hi: "पूरा भुगतान नहीं हुआ।",
    },
    url: applicationUrl,
    idempotency_key: input.idempotencyKey,
  };

  for (let attempt = 1; attempt <= maximumAttempts; attempt++) {
    let response: Response;
    try {
      response = await dependencies.fetcher(oneSignalNotificationsUrl, {
        method: "POST",
        headers: {
          Accept: "application/json",
          Authorization: `Key ${input.apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(payload),
        signal: AbortSignal.timeout(requestTimeoutMilliseconds),
      });
    } catch {
      if (attempt === maximumAttempts) {
        return failedResult(null, "network_error", null);
      }

      await dependencies.wait(250 * 2 ** (attempt - 1));
      continue;
    }

    if (response.ok) {
      const result = await readSuccessResponse(response);
      if (result !== null) {
        return {
          delivered: true,
          httpStatus: response.status,
          messageId: result,
          errorCode: null,
          retryAfter: null,
        };
      }

      if (attempt === maximumAttempts) {
        return failedResult(response.status, "invalid_response", null);
      }

      await dependencies.wait(250 * 2 ** (attempt - 1));
      continue;
    }

    const retryAt = parseRetryAfter(
      response.headers.get("Retry-After"),
      dependencies.now(),
    );
    const isRetryable = response.status === 429 || response.status >= 500;
    if (!isRetryable) {
      return failedResult(response.status, "upstream_4xx", null);
    }

    if (retryAt !== null) {
      const waitMilliseconds = Date.parse(retryAt) - dependencies.now();
      if (
        waitMilliseconds > maximumInlineRetryDelayMilliseconds ||
        attempt === maximumAttempts
      ) {
        return failedResult(
          response.status,
          response.status === 429 ? "rate_limited" : "upstream_5xx",
          retryAt,
        );
      }

      await dependencies.wait(Math.max(0, waitMilliseconds));
      continue;
    }

    if (attempt === maximumAttempts) {
      return failedResult(
        response.status,
        response.status === 429 ? "rate_limited" : "upstream_5xx",
        null,
      );
    }

    await dependencies.wait(250 * 2 ** (attempt - 1));
  }

  return failedResult(null, "delivery_failed", null);
}

function createSessionUrl(
  applicationOrigin: string,
  sessionId: string,
): string | null {
  try {
    const origin = new URL(applicationOrigin);
    if (
      origin.protocol !== "https:" ||
      origin.username !== "" ||
      origin.password !== "" ||
      origin.pathname !== "/" ||
      origin.search !== "" ||
      origin.hash !== ""
    ) {
      return null;
    }

    origin.searchParams.set("parkingSessionId", sessionId);
    return origin.toString();
  } catch {
    return null;
  }
}

async function readSuccessResponse(response: Response): Promise<string | null> {
  try {
    const value = await response.json() as OneSignalResponse;
    return typeof value.id === "string" && value.id.length <= 128
      ? value.id
      : null;
  } catch {
    return null;
  }
}

function parseRetryAfter(value: string | null, now: number): string | null {
  if (value === null || value.trim().length === 0) {
    return null;
  }

  const seconds = Number(value);
  const retryAt = Number.isFinite(seconds)
    ? now + Math.max(0, seconds) * 1_000
    : Date.parse(value);
  if (!Number.isFinite(retryAt) || retryAt <= now) {
    return null;
  }

  return new Date(retryAt).toISOString();
}

function failedResult(
  httpStatus: number | null,
  errorCode: OneSignalErrorCode,
  retryAfter: string | null,
): OneSignalSendResult {
  return {
    delivered: false,
    httpStatus,
    messageId: null,
    errorCode,
    retryAfter,
  };
}
