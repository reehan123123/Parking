import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  bool get isSignedIn;

  bool get requiresTemporaryPasswordChange;

  Stream<bool> get signedInChanges;

  Future<void> signIn({required String email, required String password});

  Future<void> changeTemporaryPassword({required String newPassword});

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isSignedIn => _client.auth.currentSession != null;

  @override
  bool get requiresTemporaryPasswordChange =>
      _client
          .auth
          .currentUser
          ?.appMetadata['parking_temporary_password_reset_required'] ==
      true;

  @override
  Stream<bool> get signedInChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> changeTemporaryPassword({required String newPassword}) async {
    if (!requiresTemporaryPasswordChange) {
      throw const AuthRepositoryException(
        'This account does not require a temporary password change.',
      );
    }
    if (newPassword.length < 12 || newPassword.length > 128) {
      throw const AuthRepositoryException(
        'Use a password between 12 and 128 characters.',
      );
    }

    try {
      final response = await _client.functions.invoke(
        'complete-temporary-password-reset',
        body: {'newPassword': newPassword},
      );
      final responseData = response.data;
      if (responseData is! Map || responseData['success'] != true) {
        throw const AuthRepositoryException(
          'The password change could not be confirmed. Try again.',
        );
      }

      await _client.auth.refreshSession();
      if (requiresTemporaryPasswordChange) {
        throw const AuthRepositoryException(
          'The password was changed, but your session could not be refreshed. '
          'Sign out and sign in again with the new password.',
        );
      }
    } on FunctionException catch (error) {
      throw AuthRepositoryException(_passwordChangeError(error.status));
    } on AuthException {
      throw const AuthRepositoryException(
        'The password was changed, but your session could not be refreshed. '
        'Sign out and sign in again with the new password.',
      );
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  static String _passwordChangeError(int status) {
    return switch (status) {
      400 => 'Use a password between 12 and 128 characters.',
      401 => 'Your session expired. Sign in again to change the password.',
      409 => 'This account is no longer waiting for a password change. Sign in again.',
      _ =>
        'The password could not be changed. Check your connection and retry.',
    };
  }
}
