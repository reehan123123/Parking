import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';
import 'package:parking_management/features/parking/domain/parking_session.dart';

void main() {
  final expiresAt = DateTime.utc(2026, 1, 1, 12);
  final session = ParkingSession(
    plateNumber: 'ABC123',
    entryTime: DateTime.utc(2026, 1, 1, 10),
    allowedDuration: const ParkingDuration(
      value: 2,
      unit: ParkingDurationUnit.hours,
    ),
    expiresAt: expiresAt,
  );

  test('is active immediately before expiry', () {
    expect(
      session.statusAt(expiresAt.subtract(const Duration(microseconds: 1))),
      ParkingSessionStatus.active,
    );
  });

  test('is expired exactly at expiry', () {
    expect(session.statusAt(expiresAt), ParkingSessionStatus.expired);
  });

  test('is expired after expiry', () {
    expect(
      session.statusAt(expiresAt.add(const Duration(microseconds: 1))),
      ParkingSessionStatus.expired,
    );
  });

  test('stores the core domain fields', () {
    expect(session.plateNumber, 'ABC123');
    expect(session.entryTime, DateTime.utc(2026, 1, 1, 10));
    expect(session.expiresAt, expiresAt);
    expect(
      session.allowedDuration,
      const ParkingDuration(value: 2, unit: ParkingDurationUnit.hours),
    );
  });
}
