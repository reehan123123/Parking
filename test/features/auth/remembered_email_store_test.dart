import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/auth/data/remembered_email_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = RememberedEmailStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('read returns null when nothing is remembered', () async {
    expect(await store.read(), isNull);
  });

  test('save then read returns the saved email', () async {
    await store.save('user@example.com');

    expect(await store.read(), 'user@example.com');
  });

  test('clear removes a previously saved email', () async {
    await store.save('user@example.com');
    await store.clear();

    expect(await store.read(), isNull);
  });

  test('a stored empty string is treated as no remembered email', () async {
    SharedPreferences.setMockInitialValues({'parking.remembered_email': ''});

    expect(await store.read(), isNull);
  });
}
