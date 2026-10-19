import 'dart:async';

import 'package:parking_management/features/auth/data/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.isSignedIn = false,
    this.requiresTemporaryPasswordChange = false,
    this.supportsPasswordRecovery = true,
    this.signInCompleter,
  });

  @override
  bool isSignedIn;

  @override
  bool requiresTemporaryPasswordChange;

  @override
  bool supportsPasswordRecovery;

  final StreamController<bool> _signedInChanges =
      StreamController<bool>.broadcast();
  final StreamController<void> _passwordRecoveryEvents =
      StreamController<void>.broadcast();
  Object? signInError;
  Object? passwordChangeError;
  Object? passwordResetRequestError;
  Object? passwordRecoveryCompletionError;
  Completer<void>? signInCompleter;
  Completer<void>? passwordResetCompleter;
  String? lastNewPassword;
  String? lastResetEmail;
  String? lastRecoveryPassword;

  @override
  Stream<bool> get signedInChanges => _signedInChanges.stream;

  @override
  Stream<void> get passwordRecoveryEvents => _passwordRecoveryEvents.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final completer = signInCompleter;
    if (completer != null) {
      await completer.future;
    }

    final error = signInError;
    if (error != null) {
      throw error;
    }

    isSignedIn = true;
    _signedInChanges.add(true);
  }

  @override
  Future<void> changeTemporaryPassword({required String newPassword}) async {
    final error = passwordChangeError;
    if (error != null) {
      throw error;
    }

    lastNewPassword = newPassword;
    requiresTemporaryPasswordChange = false;
    _signedInChanges.add(isSignedIn);
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    final completer = passwordResetCompleter;
    if (completer != null) {
      await completer.future;
    }

    lastResetEmail = email;
    final error = passwordResetRequestError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> completePasswordRecovery({required String newPassword}) async {
    lastRecoveryPassword = newPassword;
    final error = passwordRecoveryCompletionError;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> signOut() async {
    isSignedIn = false;
    _signedInChanges.add(false);
  }

  void emitSignedIn(bool value) {
    isSignedIn = value;
    _signedInChanges.add(value);
  }

  void emitPasswordRecoveryEvent() {
    _passwordRecoveryEvents.add(null);
  }

  Future<void> dispose() async {
    await _signedInChanges.close();
    await _passwordRecoveryEvents.close();
  }
}
