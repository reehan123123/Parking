import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class MaintenanceModePage extends StatelessWidget {
  const MaintenanceModePage({
    required this.maintenanceUntil,
    this.onSignOut,
    super.key,
  });

  final DateTime maintenanceUntil;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DateTime localUntil = maintenanceUntil.toLocal();
    final MaterialLocalizations materialLocalizations =
        MaterialLocalizations.of(context);
    final String date = materialLocalizations.formatMediumDate(localUntil);
    final String time = materialLocalizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(localUntil),
    );
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      size: 64,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.maintenancePageTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.maintenancePageMessage,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.maintenancePageEndTime(date, time),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    if (onSignOut != null) ...[
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => unawaited(onSignOut!()),
                        icon: const Icon(Icons.logout),
                        label: Text(l10n.navSignOut),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
