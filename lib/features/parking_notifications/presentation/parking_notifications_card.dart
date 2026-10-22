import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../data/parking_push_notification_service.dart';

class ParkingNotificationsCard extends StatefulWidget {
  const ParkingNotificationsCard({required this.service, super.key});

  final ParkingPushNotificationService service;

  @override
  State<ParkingNotificationsCard> createState() =>
      _ParkingNotificationsCardState();
}

class _ParkingNotificationsCardState extends State<ParkingNotificationsCard> {
  ParkingPushNotificationStatus? _status;
  ParkingPushErrorCode? _errorCode;
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStatus());
  }

  @override
  void didUpdateWidget(covariant ParkingNotificationsCard oldWidget) {
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

    try {
      final status = await widget.service.loadStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _status = status;
        _isLoading = false;
      });
    } on ParkingPushNotificationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorCode = error.code;
        _isLoading = false;
      });
    }
  }

  Future<void> _setEnabled(bool isEnabled) async {
    setState(() {
      _isUpdating = true;
      _errorCode = null;
    });

    try {
      if (isEnabled) {
        await widget.service.enable(
          localeCode: Localizations.localeOf(context).languageCode,
        );
      } else {
        await widget.service.disable();
      }
      final status = await widget.service.loadStatus();
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
    } on ParkingPushNotificationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorCode = error.code;
        _isUpdating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ParkingPushNotificationStatus? status = _status;
    final bool canToggle =
        !_isLoading &&
        !_isUpdating &&
        status?.availability == ParkingPushAvailability.ready;

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
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.parkingNotificationsToggleLabel),
              subtitle: Text(_description(l10n, status)),
              value: status?.isEnabled ?? false,
              onChanged: canToggle ? _setEnabled : null,
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
          ],
        ),
      ),
    );
  }

  String _description(
    AppLocalizations l10n,
    ParkingPushNotificationStatus? status,
  ) {
    if (_isLoading) {
      return l10n.parkingNotificationsStatusLoading;
    }

    return switch (status?.availability) {
      ParkingPushAvailability.setupRequired =>
        l10n.parkingNotificationsSetupRequired,
      ParkingPushAvailability.unsupported =>
        l10n.parkingNotificationsUnsupported,
      ParkingPushAvailability.permissionBlocked =>
        l10n.parkingNotificationsPermissionBlocked,
      ParkingPushAvailability.ready =>
        status!.isEnabled
            ? l10n.parkingNotificationsEnabled
            : l10n.parkingNotificationsDisabled,
      null => l10n.parkingNotificationsRequestFailed,
    };
  }

  String _errorMessage(AppLocalizations l10n, ParkingPushErrorCode errorCode) {
    return switch (errorCode) {
      ParkingPushErrorCode.setupRequired =>
        l10n.parkingNotificationsSetupRequired,
      ParkingPushErrorCode.unsupported => l10n.parkingNotificationsUnsupported,
      ParkingPushErrorCode.permissionDenied =>
        l10n.parkingNotificationsPermissionBlocked,
      ParkingPushErrorCode.endpointInUse =>
        l10n.parkingNotificationsEndpointInUse,
      ParkingPushErrorCode.subscriptionLimitReached =>
        l10n.parkingNotificationsLimitReached,
      ParkingPushErrorCode.permissionRevoked =>
        l10n.parkingNotificationsPermissionRevoked,
      ParkingPushErrorCode.requestFailed =>
        l10n.parkingNotificationsRequestFailed,
    };
  }
}
