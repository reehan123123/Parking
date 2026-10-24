import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/core/locale/locale_controller.dart';
import 'package:parking_management/features/maintenance/domain/maintenance_mode_status.dart';
import 'package:parking_management/features/settings/presentation/settings_page.dart';
import 'package:parking_management/l10n/app_localizations.dart';

import '../test_maintenance_mode_repository.dart';

void main() {
  testWidgets('only Super Admins see the maintenance switch', (
    WidgetTester tester,
  ) async {
    final DateTime serverTime = DateTime.now().toUtc();
    final TestMaintenanceModeRepository repository =
        TestMaintenanceModeRepository(
          status: MaintenanceModeStatus(
            callerIsSuperAdmin: true,
            isActive: false,
            maintenanceUntil: null,
            serverTime: serverTime,
          ),
        );
    final LocaleController localeController = LocaleController();
    addTearDown(localeController.dispose);

    await tester.pumpWidget(
      LocaleScope(
        controller: localeController,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsPage(
              isSuperAdmin: true,
              maintenanceModeRepository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform maintenance'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('non-admin users do not load or see the maintenance switch', (
    WidgetTester tester,
  ) async {
    final DateTime serverTime = DateTime.now().toUtc();
    final TestMaintenanceModeRepository repository =
        TestMaintenanceModeRepository(
          status: MaintenanceModeStatus(
            callerIsSuperAdmin: false,
            isActive: false,
            maintenanceUntil: null,
            serverTime: serverTime,
          ),
        );
    final LocaleController localeController = LocaleController();
    addTearDown(localeController.dispose);

    await tester.pumpWidget(
      LocaleScope(
        controller: localeController,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsPage(
              isSuperAdmin: false,
              maintenanceModeRepository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform maintenance'), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    expect(repository.loadCalls, 0);
  });

  testWidgets('enabling maintenance requires and saves a future date/time', (
    WidgetTester tester,
  ) async {
    final DateTime serverTime = DateTime.now().toUtc();
    final TestMaintenanceModeRepository repository =
        TestMaintenanceModeRepository(
          status: MaintenanceModeStatus(
            callerIsSuperAdmin: true,
            isActive: false,
            maintenanceUntil: null,
            serverTime: serverTime,
          ),
        );
    final LocaleController localeController = LocaleController();
    addTearDown(localeController.dispose);

    await tester.pumpWidget(
      LocaleScope(
        controller: localeController,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettingsPage(
              isSuperAdmin: true,
              maintenanceModeRepository: repository,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK').last);
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(repository.lastMaintenanceUntil, isNotNull);
    expect(repository.lastMaintenanceUntil!.isAfter(DateTime.now()), isTrue);
    expect(find.textContaining('Maintenance mode is on until'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });
}
