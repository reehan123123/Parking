import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'locale_controller.dart';

/// A compact dropdown used to switch the app's language.
class LanguageSwitch extends StatelessWidget {
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = LocaleScope.of(context);
    final l10n = AppLocalizations.of(context);

    return Tooltip(
      message: l10n.languageSwitchTooltip,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return DropdownButtonHideUnderline(
            child: DropdownButton<Locale>(
              value: controller.locale,
              icon: const Icon(Icons.language),
              borderRadius: BorderRadius.circular(12),
              onChanged: (locale) {
                if (locale != null) {
                  unawaited(_setLocale(context, controller, locale));
                }
              },
              items: [
                DropdownMenuItem(
                  value: const Locale('en'),
                  child: Text(l10n.languageEnglish),
                ),
                DropdownMenuItem(
                  value: const Locale('hi'),
                  child: Text(l10n.languageHindi),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _setLocale(
    BuildContext context,
    LocaleController controller,
    Locale locale,
  ) async {
    try {
      await controller.setLocale(locale);
    } on LocalePreferenceException {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).languageSaveFailed),
        ),
      );
    }
  }
}
