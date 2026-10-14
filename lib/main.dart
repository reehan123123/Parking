import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/config/supabase_initializer.dart';
import 'features/auth/data/auth_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = const SupabaseConfig.fromEnvironment();
  AuthRepository? authRepository;
  String? configurationError = config.validationError;

  if (configurationError == null) {
    try {
      final SupabaseClient client = await SupabaseInitializer.initialize(
        config,
      );
      authRepository = SupabaseAuthRepository(client);
    } on Exception {
      configurationError =
          'Supabase could not be initialized. Check the public URL and '
          'publishable key used for this build.';
    }
  }

  runApp(
    ParkingManagementApp(
      authRepository: authRepository,
      configurationError: configurationError,
    ),
  );
}
