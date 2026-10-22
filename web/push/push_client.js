(() => {
  function getWorkerPaths() {
    const baseUrl = document.baseURI;
    return {
      scope: new URL("push/", baseUrl).pathname,
      script: new URL("push/parking_push_service_worker.js", baseUrl).pathname,
    };
  }

  function isSupported() {
    return (
      "serviceWorker" in navigator &&
      "PushManager" in window &&
      "Notification" in window
    );
  }

  async function registerWorker() {
    const paths = getWorkerPaths();
    return navigator.serviceWorker.register(paths.script, {
      scope: paths.scope,
    });
  }

  function decodeApplicationServerKey(value) {
    const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
    const padded = normalized + "=".repeat((4 - normalized.length % 4) % 4);
    const binary = window.atob(padded);
    const key = Uint8Array.from(binary, (character) =>
      character.charCodeAt(0),
    );
    if (key.length !== 65) {
      throw new Error("The push notification public key is invalid.");
    }
    return key;
  }

  async function getSubscription() {
    if (!isSupported()) {
      return "";
    }

    const paths = getWorkerPaths();
    const registration = await navigator.serviceWorker.getRegistration(
      paths.scope,
    );
    if (!registration) {
      return "";
    }
    const subscription = await registration.pushManager.getSubscription();
    return subscription ? JSON.stringify(subscription.toJSON()) : "";
  }

  async function subscribe(applicationServerKey) {
    if (!isSupported()) {
      throw new Error("Push notifications are not supported by this browser.");
    }

    let permission = Notification.permission;
    if (permission === "default") {
      permission = await Notification.requestPermission();
    }
    if (permission !== "granted") {
      throw new Error("Push notification permission was not granted.");
    }

    const registration = await registerWorker();
    let subscription = await registration.pushManager.getSubscription();
    if (subscription === null) {
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: decodeApplicationServerKey(
          applicationServerKey,
        ),
      });
    }
    return JSON.stringify(subscription.toJSON());
  }

  async function unsubscribe() {
    if (!isSupported()) {
      return true;
    }

    const paths = getWorkerPaths();
    const registration = await navigator.serviceWorker.getRegistration(
      paths.scope,
    );
    const subscription = await registration?.pushManager.getSubscription();
    return subscription === null || subscription === undefined
      ? true
      : subscription.unsubscribe();
  }

  function clearLaunchParameters() {
    const url = new URL(window.location.href);
    url.searchParams.delete("parkingSessionId");
    url.searchParams.delete("parkingTenantId");
    url.searchParams.delete("parkingAction");
    window.history.replaceState(
      window.history.state,
      "",
      `${url.pathname}${url.search}${url.hash}`,
    );
  }

  window.parkingPush = Object.freeze({
    isSupported,
    permission: () => Notification.permission,
    getSubscription,
    subscribe,
    unsubscribe,
    clearLaunchParameters,
  });
})();
