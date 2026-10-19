import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../data/auth_repository.dart';

class TemporaryPasswordResetPage extends StatefulWidget {
  const TemporaryPasswordResetPage({
    required this.authRepository,
    required this.onSignOut,
    super.key,
  });

  final AuthRepository authRepository;
  final Future<void> Function() onSignOut;

  @override
  State<TemporaryPasswordResetPage> createState() =>
      _TemporaryPasswordResetPageState();
}

class _TemporaryPasswordResetPageState
    extends State<TemporaryPasswordResetPage> {
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
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authRepository.changeTemporaryPassword(
        newPassword: _passwordController.text,
      );
    } on AuthRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)
              .temporaryPasswordGenericError;
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

  Future<void> _signOut() async {
    if (_isSubmitting) {
      return;
    }

    try {
      await widget.onSignOut();
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).signOutFailedError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          TextButton.icon(
            onPressed: _isSubmitting ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: Text(l10n.navSignOut),
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
                        l10n.temporaryPasswordSetTitle,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.temporaryPasswordInstructions,
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const ValueKey('new-password'),
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l10n.newPasswordLabel,
                          helperText: l10n.newPasswordHelper,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? l10n.showPasswordTooltip
                                : l10n.hidePasswordTooltip,
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
                            return l10n.passwordTooShort;
                          }
                          if (password.length > 128) {
                            return l10n.passwordTooLong;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('confirm-new-password'),
                        controller: _confirmationController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: l10n.confirmNewPasswordLabel,
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return l10n.passwordsDoNotMatch;
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
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
                            : Text(l10n.changePasswordButton),
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
