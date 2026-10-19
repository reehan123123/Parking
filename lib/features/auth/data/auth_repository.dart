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

  /// Whether this backend can send and complete self-service password-reset
  /// emails. The opt-in local development backend has no email capability
  /// and reports `false` so the UI can disable the affordance instead of
  /// failing every attempt.
  bool get supportsPasswordRecovery;

  Stream<bool> get signedInChanges;

  /// Emits whenever the user opens a Supabase password-recovery link. The
  /// recovery flow establishes a temporary session that must only be used to
  /// set a new password, never to silently grant standing app access.
  Stream<void> get passwordRecoveryEvents;

  Future<void> signIn({required String email, required String password});

  Future<void> changeTemporaryPassword({required String newPassword});

  /// Requests a password-reset email for [email] using the backend's
  /// built-in recovery mechanism. Throws [AuthRepositoryException] if
  /// [supportsPasswordRecovery] is `false`.
  Future<void> requestPasswordReset({required String email});

  /// Completes a password-recovery session by setting [newPassword]. Must
  /// only be called while a recovery session (see [passwordRecoveryEvents])
  /// is active. Throws [AuthRepositoryException] if
  /// [supportsPasswordRecovery] is `false`.
  Future<void> completePasswordRecovery({required String newPassword});

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
  bool get supportsPasswordRecovery => true;

  @override
  Stream<bool> get signedInChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session != null);

  @override
  Stream<void> get passwordRecoveryEvents => _client.auth.onAuthStateChange
      .where((state) => state.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

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
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: '${Uri.base.origin}/',
      );
    } on AuthException catch (error) {
      throw AuthRepositoryException(_passwordResetRequestError(error));
    }
  }

  @override
  Future<void> completePasswordRecovery({required String newPassword}) async {
    if (newPassword.length < 12 || newPassword.length > 128) {
      throw const AuthRepositoryException(
        'Use a password between 12 and 128 characters.',
      );
    }

    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw AuthRepositoryException(_passwordRecoveryUpdateError(error));
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  static String _passwordResetRequestError(AuthException error) {
    final statusCode = int.tryParse(error.statusCode ?? '');
    if (statusCode == 429) {
      return 'Too many reset requests. Wait a few minutes and try again.';
    }
    return 'The reset email could not be sent right now. Check your connection and try again.';
  }

  static String _passwordRecoveryUpdateError(AuthException error) {
    final statusCode = int.tryParse(error.statusCode ?? '');
    if (statusCode == 422 || statusCode == 400) {
      return 'Use a password between 12 and 128 characters.';
    }
    return 'This reset link has expired or was already used. Request a new password reset email.';
  }

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
