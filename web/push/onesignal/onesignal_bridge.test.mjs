import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import vm from "node:vm";

const bridgePath = new URL("./onesignal_bridge.js", import.meta.url);
const workerPath = new URL("./OneSignalSDKWorker.js", import.meta.url);

test("initializes OneSignal in a separate Flutter-compatible worker scope", async () => {
  const { bridge, deferred, fakeOneSignal } = await loadBridge();
  const initialization = bridge.initialize(
    "11111111-1111-4111-8111-111111111111",
  );

  assert.equal(deferred.length, 1);
  await deferred.shift()(fakeOneSignal);
  assert.equal(await initialization, true);
  assert.equal(JSON.stringify(fakeOneSignal.initOptions), JSON.stringify({
    appId: "11111111-1111-4111-8111-111111111111",
    serviceWorkerPath: "push/onesignal/OneSignalSDKWorker.js",
    serviceWorkerParam: { scope: "/push/onesignal/" },
  }));
  assert.equal(fakeOneSignal.permissionRequests, 0);
});

test("allows initialization to retry when the deferred SDK callback never runs", async () => {
  const { bridge, deferred, fakeOneSignal, timers } = await loadBridge();
  const firstAttempt = bridge.initialize(
    "11111111-1111-4111-8111-111111111111",
  );

  assert.equal(deferred.length, 1);
  const timeout = timers.values().next().value;
  assert.equal(timeout.delay, 18000);
  timeout.callback();
  await assert.rejects(firstAttempt, /initialization timed out/);

  const retry = bridge.initialize(
    "11111111-1111-4111-8111-111111111111",
  );
  assert.equal(deferred.length, 2);
  await deferred[0](fakeOneSignal);
  await deferred[1](fakeOneSignal);

  assert.equal(await retry, true);
  assert.equal(fakeOneSignal.initCalls, 1);
});

test("exposes subscription state and supports account identity changes", async () => {
  const { bridge, deferred, fakeOneSignal, window } = await loadBridge();
  const initialization = bridge.initialize(
    "11111111-1111-4111-8111-111111111111",
  );
  await deferred.shift()(fakeOneSignal);
  await initialization;

  fakeOneSignal.User.PushSubscription.optedIn = true;
  window.Notification.permission = "granted";
  assert.deepEqual(JSON.parse(await bridge.loadStatus()), {
    permission: "granted",
    optedIn: true,
  });

  await bridge.login("22222222-2222-4222-8222-222222222222");
  assert.equal(
    await bridge.getExternalId(),
    "22222222-2222-4222-8222-222222222222",
  );
  await bridge.logout();
  assert.equal(await bridge.getExternalId(), "");
});

test("requests permission only when the explicit API is called", async () => {
  const { bridge, deferred, fakeOneSignal, window } = await loadBridge();
  const initialization = bridge.initialize(
    "11111111-1111-4111-8111-111111111111",
  );
  await deferred.shift()(fakeOneSignal);
  await initialization;

  assert.equal(fakeOneSignal.permissionRequests, 0);
  window.Notification.permission = "granted";
  assert.equal(await bridge.requestPermission(), "granted");
  assert.equal(fakeOneSignal.permissionRequests, 1);
  await bridge.optIn();
  await bridge.optOut();
  assert.equal(fakeOneSignal.optInCalls, 1);
  assert.equal(fakeOneSignal.optOutCalls, 1);
});

test("clears notification query parameters without changing the route", async () => {
  const { bridge, window } = await loadBridge();
  bridge.clearLaunchParameters();

  assert.equal(
    window.replacedUrl,
    "/?keep=1#details",
  );
});

test("keeps Flutter startup assets and the official OneSignal worker", async () => {
  const [indexHtml, worker, manifest, headers] = await Promise.all([
    readFile(new URL("../../index.html", import.meta.url), "utf8"),
    readFile(workerPath, "utf8"),
    readFile(new URL("../../manifest.json", import.meta.url), "utf8"),
    readFile(new URL("../../_headers", import.meta.url), "utf8"),
  ]);

  assert.match(
    indexHtml,
    /https:\/\/cdn\.onesignal\.com\/sdks\/web\/v16\/OneSignalSDK\.page\.js/,
  );
  assert.match(indexHtml, /push\/onesignal\/onesignal_bridge\.js/);
  assert.match(indexHtml, /flutter_bootstrap\.js/);
  assert.match(worker, /importScripts\(\s*"https:\/\/cdn\.onesignal\.com\/sdks\/web\/v16\/OneSignalSDK\.sw\.js"/);
  assert.equal(JSON.parse(manifest).display, "standalone");
  assert.match(headers, /X-Content-Type-Options: nosniff/);
});

async function loadBridge() {
  const source = await readFile(bridgePath, "utf8");
  const deferred = [];
  const timers = new Map();
  let nextTimerId = 0;
  const fakeOneSignal = {
    initOptions: null,
    initCalls: 0,
    permissionRequests: 0,
    optInCalls: 0,
    optOutCalls: 0,
    currentExternalId: "",
    init: async function (options) {
      this.initCalls++;
      this.initOptions = options;
    },
    User: {
      externalId: "",
      PushSubscription: {
        optedIn: false,
        optIn: async function () {
          fakeOneSignal.optInCalls++;
        },
        optOut: async function () {
          fakeOneSignal.optOutCalls++;
        },
      },
    },
    Notifications: {
      requestPermission: async function () {
        fakeOneSignal.permissionRequests++;
      },
    },
    login: async function (externalId) {
      this.User.externalId = externalId;
    },
    logout: async function () {
      this.User.externalId = "";
    },
  };
  const window = {
    OneSignalDeferred: deferred,
    Notification: { permission: "default" },
    PushManager: function PushManager() {},
    location: {
      href:
        "https://parking-85u.pages.dev/?parkingSessionId=session&parkingLegacyOption=old&keep=1#details",
    },
    history: {
      state: null,
      replaceState(_state, _title, url) {
        window.replacedUrl = url;
      },
    },
    setTimeout(callback, delay) {
      const id = nextTimerId++;
      timers.set(id, {
        callback: () => {
          timers.delete(id);
          callback();
        },
        delay,
      });
      return id;
    },
    clearTimeout(id) {
      timers.delete(id);
    },
  };
  const navigator = { serviceWorker: {} };

  vm.runInNewContext(source, {
    window,
    navigator,
    URL,
    Promise,
    Error,
  });

  return {
    bridge: window.ParkingOneSignalBridge,
    deferred,
    fakeOneSignal,
    timers,
    window,
  };
}
