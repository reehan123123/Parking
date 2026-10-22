export type ParkingNotificationType = "ninety_percent" | "expired";

export interface ParkingNotificationPayloadInput {
  notificationType: ParkingNotificationType;
  sessionId: string;
  tenantId: string;
  remainingBalance: number;
  locale: string;
  canMarkPaid: boolean;
}

export interface ParkingNotificationPayload {
  title: string;
  body: string;
  icon: string;
  badge: string;
  tag: string;
  requireInteraction: boolean;
  canMarkPaid: boolean;
  fullPaidAction: string;
  languageCode: "en" | "hi";
  data: {
    sessionId: string;
    tenantId: string;
    notificationType: ParkingNotificationType;
  };
}

export function buildParkingNotificationPayload(
  input: ParkingNotificationPayloadInput,
): ParkingNotificationPayload {
  if (!Number.isFinite(input.remainingBalance) || input.remainingBalance <= 0) {
    throw new RangeError("A positive parking balance is required.");
  }

  const isHindi = input.locale === "hi";
  const amount = new Intl.NumberFormat(isHindi ? "hi-IN" : "en-IN", {
    style: "currency",
    currency: "INR",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(input.remainingBalance);
  const isExpired = input.notificationType === "expired";
  const title = isHindi
    ? isExpired
      ? "पार्किंग का समय समाप्त हो गया"
      : "पार्किंग का समय समाप्त होने वाला है"
    : isExpired
    ? "Parking has expired"
    : "Parking is nearing expiry";
  const body = isHindi
    ? isExpired
      ? `बकाया राशि: ${amount}।`
      : `पार्किंग का समय लगभग समाप्त होने वाला है। बकाया राशि: ${amount}।`
    : isExpired
    ? `Outstanding amount: ${amount}.`
    : `Parking is nearing expiry. Outstanding amount: ${amount}.`;

  return {
    title,
    body,
    icon: "../icons/Icon-192.png",
    badge: "../icons/Icon-192.png",
    tag: `parking-${input.sessionId}-${input.notificationType}`,
    requireInteraction: isExpired,
    canMarkPaid: input.canMarkPaid,
    fullPaidAction: isHindi ? "पूरा भुगतान" : "Full Paid",
    languageCode: isHindi ? "hi" : "en",
    data: {
      sessionId: input.sessionId,
      tenantId: input.tenantId,
      notificationType: input.notificationType,
    },
  };
}
