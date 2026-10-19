import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/device_sessions/data/device_session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesDeviceInstallationIdStore', () {
    test('creates and reuses one opaque UUIDv4 per installation', () async {
      SharedPreferences.setMockInitialValues({});
      const SharedPreferencesDeviceInstallationIdStore store =
          SharedPreferencesDeviceInstallationIdStore();

      final String firstId = await store.getOrCreate();
      final String secondId = await store.getOrCreate();

      expect(
        firstId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(secondId, firstId);
    });

    test('replaces an invalid stored identifier', () async {
      SharedPreferences.setMockInitialValues({
        'parking_device_installation_id': 'not-a-device-id',
      });
      const SharedPreferencesDeviceInstallationIdStore store =
          SharedPreferencesDeviceInstallationIdStore();

      final String installationId = await store.getOrCreate();

      expect(installationId, isNot('not-a-device-id'));
      expect(
        installationId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });
  });
}
