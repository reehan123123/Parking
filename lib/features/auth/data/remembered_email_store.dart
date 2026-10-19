import 'package:shared_preferences/shared_preferences.dart';

/// Persists only the last-used sign-in email address locally, so it can be
/// prefilled on a future visit when the user opts in via "Remember me".
///
/// This never stores a password, access token, or refresh token; Supabase's
/// own session persistence remains the only mechanism that keeps a user
/// signed in.
class RememberedEmailStore {
  const RememberedEmailStore();

  static const _rememberedEmailKey = 'parking.remembered_email';

  /// Returns the remembered email address, or `null` if none is stored.
  Future<String?> read() async {
    final preferences = await SharedPreferences.getInstance();
    final email = preferences.getString(_rememberedEmailKey);
    return (email == null || email.isEmpty) ? null : email;
  }

  /// Saves [email] so it can be prefilled next time the sign-in screen opens.
  Future<void> save(String email) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_rememberedEmailKey, email);
  }

  /// Clears any previously remembered email address.
  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_rememberedEmailKey);
  }
}
