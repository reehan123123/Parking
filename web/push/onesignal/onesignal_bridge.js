(() => {
  const workerPath = "/push/onesignal/OneSignalSDKWorker.js";
  const workerScope = "/push/onesignal/";
  let appId = null;
  let initialization = null;
  let oneSignal = null;

  window.OneSignalDeferred = window.OneSignalDeferred || [];

  function isSupported() {
    return typeof window.Notification !== "undefined" &&
      typeof window.PushManager !== "undefined" &&
      typeof navigator !== "undefined" &&
      "serviceWorker" in navigator;
  }

  function initialize(requestedAppId) {
    if (typeof requestedAppId !== "string" || requestedAppId.trim() === "") {
      return Promise.reject(new Error("OneSignal app ID is required."));
    }
    if (appId !== null && appId !== requestedAppId) {
      return Promise.reject(new Error("OneSignal app ID cannot be changed."));
    }
    appId = requestedAppId;
    if (initialization !== null) {
      return initialization;
    }

    initialization = new Promise((resolve, reject) => {
      window.OneSignalDeferred.push(async (sdk) => {
        try {
          await sdk.init({
            appId,
            serviceWorkerPath: workerPath,
            serviceWorkerParam: { scope: workerScope },
          });
          oneSignal = sdk;
          resolve(true);
        } catch (error) {
          initialization = null;
          reject(error);
        }
      });
    });
    return initialization;
  }

  function requireInitialized() {
    if (oneSignal === null) {
      return Promise.reject(new Error("OneSignal is not initialized."));
    }
    return Promise.resolve(oneSignal);
  }

  function loadStatus() {
    if (!isSupported()) {
      return Promise.resolve(
        JSON.stringify({ permission: "unsupported", optedIn: null }),
      );
    }

    const permission = window.Notification.permission;
    if (permission !== "granted" || oneSignal === null) {
      return Promise.resolve(JSON.stringify({ permission, optedIn: null }));
    }

    const optedIn = oneSignal.User.PushSubscription.optedIn;
    return Promise.resolve(
      JSON.stringify({
        permission,
        optedIn: typeof optedIn === "boolean" ? optedIn : null,
      }),
    );
  }

  function getExternalId() {
    return requireInitialized().then((sdk) => {
      const externalId = sdk.User.externalId;
      return typeof externalId === "string" ? externalId : "";
    });
  }

  function login(externalId) {
    return requireInitialized()
      .then((sdk) => sdk.login(externalId))
      .then(() => true);
  }

  function logout() {
    return requireInitialized()
      .then((sdk) => sdk.logout())
      .then(() => true);
  }

  function requestPermission() {
    return requireInitialized().then((sdk) => sdk.Notifications.requestPermission())
      .then(() => window.Notification.permission);
  }

  function optIn() {
    return requireInitialized()
      .then((sdk) => sdk.User.PushSubscription.optIn())
      .then(() => true);
  }

  function optOut() {
    return requireInitialized()
      .then((sdk) => sdk.User.PushSubscription.optOut())
      .then(() => true);
  }

  function clearLaunchParameters() {
    const url = new URL(window.location.href);
    for (const name of [...url.searchParams.keys()]) {
      if (name.startsWith("parking")) {
        url.searchParams.delete(name);
      }
    }
    window.history.replaceState(
      window.history.state,
      "",
      `${url.pathname}${url.search}${url.hash}`,
    );
  }

  window.ParkingOneSignalBridge = {
    clearLaunchParameters,
    getExternalId,
    initialize,
    isSupported,
    loadStatus,
    login,
    logout,
    optIn,
    optOut,
    requestPermission,
  };
})();
