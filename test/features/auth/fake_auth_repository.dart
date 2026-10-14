import 'dart:async';

import 'package:parking_management/features/auth/data/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.isSignedIn = false, this.signInCompleter});

  @override
  bool isSignedIn;

  final StreamController<bool> _signedInChanges =
      StreamController<bool>.broadcast();
  Object? signInError;
  Completer<void>? signInCompleter;

  @override
  Stream<bool> get signedInChanges => _signedInChanges.stream;

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
  Future<void> signOut() async {
    isSignedIn = false;
    _signedInChanges.add(false);
  }

  void emitSignedIn(bool value) {
    isSignedIn = value;
    _signedInChanges.add(value);
  }

  Future<void> dispose() => _signedInChanges.close();
}
