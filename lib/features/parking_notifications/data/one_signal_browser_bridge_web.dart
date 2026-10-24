import 'dart:convert';
import 'dart:js_interop';

import 'one_signal_browser_bridge_stub.dart';

@JS('ParkingOneSignalBridge')
external _ParkingOneSignalApi get _parkingOneSignal;

@JS()
extension type _ParkingOneSignalApi(JSObject _) implements JSObject {
  external JSBoolean isSupported();

  external JSPromise<JSBoolean> initialize(JSString appId);

  external JSPromise<JSString> loadStatus();

  external JSPromise<JSString> getExternalId();

  external JSPromise<JSBoolean> login(JSString externalId);

  external JSPromise<JSBoolean> logout();

  external JSPromise<JSString> requestPermission();

  external JSPromise<JSBoolean> optIn();

  external JSPromise<JSBoolean> optOut();

  external void clearLaunchParameters();
}

class WebOneSignalBrowserBridge implements OneSignalBrowserBridge {
  const WebOneSignalBrowserBridge();

  @override
  void clearLaunchParameters() {
    _parkingOneSignal.clearLaunchParameters();
  }

  @override
  Future<String> getExternalId() async {
    return (await _parkingOneSignal.getExternalId().toDart).toDart;
  }

  @override
  Future<void> initialize(String appId) async {
    await _parkingOneSignal.initialize(appId.toJS).toDart;
  }

  @override
  bool get isSupported {
    try {
      return _parkingOneSignal.isSupported().toDart;
    } on Object {
      return false;
    }
  }

  @override
  Future<OneSignalBrowserStatus> loadStatus() async {
    final String statusJson =
        (await _parkingOneSignal.loadStatus().toDart).toDart;
    final Object? decoded = jsonDecode(statusJson);
    if (decoded is! Map<String, dynamic> ||
        decoded['permission'] is! String ||
        (decoded['optedIn'] != null && decoded['optedIn'] is! bool)) {
      throw const FormatException('The OneSignal status is invalid.');
    }

    return OneSignalBrowserStatus(
      permission: decoded['permission']! as String,
      isOptedIn: decoded['optedIn'] as bool?,
    );
  }

  @override
  Future<void> login(String externalId) async {
    await _parkingOneSignal.login(externalId.toJS).toDart;
  }

  @override
  Future<void> logout() async {
    await _parkingOneSignal.logout().toDart;
  }

  @override
  Future<void> optIn() async {
    await _parkingOneSignal.optIn().toDart;
  }

  @override
  Future<void> optOut() async {
    await _parkingOneSignal.optOut().toDart;
  }

  @override
  Future<String> requestPermission() async {
    return (await _parkingOneSignal.requestPermission().toDart).toDart;
  }
}

OneSignalBrowserBridge createOneSignalBrowserBridge() {
  return const WebOneSignalBrowserBridge();
}
