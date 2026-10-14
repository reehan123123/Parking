class SupabaseConfig {
  const SupabaseConfig({required this.url, required this.publishableKey});

  const SupabaseConfig.fromEnvironment()
    : url = const String.fromEnvironment('SUPABASE_URL'),
      publishableKey = const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  final String url;
  final String publishableKey;

  String? get validationError {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      return 'SUPABASE_URL is not configured.';
    }

    final parsedUrl = Uri.tryParse(trimmedUrl);
    if (parsedUrl == null ||
        parsedUrl.host.isEmpty ||
        (parsedUrl.scheme != 'https' && parsedUrl.scheme != 'http')) {
      return 'SUPABASE_URL must be a valid HTTP or HTTPS URL.';
    }

    if (publishableKey.trim().isEmpty) {
      return 'SUPABASE_PUBLISHABLE_KEY is not configured.';
    }

    return null;
  }
}
