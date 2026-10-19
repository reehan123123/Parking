import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/parking_backend_config.dart';
import 'core/config/supabase_config.dart';
import 'core/config/supabase_initializer.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/local_auth_repository.dart';
import 'core/network/local_api_client.dart';
import 'features/device_sessions/data/device_session_repository.dart';
import 'features/parking/data/parking_session_repository.dart';
import 'features/parking/data/local_api_parking_session_store.dart';
import 'features/parking/data/supabase_parking_session_repository.dart';
import 'features/tenants/data/local_api_tenant_store.dart';
import 'features/tenants/data/supabase_tenant_repository.dart';
import 'features/tenants/data/tenant_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const backendConfig = ParkingBackendConfig.fromEnvironment();
  AuthRepository? authRepository;
  ParkingSessionRepository? parkingSessionRepository;
  TenantRepository? tenantRepository;
  DeviceSessionRepository? deviceSessionRepository;
  SupabaseClient? supabaseClient;

  String? configurationError = backendConfig.validationError;
  if (configurationError == null && backendConfig.usesLocalApi) {
    final api = LocalApiClient(baseUri: backendConfig.localApiUri!);
    final localAuthRepository = LocalAuthRepository(api);
    authRepository = localAuthRepository;
    parkingSessionRepository = SupabaseParkingSessionRepository(
      null,
      sessionStore: LocalApiParkingSessionStore(api),
      photoStorage: LocalApiVehiclePhotoStorage(api),
      currentUserId: () => localAuthRepository.currentUserId,
    );
    tenantRepository = SupabaseTenantRepository(
      null,
      tenantStore: LocalApiTenantStore(api),
    );
  } else if (configurationError == null) {
    final config = const SupabaseConfig.fromEnvironment();
    configurationError = config.validationError;
    if (configurationError == null) {
      try {
        final SupabaseClient client = await SupabaseInitializer.initialize(
          config,
        );
        authRepository = SupabaseAuthRepository(client);
        parkingSessionRepository = SupabaseParkingSessionRepository(client);
        tenantRepository = SupabaseTenantRepository(client);
        deviceSessionRepository = SupabaseDeviceSessionRepository(client);
        supabaseClient = client;
      } on Exception {
        configurationError =
            'Supabase could not be initialized. Check the public URL and '
            'publishable key used for this build.';
      }
    }
  }

  if (configurationError != null) {
    authRepository = null;
    parkingSessionRepository = null;
    tenantRepository = null;
    deviceSessionRepository = null;
  }

  runApp(
    ParkingManagementApp(
      authRepository: authRepository,
      parkingSessionRepository: parkingSessionRepository,
      tenantRepository: tenantRepository,
      deviceSessionRepository: deviceSessionRepository,
      configurationError: configurationError,
      supabaseClient: supabaseClient,
    ),
  );
}
