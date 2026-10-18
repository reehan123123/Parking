/// Applies the shared safe normalization rules for vehicle registrations.
class ParkingPlateNormalizer {
  const ParkingPlateNormalizer._();

  /// Trims a registration and normalizes its case without guessing characters.
  static String normalize(String value) {
    return value.trim().toUpperCase();
  }
}
