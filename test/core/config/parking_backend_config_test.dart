import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/config/parking_backend_config.dart';

void main() {
  group('ParkingBackendConfig', () {
    test('defaults to the existing Supabase backend', () {
      const config = ParkingBackendConfig(
        backend: 'supabase',
        localApiUrl: 'http://127.0.0.1:8765',
      );

      expect(config.usesLocalApi, isFalse);
      expect(config.validationError, isNull);
    });

    test('accepts a loopback-only local API URL', () {
      const config = ParkingBackendConfig(
        backend: 'local',
        localApiUrl: 'http://localhost:8765',
      );

      expect(config.usesLocalApi, isTrue);
      expect(config.localApiUri, Uri.parse('http://localhost:8765'));
      expect(config.validationError, isNull);
    });

    test('rejects remote or credential-bearing local API URLs', () {
      for (final url in [
        'https://api.example.com',
        'http://user:password@localhost:8765',
        'http://localhost:8765/api',
      ]) {
        final config = ParkingBackendConfig(backend: 'local', localApiUrl: url);

        expect(config.validationError, isNotNull, reason: url);
        expect(config.localApiUri, isNull, reason: url);
      }
    });

    test('rejects unknown backend modes', () {
      const config = ParkingBackendConfig(
        backend: 'postgres',
        localApiUrl: 'http://127.0.0.1:8765',
      );

      expect(config.validationError, contains('PARKING_BACKEND'));
    });
  });
}
