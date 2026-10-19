import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/locale/language_switch.dart';
import 'package:parking_management/core/locale/locale_controller.dart';
import 'package:parking_management/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('switches locale and saves the choice locally', (tester) async {
    final controller = LocaleController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      LocaleScope(
        controller: controller,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MaterialApp(
            locale: controller.locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    Text(AppLocalizations.of(context).signInTitle),
                    const LanguageSwitch(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sign in'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<Locale>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hindi').last);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(controller.locale, const Locale('hi'));
    expect(preferences.getString('app_locale_code'), 'hi');
    expect(find.text('साइन इन करें'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });
}
