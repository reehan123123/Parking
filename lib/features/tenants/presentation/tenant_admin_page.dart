import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/validation/indian_mobile_normalizer.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../data/supabase_tenant_repository.dart';
import '../data/tenant_repository.dart';
import '../domain/parking_tenant.dart';

class TenantAdminPage extends StatefulWidget {
  const TenantAdminPage({
    required this.access,
    required this.repository,
    required this.onTenantChanged,
    super.key,
  });

  final ParkingTenantAccess access;
  final TenantRepository repository;
  final Future<void> Function(ParkingTenant? tenant) onTenantChanged;

  @override
  State<TenantAdminPage> createState() => _TenantAdminPageState();
}

class _TenantAdminPageState extends State<TenantAdminPage> {
  bool _isCreating = false;
  String? _errorMessage;

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

  Future<void> _manageMembers(ParkingTenant tenant) {
    return showDialog<void>(
      context: context,
      builder: (context) =>
          _TenantMembersDialog(tenant: tenant, repository: widget.repository),
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
  const _TenantMembersDialog({required this.tenant, required this.repository});

  final ParkingTenant tenant;
  final TenantRepository repository;

  @override
  State<_TenantMembersDialog> createState() => _TenantMembersDialogState();
}

class _TenantMembersDialogState extends State<_TenantMembersDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  List<ParkingTenantMember> _members = const [];
  ParkingTenantRole _newMemberRole = ParkingTenantRole.member;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadMembers());
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await widget.repository.listMembers(
        tenantId: widget.tenant.id,
      );
      if (mounted) {
        setState(() {
          _members = members;
          _errorMessage = null;
          _isLoading = false;
        });
      }
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
      final members = await widget.repository.listMembers(
        tenantId: widget.tenant.id,
      );
      if (mounted) {
        setState(() {
          _members = members;
        });
      }
      return true;
    } on TenantRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
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
        !_formKey.currentState!.validate()) {
      return;
    }

    final wasAdded = await _runMemberAction(
      () => widget.repository.addMember(
        tenantId: widget.tenant.id,
        email: _emailController.text,
        role: _newMemberRole,
      ),
    );
    if (wasAdded && mounted) {
      _emailController.clear();
      _formKey.currentState!.reset();
      setState(() {
        _newMemberRole = ParkingTenantRole.member;
      });
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.membersDialogTitle(widget.tenant.name)),
      content: SizedBox(
        width: 560,
        height: 470,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.tenant.isArchived)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(l10n.restoreBeforeAddingMembers),
              )
            else
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.existingAccountEmailLabel,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return l10n.emailInvalid;
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => unawaited(_addMember()),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<ParkingTenantRole>(
                            initialValue: _newMemberRole,
                            decoration: InputDecoration(
                              labelText: l10n.roleLabel,
                            ),
                            items: [
                              for (final role in ParkingTenantRole.values)
                                DropdownMenuItem(
                                  value: role,
                                  child: Text(_roleLabel(role, l10n)),
                                ),
                            ],
                            onChanged: _isBusy
                                ? null
                                : (role) {
                                    if (role != null) {
                                      setState(() {
                                        _newMemberRole = role;
                                      });
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: _isBusy
                              ? null
                              : () => unawaited(_addMember()),
                          icon: const Icon(Icons.person_add_alt_1),
                          label: Text(l10n.addButton),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (_isBusy) const LinearProgressIndicator(),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ErrorStateView(message: _errorMessage!),
              ),
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_members.isEmpty)
              Expanded(
                child: EmptyStateView(
                  icon: Icons.people_outline,
                  title: l10n.noMembersTitle,
                  message: l10n.noMembersMessage,
                ),
              )
            else ...[
              const SizedBox(height: 12),
              Text(l10n.keepAtLeastOneOwner),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: _members.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final isLastOwner =
                        member.role == ParkingTenantRole.owner &&
                        _ownerCount <= 1;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(
                        member.email.isEmpty ? l10n.unknownEmail : member.email,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(_roleLabel(member.role, l10n)),
                      trailing: PopupMenuButton<_TenantMemberAction>(
                        tooltip: l10n.manageMemberTooltip(member.email),
                        enabled: !_isBusy && !isLastOwner,
                        onSelected: (action) =>
                            _handleMemberAction(member, action),
                        itemBuilder: (context) => [
                          if (member.role == ParkingTenantRole.member)
                            PopupMenuItem(
                              value: _TenantMemberAction.promote,
                              child: Text(l10n.makeOwnerMenuItem),
                            )
                          else
                            PopupMenuItem(
                              value: _TenantMemberAction.demote,
                              child: Text(l10n.makeMemberMenuItem),
                            ),
                          PopupMenuItem(
                            value: _TenantMemberAction.remove,
                            child: Text(l10n.removeMemberMenuItem),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
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

enum _TenantMemberAction { promote, demote, remove }

String _roleLabel(ParkingTenantRole role, AppLocalizations l10n) {
  return switch (role) {
    ParkingTenantRole.owner => l10n.roleOwner,
    ParkingTenantRole.member => l10n.roleMember,
  };
}
