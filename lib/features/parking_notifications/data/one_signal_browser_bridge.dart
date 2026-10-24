export 'one_signal_browser_bridge_stub.dart'
    show OneSignalBrowserBridge, OneSignalBrowserStatus;
export 'one_signal_browser_bridge_stub.dart'
    if (dart.library.js_interop) 'one_signal_browser_bridge_web.dart'
    show createOneSignalBrowserBridge;
