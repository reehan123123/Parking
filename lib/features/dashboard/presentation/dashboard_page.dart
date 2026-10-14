import 'package:flutter/material.dart';

import '../../../shared/widgets/empty_state_view.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({this.onNewParkingEntry, super.key});

  final VoidCallback? onNewParkingEntry;

  @override
  Widget build(BuildContext context) {
    return _PageContent(
      title: 'Dashboard',
      child: EmptyStateView(
        icon: Icons.local_parking_outlined,
        title: 'Your parking overview will appear here',
        message: 'Create a parking entry to start tracking a vehicle.',
        action: onNewParkingEntry == null
            ? null
            : FilledButton.icon(
                onPressed: onNewParkingEntry,
                icon: const Icon(Icons.add),
                label: const Text('New Parking Entry'),
              ),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({required this.title, required this.child});

  final String title;
  final Widget child;

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
              SizedBox(width: double.infinity, child: child),
            ],
          ),
        ),
      ),
    );
  }
}
