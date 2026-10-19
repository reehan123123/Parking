import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking/data/parking_session_repository.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';
import 'package:parking_management/features/parking/presentation/parking_session_details_page.dart';
import 'package:parking_management/l10n/app_localizations.dart';

import 'parking_test_repository.dart';

void main() {
  testWidgets('shows session details and current status', (
    WidgetTester tester,
  ) async {
    final session = _session();
    final repository = TestParkingSessionRepository(sessions: [session]);

    await _pumpDetails(tester, repository, session);
    await tester.pump();

    expect(find.text('AB 123'), findsOneWidget);
    expect(find.text('Entry time'), findsOneWidget);
    expect(find.text('Allowed duration'), findsOneWidget);
    expect(find.text('Expiry'), findsOneWidget);
    expect(
      find.text('No vehicle photo is attached to this session.'),
      findsOneWidget,
    );
  });

  testWidgets('loads a signed private photo URL when a photo exists', (
    WidgetTester tester,
  ) async {
    final session = _session(photoPath: 'user-1/session-1/car.jpg');
    final repository = TestParkingSessionRepository(
      sessions: [session],
      photoUrlResult: const ParkingSessionPhotoUrlSuccess(
        url: 'https://example.test/photo.jpg',
      ),
    );

    await _pumpDetails(tester, repository, session);
    await tester.pump();

    expect(find.text('Vehicle photo'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('confirms deletion before removing the session', (
    WidgetTester tester,
  ) async {
    final session = _session();
    final repository = TestParkingSessionRepository(sessions: [session]);

    await _pumpDetails(tester, repository, session);
    await tester.pump();
    await tester.tap(find.byTooltip('Delete session'));
    await tester.pump();

    expect(find.text('Delete parking session?'), findsOneWidget);
    await tester.tap(find.text('Delete').last);
    await tester.pump();

    expect(repository.deleteCalls, 1);
    expect(find.text('Delete parking session?'), findsNothing);
  });

  testWidgets('opens the entry form in edit mode', (WidgetTester tester) async {
    final session = _session();
    final repository = TestParkingSessionRepository(sessions: [session]);

    await _pumpDetails(tester, repository, session);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit session'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Parking Entry'), findsOneWidget);
    expect(find.text('Update parking entry'), findsOneWidget);
  });
}

Future<void> _pumpDetails(
  WidgetTester tester,
  TestParkingSessionRepository repository,
  ParkingSession session,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ParkingSessionDetailsPage(repository: repository, session: session),
    ),
  );
}

ParkingSession _session({String? photoPath}) {
  return ParkingSession(
    id: 'session-1',
    plateNumber: 'AB 123',
    photoPath: photoPath,
    entryTime: DateTime(2026, 10, 14, 10, 30),
    allowedDuration: const ParkingDuration(
      value: 2,
      unit: ParkingDurationUnit.hours,
    ),
    expiresAt: DateTime(2026, 10, 14, 12, 30),
  );
}
