import 'parking_duration_unit.dart';

class ParkingDuration {
  const ParkingDuration({required this.value, required this.unit});

  final int value;
  final ParkingDurationUnit unit;

  bool get isPositive => value > 0;

  @override
  bool operator ==(Object other) {
    return other is ParkingDuration &&
        other.value == value &&
        other.unit == unit;
  }

  @override
  int get hashCode => Object.hash(value, unit);
}
