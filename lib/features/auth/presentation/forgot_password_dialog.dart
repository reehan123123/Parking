import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../data/auth_repository.dart';
import 'email_validation.dart';

/// A minimal, responsive dialog that requests a Supabase password-reset
/// email for an address the user enters. It never reveals whether an
/// account exists for that address.
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({
    required this.authRepository,
    this.initialEmail,
    super.key,
  });

  final AuthRepository authRepository;
  final String? initialEmail;

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  bool _isSubmitting = false;
  bool _requestSucceeded = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
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
      await widget.authRepository.requestPasswordReset(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        setState(() {
          _requestSucceeded = true;
        });
      }
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
              .forgotPasswordGenericError;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.forgotPasswordTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: _requestSucceeded
            ? Text(l10n.forgotPasswordSuccessMessage)
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.forgotPasswordInstructions),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isSubmitting,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        labelText: l10n.signInEmailLabel,
                      ),
                      validator: validateEmailAddress,
                      onFieldSubmitted: _isSubmitting ? null : (_) => _submit(),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_requestSucceeded ? l10n.commonClose : l10n.commonCancel),
        ),
        if (!_requestSucceeded)
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.forgotPasswordSendButton),
          ),
      ],
    );
  }
}
