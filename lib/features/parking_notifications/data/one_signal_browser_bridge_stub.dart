class OneSignalBrowserStatus {
  const OneSignalBrowserStatus({
    required this.permission,
    required this.isOptedIn,
  });

  final String permission;
  final bool? isOptedIn;
}

abstract interface class OneSignalBrowserBridge {
  bool get isSupported;

  Future<void> initialize(String appId);

  Future<OneSignalBrowserStatus> loadStatus();

  Future<String> getExternalId();

  Future<void> login(String externalId);

  Future<void> logout();

  Future<String> requestPermission();

  Future<void> optIn();

  Future<void> optOut();

  void clearLaunchParameters();
}

class StubOneSignalBrowserBridge implements OneSignalBrowserBridge {
  const StubOneSignalBrowserBridge();

  @override
  void clearLaunchParameters() {}

  @override
  Future<String> getExternalId() async => '';

  @override
  Future<void> initialize(String appId) {
    throw UnsupportedError('OneSignal is available only in a web browser.');
  }

  @override
  bool get isSupported => false;

  @override
  Future<OneSignalBrowserStatus> loadStatus() async {
    return const OneSignalBrowserStatus(
      permission: 'unsupported',
      isOptedIn: null,
    );
  }

  @override
  Future<void> login(String externalId) {
    throw UnsupportedError('OneSignal is available only in a web browser.');
  }

  @override
  Future<void> logout() {
    throw UnsupportedError('OneSignal is available only in a web browser.');
  }

  @override
  Future<void> optIn() {
    throw UnsupportedError('OneSignal is available only in a web browser.');
  }

  @override
  Future<void> optOut() {
    throw UnsupportedError('OneSignal is available only in a web browser.');
  }

  @override
  Future<String> requestPermission() {
    throw UnsupportedError('OneSignal is available only in a web browser.');
  }
}

OneSignalBrowserBridge createOneSignalBrowserBridge() {
  return const StubOneSignalBrowserBridge();
}
