import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/error_state_view.dart';
import '../data/auth_repository.dart';
import 'sign_in_page.dart';

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
  StreamSubscription<bool>? _authSubscription;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _isSignedIn = widget.authRepository.isSignedIn;
    _authSubscription = widget.authRepository.signedInChanges.listen(
      _handleAuthState,
      onError: _handleAuthError,
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _handleAuthState(bool isSignedIn) {
    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSignedIn = isSignedIn;
    });
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

    if (!_isSignedIn) {
      return SignInPage(authRepository: widget.authRepository);
    }

    return widget.authenticatedBuilder(context, widget.authRepository.signOut);
  }
}
