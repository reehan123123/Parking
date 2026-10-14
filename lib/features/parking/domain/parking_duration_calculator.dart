import 'duration_calculation_result.dart';
import 'parking_duration.dart';
import 'parking_duration_unit.dart';

class ParkingDurationCalculator {
  const ParkingDurationCalculator();

  DurationCalculationResult calculateExpiry({
    required DateTime entryTime,
    required ParkingDuration duration,
  }) {
    if (!duration.isPositive) {
      return const DurationCalculationFailure(
        reason: DurationCalculationFailureReason.nonPositiveValue,
      );
    }

    try {
      final DateTime expiresAt = switch (duration.unit) {
        ParkingDurationUnit.minutes => entryTime.add(
          Duration(minutes: duration.value),
        ),
        ParkingDurationUnit.hours => entryTime.add(
          Duration(hours: duration.value),
        ),
        ParkingDurationUnit.days => _addCalendarDays(entryTime, duration.value),
        ParkingDurationUnit.months => _addCalendarMonths(
          entryTime,
          duration.value,
        ),
      };

      return DurationCalculationSuccess(expiresAt: expiresAt);
    } on RangeError {
      return const DurationCalculationFailure(
        reason: DurationCalculationFailureReason.outOfRange,
      );
    } on ArgumentError {
      return const DurationCalculationFailure(
        reason: DurationCalculationFailureReason.outOfRange,
      );
    }
  }

  DateTime _addCalendarDays(DateTime entryTime, int days) {
    return _createDateTime(
      source: entryTime,
      year: entryTime.year,
      month: entryTime.month,
      day: entryTime.day + days,
    );
  }

  DateTime _addCalendarMonths(DateTime entryTime, int months) {
    final int targetMonthIndex = entryTime.month - 1 + months;
    final int targetYear = entryTime.year + targetMonthIndex ~/ 12;
    final int targetMonth = targetMonthIndex % 12 + 1;
    final int lastDayOfTargetMonth = _daysInMonth(
      year: targetYear,
      month: targetMonth,
    );
    final int targetDay = entryTime.day > lastDayOfTargetMonth
        ? lastDayOfTargetMonth
        : entryTime.day;

    return _createDateTime(
      source: entryTime,
      year: targetYear,
      month: targetMonth,
      day: targetDay,
    );
  }

  int _daysInMonth({required int year, required int month}) {
    return DateTime.utc(year, month + 1, 0).day;
  }

  DateTime _createDateTime({
    required DateTime source,
    required int year,
    required int month,
    required int day,
  }) {
    if (source.isUtc) {
      return DateTime.utc(
        year,
        month,
        day,
        source.hour,
        source.minute,
        source.second,
        source.millisecond,
        source.microsecond,
      );
    }

    return DateTime(
      year,
      month,
      day,
      source.hour,
      source.minute,
      source.second,
      source.millisecond,
      source.microsecond,
    );
  }
}
