/// Applies the shared safe normalization rules for vehicle registrations.
class ParkingPlateNormalizer {
  const ParkingPlateNormalizer._();

  /// Trims a registration and normalizes its case without guessing characters.
  static String normalize(String value) {
    return value.trim().toUpperCase();
  }

  /// Selects a reviewable registration candidate from OCR text.
  static String? candidateFromOcr(String rawText) {
    final candidates = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => normalize(line).replaceAll(RegExp(r'\s+'), ' '))
        .where((line) => RegExp(r'[A-Z0-9]').hasMatch(line))
        .toList();
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((first, second) {
      final scoreComparison = _score(second).compareTo(_score(first));
      if (scoreComparison != 0) {
        return scoreComparison;
      }

      return second.length.compareTo(first.length);
    });
    return candidates.first;
  }

  static int _score(String candidate) {
    final hasLetters = RegExp(r'[A-Z]').hasMatch(candidate);
    final hasDigits = RegExp(r'\d').hasMatch(candidate);
    final alphanumericCount = RegExp(r'[A-Z0-9]').allMatches(candidate).length;
    final mixedCharacterBonus = hasLetters && hasDigits ? 8 : 0;
    return alphanumericCount + mixedCharacterBonus;
  }
}
