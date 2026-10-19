import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                  ? '${tenant.name} was created.'
                  : '${tenant.name} was created. The temporary password '
                        'was shown once.',
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
          _errorMessage = 'The tenant could not be created. Check your connection and retry.';
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
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _EditTenantDialog(tenant: tenant),
    );
    if (name == null || !mounted) {
      return;
    }

    await _runTenantAction(
      successMessage: '${tenant.name} was updated.',
      action: () async {
        await widget.repository.updateTenant(tenantId: tenant.id, name: name);
      },
    );
  }

  Future<void> _archiveTenant(ParkingTenant tenant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive tenant?'),
        content: Text(
          '${tenant.name} will no longer be available to its members. '
          'Parking records and photos will be retained, and this tenant can '
          'be restored later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    await _runTenantAction(
      successMessage: '${tenant.name} was archived. Its data was retained.',
      action: () async {
        await widget.repository.archiveTenant(tenantId: tenant.id);
      },
    );
  }

  Future<void> _restoreTenant(ParkingTenant tenant) {
    return _runTenantAction(
      successMessage: '${tenant.name} was restored.',
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
          _errorMessage = 'The tenant could not be updated. Check your connection and retry.';
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
    final tenants = widget.access.tenants;
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            _buildHeader(theme),
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
                            'Tenant workspaces',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Each workspace keeps its parking records and photos isolated.',
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
                  child: Text('All tenants', style: theme.textTheme.titleLarge),
                ),
                FilledButton.icon(
                  onPressed: _isCreating ? null : _createTenant,
                  icon: const Icon(Icons.add),
                  label: const Text('Create tenant'),
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
              const EmptyStateView(
                icon: Icons.apartment_outlined,
                title: 'No tenant workspaces yet',
                message: 'Create a workspace and assign an existing Supabase account as its owner.',
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
                      subtitle: Text(tenant.slug),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (tenant.isArchived)
                            const Chip(label: Text('Archived')),
                          PopupMenuButton<_TenantAction>(
                            tooltip: 'Manage ${tenant.name}',
                            onSelected: (action) =>
                                _handleTenantAction(tenant, action),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: _TenantAction.edit,
                                child: Text('Edit name'),
                              ),
                              const PopupMenuItem(
                                value: _TenantAction.members,
                                child: Text('Manage members'),
                              ),
                              PopupMenuItem(
                                value: tenant.isArchived
                                    ? _TenantAction.restore
                                    : _TenantAction.archive,
                                child: Text(
                                  tenant.isArchived
                                      ? 'Restore tenant'
                                      : 'Archive tenant',
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

  Widget _buildHeader(ThemeData theme) {
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
                  'Super Admin',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage parking workspaces across the platform.',
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
  bool _isCreating = false;
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
    super.dispose();
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
          _errorMessage = 'The tenant could not be created. Check your connection and retry.';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not copy the password. Select it and copy it manually.',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Temporary password copied.')));
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
    return PopScope<TenantCreationResult?>(
      canPop: _temporaryPassword == null || _allowCredentialDismiss,
      child: AlertDialog(
        title: Text(
          _creationResult == null ? 'Create tenant' : 'Tenant created',
        ),
        content: SizedBox(
          width: 440,
          child: _creationResult == null
              ? _buildCreateForm(context)
              : _buildCredentialResult(context),
        ),
        actions: _buildActions(),
      ),
    );
  }

  Widget _buildCreateForm(BuildContext context) {
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
              decoration: const InputDecoration(
                labelText: 'Tenant name',
                hintText: 'Example: Central Parking',
              ),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) {
                  return 'Enter a tenant name.';
                }
                if (name.length > 120) {
                  return 'Use 120 characters or fewer.';
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
              decoration: const InputDecoration(
                labelText: 'Owner email',
                hintText: 'owner@example.com',
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Enter a valid email address.';
                }
                return null;
              },
              onFieldSubmitted: (_) => unawaited(_submit()),
            ),
            const SizedBox(height: 12),
            Text(
              'An existing account keeps its current password. A new account '
              'receives a temporary password that must be changed before it '
              'can access parking data.',
              style: theme.textTheme.bodySmall,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _errorContainer(context, _errorMessage!),
            ],
            if (_temporaryPassword != null) ...[
              const SizedBox(height: 12),
              _temporaryPasswordView(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialResult(BuildContext context) {
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
            '${_creationResult!.tenant.name} is ready.',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          _temporaryPasswordView(context, password: password),
          const SizedBox(height: 12),
          Text(
            'The owner must change this password before accessing tenant data.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Share this password with the owner through a secure channel. '
            'It will not be shown again after closing this dialog.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _temporaryPasswordView(BuildContext context, {String? password}) {
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
          Text('Temporary password', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SelectableText(
            shownPassword,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'If you retry setup, use the latest password shown here.',
            style: theme.textTheme.bodySmall,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _copyTemporaryPassword,
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
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

  List<Widget> _buildActions() {
    final creationResult = _creationResult;
    if (creationResult != null) {
      return [
        FilledButton(
          onPressed: () => _closeDialog(creationResult),
          child: const Text('Done'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: _isCreating ? null : () => _closeDialog(null),
        child: Text(
          _temporaryPassword == null
              ? 'Cancel'
              : "Close (I've saved the password)",
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
                    ? 'Create tenant'
                    : 'Retry tenant setup',
              ),
      ),
    ];
  }
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tenant.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(_nameController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit tenant'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _nameController,
            autofocus: true,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Tenant name'),
            validator: (value) {
              final name = value?.trim() ?? '';
              if (name.isEmpty) {
                return 'Enter a tenant name.';
              }
              if (name.length > 120) {
                return 'Use 120 characters or fewer.';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
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
          _errorMessage =
              'Tenant members could not be loaded. Retry the request.';
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
          _errorMessage =
              'The member change failed. Check your connection and retry.';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove tenant member?'),
        content: Text(
          'Remove ${member.email} from ${widget.tenant.name}? Their Auth '
          'account and parking records will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
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
    return AlertDialog(
      title: Text('Members: ${widget.tenant.name}'),
      content: SizedBox(
        width: 560,
        height: 470,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.tenant.isArchived)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Restore this tenant before adding members.'),
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
                      decoration: const InputDecoration(
                        labelText: 'Existing Supabase account email',
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(email)) {
                          return 'Enter a valid email address.';
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
                            decoration: const InputDecoration(
                              labelText: 'Role',
                            ),
                            items: [
                              for (final role in ParkingTenantRole.values)
                                DropdownMenuItem(
                                  value: role,
                                  child: Text(_roleLabel(role)),
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
                          label: const Text('Add'),
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
              const Expanded(
                child: EmptyStateView(
                  icon: Icons.people_outline,
                  title: 'No members',
                  message: 'Add an existing Supabase account to this tenant.',
                ),
              )
            else ...[
              const SizedBox(height: 12),
              const Text('Each tenant must keep at least one owner.'),
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
                        member.email.isEmpty ? 'Unknown email' : member.email,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(_roleLabel(member.role)),
                      trailing: PopupMenuButton<_TenantMemberAction>(
                        tooltip: 'Manage ${member.email}',
                        enabled: !_isBusy && !isLastOwner,
                        onSelected: (action) =>
                            _handleMemberAction(member, action),
                        itemBuilder: (context) => [
                          if (member.role == ParkingTenantRole.member)
                            const PopupMenuItem(
                              value: _TenantMemberAction.promote,
                              child: Text('Make owner'),
                            )
                          else
                            const PopupMenuItem(
                              value: _TenantMemberAction.demote,
                              child: Text('Make member'),
                            ),
                          const PopupMenuItem(
                            value: _TenantMemberAction.remove,
                            child: Text('Remove member'),
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
          child: const Text('Close'),
        ),
      ],
    );
  }
}

enum _TenantMemberAction { promote, demote, remove }

String _roleLabel(ParkingTenantRole role) {
  return switch (role) {
    ParkingTenantRole.owner => 'Owner',
    ParkingTenantRole.member => 'Member',
  };
}
