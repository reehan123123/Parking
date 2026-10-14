import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state_view.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SettingsContent();
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

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
                  message: 'Account and application settings will be added after authentication is available.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
