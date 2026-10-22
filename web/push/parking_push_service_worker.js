const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

self.addEventListener("push", (event) => {
  if (!event.data) {
    return;
  }

  event.waitUntil(
    (async () => {
      const payload = event.data.json();
      const data = payload.data;
      if (
        typeof payload.title !== "string" ||
        typeof payload.body !== "string" ||
        typeof data?.sessionId !== "string" ||
        typeof data?.tenantId !== "string" ||
        !uuidPattern.test(data.sessionId) ||
        !uuidPattern.test(data.tenantId)
      ) {
        throw new Error("The parking notification payload is invalid.");
      }

      const iconUrl = new URL(
        payload.icon,
        self.registration.scope,
      ).toString();
      const badgeUrl = new URL(
        payload.badge,
        self.registration.scope,
      ).toString();
      const canMarkPaid = payload.canMarkPaid === true;
      const actions = canMarkPaid && Notification.maxActions > 0
        ? [{ action: "full-paid", title: payload.fullPaidAction }]
        : [];
      await self.registration.showNotification(payload.title, {
        body: payload.body,
        icon: iconUrl,
        badge: badgeUrl,
        tag: payload.tag,
        requireInteraction: false,
        lang: payload.languageCode === "hi" ? "hi" : "en",
        data: {
          sessionId: data.sessionId,
          tenantId: data.tenantId,
          notificationType: data.notificationType,
          canMarkPaid,
        },
        actions,
      });
    })(),
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();

  const data = event.notification.data;
  if (
    typeof data?.sessionId !== "string" ||
    typeof data?.tenantId !== "string" ||
    !uuidPattern.test(data.sessionId) ||
    !uuidPattern.test(data.tenantId)
  ) {
    return;
  }

  const action = event.action === "full-paid" && data.canMarkPaid === true
    ? "full-paid"
    : "open";
  const appUrl = new URL("../", self.registration.scope);
  appUrl.searchParams.set("parkingSessionId", data.sessionId);
  appUrl.searchParams.set("parkingTenantId", data.tenantId);
  appUrl.searchParams.set("parkingAction", action);

  event.waitUntil(
    (async () => {
      const clients = await self.clients.matchAll({
        type: "window",
        includeUncontrolled: true,
      });
      for (const client of clients) {
        if (new URL(client.url).origin !== self.location.origin) {
          continue;
        }
        if ("navigate" in client) {
          const navigatedClient = await client.navigate(appUrl.toString());
          if (navigatedClient) {
            await navigatedClient.focus();
            return;
          }
        }
        await client.focus();
        return;
      }

      await self.clients.openWindow(appUrl.toString());
    })(),
  );
});
