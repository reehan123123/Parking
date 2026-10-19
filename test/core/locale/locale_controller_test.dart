import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/locale/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads a saved supported locale', () async {
    SharedPreferences.setMockInitialValues({'app_locale_code': 'hi'});
    final controller = LocaleController();
    addTearDown(controller.dispose);

    await controller.loadSaved();

    expect(controller.locale, const Locale('hi'));
  });

  test('persists the selected locale locally', () async {
    final controller = LocaleController();
    addTearDown(controller.dispose);

    await controller.setLocale(const Locale('hi'));
    final preferences = await SharedPreferences.getInstance();

    expect(controller.locale, const Locale('hi'));
    expect(preferences.getString('app_locale_code'), 'hi');
  });

  test('applies and caches the signed-in account preference', () async {
    final controller = LocaleController();
    addTearDown(controller.dispose);

    await controller.applyUserPreference({'language_code': 'hi'});
    final preferences = await SharedPreferences.getInstance();

    expect(controller.locale, const Locale('hi'));
    expect(preferences.getString('app_locale_code'), 'hi');
  });

  test('rejects unsupported locales', () async {
    final controller = LocaleController();
    addTearDown(controller.dispose);

    await expectLater(
      controller.setLocale(const Locale('fr')),
      throwsArgumentError,
    );
    expect(controller.locale, const Locale('en'));
  });
}
