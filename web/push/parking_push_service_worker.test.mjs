import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import vm from "node:vm";

const workerSource = await readFile(
  new URL("./parking_push_service_worker.js", import.meta.url),
  "utf8",
);
const sessionId = "11111111-1111-4111-8111-111111111111";
const tenantId = "22222222-2222-4222-8222-222222222222";

test("keeps expiry notifications visible until dismissed", async () => {
  const worker = createWorker();

  await dispatchPush(worker, "expired");

  assert.equal(worker.notifications.length, 1);
  assert.equal(worker.notifications[0].options.requireInteraction, true);
  assert.equal(worker.notifications[0].options.renotify, true);
  assert.equal(worker.notifications[0].options.actions, undefined);
});

test("keeps 90-percent reminders dismissible", async () => {
  const worker = createWorker();

  await dispatchPush(worker, "ninety_percent");

  assert.equal(worker.notifications.length, 1);
  assert.equal(worker.notifications[0].options.requireInteraction, false);
  assert.equal(worker.notifications[0].options.renotify, false);
  assert.equal(worker.notifications[0].options.actions, undefined);
});

test("routes even legacy Full Paid clicks to the session without marking it", async () => {
  let navigatedUrl;
  let focused = false;
  const client = {
    url: "https://parking.example/",
    navigate: async (url) => {
      navigatedUrl = url;
      return {
        focus: async () => {
          focused = true;
        },
      };
    },
  };
  const worker = createWorker({ clients: [client] });

  await dispatchClick(worker, "full-paid");

  assert.equal(focused, true);
  assert.equal(worker.openedUrls.length, 0);
  assertLaunchUrl(navigatedUrl, "open");
});

test("opens the session when an existing window cannot be navigated", async () => {
  const client = {
    url: "https://parking.example/",
    navigate: async () => null,
    focus: async () => {
      assert.fail("A stale app window should not be focused.");
    },
  };
  const worker = createWorker({ clients: [client] });

  await dispatchClick(worker, "");

  assert.equal(worker.openedUrls.length, 1);
  assertLaunchUrl(worker.openedUrls[0], "open");
});

test("opens the session when navigation of an existing window fails", async () => {
  const client = {
    url: "https://parking.example/",
    navigate: async () => {
      throw new Error("Navigation failed.");
    },
  };
  const worker = createWorker({ clients: [client] });

  await dispatchClick(worker, "");

  assert.equal(worker.openedUrls.length, 1);
  assert.equal(worker.warnings.length, 1);
  assertLaunchUrl(worker.openedUrls[0], "open");
});

function createWorker({ clients = [] } = {}) {
  const listeners = new Map();
  const openedUrls = [];
  const notifications = [];
  const warnings = [];
  const self = {
    addEventListener: (type, listener) => listeners.set(type, listener),
    location: { origin: "https://parking.example" },
    registration: {
      scope: "https://parking.example/push/",
      showNotification: async (title, options) => {
        notifications.push({ title, options });
      },
    },
    clients: {
      matchAll: async () => clients,
      openWindow: async (url) => {
        openedUrls.push(url);
        return null;
      },
    },
  };

  vm.runInNewContext(
    workerSource,
    {
      URL,
      console: { warn: (...values) => warnings.push(values) },
      self,
    },
    { filename: "parking_push_service_worker.js" },
  );

  return { listeners, notifications, openedUrls, warnings };
}

async function dispatchPush(worker, notificationType) {
  const waits = [];
  worker.listeners.get("push")({
    data: {
      json: () => ({
        title: "Parking notice",
        body: "Outstanding amount is due.",
        icon: "../icons/Icon-192.png",
        badge: "../icons/Icon-192.png",
        tag: `parking-${sessionId}-${notificationType}`,
        requireInteraction: false,
        canMarkPaid: true,
        fullPaidAction: "Full Paid",
        languageCode: "en",
        data: { sessionId, tenantId, notificationType },
      }),
    },
    waitUntil: (wait) => waits.push(wait),
  });

  await Promise.all(waits);
}

async function dispatchClick(worker, action) {
  const waits = [];
  let closed = false;

  worker.listeners.get("notificationclick")({
    action,
    notification: {
      close: () => {
        closed = true;
      },
      data: { sessionId, tenantId, canMarkPaid: true },
    },
    waitUntil: (wait) => waits.push(wait),
  });

  await Promise.all(waits);
  assert.equal(closed, true);
}

function assertLaunchUrl(value, expectedAction) {
  const url = new URL(value);

  assert.equal(url.origin, "https://parking.example");
  assert.equal(url.pathname, "/");
  assert.equal(url.searchParams.get("parkingSessionId"), sessionId);
  assert.equal(url.searchParams.get("parkingTenantId"), tenantId);
  assert.equal(url.searchParams.get("parkingAction"), expectedAction);
}
