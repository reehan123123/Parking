import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class SupabaseInitializer {
  const SupabaseInitializer._();

  static Future<SupabaseClient> initialize(SupabaseConfig config) async {
    final validationError = config.validationError;
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    await Supabase.initialize(
      url: config.url.trim(),
      publishableKey: config.publishableKey.trim(),
      // Implicit flow puts the session tokens directly in the email link's
      // URL fragment, so recovery/signup/invite/magic-link emails work when
      // opened in any browser or device, not only the one that originated
      // the request. PKCE (the package default) instead requires a
      // code_verifier stored in the *same* browser's local storage, which
      // breaks whenever a user opens the link in a different browser/
      // profile, or requests multiple resets before clicking the link.
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );

    return Supabase.instance.client;
  }
}
