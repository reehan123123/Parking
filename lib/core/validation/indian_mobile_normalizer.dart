/// Shared validation/normalization for Indian mobile numbers, used by both
/// tenant contact details and parking-session contact numbers.
///
/// Accepted input formats (after trimming whitespace):
/// - `9876543210` (10 digits starting with 6-9)
/// - `+919876543210` or `919876543210` (optional `+91`/`91` country prefix)
///
/// The normalized, stored form is always `+91XXXXXXXXXX`.
class IndianMobileNormalizer {
  const IndianMobileNormalizer._();

  static final RegExp _tenDigit = RegExp(r'^[6-9][0-9]{9}$');
  static final RegExp _normalized = RegExp(r'^\+91[6-9][0-9]{9}$');

  /// Returns the normalized `+91XXXXXXXXXX` form, or `null` if [value] does
  /// not match a recognized Indian mobile number format.
  static String? tryNormalize(String value) {
    var digits = value.trim();
    if (digits.isEmpty) {
      return null;
    }

    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0') && digits.length == 11) {
      digits = digits.substring(1);
    }

    if (!_tenDigit.hasMatch(digits)) {
      return null;
    }

    return '+91$digits';
  }

  /// Whether [value] is already in the normalized `+91XXXXXXXXXX` form.
  static bool isNormalized(String value) => _normalized.hasMatch(value);
}
