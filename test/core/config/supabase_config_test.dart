import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/config/supabase_config.dart';

void main() {
  test('rejects missing public configuration', () {
    const config = SupabaseConfig(url: '', publishableKey: '');

    expect(config.validationError, 'SUPABASE_URL is not configured.');
  });

  test('rejects an invalid project URL', () {
    const config = SupabaseConfig(
      url: 'not-a-url',
      publishableKey: 'sb_publishable_example',
    );

    expect(
      config.validationError,
      'SUPABASE_URL must be a valid HTTP or HTTPS URL.',
    );
  });

  test('accepts a valid public configuration', () {
    const config = SupabaseConfig(
      url: 'https://example.supabase.co',
      publishableKey: 'sb_publishable_example',
    );

    expect(config.validationError, isNull);
  });
}
