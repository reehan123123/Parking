import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../data/one_signal_notification_service.dart';

class OneSignalNotificationsCard extends StatefulWidget {
  const OneSignalNotificationsCard({required this.service, super.key});

  final OneSignalNotificationService service;

  @override
  State<OneSignalNotificationsCard> createState() =>
      _OneSignalNotificationsCardState();
}

class _OneSignalNotificationsCardState
    extends State<OneSignalNotificationsCard> {
  OneSignalNotificationStatus? _status;
  OneSignalNotificationErrorCode? _errorCode;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStatus());
  }

  @override
  void didUpdateWidget(covariant OneSignalNotificationsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.service != widget.service) {
      unawaited(_loadStatus());
    }
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorCode = null;
    });

    final OneSignalNotificationStatus status = await widget.service
        .loadStatus();
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
      _isLoading = false;
    });
  }

  Future<void> _setEnabled(bool isEnabled) async {
    setState(() {
      _isUpdating = true;
      _errorCode = null;
    });

    try {
      if (isEnabled) {
        await widget.service.enable();
      } else {
        await widget.service.disable();
      }
      final OneSignalNotificationStatus status = await widget.service
          .loadStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _isUpdating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEnabled
                ? AppLocalizations.of(context)
                      .parkingNotificationsEnabledMessage
                : AppLocalizations.of(context)
                      .parkingNotificationsDisabledMessage,
          ),
        ),
      );
    } on OneSignalNotificationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorCode = error.code;
        _isUpdating = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorCode = OneSignalNotificationErrorCode.requestFailed;
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final OneSignalNotificationAvailability? availability =
        _status?.availability;
    final bool canToggle =
        !_isLoading &&
        !_isUpdating &&
        availability != OneSignalNotificationAvailability.setupRequired &&
        availability != OneSignalNotificationAvailability.unsupported &&
        availability != OneSignalNotificationAvailability.failed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsParkingNotificationsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.settingsParkingNotificationsDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (_isLoading || _isUpdating) const LinearProgressIndicator(),
            Row(
              children: [
                Expanded(child: Text(_description(l10n, availability))),
                const SizedBox(width: 16),
                if (availability == OneSignalNotificationAvailability.enabled)
                  OutlinedButton.icon(
                    onPressed: canToggle ? () => _setEnabled(false) : null,
                    icon: const Icon(Icons.notifications_off_outlined),
                    label: Text(l10n.parkingNotificationsDisableAction),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: canToggle ? () => _setEnabled(true) : null,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(l10n.parkingNotificationsEnableAction),
                  ),
              ],
            ),
            if (_errorCode != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage(l10n, _errorCode!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _isUpdating ? null : _loadStatus,
                  child: Text(l10n.commonRetry),
                ),
              ),
            ],
            if (availability == OneSignalNotificationAvailability.failed &&
                _errorCode == null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _isLoading ? null : _loadStatus,
                  child: Text(l10n.commonRetry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _description(
    AppLocalizations l10n,
    OneSignalNotificationAvailability? availability,
  ) {
    if (_isLoading) {
      return l10n.parkingNotificationsStatusLoading;
    }

    return switch (availability) {
      OneSignalNotificationAvailability.setupRequired =>
        l10n.parkingNotificationsSetupRequired,
      OneSignalNotificationAvailability.unsupported =>
        l10n.parkingNotificationsUnsupported,
      OneSignalNotificationAvailability.permissionNotGranted =>
        l10n.parkingNotificationsPermissionNotGranted,
      OneSignalNotificationAvailability.pending =>
        l10n.parkingNotificationsPending,
      OneSignalNotificationAvailability.enabled =>
        l10n.parkingNotificationsEnabled,
      OneSignalNotificationAvailability.disabled =>
        l10n.parkingNotificationsDisabled,
      OneSignalNotificationAvailability.failed ||
      null => l10n.parkingNotificationsRequestFailed,
    };
  }

  String _errorMessage(
    AppLocalizations l10n,
    OneSignalNotificationErrorCode errorCode,
  ) {
    return switch (errorCode) {
      OneSignalNotificationErrorCode.setupRequired =>
        l10n.parkingNotificationsSetupRequired,
      OneSignalNotificationErrorCode.unsupported =>
        l10n.parkingNotificationsUnsupported,
      OneSignalNotificationErrorCode.permissionDenied =>
        l10n.parkingNotificationsPermissionNotGranted,
      OneSignalNotificationErrorCode.notSignedIn =>
        l10n.parkingNotificationsNotSignedIn,
      OneSignalNotificationErrorCode.requestFailed =>
        l10n.parkingNotificationsRequestFailed,
    };
  }
}
