import 'package:flutter_test/flutter_test.dart';
import 'package:parking_management/features/parking/domain/duration_calculation_result.dart';
import 'package:parking_management/features/parking/domain/parking_duration.dart';
import 'package:parking_management/features/parking/domain/parking_duration_calculator.dart';
import 'package:parking_management/features/parking/domain/parking_duration_unit.dart';

void main() {
  const calculator = ParkingDurationCalculator();

  group('calculateExpiry', () {
    test('adds minutes as elapsed time', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.utc(2026, 1, 15, 10, 30, 45, 123, 456),
        duration: const ParkingDuration(
          value: 30,
          unit: ParkingDurationUnit.minutes,
        ),
      );

      expect(
        result,
        isA<DurationCalculationSuccess>().having(
          (success) => success.expiresAt,
          'expiresAt',
          DateTime.utc(2026, 1, 15, 11, 0, 45, 123, 456),
        ),
      );
    });

    test('adds multiple hours as elapsed time', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.utc(2026, 1, 15, 10, 30),
        duration: const ParkingDuration(
          value: 5,
          unit: ParkingDurationUnit.hours,
        ),
      );

      expect(
        result,
        isA<DurationCalculationSuccess>().having(
          (success) => success.expiresAt,
          'expiresAt',
          DateTime.utc(2026, 1, 15, 15, 30),
        ),
      );
    });

    test('adds calendar days while preserving the time of day', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.utc(2026, 1, 31, 23, 45, 12, 250, 750),
        duration: const ParkingDuration(
          value: 2,
          unit: ParkingDurationUnit.days,
        ),
      );

      expect(
        result,
        isA<DurationCalculationSuccess>().having(
          (success) => success.expiresAt,
          'expiresAt',
          DateTime.utc(2026, 2, 2, 23, 45, 12, 250, 750),
        ),
      );
    });

    test('adds one month from a mid-month date', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.utc(2026, 3, 15, 8, 20),
        duration: const ParkingDuration(
          value: 1,
          unit: ParkingDurationUnit.months,
        ),
      );

      expect(
        result,
        isA<DurationCalculationSuccess>().having(
          (success) => success.expiresAt,
          'expiresAt',
          DateTime.utc(2026, 4, 15, 8, 20),
        ),
      );
    });

    test('adds multiple months across a year boundary', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.utc(2026, 3, 15, 8, 20),
        duration: const ParkingDuration(
          value: 11,
          unit: ParkingDurationUnit.months,
        ),
      );

      expect(
        result,
        isA<DurationCalculationSuccess>().having(
          (success) => success.expiresAt,
          'expiresAt',
          DateTime.utc(2027, 2, 15, 8, 20),
        ),
      );
    });

    test('calculates multiple months from the original calendar day', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.utc(2025, 1, 31, 8, 20),
        duration: const ParkingDuration(
          value: 2,
          unit: ParkingDurationUnit.months,
        ),
      );

      expect(
        result,
        isA<DurationCalculationSuccess>().having(
          (success) => success.expiresAt,
          'expiresAt',
          DateTime.utc(2025, 3, 31, 8, 20),
        ),
      );
    });

    test('clamps January 31 to February 28 in a non-leap year', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.utc(2025, 1, 31, 12, 10),
        duration: const ParkingDuration(
          value: 1,
          unit: ParkingDurationUnit.months,
        ),
      );

      expect(
        result,
        isA<DurationCalculationSuccess>().having(
          (success) => success.expiresAt,
          'expiresAt',
          DateTime.utc(2025, 2, 28, 12, 10),
        ),
      );
    });

    test('clamps January 31 to February 29 in a leap year', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.utc(2024, 1, 31, 12, 10),
        duration: const ParkingDuration(
          value: 1,
          unit: ParkingDurationUnit.months,
        ),
      );

      expect(
        result,
        isA<DurationCalculationSuccess>().having(
          (success) => success.expiresAt,
          'expiresAt',
          DateTime.utc(2024, 2, 29, 12, 10),
        ),
      );
    });

    test('handles December to January rollover', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.utc(2026, 12, 31, 18, 5),
        duration: const ParkingDuration(
          value: 1,
          unit: ParkingDurationUnit.months,
        ),
      );

      expect(
        result,
        isA<DurationCalculationSuccess>().having(
          (success) => success.expiresAt,
          'expiresAt',
          DateTime.utc(2027, 1, 31, 18, 5),
        ),
      );
    });

    test('preserves local DateTime context for calendar calculations', () {
      final entryTime = DateTime(2026, 6, 15, 10, 20, 30, 400, 500);
      final result = calculator.calculateExpiry(
        entryTime: entryTime,
        duration: const ParkingDuration(
          value: 1,
          unit: ParkingDurationUnit.months,
        ),
      );

      final success = result as DurationCalculationSuccess;
      expect(success.expiresAt.isUtc, isFalse);
      expect(success.expiresAt, DateTime(2026, 7, 15, 10, 20, 30, 400, 500));
    });

    test('returns a failure for zero duration', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.utc(2026, 1, 1),
        duration: const ParkingDuration(
          value: 0,
          unit: ParkingDurationUnit.minutes,
        ),
      );

      expect(
        result,
        isA<DurationCalculationFailure>().having(
          (failure) => failure.reason,
          'reason',
          DurationCalculationFailureReason.nonPositiveValue,
        ),
      );
    });

    test('returns a failure for negative duration', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.utc(2026, 1, 1),
        duration: const ParkingDuration(
          value: -1,
          unit: ParkingDurationUnit.days,
        ),
      );

      expect(
        result,
        isA<DurationCalculationFailure>().having(
          (failure) => failure.reason,
          'reason',
          DurationCalculationFailureReason.nonPositiveValue,
        ),
      );
    });

    test('returns a failure when the result exceeds DateTime range', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.fromMillisecondsSinceEpoch(
          8640000000000000,
          isUtc: true,
        ),
        duration: const ParkingDuration(
          value: 1,
          unit: ParkingDurationUnit.minutes,
        ),
      );

      expect(
        result,
        isA<DurationCalculationFailure>().having(
          (failure) => failure.reason,
          'reason',
          DurationCalculationFailureReason.outOfRange,
        ),
      );
    });

    test('returns a failure when a calendar result exceeds DateTime range', () {
      final result = calculator.calculateExpiry(
        entryTime: DateTime.fromMillisecondsSinceEpoch(
          8640000000000000,
          isUtc: true,
        ),
        duration: const ParkingDuration(
          value: 1,
          unit: ParkingDurationUnit.months,
        ),
      );

      expect(
        result,
        isA<DurationCalculationFailure>().having(
          (failure) => failure.reason,
          'reason',
          DurationCalculationFailureReason.outOfRange,
        ),
      );
    });
  });
}
