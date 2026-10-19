import 'package:flutter/material.dart';

import '../data/auth_repository.dart';

/// Shown whenever the app detects an active Supabase password-recovery
/// session (see [AuthRepository.passwordRecoveryEvents]). The user must set
/// a new password here before the recovery session can be used for
/// anything else; on success the caller signs the user out and returns to
/// the normal sign-in screen.
class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({
    required this.authRepository,
    required this.onRecoveryComplete,
    required this.onCancel,
    super.key,
  });

  final AuthRepository authRepository;

  /// Called after the password has been updated successfully. The caller is
  /// responsible for signing the user out of the temporary recovery session.
  final Future<void> Function() onRecoveryComplete;

  /// Called when the user chooses to abandon the recovery flow.
  final Future<void> Function() onCancel;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (_isSubmitting || form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepository.completePasswordRecovery(
        newPassword: _passwordController.text,
      );
      await widget.onRecoveryComplete();
    } on AuthRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = 'The password could not be updated. Check your connection and retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _cancel() async {
    if (_isSubmitting) {
      return;
    }
    await widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Management'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _cancel,
            child: const Text('Back to sign in'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_reset,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Choose a new password',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Enter a new password to finish resetting your account.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('recovery-new-password'),
                        controller: _passwordController,
                        enabled: !_isSubmitting,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          helperText: 'Use 12 to 128 characters.',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';
                          if (password.length < 12) {
                            return 'Use at least 12 characters.';
                          }
                          if (password.length > 128) {
                            return 'Use 128 characters or fewer.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('recovery-confirm-password'),
                        controller: _confirmationController,
                        enabled: !_isSubmitting,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'The passwords do not match.';
                          }
                          return null;
                        },
                        onFieldSubmitted: _isSubmitting
                            ? null
                            : (_) => _submit(),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Update password'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
