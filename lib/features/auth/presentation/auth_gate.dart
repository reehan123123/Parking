import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/error_state_view.dart';
import '../data/auth_repository.dart';
import 'password_recovery_page.dart';
import 'sign_in_page.dart';
import 'temporary_password_reset_page.dart';

typedef AuthenticatedBuilder = Widget Function(
  BuildContext context,
  Future<void> Function() onSignOut,
);

class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.authRepository,
    required this.authenticatedBuilder,
    super.key,
  });

  final AuthRepository authRepository;
  final AuthenticatedBuilder authenticatedBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late bool _isSignedIn;
  late bool _requiresTemporaryPasswordChange;
  bool _isRecoveringPassword = false;
  StreamSubscription<bool>? _authSubscription;
  StreamSubscription<void>? _recoverySubscription;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isSignedIn = widget.authRepository.isSignedIn;
    _requiresTemporaryPasswordChange =
        widget.authRepository.requiresTemporaryPasswordChange;
    _authSubscription = widget.authRepository.signedInChanges.listen(
      _handleAuthState,
      onError: _handleAuthError,
    );
    _recoverySubscription = widget.authRepository.passwordRecoveryEvents.listen(
      (_) => _handlePasswordRecoveryEvent(),
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _recoverySubscription?.cancel();
    super.dispose();
  }

  void _handleAuthState(bool isSignedIn) {
    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSignedIn = isSignedIn;
      _requiresTemporaryPasswordChange =
          widget.authRepository.requiresTemporaryPasswordChange;
    });
  }

  void _handlePasswordRecoveryEvent() {
    if (!mounted) {
      return;
    }

    setState(() {
      _isRecoveringPassword = true;
    });
  }

  Future<void> _completePasswordRecovery() async {
    try {
      await widget.authRepository.signOut();
    } on Exception {
      // Ignore sign-out failures here; the recovery screen already applied
      // the new password, and the user can sign in again directly.
    } finally {
      if (mounted) {
        setState(() {
          _isRecoveringPassword = false;
        });
      }
    }
  }

  void _handleAuthError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = 'Unable to read the authentication state. Try again.';
    });
  }

  void _retryAuthState() {
    setState(() {
      _errorMessage = null;
      _isSignedIn = widget.authRepository.isSignedIn;
      _requiresTemporaryPasswordChange =
          widget.authRepository.requiresTemporaryPasswordChange;
    });
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parking Management')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorStateView(
              message: errorMessage,
              onRetry: _retryAuthState,
            ),
          ),
        ),
      );
    }

    if (_isRecoveringPassword) {
      // A recovery link must only ever be used to set a new password. Show
      // this screen even if the temporary recovery session also satisfies
      // the normal signed-in checks below, so it can never grant silent
      // standing access to parking data.
      return PasswordRecoveryPage(
        authRepository: widget.authRepository,
        onRecoveryComplete: _completePasswordRecovery,
        onCancel: _completePasswordRecovery,
      );
    }

    if (!_isSignedIn) {
      return SignInPage(authRepository: widget.authRepository);
    }

    if (_requiresTemporaryPasswordChange) {
      return TemporaryPasswordResetPage(
        authRepository: widget.authRepository,
        onSignOut: widget.authRepository.signOut,
      );
    }

    return widget.authenticatedBuilder(context, widget.authRepository.signOut);
  }
}
