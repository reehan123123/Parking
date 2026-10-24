import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../data/maintenance_mode_repository.dart';
import '../domain/maintenance_mode_status.dart';

class MaintenanceModeCard extends StatefulWidget {
  const MaintenanceModeCard({required this.repository, super.key});

  final MaintenanceModeRepository repository;

  @override
  State<MaintenanceModeCard> createState() => _MaintenanceModeCardState();
}

class _MaintenanceModeCardState extends State<MaintenanceModeCard>
    with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 30);
  static const Duration _maximumExpiryTimer = Duration(days: 24);

  MaintenanceModeStatus? _status;
  bool _hasLoadError = false;
  bool _hasSaveError = false;
  bool _hasInvalidEndTime = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isRequestInProgress = false;
  Timer? _pollingTimer;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pollingTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_loadStatus()),
    );
    unawaited(_loadStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _expiryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadStatus());
    }
  }

  Future<void> _loadStatus() async {
    if (_isRequestInProgress || _isSaving) {
      return;
    }

    _isRequestInProgress = true;
    try {
      final MaintenanceModeStatus status = await widget.repository.loadStatus();
      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
        _hasLoadError = false;
        _isLoading = false;
      });
      _scheduleExpiryRefresh(status);
    } on MaintenanceModeRepositoryException {
      if (mounted) {
        setState(() {
          _hasLoadError = true;
          _isLoading = false;
        });
      }
    } finally {
      _isRequestInProgress = false;
    }
  }

  Future<void> _handleToggle(bool enabled) async {
    setState(() {
      _isSaving = true;
      _hasSaveError = false;
      _hasInvalidEndTime = false;
    });

    try {
      DateTime? until;
      if (enabled) {
        until = await _pickMaintenanceEndTime();
        if (until == null) {
          return;
        }
      }

      if (until != null && !until.isAfter(DateTime.now())) {
        setState(() {
          _hasInvalidEndTime = true;
        });
        return;
      }

      final MaintenanceModeStatus status = await widget.repository
          .setMaintenanceUntil(until: until?.toUtc());
      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
        _hasLoadError = false;
      });
      _scheduleExpiryRefresh(status);
    } on MaintenanceModeRepositoryException {
      if (mounted) {
        setState(() {
          _hasSaveError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<DateTime?> _pickMaintenanceEndTime() async {
    final DateTime now = DateTime.now();
    final DateTime? currentUntil = _status?.maintenanceUntil?.toLocal();
    final DateTime initialUntil =
        currentUntil != null && currentUntil.isAfter(now)
        ? currentUntil
        : now.add(const Duration(hours: 1));
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(initialUntil),
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateTime(now.year + 100, 12, 31),
    );
    if (date == null || !mounted) {
      return null;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialUntil),
    );
    if (time == null || !mounted) {
      return null;
    }

    final DateTime until = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!until.isAfter(DateTime.now())) {
      setState(() {
        _hasInvalidEndTime = true;
      });
      return null;
    }

    return until;
  }

  void _scheduleExpiryRefresh(MaintenanceModeStatus status) {
    _expiryTimer?.cancel();
    final Duration? remaining = status.remainingUntilMaintenanceEnds;
    if (remaining == null ||
        remaining <= Duration.zero ||
        remaining > _maximumExpiryTimer) {
      return;
    }

    _expiryTimer = Timer(remaining, () => unawaited(_loadStatus()));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MaintenanceModeStatus? status = _status;
    final bool isActive = status?.isActive ?? false;
    final DateTime? maintenanceUntil = status?.maintenanceUntil;
    final String statusMessage;
    if (_isLoading && status == null) {
      statusMessage = l10n.maintenanceCheckingStatus;
    } else if (isActive && maintenanceUntil != null) {
      final DateTime localUntil = maintenanceUntil.toLocal();
      final MaterialLocalizations materialLocalizations =
          MaterialLocalizations.of(context);
      final String date = materialLocalizations.formatMediumDate(localUntil);
      final String time = materialLocalizations.formatTimeOfDay(
        TimeOfDay.fromDateTime(localUntil),
      );
      statusMessage = l10n.maintenanceModeEndsAt(date, time);
    } else {
      statusMessage = l10n.maintenanceModeOff;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.maintenanceModeTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.maintenanceModeDescription,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.maintenanceModeSwitchLabel),
              subtitle: Text(statusMessage),
              value: isActive,
              onChanged:
                  _isLoading || _isSaving || status?.callerIsSuperAdmin != true
                  ? null
                  : (bool enabled) => unawaited(_handleToggle(enabled)),
            ),
            if (_isLoading && status == null) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (_hasLoadError) ...[
              const SizedBox(height: 8),
              Text(
                l10n.maintenanceSettingsLoadError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton.icon(
                onPressed: _isSaving ? null : () => unawaited(_loadStatus()),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.maintenanceRetry),
              ),
            ],
            if (_hasSaveError || _hasInvalidEndTime) ...[
              const SizedBox(height: 8),
              Text(
                _hasInvalidEndTime
                    ? l10n.maintenanceInvalidEnd
                    : l10n.maintenanceSettingsSaveError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (status != null && !status.callerIsSuperAdmin) ...[
              const SizedBox(height: 8),
              Text(
                l10n.maintenanceAdminOnly,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
