import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/locale/language_switch.dart';
import '../../../l10n/app_localizations.dart';
import '../../device_sessions/data/device_session_repository.dart';
import '../../device_sessions/presentation/device_sessions_panel.dart';
import '../../parking_notifications/data/one_signal_notification_service.dart';
import '../../parking_notifications/presentation/parking_notifications_card.dart';
import '../../tenants/data/tenant_repository.dart';
import '../../tenants/domain/parking_tenant.dart';
import '../../tenants/presentation/tenant_admin_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    this.onSignOut,
    this.deviceSessionRepository,
    this.oneSignalNotificationService,
    this.tenant,
    this.tenantRepository,
    this.isSuperAdmin = false,
    this.onManageTenants,
    this.onMembersChanged,
    super.key,
  });

  final Future<void> Function()? onSignOut;
  final DeviceSessionRepository? deviceSessionRepository;
  final OneSignalNotificationService? oneSignalNotificationService;
  final ParkingTenant? tenant;
  final TenantRepository? tenantRepository;
  final bool isSuperAdmin;
  final VoidCallback? onManageTenants;
  final Future<void> Function()? onMembersChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isSigningOut = false;
  String? _errorMessage;

  void _manageTenants() {
    if (!widget.isSuperAdmin) {
      return;
    }
    widget.onManageTenants?.call();
  }

  Future<void> _manageMembers() async {
    final ParkingTenant? tenant = widget.tenant;
    final TenantRepository? repository = widget.tenantRepository;
    if (tenant == null ||
        repository == null ||
        tenant.role != ParkingTenantRole.owner) {
      return;
    }

    await showTenantMembersDialog(
      context: context,
      tenant: tenant,
      repository: repository,
      canManageMemberLimit: false,
      canManageMemberRoles: false,
    );
    if (!mounted) {
      return;
    }
    final Future<void> Function()? onMembersChanged = widget.onMembersChanged;
    if (onMembersChanged != null) {
      await onMembersChanged();
    }
  }

  Future<void> _signOut() async {
    final onSignOut = widget.onSignOut;
    if (onSignOut == null) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSigningOut = true;
    });

    try {
      await onSignOut();
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
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
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settingsTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settingsLanguageTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.settingsLanguageDescription,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const LanguageSwitch(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.oneSignalNotificationService != null) ...[
                OneSignalNotificationsCard(
                  service: widget.oneSignalNotificationService!,
                ),
                const SizedBox(height: 16),
              ],
              if (widget.isSuperAdmin && widget.onManageTenants != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsManageTenantsTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.settingsManageTenantsDescription,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _manageTenants,
                          icon: const Icon(Icons.admin_panel_settings_outlined),
                          label: Text(l10n.manageTenantsMenuItem),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.tenant?.role == ParkingTenantRole.owner &&
                  widget.tenantRepository != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.settingsManageMembersTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.settingsManageMembersDescription,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _manageMembers,
                          icon: const Icon(Icons.group_outlined),
                          label: Text(l10n.manageMembersMenuItem),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.deviceSessionRepository != null) ...[
                DeviceSessionsPanel(
                  repository: widget.deviceSessionRepository!,
                ),
                const SizedBox(height: 16),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (widget.onSignOut != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSigningOut ? null : _signOut,
                  icon: const Icon(Icons.logout),
                  label: Text(
                    _isSigningOut ? l10n.settingsSigningOut : l10n.navSignOut,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
