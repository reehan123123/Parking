import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/history/presentation/history_page.dart';
import 'package:parking_management/features/parking/data/parking_session_repository.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';

import '../../parking/presentation/parking_test_repository.dart';

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
      home: Scaffold(body: HistoryPage(repository: repository)),
    ),
  );
}

ParkingSession _session({required String id, required String plateNumber}) {
  return ParkingSession(
    id: id,
    plateNumber: plateNumber,
    entryTime: DateTime(2026, 10, 14, 10, 30),
    allowedDuration: const ParkingDuration(
      value: 1,
      unit: ParkingDurationUnit.hours,
    ),
    expiresAt: DateTime(2026, 10, 14, 11, 30),
  );
}
