class ParkingBackendConfig {
  const ParkingBackendConfig({
    required this.backend,
    required this.localApiUrl,
  });

  const ParkingBackendConfig.fromEnvironment()
    : backend = const String.fromEnvironment(
        'PARKING_BACKEND',
        defaultValue: 'supabase',
      ),
      localApiUrl = const String.fromEnvironment(
        'PARKING_LOCAL_API_URL',
        defaultValue: 'http://127.0.0.1:8765',
      );

  final String backend;
  final String localApiUrl;

  bool get usesLocalApi => backend == 'local';

  String? get validationError {
    if (backend != 'supabase' && backend != 'local') {
      return 'PARKING_BACKEND must be either supabase or local.';
    }
    if (!usesLocalApi) {
      return null;
    }

    final uri = Uri.tryParse(localApiUrl.trim());
    if (uri == null ||
        uri.scheme != 'http' ||
        !const {'localhost', '127.0.0.1', '::1'}.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.port < 1 ||
        uri.port > 65535) {
      return 'PARKING_LOCAL_API_URL must be an HTTP loopback URL such as '
          'http://127.0.0.1:8765.';
    }

    return null;
  }

  Uri? get localApiUri {
    if (!usesLocalApi || validationError != null) {
      return null;
    }
    return Uri.parse(localApiUrl.trim());
  }
}
