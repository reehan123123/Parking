import '../domain/parking_duration_unit.dart';

class ParkingEntryLimits {
  const ParkingEntryLimits._();

  static const int maximumMinutes = 525600;
  static const int maximumHours = 8760;
  static const int maximumDays = 365;
  static const int maximumMonths = 12;

  static int maximumFor(ParkingDurationUnit unit) {
    return switch (unit) {
      ParkingDurationUnit.minutes => maximumMinutes,
      ParkingDurationUnit.hours => maximumHours,
      ParkingDurationUnit.days => maximumDays,
      ParkingDurationUnit.months => maximumMonths,
    };
  }
}
