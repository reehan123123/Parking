import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/config/supabase_initializer.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/parking/data/parking_session_repository.dart';
import 'features/parking/data/supabase_parking_session_repository.dart';
import 'features/tenants/data/supabase_tenant_repository.dart';
import 'features/tenants/data/tenant_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = const SupabaseConfig.fromEnvironment();
  AuthRepository? authRepository;
  ParkingSessionRepository? parkingSessionRepository;
  TenantRepository? tenantRepository;
  String? configurationError = config.validationError;

  if (configurationError == null) {
    try {
      final SupabaseClient client = await SupabaseInitializer.initialize(
        config,
      );
      authRepository = SupabaseAuthRepository(client);
      parkingSessionRepository = SupabaseParkingSessionRepository(client);
      tenantRepository = SupabaseTenantRepository(client);
    } on Exception {
      configurationError =
          'Supabase could not be initialized. Check the public URL and '
          'publishable key used for this build.';
    }
  }

  runApp(
    ParkingManagementApp(
      authRepository: authRepository,
      parkingSessionRepository: parkingSessionRepository,
      tenantRepository: tenantRepository,
      configurationError: configurationError,
    ),
  );
}
