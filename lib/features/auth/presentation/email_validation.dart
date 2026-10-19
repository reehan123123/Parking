/// Shared email-format validation used by the sign-in and
/// forgot-password screens, so both present the same validation message.
String? validateEmailAddress(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Enter your email address.';
  }

  if (!email.contains('@')) {
    return 'Enter a valid email address.';
  }

  return null;
}
