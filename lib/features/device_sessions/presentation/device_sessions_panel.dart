import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../data/device_session_repository.dart';
import '../domain/device_session_models.dart';

/// Displays and revokes the signed-in user's own tenant-scoped installations.
class DeviceSessionsPanel extends StatefulWidget {
  /// Creates a device-session list for the signed-in user.
  const DeviceSessionsPanel({required this.repository, super.key});

  /// The authenticated device-session repository.
  final DeviceSessionRepository repository;

  @override
  State<DeviceSessionsPanel> createState() => _DeviceSessionsPanelState();
}

class _DeviceSessionsPanelState extends State<DeviceSessionsPanel> {
  List<UserDeviceSession> _sessions = const [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _revokingInstallationId;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessions = await widget.repository.listMySessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } on DeviceSessionRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.message;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context).deviceSessionLoadError;
        });
      }
    }
  }

  Future<void> _revoke(UserDeviceSession session) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deviceSessionRemoveTitle),
        content: Text(l10n.deviceSessionRemoveMessage(session.tenantName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deviceSessionRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _revokingInstallationId = session.installationId;
      _errorMessage = null;
    });
    try {
      await widget.repository.revokeMyInstallation(
        tenantId: session.tenantId,
        installationId: session.installationId,
      );
      await _loadSessions();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.deviceSessionRemoved)));
      }
    } on DeviceSessionRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.deviceSessionRemoveError;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _revokingInstallationId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.deviceSessionTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _isLoading ? null : _loadSessions,
                  tooltip: l10n.commonRetry,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l10n.deviceSessionDescription,
              style: theme.textTheme.bodySmall,
            ),
            if (_isLoading) ...[
              const SizedBox(height: 16),
              LoadingView(message: l10n.deviceSessionLoading),
            ] else if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorStateView(
                message: _errorMessage!,
                onRetry: () => _loadSessions(),
              ),
            ] else if (_sessions.isEmpty) ...[
              const SizedBox(height: 16),
              EmptyStateView(
                icon: Icons.devices_outlined,
                title: l10n.deviceSessionEmpty,
                message: l10n.deviceSessionDescription,
              ),
            ] else ...[
              const SizedBox(height: 12),
              for (final session in _sessions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    session.isCurrentInstallation
                        ? Icons.laptop_chromebook_outlined
                        : Icons.devices_other_outlined,
                  ),
                  title: Text(
                    '${session.tenantName} · '
                    '${session.isCurrentInstallation ? l10n.deviceSessionThisDevice : l10n.deviceSessionOtherDevice}',
                  ),
                  subtitle: Text(
                    '${l10n.deviceSessionLastActivity}: '
                    '${_formatActivity(session.lastActivityAt, context)}'
                    '${session.activeSessionCount > 1 ? '\n${l10n.deviceSessionActiveAuthSessions(session.activeSessionCount)}' : ''}',
                  ),
                  isThreeLine: session.activeSessionCount > 1,
                  trailing: session.isCurrentInstallation
                      ? null
                      : IconButton(
                          tooltip: l10n.deviceSessionRemove,
                          onPressed:
                              _revokingInstallationId == session.installationId
                              ? null
                              : () => _revoke(session),
                          icon:
                              _revokingInstallationId == session.installationId
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.delete_outline),
                        ),
                ),
            ],
            if (_errorMessage != null && !_isLoading && _sessions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatActivity(DateTime value, BuildContext context) {
    final String locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).add_jm().format(value.toLocal());
  }
}
