import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/validation/indian_mobile_normalizer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../device_sessions/data/device_session_repository.dart';
import '../../device_sessions/presentation/device_session_admin_page.dart';
import '../data/supabase_tenant_repository.dart';
import '../data/tenant_repository.dart';
import '../domain/parking_tenant.dart';

Future<void> showTenantMembersDialog({
  required BuildContext context,
  required ParkingTenant tenant,
  required TenantRepository repository,
  required bool canManageMemberLimit,
  required bool canManageMemberRoles,
  Future<void> Function()? onManageDevicePolicies,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _TenantMembersDialog(
      tenant: tenant,
      repository: repository,
      canManageMemberLimit: canManageMemberLimit,
      canManageMemberRoles: canManageMemberRoles,
      onManageDevicePolicies: onManageDevicePolicies,
    ),
  );
}

class TenantAdminPage extends StatefulWidget {
  const TenantAdminPage({
    required this.access,
    required this.repository,
    required this.onTenantChanged,
    this.deviceSessionAdminRepository,
    super.key,
  });

  final ParkingTenantAccess access;
  final TenantRepository repository;
  final Future<void> Function(ParkingTenant? tenant) onTenantChanged;
  final DeviceSessionAdminRepository? deviceSessionAdminRepository;

  @override
  State<TenantAdminPage> createState() => _TenantAdminPageState();
}

class _TenantAdminPageState extends State<TenantAdminPage> {
  bool _isCreating = false;
  String? _errorMessage;
  Map<String, TenantMemberCapacity> _memberCapacities = const {};
  String? _memberCapacityError;
  bool _isLoadingMemberCapacities = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMemberCapacities());
  }

  @override
  void didUpdateWidget(covariant TenantAdminPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.access.tenants != widget.access.tenants) {
      unawaited(_loadMemberCapacities());
    }
  }

  Future<void> _loadMemberCapacities() async {
    setState(() {
      _isLoadingMemberCapacities = true;
      _memberCapacityError = null;
    });
    try {
      final List<TenantMemberCapacity> capacities = await widget.repository
          .listMemberCapacities();
      if (mounted) {
        setState(() {
          _memberCapacities = {
            for (final TenantMemberCapacity capacity in capacities)
              capacity.tenantId: capacity,
          };
          _isLoadingMemberCapacities = false;
        });
      }
    } on TenantRepositoryException {
      if (mounted) {
        setState(() {
          _memberCapacityError = AppLocalizations.of(context)
              .memberCapacityLoadError;
          _isLoadingMemberCapacities = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _memberCapacityError = AppLocalizations.of(context)
              .memberCapacityLoadError;
          _isLoadingMemberCapacities = false;
        });
      }
    }
  }

  String _memberUsageLabel(ParkingTenant tenant, AppLocalizations l10n) {
    final TenantMemberCapacity? capacity = _memberCapacities[tenant.id];
    if (capacity != null) {
      return l10n.memberUsageTemplate(
        capacity.activeMemberCount,
        capacity.memberLimit,
      );
    }
    return _isLoadingMemberCapacities
        ? l10n.memberUsageLoading
        : l10n.memberUsageUnavailable;
  }

  Future<void> _createTenant() async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<TenantCreationResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _CreateTenantDialog(repository: widget.repository),
    );
    if (result == null || !mounted) {
      return;
    }
    final tenant = result.tenant;

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      await widget.onTenantChanged(tenant);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.temporaryPassword == null
                  ? l10n.tenantCreatedMessage(tenant.name)
                  : l10n.tenantCreatedWithPasswordMessage(tenant.name),
            ),
          ),
        );
      }
    } on TenantRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = l10n.tenantCreateGenericError;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _editTenant(ParkingTenant tenant) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<_TenantEditResult>(
      context: context,
      builder: (context) => _EditTenantDialog(tenant: tenant),
    );
    if (result == null || !mounted) {
      return;
    }

    await _runTenantAction(
      successMessage: l10n.tenantUpdatedMessage(tenant.name),
      action: () async {
        await widget.repository.updateTenant(
          tenantId: tenant.id,
          name: result.name,
          validUntil: result.validUntil,
          contactName: result.contactName,
          contactMobile: result.contactMobile,
          contactEmail: result.contactEmail,
        );
      },
    );
  }

  Future<void> _archiveTenant(ParkingTenant tenant) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.archiveTenantTitle),
        content: Text(l10n.archiveTenantMessage(tenant.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.archiveButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _runTenantAction(
      successMessage: l10n.tenantArchivedMessage(tenant.name),
      action: () async {
        await widget.repository.archiveTenant(tenantId: tenant.id);
      },
    );
  }

  Future<void> _restoreTenant(ParkingTenant tenant) {
    final l10n = AppLocalizations.of(context);
    return _runTenantAction(
      successMessage: l10n.tenantRestoredMessage(tenant.name),
      action: () async {
        await widget.repository.restoreTenant(tenantId: tenant.id);
      },
    );
  }

  Future<void> _manageMembers(ParkingTenant tenant) async {
    await showTenantMembersDialog(
      context: context,
      tenant: tenant,
      repository: widget.repository,
      canManageMemberLimit: true,
      canManageMemberRoles: true,
      onManageDevicePolicies: () => _manageDevicePoliciesForTenant(tenant.id),
    );
    if (mounted) {
      await widget.onTenantChanged(null);
    }
  }

  Future<void> _manageDevicePolicies() {
    return _openDeviceSessionAdmin();
  }

  Future<void> _manageDevicePoliciesForTenant(String tenantId) {
    return _openDeviceSessionAdmin(initialTenantId: tenantId);
  }

  Future<void> _openDeviceSessionAdmin({String? initialTenantId}) {
    final DeviceSessionAdminRepository? repository =
        widget.deviceSessionAdminRepository;
    if (repository == null) {
      return Future<void>.value();
    }

    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => DeviceSessionAdminPage(
          tenants: widget.access.tenants,
          repository: repository,
          initialTenantId: initialTenantId,
        ),
      ),
    );
  }

  /// Informational-only expiry check for the listing UI. The database (via
  /// `is_tenant_member`) is the authoritative enforcement point.
  static bool _isExpired(DateTime? validUntil) {
    if (validUntil == null) {
      return true;
    }
    final today = DateTime.now();
    final endOfValidDay = DateTime(
      validUntil.year,
      validUntil.month,
      validUntil.day,
    ).add(const Duration(days: 1));
    return !today.isBefore(endOfValidDay);
  }

  static String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _runTenantAction({
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    if (_isCreating) {
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      await action();
      await widget.onTenantChanged(null);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } on TenantRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).tenantUpdateGenericError;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  void _handleTenantAction(ParkingTenant tenant, _TenantAction action) {
    switch (action) {
      case _TenantAction.edit:
        unawaited(_editTenant(tenant));
      case _TenantAction.members:
        unawaited(_manageMembers(tenant));
      case _TenantAction.archive:
        unawaited(_archiveTenant(tenant));
      case _TenantAction.restore:
        unawaited(_restoreTenant(tenant));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tenants = widget.access.tenants;
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            _buildHeader(theme, l10n),
            if (widget.deviceSessionAdminRepository != null) ...[
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.devices_other_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Text(l10n.devicePolicyAdminTitle),
                  subtitle: Text(l10n.devicePolicyAdminDescription),
                  trailing: FilledButton.tonal(
                    onPressed: _manageDevicePolicies,
                    child: Text(l10n.devicePolicyManageButton),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Icon(
                      Icons.apartment_outlined,
                      size: 30,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.tenantWorkspacesTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.tenantWorkspacesSubtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _TenantCount(count: tenants.length),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.allTenantsTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isCreating ? null : _createTenant,
                  icon: const Icon(Icons.add),
                  label: Text(l10n.createTenantButton),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorStateView(message: _errorMessage!),
            ],
            if (_memberCapacityError != null) ...[
              const SizedBox(height: 16),
              ErrorStateView(
                message: _memberCapacityError!,
                onRetry: () => unawaited(_loadMemberCapacities()),
              ),
            ],
            if (_isCreating) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 16),
            if (tenants.isEmpty)
              EmptyStateView(
                icon: Icons.apartment_outlined,
                title: l10n.noTenantsTitle,
                message: l10n.noTenantsMessage,
              )
            else
              ...tenants.map(
                (tenant) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(
                          Icons.apartment,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(tenant.name),
                      subtitle: Text(
                        [
                          tenant.slug,
                          if (tenant.validUntil != null)
                            l10n.validUntilTemplate(
                              _formatDate(tenant.validUntil!),
                            ),
                          if (tenant.contactMobile != null)
                            l10n.contactLineTemplate(tenant.contactMobile!),
                          _memberUsageLabel(tenant, l10n),
                        ].join(' • '),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tenant.isArchived)
                            Chip(label: Text(l10n.commonInactive))
                          else if (_isExpired(tenant.validUntil))
                            Chip(label: Text(l10n.commonExpired))
                          else
                            Chip(label: Text(l10n.commonActive)),
                          PopupMenuButton<_TenantAction>(
                            tooltip: l10n.manageTenantTooltip(tenant.name),
                            onSelected: (action) =>
                                _handleTenantAction(tenant, action),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: _TenantAction.edit,
                                child: Text(l10n.commonEdit),
                              ),
                              PopupMenuItem(
                                value: _TenantAction.members,
                                child: Text(l10n.manageMembersMenuItem),
                              ),
                              PopupMenuItem(
                                value: tenant.isArchived
                                    ? _TenantAction.restore
                                    : _TenantAction.archive,
                                child: Text(
                                  tenant.isArchived
                                      ? l10n.restoreTenantMenuItem
                                      : l10n.archiveTenantMenuItem,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            Color.lerp(theme.colorScheme.primary, Colors.black, 0.22)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.admin_panel_settings_outlined,
            color: Colors.white,
            size: 40,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.superAdminTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.superAdminSubtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantCount extends StatelessWidget {
  const _TenantCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        count.toString(),
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

enum _TenantAction { edit, members, archive, restore }

class _CreateTenantDialog extends StatefulWidget {
  const _CreateTenantDialog({required this.repository});

  final TenantRepository repository;

  @override
  State<_CreateTenantDialog> createState() => _CreateTenantDialogState();
}

class _CreateTenantDialogState extends State<_CreateTenantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactMobileController = TextEditingController();
  final _contactEmailController = TextEditingController();
  bool _isCreating = false;
  bool _isActive = true;
  DateTime _validUntil = DateTime.now().add(const Duration(days: 365));
  bool _allowCredentialDismiss = false;
  String? _errorMessage;
  String? _temporaryPassword;
  String? _requestName;
  String? _requestEmail;
  String? _requestId;
  TenantCreationResult? _creationResult;

  @override
  void dispose() {
    _nameController.dispose();
    _ownerEmailController.dispose();
    _contactNameController.dispose();
    _contactMobileController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) {
      setState(() {
        _validUntil = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (_isCreating ||
        _creationResult != null ||
        !_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final ownerEmail = _ownerEmailController.text.trim().toLowerCase();
    final requestId = _requestIdFor(name, ownerEmail);

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.repository.createTenant(
        name: name,
        ownerEmail: ownerEmail,
        requestId: requestId,
        isActive: _isActive,
        validUntil: _validUntil,
        contactName: _contactNameController.text.trim().isEmpty
            ? null
            : _contactNameController.text.trim(),
        contactMobile: _contactMobileController.text.trim().isEmpty
            ? null
            : _contactMobileController.text.trim(),
        contactEmail: _contactEmailController.text.trim().isEmpty
            ? null
            : _contactEmailController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      if (result.temporaryPassword == null) {
        Navigator.of(context).pop(result);
      } else {
        setState(() {
          _creationResult = result;
          _temporaryPassword = result.temporaryPassword;
          _allowCredentialDismiss = false;
        });
      }
    } on TenantRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          if (error.temporaryPassword != null) {
            _temporaryPassword = error.temporaryPassword;
            _allowCredentialDismiss = false;
          }
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).tenantCreateGenericError;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  String _requestIdFor(String name, String ownerEmail) {
    if (_requestId != null &&
        _requestName == name &&
        _requestEmail == ownerEmail) {
      return _requestId!;
    }

    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    _requestId =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
    _requestName = name;
    _requestEmail = ownerEmail;
    return _requestId!;
  }

  Future<void> _copyTemporaryPassword() async {
    final password = _temporaryPassword;
    if (password == null) {
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: password));
    } on Exception {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.copyPasswordFailedMessage)));
      }
      return;
    }

    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.passwordCopiedMessage)));
  }

  void _closeDialog(TenantCreationResult? result) {
    if (_temporaryPassword != null && !_allowCredentialDismiss) {
      setState(() {
        _allowCredentialDismiss = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(result);
        }
      });
      return;
    }

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope<TenantCreationResult?>(
      canPop: _temporaryPassword == null || _allowCredentialDismiss,
      child: AlertDialog(
        title: Text(
          _creationResult == null
              ? l10n.createTenantDialogTitle
              : l10n.tenantCreatedDialogTitle,
        ),
        content: SizedBox(
          width: 440,
          child: _creationResult == null
              ? _buildCreateForm(context, l10n)
              : _buildCredentialResult(context, l10n),
        ),
        actions: _buildActions(l10n),
      ),
    );
  }

  Widget _buildCreateForm(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: l10n.tenantNameLabel,
                hintText: l10n.tenantNameHint,
              ),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) {
                  return l10n.tenantNameRequired;
                }
                if (name.length > 120) {
                  return l10n.tenantNameTooLong;
                }
                return null;
              },
              onFieldSubmitted: (_) => unawaited(_submit()),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ownerEmailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: l10n.ownerEmailLabel,
                hintText: l10n.ownerEmailHint,
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return l10n.emailInvalid;
                }
                return null;
              },
              onFieldSubmitted: (_) => unawaited(_submit()),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.commonActive),
              subtitle: Text(l10n.activeSubtitle),
              value: _isActive,
              onChanged: (value) => setState(() => _isActive = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.validUntilTitle),
              subtitle: Text(_TenantAdminPageState._formatDate(_validUntil)),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickValidUntil,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactNameController,
              decoration: InputDecoration(
                labelText: l10n.contactPersonNameLabel,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactMobileController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.contactMobileLabel,
                hintText: l10n.contactMobileHint,
              ),
              validator: (value) {
                final mobile = value?.trim() ?? '';
                if (mobile.isEmpty) {
                  return null;
                }
                if (IndianMobileNormalizer.tryNormalize(mobile) == null) {
                  return l10n.contactMobileInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l10n.contactEmailLabel),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty) {
                  return null;
                }
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return l10n.emailInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            Text(l10n.accountPasswordNote, style: theme.textTheme.bodySmall),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _errorContainer(context, _errorMessage!),
            ],
            if (_temporaryPassword != null) ...[
              const SizedBox(height: 12),
              _temporaryPasswordView(context, l10n),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialResult(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final password = _temporaryPassword!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.tenantReadyMessage(_creationResult!.tenant.name),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _temporaryPasswordView(context, l10n, password: password),
          const SizedBox(height: 12),
          Text(
            l10n.ownerMustChangePassword,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.sharePasswordSecurely,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _temporaryPasswordView(
    BuildContext context,
    AppLocalizations l10n, {
    String? password,
  }) {
    final shownPassword = password ?? _temporaryPassword!;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.temporaryPasswordLabel, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SelectableText(
            shownPassword,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(l10n.retrySetupNote, style: theme.textTheme.bodySmall),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _copyTemporaryPassword,
              icon: const Icon(Icons.copy),
              label: Text(l10n.copyButton),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorContainer(BuildContext context, String message) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: TextStyle(color: colorScheme.onErrorContainer),
      ),
    );
  }

  List<Widget> _buildActions(AppLocalizations l10n) {
    final creationResult = _creationResult;
    if (creationResult != null) {
      return [
        FilledButton(
          onPressed: () => _closeDialog(creationResult),
          child: Text(l10n.doneButton),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: _isCreating ? null : () => _closeDialog(null),
        child: Text(
          _temporaryPassword == null
              ? l10n.commonCancel
              : l10n.closeWithPasswordSavedButton,
        ),
      ),
      FilledButton(
        onPressed: _isCreating ? null : () => unawaited(_submit()),
        child: _isCreating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                _temporaryPassword == null
                    ? l10n.createTenantButton
                    : l10n.retryTenantSetupButton,
              ),
      ),
    ];
  }
}

class _TenantEditResult {
  const _TenantEditResult({
    required this.name,
    required this.validUntil,
    this.contactName,
    this.contactMobile,
    this.contactEmail,
  });

  final String name;
  final DateTime validUntil;
  final String? contactName;
  final String? contactMobile;
  final String? contactEmail;
}

class _EditTenantDialog extends StatefulWidget {
  const _EditTenantDialog({required this.tenant});

  final ParkingTenant tenant;

  @override
  State<_EditTenantDialog> createState() => _EditTenantDialogState();
}

class _EditTenantDialogState extends State<_EditTenantDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactNameController;
  late final TextEditingController _contactMobileController;
  late final TextEditingController _contactEmailController;
  late DateTime _validUntil;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tenant.name);
    _contactNameController = TextEditingController(
      text: widget.tenant.contactName ?? '',
    );
    _contactMobileController = TextEditingController(
      text: widget.tenant.contactMobile ?? '',
    );
    _contactEmailController = TextEditingController(
      text: widget.tenant.contactEmail ?? '',
    );
    _validUntil =
        widget.tenant.validUntil ??
        DateTime.now().add(const Duration(days: 365));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactNameController.dispose();
    _contactMobileController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<void> _pickValidUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) {
      setState(() {
        _validUntil = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _TenantEditResult(
        name: _nameController.text.trim(),
        validUntil: _validUntil,
        contactName: _contactNameController.text.trim().isEmpty
            ? null
            : _contactNameController.text.trim(),
        contactMobile: _contactMobileController.text.trim().isEmpty
            ? null
            : _contactMobileController.text.trim(),
        contactEmail: _contactEmailController.text.trim().isEmpty
            ? null
            : _contactEmailController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editTenantDialogTitle),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: 120,
                  decoration: InputDecoration(labelText: l10n.tenantNameLabel),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) {
                      return l10n.tenantNameRequired;
                    }
                    if (name.length > 120) {
                      return l10n.tenantNameTooLong;
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.validUntilTitle),
                  subtitle: Text(
                    _TenantAdminPageState._formatDate(_validUntil),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickValidUntil,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contactNameController,
                  decoration: InputDecoration(
                    labelText: l10n.contactPersonNameLabel,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contactMobileController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.contactMobileLabel,
                    hintText: l10n.contactMobileHint,
                  ),
                  validator: (value) {
                    final mobile = value?.trim() ?? '';
                    if (mobile.isEmpty) {
                      return null;
                    }
                    if (IndianMobileNormalizer.tryNormalize(mobile) == null) {
                      return l10n.contactMobileInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contactEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.contactEmailLabel,
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) {
                      return null;
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(email)) {
                      return l10n.emailInvalid;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.commonSave)),
      ],
    );
  }
}

class _TenantMembersDialog extends StatefulWidget {
  const _TenantMembersDialog({
    required this.tenant,
    required this.repository,
    required this.canManageMemberLimit,
    required this.canManageMemberRoles,
    this.onManageDevicePolicies,
  });

  final ParkingTenant tenant;
  final TenantRepository repository;
  final bool canManageMemberLimit;
  final bool canManageMemberRoles;
  final Future<void> Function()? onManageDevicePolicies;

  @override
  State<_TenantMembersDialog> createState() => _TenantMembersDialogState();
}

class _TenantMembersDialogState extends State<_TenantMembersDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  List<ParkingTenantMember> _members = const [];
  List<TenantMemberAuditEvent> _auditEvents = const [];
  TenantMemberCapacity? _capacity;
  String? _errorMessage;
  String? _auditErrorMessage;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadData());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final List<ParkingTenantMember> members = await widget.repository
          .listMembers(tenantId: widget.tenant.id);
      final TenantMemberCapacity capacity = await widget.repository
          .getMemberCapacity(tenantId: widget.tenant.id);
      if (mounted) {
        setState(() {
          _members = members;
          _capacity = capacity;
          _errorMessage = null;
          _isLoading = false;
        });
      }
      await _loadAuditEvents();
    } on TenantRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _isLoading = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).membersLoadGenericError;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAuditEvents() async {
    try {
      final List<TenantMemberAuditEvent> events = await widget.repository
          .listMemberAuditEvents(tenantId: widget.tenant.id);
      if (mounted) {
        setState(() {
          _auditEvents = events;
          _auditErrorMessage = null;
        });
      }
    } on TenantRepositoryException {
      if (mounted) {
        setState(() {
          _auditErrorMessage = AppLocalizations.of(context)
              .memberAuditLoadError;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _auditErrorMessage = AppLocalizations.of(context)
              .memberAuditLoadError;
        });
      }
    }
  }

  Future<bool> _runMemberAction(Future<void> Function() action) async {
    if (_isBusy) {
      return false;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      await action();
      await _loadData();
      return true;
    } on TenantRepositoryException catch (error) {
      if (error is TenantMemberLimitReachedException && mounted) {
        await _loadData();
      }
      if (mounted) {
        final TenantMemberCapacity? capacity = _capacity;
        final int? activeMemberCount =
            error is TenantMemberLimitReachedException
            ? error.activeMemberCount ?? capacity?.activeMemberCount
            : null;
        final int? memberLimit = error is TenantMemberLimitReachedException
            ? error.memberLimit ?? capacity?.memberLimit
            : null;
        setState(() {
          _errorMessage = activeMemberCount != null && memberLimit != null
              ? AppLocalizations.of(context)
                    .memberLimitReachedMessage(activeMemberCount, memberLimit)
              : error.message;
        });
      }
      return false;
    } on Exception {
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(context).memberActionGenericError;
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _addMember() async {
    if (_isBusy ||
        widget.tenant.isArchived ||
        _capacity == null ||
        _capacity!.isAtCapacity ||
        !_formKey.currentState!.validate()) {
      return;
    }

    final String email = _emailController.text.trim().toLowerCase();
    final wasAdded = await _runMemberAction(
      () => widget.repository.addMember(
        tenantId: widget.tenant.id,
        email: email,
        role: ParkingTenantRole.member,
      ),
    );
    if (wasAdded && mounted) {
      _emailController.clear();
      _formKey.currentState!.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).memberAddedMessage(email)),
        ),
      );
    }
  }

  Future<void> _editPermissions(ParkingTenantMember member) async {
    final TenantEntryPermissions? permissions =
        await showDialog<TenantEntryPermissions>(
          context: context,
          builder: (context) => _MemberPermissionsDialog(
            email: member.email,
            initialPermissions: member.permissions,
          ),
        );
    if (permissions == null || permissions == member.permissions || !mounted) {
      return;
    }

    final bool saved = await _runMemberAction(
      () => widget.repository.updateMemberPermissions(
        tenantId: widget.tenant.id,
        userId: member.userId,
        permissions: permissions,
      ),
    );
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).memberPermissionsSavedMessage,
          ),
        ),
      );
    }
  }

  Future<void> _changeMemberLimit() async {
    final TenantMemberCapacity? capacity = _capacity;
    if (!widget.canManageMemberLimit || capacity == null || _isBusy) {
      return;
    }

    final int? memberLimit = await showDialog<int>(
      context: context,
      builder: (context) =>
          _MemberLimitDialog(initialLimit: capacity.memberLimit),
    );
    if (memberLimit == null ||
        memberLimit == capacity.memberLimit ||
        !mounted) {
      return;
    }

    final bool saved = await _runMemberAction(() async {
      await widget.repository.setMemberLimit(
        tenantId: widget.tenant.id,
        memberLimit: memberLimit,
      );
    });
    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).memberLimitSavedMessage),
        ),
      );
    }
  }

  Future<void> _changeRole(
    ParkingTenantMember member,
    ParkingTenantRole role,
  ) async {
    await _runMemberAction(
      () => widget.repository.updateMemberRole(
        tenantId: widget.tenant.id,
        userId: member.userId,
        role: role,
      ),
    );
  }

  Future<void> _removeMember(ParkingTenantMember member) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.removeTenantMemberTitle),
        content: Text(
          l10n.removeTenantMemberMessage(member.email, widget.tenant.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.removeButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _runMemberAction(
      () => widget.repository.removeMember(
        tenantId: widget.tenant.id,
        userId: member.userId,
      ),
    );
  }

  void _handleMemberAction(
    ParkingTenantMember member,
    _TenantMemberAction action,
  ) {
    switch (action) {
      case _TenantMemberAction.permissions:
        unawaited(_editPermissions(member));
      case _TenantMemberAction.promote:
        unawaited(_changeRole(member, ParkingTenantRole.owner));
      case _TenantMemberAction.demote:
        unawaited(_changeRole(member, ParkingTenantRole.member));
      case _TenantMemberAction.remove:
        unawaited(_removeMember(member));
    }
  }

  int get _ownerCount =>
      _members.where((member) => member.role == ParkingTenantRole.owner).length;

  void _retryLoad() {
    unawaited(_loadData(showLoading: true));
  }

  void _openDevicePolicies() {
    final Future<void> Function()? callback = widget.onManageDevicePolicies;
    if (callback == null) {
      return;
    }
    Navigator.of(context).pop();
    unawaited(callback());
  }

  Widget _buildCapacityCard(
    AppLocalizations l10n,
    ThemeData theme,
    TenantMemberCapacity capacity,
  ) {
    final double progress = min(
      1.0,
      capacity.activeMemberCount / capacity.memberLimit,
    );
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  l10n.memberUsageTemplate(
                    capacity.activeMemberCount,
                    capacity.memberLimit,
                  ),
                  style: theme.textTheme.titleSmall,
                ),
                if (widget.canManageMemberLimit)
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : _changeMemberLimit,
                    icon: const Icon(Icons.tune),
                    label: Text(l10n.memberLimitEditButton),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(l10n.memberRemainingTemplate(capacity.remainingMemberCount)),
            if (!widget.canManageMemberLimit) ...[
              const SizedBox(height: 4),
              Text(l10n.memberLimitOwnerHint, style: theme.textTheme.bodySmall),
            ],
            if (widget.canManageMemberLimit) ...[
              const SizedBox(height: 4),
              Text(l10n.memberLimitAdminHint, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLimitReachedNotice(AppLocalizations l10n) {
    final TenantMemberCapacity capacity = _capacity!;
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.memberLimitReachedTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.memberLimitReachedMessage(
                capacity.activeMemberCount,
                capacity.memberLimit,
              ),
            ),
            if (widget.canManageMemberLimit) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: _isBusy ? null : _changeMemberLimit,
                icon: const Icon(Icons.tune),
                label: Text(l10n.memberLimitIncreaseButton),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddMemberForm(AppLocalizations l10n) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.memberNewMemberPermissionNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: l10n.existingAccountEmailLabel,
              prefixIcon: const Icon(Icons.alternate_email),
            ),
            validator: (value) {
              final String email = value?.trim() ?? '';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                return l10n.emailInvalid;
              }
              return null;
            },
            onFieldSubmitted: (_) => unawaited(_addMember()),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _isBusy ? null : () => unawaited(_addMember()),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(l10n.addButton),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberList(AppLocalizations l10n) {
    if (_members.isEmpty) {
      return EmptyStateView(
        icon: Icons.people_outline,
        title: l10n.noMembersTitle,
        message: l10n.noMembersMessage,
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _members.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final ParkingTenantMember member = _members[index];
        final bool isLastOwner =
            member.role == ParkingTenantRole.owner && _ownerCount <= 1;
        final List<Widget> permissionChips = _permissionChips(
          member.permissions,
          l10n,
        );
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(
            member.email.isEmpty ? l10n.unknownEmail : member.email,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_roleLabel(member.role, l10n)),
              const SizedBox(height: 4),
              Wrap(spacing: 4, runSpacing: 0, children: permissionChips),
              if (member.createdAt case final DateTime createdAt)
                Text(
                  l10n.memberCreatedAt(
                    MaterialLocalizations.of(context)
                        .formatShortDate(createdAt.toLocal()),
                  ),
                ),
            ],
          ),
          trailing: _buildMemberActions(member, isLastOwner, l10n),
        );
      },
    );
  }

  List<Widget> _permissionChips(
    TenantEntryPermissions permissions,
    AppLocalizations l10n,
  ) {
    final List<Widget> chips = [
      if (permissions.canView) _permissionChip(l10n.memberPermissionView),
      if (permissions.canAdd) _permissionChip(l10n.memberPermissionAdd),
      if (permissions.canEdit) _permissionChip(l10n.memberPermissionEdit),
      if (permissions.canDelete) _permissionChip(l10n.memberPermissionDelete),
    ];
    if (chips.isEmpty) {
      chips.add(_permissionChip(l10n.memberPermissionNone));
    }
    return chips;
  }

  Widget _permissionChip(String label) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: EdgeInsets.zero,
    );
  }

  Widget? _buildMemberActions(
    ParkingTenantMember member,
    bool isLastOwner,
    AppLocalizations l10n,
  ) {
    final List<PopupMenuEntry<_TenantMemberAction>> actions = [];
    if (member.role == ParkingTenantRole.member) {
      actions.add(
        PopupMenuItem(
          value: _TenantMemberAction.permissions,
          child: Text(l10n.memberPermissionsEditButton),
        ),
      );
      if (widget.canManageMemberRoles) {
        actions.add(
          PopupMenuItem(
            value: _TenantMemberAction.promote,
            child: Text(l10n.makeOwnerMenuItem),
          ),
        );
      }
      actions.add(
        PopupMenuItem(
          value: _TenantMemberAction.remove,
          child: Text(l10n.removeMemberMenuItem),
        ),
      );
    } else if (widget.canManageMemberRoles && !isLastOwner) {
      actions
        ..add(
          PopupMenuItem(
            value: _TenantMemberAction.demote,
            child: Text(l10n.makeMemberMenuItem),
          ),
        )
        ..add(
          PopupMenuItem(
            value: _TenantMemberAction.remove,
            child: Text(l10n.removeMemberMenuItem),
          ),
        );
    }
    if (actions.isEmpty) {
      return null;
    }
    return PopupMenuButton<_TenantMemberAction>(
      tooltip: l10n.manageMemberTooltip(member.email),
      enabled: !_isBusy,
      onSelected: (action) => _handleMemberAction(member, action),
      itemBuilder: (context) => actions,
    );
  }

  Widget _buildAuditSection(AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.memberAuditTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.commonRetry,
                  onPressed: _isBusy
                      ? null
                      : () => unawaited(_loadAuditEvents()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (_auditErrorMessage != null)
              Text(
                _auditErrorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_auditEvents.isEmpty)
              Text(l10n.memberAuditEmpty)
            else
              for (final TenantMemberAuditEvent event in _auditEvents.take(5))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text(_auditLabel(event.action, l10n)),
                  subtitle: Text(_auditDetails(event, context)),
                ),
          ],
        ),
      ),
    );
  }

  static String _auditLabel(String action, AppLocalizations l10n) {
    return switch (action) {
      'member_added' => l10n.memberAuditAdded,
      'member_removed' => l10n.memberAuditRemoved,
      'member_role_changed' => l10n.memberAuditRoleChanged,
      'member_permissions_changed' => l10n.memberAuditPermissionsChanged,
      'member_limit_changed' => l10n.memberAuditLimitChanged,
      _ => action.replaceAll('_', ' '),
    };
  }

  static String _auditDetails(
    TenantMemberAuditEvent event,
    BuildContext context,
  ) {
    final DateTime localTime = event.createdAt.toLocal();
    final String date = MaterialLocalizations.of(context)
        .formatShortDate(localTime);
    final String time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(localTime));
    return [
      if (event.subjectEmail case final String email when email.isNotEmpty)
        email,
      if (event.actorEmail case final String email when email.isNotEmpty) email,
      '$date $time',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MediaQueryData media = MediaQuery.of(context);
    final double width = min(
      720.0,
      media.size.width - 32,
    ).clamp(240.0, 720.0).toDouble();
    final double height = min(
      640.0,
      media.size.height - 180,
    ).clamp(240.0, 640.0).toDouble();
    final TenantMemberCapacity? capacity = _capacity;
    return AlertDialog(
      title: Text(l10n.membersDialogTitle(widget.tenant.name)),
      content: SizedBox(
        width: width,
        height: height,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.onManageDevicePolicies != null) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isBusy ? null : () => _openDevicePolicies(),
                    icon: const Icon(Icons.devices_outlined),
                    label: Text(l10n.memberManageDevicePolicies),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (capacity != null) ...[
                _buildCapacityCard(l10n, Theme.of(context), capacity),
                const SizedBox(height: 12),
              ],
              if (widget.tenant.isArchived)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l10n.restoreBeforeAddingMembers),
                )
              else if (capacity?.isAtCapacity ?? false)
                _buildLimitReachedNotice(l10n)
              else if (capacity != null)
                _buildAddMemberForm(l10n),
              if (_isLoading) ...[
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                ErrorStateView(message: _errorMessage!, onRetry: _retryLoad),
              ],
              if (!_isLoading) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.keepAtLeastOneOwner,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                _buildMemberList(l10n),
              ],
              const SizedBox(height: 12),
              _buildAuditSection(l10n),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    );
  }
}

class _MemberLimitDialog extends StatefulWidget {
  const _MemberLimitDialog({required this.initialLimit});

  final int initialLimit;

  @override
  State<_MemberLimitDialog> createState() => _MemberLimitDialogState();
}

class _MemberLimitDialogState extends State<_MemberLimitDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _limitController = TextEditingController(
    text: widget.initialLimit.toString(),
  );

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(int.parse(_limitController.text));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.memberLimitDialogTitle),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.memberLimitAdminHint),
              const SizedBox(height: 12),
              TextFormField(
                controller: _limitController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.memberLimitFieldLabel,
                  helperText: l10n.memberLimitRangeHint,
                ),
                validator: (value) {
                  final int? limit = int.tryParse(value ?? '');
                  if (limit == null || limit < 1 || limit > 50) {
                    return l10n.memberLimitValidation;
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}

class _MemberPermissionsDialog extends StatefulWidget {
  const _MemberPermissionsDialog({
    required this.email,
    required this.initialPermissions,
  });

  final String email;
  final TenantEntryPermissions initialPermissions;

  @override
  State<_MemberPermissionsDialog> createState() =>
      _MemberPermissionsDialogState();
}

class _MemberPermissionsDialogState extends State<_MemberPermissionsDialog> {
  late TenantEntryPermissions _permissions = widget.initialPermissions;

  void _setPermission({
    required bool? value,
    required bool Function(TenantEntryPermissions) getValue,
    required TenantEntryPermissions Function(bool) update,
  }) {
    if (value == null || value == getValue(_permissions)) {
      return;
    }
    setState(() {
      _permissions = update(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.memberPermissionsDialogTitle(widget.email)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.memberPermissionsDialogDescription),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.memberPermissionView),
                subtitle: Text(l10n.memberPermissionViewDescription),
                value: _permissions.canView,
                onChanged: (value) => _setPermission(
                  value: value,
                  getValue: (permissions) => permissions.canView,
                  update: (value) => TenantEntryPermissions(
                    canView: value,
                    canAdd: _permissions.canAdd,
                    canEdit: _permissions.canEdit,
                    canDelete: _permissions.canDelete,
                  ),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.memberPermissionAdd),
                subtitle: Text(l10n.memberPermissionAddDescription),
                value: _permissions.canAdd,
                onChanged: (value) => _setPermission(
                  value: value,
                  getValue: (permissions) => permissions.canAdd,
                  update: (value) => TenantEntryPermissions(
                    canView: _permissions.canView,
                    canAdd: value,
                    canEdit: _permissions.canEdit,
                    canDelete: _permissions.canDelete,
                  ),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.memberPermissionEdit),
                subtitle: Text(l10n.memberPermissionEditDescription),
                value: _permissions.canEdit,
                onChanged: (value) => _setPermission(
                  value: value,
                  getValue: (permissions) => permissions.canEdit,
                  update: (value) => TenantEntryPermissions(
                    canView: _permissions.canView,
                    canAdd: _permissions.canAdd,
                    canEdit: value,
                    canDelete: _permissions.canDelete,
                  ),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.memberPermissionDelete),
                subtitle: Text(l10n.memberPermissionDeleteDescription),
                value: _permissions.canDelete,
                onChanged: (value) => _setPermission(
                  value: value,
                  getValue: (permissions) => permissions.canDelete,
                  update: (value) => TenantEntryPermissions(
                    canView: _permissions.canView,
                    canAdd: _permissions.canAdd,
                    canEdit: _permissions.canEdit,
                    canDelete: value,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_permissions),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

enum _TenantMemberAction { permissions, promote, demote, remove }

String _roleLabel(ParkingTenantRole role, AppLocalizations l10n) {
  return switch (role) {
    ParkingTenantRole.owner => l10n.roleOwner,
    ParkingTenantRole.member => l10n.roleMember,
  };
}
