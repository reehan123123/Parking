import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/dashboard/presentation/dashboard_page.dart';
import 'package:parking_management/features/parking/data/parking_session_repository.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';
import 'package:parking_management/features/tenants/domain/parking_tenant_scope.dart';
import 'package:parking_management/l10n/app_localizations.dart';

import '../../parking/presentation/parking_test_repository.dart';

const _tenantScope = ParkingTenantScope(
  isSuperAdmin: false,
  tenantId: 'test-tenant',
);

void main() {
  testWidgets('shows summary counts and recent sessions', (
    WidgetTester tester,
  ) async {
    final repository = TestParkingSessionRepository(
      sessions: [_session(id: 'session-1', plateNumber: 'AB 123')],
      summaryValue: const ParkingSessionSummary(
        activeCount: 2,
        expiredCount: 1,
      ),
    );

    await _pumpDashboard(tester, repository);
    await tester.pump();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('AB 123'), findsOneWidget);
    expect(find.text('Recent sessions'), findsOneWidget);
  });

  testWidgets('forwards registration searches to the repository', (
    WidgetTester tester,
  ) async {
    final repository = TestParkingSessionRepository();
    await _pumpDashboard(tester, repository);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'ab 12');
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.lastSearch, 'ab 12');
    expect(repository.listCalls, 2);
    expect(repository.lastPageSize, 10);
    expect(repository.summaryCalls, 1);
  });

  testWidgets('bounds the dashboard preview and opens History', (
    WidgetTester tester,
  ) async {
    final repository = TestParkingSessionRepository(
      sessions: List.generate(
        11,
        (index) => _session(id: 'session-$index', plateNumber: 'PLATE $index'),
      ),
    );
    var openedHistory = false;

    await _pumpDashboard(
      tester,
      repository,
      onViewHistory: () => openedHistory = true,
    );
    await tester.pump();

    expect(repository.lastPageSize, 10);
    expect(find.text('PLATE 9'), findsOneWidget);
    expect(find.text('PLATE 10'), findsNothing);
    expect(find.text('View all'), findsOneWidget);

    await tester.tap(find.text('View all'));

    expect(openedHistory, isTrue);
  });

  testWidgets('does not reload twice after a parent-handled data change', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = TestParkingSessionRepository(
      sessions: [_session(id: 'session-1', plateNumber: 'AB 123')],
    );
    var refreshToken = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: DashboardPage(
              scope: _tenantScope,
              repository: repository,
              refreshToken: refreshToken,
              onDataChanged: () => setState(() => refreshToken++),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.listCalls, 1);
    expect(repository.summaryCalls, 1);

    await tester.tap(find.text('AB 123'));
    await tester.pumpAndSettle();
    expect(repository.listCalls, 1);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.listCalls, 2);
    expect(repository.summaryCalls, 2);
  });

  testWidgets('shows an empty state for a dashboard without sessions', (
    WidgetTester tester,
  ) async {
    final repository = TestParkingSessionRepository();
    await _pumpDashboard(tester, repository);
    await tester.pump();

    expect(find.text('No parking sessions yet'), findsOneWidget);
    expect(find.text('New Parking Entry'), findsWidgets);
  });

  testWidgets('shows an error and retries the failed list request', (
    WidgetTester tester,
  ) async {
    final repository = TestParkingSessionRepository(
      listResult: const ParkingSessionListFailure(
        message: 'Network unavailable.',
      ),
    );
    await _pumpDashboard(tester, repository);
    await tester.pump();

    expect(find.text('Network unavailable.'), findsOneWidget);
    repository.listResult = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(find.text('No parking sessions yet'), findsOneWidget);
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  TestParkingSessionRepository repository, {
  VoidCallback? onViewHistory,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: DashboardPage(
          scope: _tenantScope,
          repository: repository,
          onNewParkingEntry: () {},
          onViewHistory: onViewHistory,
        ),
      ),
    ),
  );
}

ParkingSession _session({required String id, required String plateNumber}) {
  return ParkingSession(
    id: id,
    plateNumber: plateNumber,
    entryTime: DateTime(2026, 10, 14, 10, 30),
    allowedDuration: const ParkingDuration(
      value: 2,
      unit: ParkingDurationUnit.hours,
    ),
    expiresAt: DateTime(2026, 10, 14, 12, 30),
  );
}
