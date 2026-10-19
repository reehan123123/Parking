import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../data/remembered_email_store.dart';
import 'email_validation.dart';
import 'forgot_password_dialog.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({required this.authRepository, super.key});

  final AuthRepository authRepository;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rememberedEmailStore = const RememberedEmailStore();
  bool _isSubmitting = false;
  bool _rememberMe = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final rememberedEmail = await _rememberedEmailStore.read();
    if (!mounted || rememberedEmail == null) {
      return;
    }
    setState(() {
      _emailController.text = rememberedEmail;
      _rememberMe = true;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _errorMessage = null;
      _isSubmitting = true;
    });

    final email = _emailController.text.trim();
    try {
      await widget.authRepository.signIn(
        email: email,
        password: _passwordController.text,
      );
      if (_rememberMe) {
        await _rememberedEmailStore.save(email);
      } else {
        await _rememberedEmailStore.clear();
      }
    } on AuthRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to sign in. Check your connection and try again.';
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

  Future<void> _showForgotPasswordDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => ForgotPasswordDialog(
        authRepository: widget.authRepository,
        initialEmail: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
      ),
    );
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Enter your password.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parking Management')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Sign in',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use the private account created by your administrator.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                        ),
                        validator: validateEmailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isSubmitting,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        validator: _validatePassword,
                        onFieldSubmitted: _isSubmitting
                            ? null
                            : (_) => _signIn(),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: CheckboxListTile(
                              value: _rememberMe,
                              onChanged: _isSubmitting
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text('Remember me'),
                            ),
                          ),
                          Tooltip(
                            message:
                                widget.authRepository.supportsPasswordRecovery
                                ? ''
                                : 'Password reset email is not available in '
                                      'local development mode.',
                            child: TextButton(
                              onPressed:
                                  _isSubmitting ||
                                      !widget
                                          .authRepository
                                          .supportsPasswordRecovery
                                  ? null
                                  : _showForgotPasswordDialog,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        ],
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _signIn,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign in'),
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
