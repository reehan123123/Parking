import 'dart:js_interop';

@JS('parkingPush')
external _ParkingPushApi get _parkingPush;

@JS()
extension type _ParkingPushApi(JSObject _) implements JSObject {
  external JSBoolean isSupported();

  external JSString permission();

  external JSPromise<JSString> getSubscription();

  external JSPromise<JSString> subscribe(JSString applicationServerKey);

  external JSPromise<JSBoolean> unsubscribe();

  external void clearLaunchParameters();
}

class PushBrowserBridge {
  const PushBrowserBridge();

  bool get isSupported => _parkingPush.isSupported().toDart;

  String get permission => _parkingPush.permission().toDart;

  Future<String> getSubscriptionJson() async {
    return (await _parkingPush.getSubscription().toDart).toDart;
  }

  Future<String> subscribe(String applicationServerKey) async {
    return (await _parkingPush.subscribe(applicationServerKey.toJS).toDart)
        .toDart;
  }

  Future<bool> unsubscribe() async {
    return (await _parkingPush.unsubscribe().toDart).toDart;
  }

  void clearLaunchParameters() {
    _parkingPush.clearLaunchParameters();
  }
}

PushBrowserBridge createPushBrowserBridge() {
  return const PushBrowserBridge();
}
