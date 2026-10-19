import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../tenants/domain/parking_tenant.dart';
import '../data/device_session_repository.dart';
import 'device_sessions_panel.dart';

/// Blocks tenant data until the current session passes server-side admission.
class DeviceSessionLimitPage extends StatefulWidget {
  /// Creates a blocked-session page with self-service device management.
  const DeviceSessionLimitPage({
    required this.deviceLimit,
    required this.activeDeviceCount,
    required this.tenants,
    required this.selectedTenantId,
    required this.repository,
    required this.onRetry,
    this.onSignOut,
    super.key,
  });

  /// The effective device limit returned by PostgreSQL.
  final int deviceLimit;

  /// The active installation count at the time registration was rejected.
  final int activeDeviceCount;

  /// The signed-in user's active tenant choices.
  final List<ParkingTenant> tenants;

  /// The tenant whose device limit rejected the registration.
  final String? selectedTenantId;

  /// The repository used to view and remove the user's own devices.
  final DeviceSessionRepository repository;

  /// Retries tenant admission after the user removes an existing device.
  final Future<void> Function(String tenantId) onRetry;

  /// Signs out the rejected Auth session.
  final Future<void> Function()? onSignOut;

  @override
  State<DeviceSessionLimitPage> createState() => _DeviceSessionLimitPageState();
}

class _DeviceSessionLimitPageState extends State<DeviceSessionLimitPage> {
  bool _isRetrying = false;
  bool _isSigningOut = false;
  String? _errorMessage;
  String? _selectedTenantId;

  @override
  void initState() {
    super.initState();
    _selectedTenantId =
        widget.selectedTenantId ??
        (widget.tenants.isEmpty ? null : widget.tenants.first.id);
  }

  @override
  void didUpdateWidget(covariant DeviceSessionLimitPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTenantId != widget.selectedTenantId) {
      _selectedTenantId = widget.selectedTenantId;
    }
  }

  Future<void> _retry() async {
    final String? tenantId = _selectedTenantId;
    if (tenantId == null) {
      return;
    }

    setState(() {
      _isRetrying = true;
      _errorMessage = null;
    });

    try {
      await widget.onRetry(tenantId);
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context)
              .deviceSessionRegistrationError;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final Future<void> Function()? onSignOut = widget.onSignOut;
    if (onSignOut == null) {
      return;
    }

    setState(() {
      _isSigningOut = true;
      _errorMessage = null;
    });
    try {
      await onSignOut();
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).settingsSignOutError;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deviceLimitReachedTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.devices_outlined,
                        size: 36,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.deviceLimitReachedMessage(widget.deviceLimit),
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.deviceLimitReachedInstructions,
                        style: theme.textTheme.bodyMedium,
                      ),
                      if (widget.tenants.length > 1) ...[
                        const SizedBox(height: 16),
                        Text(
                          l10n.deviceLimitTenantChoiceDescription,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.deviceLimitTenantChoiceLabel,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedTenantId,
                              isExpanded: true,
                              items: [
                                for (final ParkingTenant tenant
                                    in widget.tenants)
                                  DropdownMenuItem<String>(
                                    value: tenant.id,
                                    child: Text(tenant.name),
                                  ),
                              ],
                              onChanged: _isRetrying || _isSigningOut
                                  ? null
                                  : (String? tenantId) {
                                      setState(() {
                                        _selectedTenantId = tenantId;
                                      });
                                    },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        l10n.deviceLimitActiveCount(widget.activeDeviceCount),
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: _isRetrying || _isSigningOut
                                ? null
                                : _retry,
                            icon: _isRetrying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh),
                            label: Text(
                              _isRetrying
                                  ? l10n.commonLoading
                                  : l10n.deviceLimitTryAgain,
                            ),
                          ),
                          if (widget.onSignOut != null)
                            OutlinedButton.icon(
                              onPressed: _isSigningOut || _isRetrying
                                  ? null
                                  : _signOut,
                              icon: const Icon(Icons.logout),
                              label: Text(
                                _isSigningOut
                                    ? l10n.settingsSigningOut
                                    : l10n.deviceLimitSignOut,
                              ),
                            ),
                        ],
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DeviceSessionsPanel(repository: widget.repository),
            ],
          ),
        ),
      ),
    );
  }
}
