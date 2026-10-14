import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/widgets/empty_state_view.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({this.onSignOut, super.key});

  final Future<void> Function()? onSignOut;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isSigningOut = false;
  String? _errorMessage;

  Future<void> _signOut() async {
    final onSignOut = widget.onSignOut;
    if (onSignOut == null) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSigningOut = true;
    });

    try {
      await onSignOut();
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
              'Unable to sign out. Check your connection and try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: double.infinity,
                child: EmptyStateView(
                  icon: Icons.settings_outlined,
                  title: 'Settings are coming later',
                  message: 'Account and application settings will be added in a later phase.',
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (widget.onSignOut != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSigningOut ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: Text(_isSigningOut ? 'Signing out…' : 'Sign out'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
