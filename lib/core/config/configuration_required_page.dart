import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/parking_brand_title.dart';

class ConfigurationRequiredPage extends StatelessWidget {
  const ConfigurationRequiredPage({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: ParkingBrandTitle(title: l10n.appTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.configurationRequiredTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message ?? l10n.configurationMissingMessage,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SelectableText(
                      l10n.configurationRequiredHint,
                      textAlign: TextAlign.center,
                    ),
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
