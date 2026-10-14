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
    );

    return Supabase.instance.client;
  }
}
