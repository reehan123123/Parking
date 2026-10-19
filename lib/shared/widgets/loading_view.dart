import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final resolvedMessage =
        message ?? AppLocalizations.of(context).commonLoading;
    return Center(
      child: Semantics(
        label: resolvedMessage,
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(resolvedMessage),
          ],
        ),
      ),
    );
  }
}
