import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/maintenance/domain/maintenance_mode_status.dart';
import 'package:parking_management/features/maintenance/presentation/maintenance_mode_gate.dart';
import 'package:parking_management/l10n/app_localizations.dart';

import '../test_maintenance_mode_repository.dart';

void main() {
  testWidgets('non-admin users see the maintenance screen', (
    WidgetTester tester,
  ) async {
    final DateTime serverTime = DateTime.now().toUtc();
    final TestMaintenanceModeRepository repository =
        TestMaintenanceModeRepository(
          status: MaintenanceModeStatus(
            callerIsSuperAdmin: false,
            isActive: true,
            maintenanceUntil: serverTime.add(const Duration(hours: 1)),
            serverTime: serverTime,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MaintenanceModeGate(
          repository: repository,
          child: const Text('App home'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Temporarily unavailable'), findsOneWidget);
    expect(find.text('App home'), findsNothing);
  });

  testWidgets('Super Admins bypass active maintenance', (
    WidgetTester tester,
  ) async {
    final DateTime serverTime = DateTime.now().toUtc();
    final TestMaintenanceModeRepository repository =
        TestMaintenanceModeRepository(
          status: MaintenanceModeStatus(
            callerIsSuperAdmin: true,
            isActive: true,
            maintenanceUntil: serverTime.add(const Duration(hours: 1)),
            serverTime: serverTime,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MaintenanceModeGate(
          repository: repository,
          child: const Text('App home'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('App home'), findsOneWidget);
    expect(find.text('Temporarily unavailable'), findsNothing);
  });

  testWidgets('the app resumes after the maintenance end time', (
    WidgetTester tester,
  ) async {
    final DateTime serverTime = DateTime.now().toUtc();
    final TestMaintenanceModeRepository repository =
        TestMaintenanceModeRepository(
          status: MaintenanceModeStatus(
            callerIsSuperAdmin: false,
            isActive: true,
            maintenanceUntil: serverTime.add(const Duration(seconds: 5)),
            serverTime: serverTime,
          ),
          queuedStatuses: [
            MaintenanceModeStatus(
              callerIsSuperAdmin: false,
              isActive: true,
              maintenanceUntil: serverTime.add(const Duration(seconds: 5)),
              serverTime: serverTime,
            ),
            MaintenanceModeStatus(
              callerIsSuperAdmin: false,
              isActive: false,
              maintenanceUntil: serverTime.add(const Duration(seconds: 5)),
              serverTime: serverTime.add(const Duration(seconds: 5)),
            ),
          ],
        );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MaintenanceModeGate(
          repository: repository,
          child: const Text('App home'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Temporarily unavailable'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('App home'), findsOneWidget);
    expect(find.text('Temporarily unavailable'), findsNothing);
    expect(repository.loadCalls, 2);
  });
}
