import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/history/presentation/history_page.dart';
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
  testWidgets('shows sessions in the repository order', (
    WidgetTester tester,
  ) async {
    final repository = TestParkingSessionRepository(
      sessions: [
        _session(id: 'newest', plateNumber: 'NEW 222'),
        _session(id: 'older', plateNumber: 'OLD 111'),
      ],
    );

    await _pumpHistory(tester, repository);
    await tester.pump();

    expect(find.text('NEW 222'), findsOneWidget);
    expect(find.text('OLD 111'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('NEW 222')).dy,
      lessThan(tester.getTopLeft(find.text('OLD 111')).dy),
    );
  });

  testWidgets('uses server-side search and displays an empty result', (
    WidgetTester tester,
  ) async {
    final repository = TestParkingSessionRepository();
    await _pumpHistory(tester, repository);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'xy 987');
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.lastSearch, 'xy 987');
    expect(find.text('No matching sessions'), findsOneWidget);
  });

  testWidgets('loads another page and resets pagination for a new search', (
    WidgetTester tester,
  ) async {
    final sessions = List.generate(
      51,
      (index) => _session(id: 'session-$index', plateNumber: 'PLATE $index'),
    );
    final repository = TestParkingSessionRepository(sessions: sessions);

    await _pumpHistory(tester, repository);
    await tester.pump();

    expect(repository.lastOffset, 0);
    expect(repository.lastPageSize, 50);
    expect(find.text('Load more'), findsOneWidget);

    final nextPage = Completer<ParkingSessionListResult>();
    repository.nextListCompleter = nextPage;
    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pump();

    expect(repository.listCalls, 2);
    expect(find.text('Load more'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    nextPage.complete(ParkingSessionListSuccess(sessions: [sessions.last]));
    await tester.pump();
    await tester.pump();

    expect(repository.lastOffset, 50);
    expect(find.text('PLATE 50'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);

    await tester.enterText(find.byType(TextField), 'new');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(repository.lastOffset, 0);
    expect(repository.lastSearch, 'new');
    expect(repository.listCalls, 3);
  });

  testWidgets('filters sessions by status and payment chips', (
    WidgetTester tester,
  ) async {
    final farFuture = DateTime.now().add(const Duration(days: 365));
    final farPast = DateTime.now().subtract(const Duration(days: 365));
    final repository = TestParkingSessionRepository(
      sessions: [
        _session(
          id: 'active-unpaid',
          plateNumber: 'ACTIVE UNPAID',
          expiresAt: farFuture,
        ),
        _session(
          id: 'expired-paid',
          plateNumber: 'EXPIRED PAID',
          expiresAt: farPast,
          totalCharge: 100,
          paidAmount: 100,
        ),
      ],
    );

    await _pumpHistory(tester, repository);
    await tester.pump();

    expect(find.text('ACTIVE UNPAID'), findsOneWidget);
    expect(find.text('EXPIRED PAID'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Active'));
    await tester.pump();

    expect(find.text('ACTIVE UNPAID'), findsOneWidget);
    expect(find.text('EXPIRED PAID'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Active'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Paid'));
    await tester.pump();

    expect(find.text('ACTIVE UNPAID'), findsNothing);
    expect(find.text('EXPIRED PAID'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Clear filters'));
    await tester.pump();

    expect(find.text('ACTIVE UNPAID'), findsOneWidget);
    expect(find.text('EXPIRED PAID'), findsOneWidget);
  });

  testWidgets('retries a failed next page without losing current sessions', (
    WidgetTester tester,
  ) async {
    final sessions = List.generate(
      51,
      (index) => _session(id: 'session-$index', plateNumber: 'PLATE $index'),
    );
    final repository = TestParkingSessionRepository(sessions: sessions);

    await _pumpHistory(tester, repository);
    await tester.pump();

    repository.listResult = const ParkingSessionListFailure(
      message: 'Next page unavailable.',
    );
    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pump();

    expect(find.text('Next page unavailable.'), findsOneWidget);
    expect(find.text('PLATE 0'), findsOneWidget);

    repository.listResult = null;
    await tester.ensureVisible(find.text('Try again'));
    await tester.pump();
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(repository.lastOffset, 50);
    expect(find.text('PLATE 50'), findsOneWidget);
  });

  testWidgets('ignores a late page response after search changes', (
    WidgetTester tester,
  ) async {
    final sessions = List.generate(
      51,
      (index) => _session(id: 'session-$index', plateNumber: 'PLATE $index'),
    );
    final repository = TestParkingSessionRepository(sessions: sessions);

    await _pumpHistory(tester, repository);
    await tester.pump();

    final nextPage = Completer<ParkingSessionListResult>();
    repository.nextListCompleter = nextPage;
    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'fresh');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    nextPage.complete(
      ParkingSessionListSuccess(
        sessions: [_session(id: 'stale', plateNumber: 'STALE')],
      ),
    );
    await tester.pump();

    expect(repository.lastOffset, 0);
    expect(repository.lastSearch, 'fresh');
    expect(find.text('STALE'), findsNothing);
    expect(find.text('PLATE 0'), findsOneWidget);
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
            body: HistoryPage(
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
    await tester.tap(find.text('AB 123'));
    await tester.pumpAndSettle();
    expect(repository.listCalls, 1);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.listCalls, 2);
  });

  testWidgets('shows and retries a history loading error', (
    WidgetTester tester,
  ) async {
    final repository = TestParkingSessionRepository()
      ..listResult = const ParkingSessionListFailure(
        message: 'History unavailable.',
      );
    await _pumpHistory(tester, repository);
    await tester.pump();

    expect(find.text('History unavailable.'), findsOneWidget);
    repository.listResult = null;
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(find.text('No parking history'), findsOneWidget);
  });
}

Future<void> _pumpHistory(
  WidgetTester tester,
  TestParkingSessionRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: HistoryPage(scope: _tenantScope, repository: repository),
      ),
    ),
  );
}

ParkingSession _session({
  required String id,
  required String plateNumber,
  DateTime? expiresAt,
  double totalCharge = 0,
  double paidAmount = 0,
}) {
  return ParkingSession(
    id: id,
    plateNumber: plateNumber,
    entryTime: DateTime(2026, 10, 14, 10, 30),
    allowedDuration: const ParkingDuration(
      value: 1,
      unit: ParkingDurationUnit.hours,
    ),
    expiresAt: expiresAt ?? DateTime(2026, 10, 14, 11, 30),
    totalCharge: totalCharge,
    paidAmount: paidAmount,
  );
}
