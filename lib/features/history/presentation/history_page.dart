import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state_view.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderPage(
      title: 'History',
      icon: Icons.history,
      message: 'Historical parking sessions will be available after Supabase integration.',
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

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
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: EmptyStateView(
                  icon: icon,
                  title: '$title is not connected yet',
                  message: message,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
