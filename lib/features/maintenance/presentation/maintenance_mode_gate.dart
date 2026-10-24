import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/parking_brand_title.dart';
import '../data/maintenance_mode_repository.dart';
import '../domain/maintenance_mode_status.dart';
import 'maintenance_mode_page.dart';

class MaintenanceModeGate extends StatefulWidget {
  const MaintenanceModeGate({
    required this.repository,
    required this.child,
    this.onSignOut,
    super.key,
  });

  final MaintenanceModeRepository repository;
  final Widget child;
  final Future<void> Function()? onSignOut;

  @override
  State<MaintenanceModeGate> createState() => _MaintenanceModeGateState();
}

class _MaintenanceModeGateState extends State<MaintenanceModeGate>
    with WidgetsBindingObserver {
  static const Duration _pollInterval = Duration(seconds: 30);
  static const Duration _maximumExpiryTimer = Duration(days: 24);

  MaintenanceModeStatus? _status;
  bool _hasLoaded = false;
  bool _hasError = false;
  bool _isRequestInProgress = false;
  Timer? _pollingTimer;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pollingTimer = Timer.periodic(
      _pollInterval,
      (_) => unawaited(_refreshStatus()),
    );
    unawaited(_refreshStatus());
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
      unawaited(_refreshStatus());
    }
  }

  Future<void> _refreshStatus() async {
    if (_isRequestInProgress) {
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
        _hasLoaded = true;
        _hasError = false;
      });
      _scheduleExpiryRefresh(status);
    } on MaintenanceModeRepositoryException {
      if (mounted) {
        setState(() {
          _hasLoaded = true;
          _hasError = true;
        });
      }
    } finally {
      _isRequestInProgress = false;
    }
  }

  void _scheduleExpiryRefresh(MaintenanceModeStatus status) {
    _expiryTimer?.cancel();
    final Duration? remaining = status.remainingUntilMaintenanceEnds;
    if (remaining == null ||
        remaining <= Duration.zero ||
        remaining > _maximumExpiryTimer) {
      return;
    }

    _expiryTimer = Timer(remaining, () => unawaited(_refreshStatus()));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    if (!_hasLoaded) {
      return Scaffold(
        body: LoadingView(message: l10n.maintenanceCheckingStatus),
      );
    }

    final MaintenanceModeStatus? status = _status;
    if (_hasError || status == null) {
      return Scaffold(
        appBar: AppBar(title: ParkingBrandTitle(title: l10n.appTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ErrorStateView(
                  message: l10n.maintenanceStatusLoadError,
                  onRetry: () => unawaited(_refreshStatus()),
                ),
                if (widget.onSignOut != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => unawaited(widget.onSignOut!()),
                    icon: const Icon(Icons.logout),
                    label: Text(l10n.navSignOut),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (status.callerIsSuperAdmin || !status.isActive) {
      return widget.child;
    }

    final DateTime? maintenanceUntil = status.maintenanceUntil;
    if (maintenanceUntil == null) {
      return Scaffold(
        body: LoadingView(message: l10n.maintenanceCheckingStatus),
      );
    }

    return MaintenanceModePage(
      maintenanceUntil: maintenanceUntil,
      onSignOut: widget.onSignOut,
    );
  }
}
