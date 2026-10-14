enum DurationCalculationFailureReason { nonPositiveValue, outOfRange }

sealed class DurationCalculationResult {
  const DurationCalculationResult();
}

final class DurationCalculationSuccess extends DurationCalculationResult {
  const DurationCalculationSuccess({required this.expiresAt});

  final DateTime expiresAt;
}

final class DurationCalculationFailure extends DurationCalculationResult {
  const DurationCalculationFailure({required this.reason});

  final DurationCalculationFailureReason reason;
}
