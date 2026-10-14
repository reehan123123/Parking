import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/dashboard/presentation/dashboard_page.dart';
import 'package:parking_management/features/parking/data/parking_session_repository.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';

import '../../parking/presentation/parking_test_repository.dart';

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
    expect(repository.listCalls, greaterThanOrEqualTo(2));
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
  TestParkingSessionRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DashboardPage(repository: repository, onNewParkingEntry: () {}),
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
