import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';
import 'package:parking_management/features/parking/presentation/parking_session_list_view.dart';
import 'package:parking_management/l10n/app_localizations.dart';

ParkingSession _sessionOverHours(int hours) {
  final entryTime = DateTime(2026, 1, 1, 0, 0);
  return ParkingSession(
    plateNumber: 'AB 123',
    entryTime: entryTime,
    allowedDuration: const ParkingDuration(
      value: 10,
      unit: ParkingDurationUnit.hours,
    ),
    expiresAt: entryTime.add(const Duration(hours: 10)),
  );
}

void main() {
  group('ParkingSessionStatusChip.elapsedFraction', () {
    test('is 0 right at entry time', () {
      final session = _sessionOverHours(10);
      expect(
        ParkingSessionStatusChip.elapsedFraction(session, session.entryTime),
        0,
      );
    });

    test('reports the proportion of the window elapsed', () {
      final session = _sessionOverHours(10);
      final threeHoursIn = session.entryTime.add(const Duration(hours: 3));
      expect(
        ParkingSessionStatusChip.elapsedFraction(session, threeHoursIn),
        closeTo(0.3, 0.0001),
      );
    });

    test('clamps to 1 once the window has passed', () {
      final session = _sessionOverHours(10);
      final afterExpiry = session.entryTime.add(const Duration(hours: 20));
      expect(ParkingSessionStatusChip.elapsedFraction(session, afterExpiry), 1);
    });

    test('treats a zero-length window as fully elapsed', () {
      final entryTime = DateTime(2026, 1, 1, 0, 0);
      final session = ParkingSession(
        plateNumber: 'AB 123',
        entryTime: entryTime,
        allowedDuration: const ParkingDuration(
          value: 0,
          unit: ParkingDurationUnit.hours,
        ),
        expiresAt: entryTime,
      );
      expect(ParkingSessionStatusChip.elapsedFraction(session, entryTime), 1);
    });
  });

  group('ParkingSessionStatusChip.activeBandColor', () {
    test('is green below 30% elapsed', () {
      expect(
        ParkingSessionStatusChip.activeBandColor(0.0),
        Colors.green.shade600,
      );
      expect(
        ParkingSessionStatusChip.activeBandColor(0.29),
        Colors.green.shade600,
      );
    });

    test('is amber between 30% and 60% elapsed', () {
      expect(
        ParkingSessionStatusChip.activeBandColor(0.3),
        Colors.amber.shade700,
      );
      expect(
        ParkingSessionStatusChip.activeBandColor(0.59),
        Colors.amber.shade700,
      );
    });

    test('is deep orange between 60% and 90% elapsed', () {
      expect(
        ParkingSessionStatusChip.activeBandColor(0.6),
        Colors.deepOrange.shade600,
      );
      expect(
        ParkingSessionStatusChip.activeBandColor(0.89),
        Colors.deepOrange.shade600,
      );
    });

    test('is red from 90% elapsed onward', () {
      expect(
        ParkingSessionStatusChip.activeBandColor(0.9),
        Colors.red.shade700,
      );
      expect(
        ParkingSessionStatusChip.activeBandColor(1.0),
        Colors.red.shade700,
      );
    });
  });

  group('ParkingSessionListView layout', () {
    testWidgets('renders without overflow when a payment chip is shown', (
      tester,
    ) async {
      final entryTime = DateTime(2026, 1, 1, 0, 0);
      final session = ParkingSession(
        plateNumber: 'TEST1235431',
        entryTime: entryTime,
        allowedDuration: const ParkingDuration(
          value: 21,
          unit: ParkingDurationUnit.hours,
        ),
        expiresAt: entryTime.add(const Duration(hours: 21)),
        totalCharge: 1234,
        paidAmount: 500,
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: ParkingSessionListView(
                sessions: [session],
                onSessionTap: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('TEST1235431'), findsOneWidget);
      expect(find.text('Partially paid'), findsOneWidget);
    });
  });

  group('ParkingPaymentStatusChip tooltip', () {
    testWidgets('shows total, paid, and remaining amounts on hover', (
      tester,
    ) async {
      final entryTime = DateTime(2026, 1, 1, 0, 0);
      final session = ParkingSession(
        plateNumber: 'TEST1235431',
        entryTime: entryTime,
        allowedDuration: const ParkingDuration(
          value: 21,
          unit: ParkingDurationUnit.hours,
        ),
        expiresAt: entryTime.add(const Duration(hours: 21)),
        totalCharge: 1234,
        paidAmount: 500,
      );

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ParkingPaymentStatusChip(session: session)),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(
        tooltip.message,
        'Total: ₹1234.00\n'
        'Paid: ₹500.00\n'
        'Remaining: ₹734.00',
      );
    });
  });
}
