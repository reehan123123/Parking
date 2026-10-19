import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../tenants/domain/parking_tenant.dart';
import '../data/device_session_repository.dart';
import '../domain/device_session_models.dart';

/// Provides Super Admin controls for platform and tenant device policies.
class DeviceSessionAdminPage extends StatefulWidget {
  /// Creates a policy dashboard for the supplied tenants.
  const DeviceSessionAdminPage({
    required this.tenants,
    required this.repository,
    this.initialTenantId,
    super.key,
  });

  /// The tenants whose inherited and explicit limits can be managed.
  final List<ParkingTenant> tenants;

  /// The server-backed Super Admin device-session repository.
  final DeviceSessionAdminRepository repository;
  final String? initialTenantId;

  @override
  State<DeviceSessionAdminPage> createState() => _DeviceSessionAdminPageState();
}

class _DeviceSessionAdminPageState extends State<DeviceSessionAdminPage> {
  final TextEditingController _deviceLimitController = TextEditingController();
  final TextEditingController _staleDaysController = TextEditingController();
  PlatformDeviceSessionPolicy? _policy;
  List<DeviceSessionAuditEvent> _auditEvents = const [];
  String? _auditErrorMessage;
  bool _isLoading = true;
  bool _isLoadingAudit = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlatformPolicy();
  }

  @override
  void dispose() {
    _deviceLimitController.dispose();
    _staleDaysController.dispose();
    super.dispose();
  }

  Future<void> _loadPlatformPolicy() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final PlatformDeviceSessionPolicy policy = await widget.repository
          .getPlatformPolicy();
      if (mounted) {
        setState(() {
          _policy = policy;
          _deviceLimitController.text = policy.deviceLimit.toString();
          _staleDaysController.text = policy.staleSessionDays.toString();
          _isLoading = false;
        });
      } else {
        return;
      }
    } on DeviceSessionRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = error.message;
        });
      }
      return;
    } on Exception {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppLocalizations.of(context).devicePolicyLoadError;
        });
      }
      return;
    }

    await _refreshAuditEvents();
  }

  Future<void> _refreshAuditEvents() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingAudit = true;
    });

    try {
      final List<DeviceSessionAuditEvent> auditEvents = await widget.repository
          .listAuditEvents();
      if (mounted) {
        setState(() {
          _auditEvents = auditEvents;
          _auditErrorMessage = null;
        });
      }
    } on DeviceSessionRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _auditErrorMessage = error.message;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _auditErrorMessage = AppLocalizations.of(context)
              .devicePolicyLoadError;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAudit = false;
        });
      }
    }
  }

  Future<void> _savePlatformPolicy() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PlatformDeviceSessionPolicy? policy = _policy;
    final int? deviceLimit = int.tryParse(_deviceLimitController.text.trim());
    final int? staleSessionDays = int.tryParse(
      _staleDaysController.text.trim(),
    );
    if (policy == null ||
        deviceLimit == null ||
        deviceLimit < 1 ||
        deviceLimit > policy.maxDeviceLimit ||
        staleSessionDays == null ||
        staleSessionDays < policy.minStaleSessionDays ||
        staleSessionDays > policy.maxStaleSessionDays) {
      setState(() {
        _errorMessage = l10n.devicePolicyValidationError;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.repository.setPlatformPolicy(
        deviceLimit: deviceLimit,
        staleSessionDays: staleSessionDays,
      );
      await _loadPlatformPolicy();
      if (mounted && _errorMessage == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.devicePolicySavedMessage)));
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
          _errorMessage = l10n.devicePolicySaveError;
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.devicePolicyAdminTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                l10n.devicePolicyAdminDescription,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                LoadingView(message: l10n.devicePolicyLoading)
              else if (_errorMessage != null && _policy == null)
                ErrorStateView(
                  message: _errorMessage!,
                  onRetry: _loadPlatformPolicy,
                )
              else if (_policy != null) ...[
                _buildPlatformPolicyCard(l10n, theme),
                const SizedBox(height: 20),
                Text(
                  l10n.devicePolicyTenantsTitle,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final ParkingTenant tenant in widget.tenants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TenantDevicePolicyCard(
                      key: ValueKey<String>(tenant.id),
                      tenant: tenant,
                      repository: widget.repository,
                      platformDeviceLimit: _policy!.deviceLimit,
                      onPolicyChanged: _refreshAuditEvents,
                      initiallyExpanded: tenant.id == widget.initialTenantId,
                    ),
                  ),
                const SizedBox(height: 16),
                _buildAuditCard(l10n, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformPolicyCard(AppLocalizations l10n, ThemeData theme) {
    final PlatformDeviceSessionPolicy policy = _policy!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.devicePolicyPlatformTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.devicePolicyPlatformDescription,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 210,
                  child: TextField(
                    controller: _deviceLimitController,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.devicePolicyPlatformLimitLabel,
                      helperText:
                          '${l10n.devicePolicyRangeLabel}: 1-${policy.maxDeviceLimit}',
                    ),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _staleDaysController,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.devicePolicyStaleDaysLabel,
                      helperText:
                          '${l10n.devicePolicyRangeLabel}: '
                          '${policy.minStaleSessionDays}-'
                          '${policy.maxStaleSessionDays}',
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _savePlatformPolicy,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(l10n.commonSave),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuditCard(AppLocalizations l10n, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.devicePolicyAuditTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _isLoadingAudit ? null : _refreshAuditEvents,
                  tooltip: l10n.commonRetry,
                  icon: _isLoadingAudit
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_auditErrorMessage != null)
              ErrorStateView(
                message: _auditErrorMessage!,
                onRetry: _refreshAuditEvents,
              )
            else if (_auditEvents.isEmpty)
              Text(l10n.devicePolicyAuditEmpty)
            else
              for (final DeviceSessionAuditEvent event in _auditEvents.take(20))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(_auditLabel(event, l10n)),
                  subtitle: Text(
                    [
                      if (event.tenantName != null) event.tenantName!,
                      if (event.actorEmail.isNotEmpty) event.actorEmail,
                      if (event.subjectEmail.isNotEmpty) event.subjectEmail,
                      _formatActivity(event.createdAt, context),
                    ].join(' · '),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static String _auditLabel(
    DeviceSessionAuditEvent event,
    AppLocalizations l10n,
  ) {
    return switch (event.action) {
      'platform_policy_updated' => l10n.deviceAuditPlatformPolicy,
      'tenant_policy_updated' => l10n.deviceAuditTenantPolicy,
      'member_override_updated' => l10n.deviceAuditMemberOverride,
      'session_revoked_by_user' => l10n.deviceAuditUserRevoked,
      'session_revoked_by_admin' => l10n.deviceAuditAdminRevoked,
      'session_signed_out' => l10n.deviceAuditSignedOut,
      'session_expired' => l10n.deviceAuditExpired,
      'membership_removed' => l10n.deviceAuditMembershipRemoved,
      'session_registered' => l10n.deviceAuditSessionRegistered,
      'session_limit_rejected' => l10n.deviceAuditLimitRejected,
      _ => event.action,
    };
  }

  static String _formatActivity(DateTime value, BuildContext context) {
    final String locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).add_jm().format(value.toLocal());
  }
}

class _TenantDevicePolicyCard extends StatefulWidget {
  const _TenantDevicePolicyCard({
    required this.tenant,
    required this.repository,
    required this.platformDeviceLimit,
    required this.onPolicyChanged,
    this.initiallyExpanded = false,
    super.key,
  });

  final ParkingTenant tenant;
  final DeviceSessionAdminRepository repository;
  final int platformDeviceLimit;
  final Future<void> Function() onPolicyChanged;
  final bool initiallyExpanded;

  @override
  State<_TenantDevicePolicyCard> createState() =>
      _TenantDevicePolicyCardState();
}

class _TenantDevicePolicyCardState extends State<_TenantDevicePolicyCard> {
  final TextEditingController _tenantLimitController = TextEditingController();
  TenantDeviceSessionPolicy? _policy;
  List<TenantMemberDevicePolicy> _members = const [];
  List<AdminDeviceSession> _sessions = const [];
  late bool _isExpanded = widget.initiallyExpanded;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _tenantLimitController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initiallyExpanded) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final TenantDeviceSessionPolicy policy = await widget.repository
          .getTenantPolicy(tenantId: widget.tenant.id);
      final List<TenantMemberDevicePolicy> members = await widget.repository
          .listTenantMemberPolicies(tenantId: widget.tenant.id);
      final List<AdminDeviceSession> sessions = await widget.repository
          .listTenantSessions(tenantId: widget.tenant.id);
      if (mounted) {
        setState(() {
          _policy = policy;
          _members = members;
          _sessions = sessions;
          _tenantLimitController.text =
              policy.tenantDeviceLimit?.toString() ?? '';
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
          _errorMessage = AppLocalizations.of(context).devicePolicyLoadError;
        });
      }
    }
  }

  Future<void> _saveTenantLimit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int? deviceLimit = _tenantLimitController.text.trim().isEmpty
        ? null
        : int.tryParse(_tenantLimitController.text.trim());
    if (deviceLimit != null && (deviceLimit < 1 || deviceLimit > 50)) {
      setState(() {
        _errorMessage = l10n.devicePolicyValidationError;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.repository.setTenantLimit(
        tenantId: widget.tenant.id,
        deviceLimit: deviceLimit,
      );
      await _load();
      if (mounted) {
        await widget.onPolicyChanged();
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
          _errorMessage = l10n.devicePolicySaveError;
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

  Future<void> _editMemberLimit(TenantMemberDevicePolicy member) async {
    final int? selectedLimit = await showDialog<int>(
      context: context,
      builder: (context) => _MemberLimitDialog(
        member: member,
        initialLimit: member.accountDeviceLimit,
      ),
    );
    if (selectedLimit == null || !mounted) {
      return;
    }

    final int? deviceLimit = selectedLimit == 0 ? null : selectedLimit;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.repository.setMemberLimit(
        tenantId: widget.tenant.id,
        userId: member.userId,
        deviceLimit: deviceLimit,
      );
      await _load();
      if (mounted) {
        await widget.onPolicyChanged();
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
          _errorMessage = AppLocalizations.of(context).devicePolicySaveError;
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

  Future<void> _revokeInstallation(AdminDeviceSession session) async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.devicePolicyRevokeTitle),
        content: Text(l10n.devicePolicyRevokeMessage(session.email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.devicePolicyRevokeButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.repository.revokeTenantInstallation(
        tenantId: widget.tenant.id,
        userId: session.userId,
        installationId: session.installationId,
      );
      await _load();
      if (mounted) {
        await widget.onPolicyChanged();
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
          _errorMessage = l10n.devicePolicyRevokeError;
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final TenantDeviceSessionPolicy? policy = _policy;
    return Card(
      child: ExpansionTile(
        initiallyExpanded: widget.initiallyExpanded,
        title: Text(widget.tenant.name),
        subtitle: policy == null
            ? null
            : Text(
                l10n.devicePolicyEffectiveLimit(_effectiveTenantLimit(policy)),
              ),
        onExpansionChanged: (bool expanded) {
          setState(() {
            _isExpanded = expanded;
          });
          if (expanded && _policy == null && !_isLoading) {
            _load();
          }
        },
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (_isLoading)
            LoadingView(message: l10n.devicePolicyLoading)
          else if (_errorMessage != null && _policy == null)
            ErrorStateView(message: _errorMessage!, onRetry: _load)
          else if (_policy != null) ...[
            _buildTenantPolicySection(l10n, theme, _policy!),
            const Divider(height: 24),
            _buildMemberSection(l10n, theme),
            const Divider(height: 24),
            _buildSessionSection(l10n, theme),
          ],
          if (_errorMessage != null && _policy != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (_isExpanded && _policy != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _isLoading || _isSaving ? null : _load,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.commonRetry),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTenantPolicySection(
    AppLocalizations l10n,
    ThemeData theme,
    TenantDeviceSessionPolicy policy,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.devicePolicyTenantTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '${l10n.devicePolicyEffectiveLimit(_effectiveTenantLimit(policy))} · '
          '${l10n.devicePolicySourceLabel}: '
          '${policy.tenantDeviceLimit == null ? l10n.devicePolicyPlatformDefault : l10n.devicePolicyTenantOverride}',
        ),
        Text(
          l10n.devicePolicyUsage(
            policy.activeDeviceCount,
            policy.activeSessionCount,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: _tenantLimitController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.devicePolicyTenantLimitLabel,
                  helperText: l10n.devicePolicyInheritHint(
                    widget.platformDeviceLimit,
                  ),
                ),
              ),
            ),
            OutlinedButton(
              onPressed: _isSaving ? null : _saveTenantLimit,
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberSection(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.devicePolicyMembersTitle, style: theme.textTheme.titleSmall),
        if (_members.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.devicePolicyNoMembers),
          )
        else
          for (final TenantMemberDevicePolicy member in _members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(member.email),
              subtitle: Text(
                '${l10n.devicePolicyEffectiveLimit(_effectiveMemberLimit(member))} · '
                '${_sourceLabel(_memberPolicySource(member), l10n)} · '
                '${l10n.devicePolicyActiveDevices(member.activeDeviceCount)}',
              ),
              trailing: TextButton(
                onPressed: _isSaving ? null : () => _editMemberLimit(member),
                child: Text(
                  member.accountDeviceLimit == null
                      ? l10n.devicePolicySetOverride
                      : l10n.commonEdit,
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildSessionSection(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.devicePolicySessionsTitle, style: theme.textTheme.titleSmall),
        if (_sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.devicePolicyNoSessions),
          )
        else
          for (final AdminDeviceSession session in _sessions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.devices_outlined),
              title: Text(session.email),
              subtitle: Text(
                '${l10n.devicePolicyInstallationLabel('…${session.installationId.substring(session.installationId.length - 8)}')} · '
                '${l10n.devicePolicyActiveSessions(session.activeSessionCount)} · '
                '${_formatActivity(session.lastActivityAt, context)}',
              ),
              trailing: IconButton(
                tooltip: l10n.devicePolicyRevokeButton,
                onPressed: _isSaving
                    ? null
                    : () => _revokeInstallation(session),
                icon: const Icon(Icons.block_outlined),
              ),
            ),
      ],
    );
  }

  static String _sourceLabel(String source, AppLocalizations l10n) {
    return switch (source) {
      'account_override' => l10n.devicePolicyAccountOverride,
      'tenant_policy' => l10n.devicePolicyTenantOverride,
      _ => l10n.devicePolicyPlatformDefault,
    };
  }

  int _effectiveTenantLimit(TenantDeviceSessionPolicy policy) {
    return policy.tenantDeviceLimit ?? widget.platformDeviceLimit;
  }

  int _effectiveMemberLimit(TenantMemberDevicePolicy member) {
    return member.accountDeviceLimit ??
        _policy?.tenantDeviceLimit ??
        widget.platformDeviceLimit;
  }

  String _memberPolicySource(TenantMemberDevicePolicy member) {
    if (member.accountDeviceLimit != null) {
      return 'account_override';
    }
    if (_policy?.tenantDeviceLimit != null) {
      return 'tenant_policy';
    }
    return 'platform_default';
  }

  static String _formatActivity(DateTime value, BuildContext context) {
    final String locale = Localizations.localeOf(context).toLanguageTag();
    return DateFormat.yMMMd(locale).add_jm().format(value.toLocal());
  }
}

class _MemberLimitDialog extends StatefulWidget {
  const _MemberLimitDialog({required this.member, required this.initialLimit});

  final TenantMemberDevicePolicy member;
  final int? initialLimit;

  @override
  State<_MemberLimitDialog> createState() => _MemberLimitDialogState();
}

class _MemberLimitDialogState extends State<_MemberLimitDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialLimit?.toString() ?? '',
  );
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final int? deviceLimit = int.tryParse(_controller.text.trim());
    if (deviceLimit == null || deviceLimit < 1 || deviceLimit > 50) {
      setState(() {
        _errorMessage = AppLocalizations.of(context)
            .devicePolicyValidationError;
      });
      return;
    }
    Navigator.of(context).pop(deviceLimit);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.devicePolicyMemberOverrideTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.member.email),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: l10n.devicePolicyOverrideLimitLabel,
              errorText: _errorMessage,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        if (widget.initialLimit != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(0),
            child: Text(l10n.devicePolicyInheritButton),
          ),
        FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}
