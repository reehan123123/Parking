abstract interface class PushBrowserBridge {
  bool get isSupported;

  String get permission;

  Future<String> getSubscriptionJson();

  Future<String> subscribe(String applicationServerKey);

  Future<bool> unsubscribe();

  void clearLaunchParameters();
}

class StubPushBrowserBridge implements PushBrowserBridge {
  const StubPushBrowserBridge();

  @override
  void clearLaunchParameters() {}

  @override
  Future<String> getSubscriptionJson() async => '';

  @override
  bool get isSupported => false;

  @override
  String get permission => 'unsupported';

  @override
  Future<String> subscribe(String applicationServerKey) {
    throw UnsupportedError(
      'Web Push is available only in a supported browser.',
    );
  }

  @override
  Future<bool> unsubscribe() async => true;
}

PushBrowserBridge createPushBrowserBridge() {
  return const StubPushBrowserBridge();
}
