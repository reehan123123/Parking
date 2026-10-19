import 'dart:async';

import 'package:flutter/material.dart';

import 'core/config/configuration_required_page.dart';
import 'shared/widgets/empty_state_view.dart';
import 'shared/widgets/error_state_view.dart';
import 'shared/widgets/loading_view.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/history/presentation/history_page.dart';
import 'features/parking/data/parking_session_repository.dart';
import 'features/parking/domain/parking_session.dart';
import 'features/parking/presentation/parking_entry_page.dart';
import 'features/settings/presentation/settings_page.dart';
import 'features/tenants/data/supabase_tenant_repository.dart';
import 'features/tenants/data/tenant_repository.dart';
import 'features/tenants/domain/parking_tenant.dart';
import 'features/tenants/domain/parking_tenant_scope.dart';
import 'features/tenants/presentation/tenant_admin_page.dart';

class ParkingManagementApp extends StatelessWidget {
  const ParkingManagementApp({
    this.authRepository,
    this.parkingSessionRepository,
    this.tenantRepository,
    this.configurationError,
    super.key,
  });

  static const _primaryColor = Color(0xFF176B4D);

  final AuthRepository? authRepository;
  final ParkingSessionRepository? parkingSessionRepository;
  final TenantRepository? tenantRepository;
  final String? configurationError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Parking Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF4F7F5),
          foregroundColor: Color(0xFF17231D),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: colorScheme.surface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    final error = configurationError;
    final repository = authRepository;
    if (error != null || repository == null) {
      return ConfigurationRequiredPage(
        message: error ?? 'Supabase is not configured for this build.',
      );
    }

    return AuthGate(
      authRepository: repository,
      authenticatedBuilder: (context, onSignOut) => AppShell(
        onSignOut: onSignOut,
        parkingSessionRepository: parkingSessionRepository,
        tenantRepository: tenantRepository,
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    this.initialIndex = 0,
    this.onSignOut,
    this.parkingSessionRepository,
    this.tenantRepository,
    this.initialTenantAccess,
    super.key,
  });

  final int initialIndex;
  final Future<void> Function()? onSignOut;
  final ParkingSessionRepository? parkingSessionRepository;
  final TenantRepository? tenantRepository;
  final ParkingTenantAccess? initialTenantAccess;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex = widget.initialIndex;
  int _dataVersion = 0;
  ParkingTenantAccess? _tenantAccess;
  String? _selectedTenantId;
  String? _tenantAccessError;
  bool _isLoadingTenantAccess = false;

  static const _allTenantsValue = '__all_tenants__';

  @override
  void initState() {
    super.initState();
    final initialAccess = widget.initialTenantAccess;
    _tenantAccess = initialAccess;
    if (initialAccess != null &&
        !initialAccess.isSuperAdmin &&
        initialAccess.tenants.isNotEmpty) {
      _selectedTenantId = initialAccess.tenants.first.id;
    }
    if (widget.tenantRepository != null) {
      unawaited(_loadTenantAccess());
    } else if (widget.parkingSessionRepository != null &&
        _tenantAccess == null) {
      _tenantAccessError =
          'Tenant access is not configured. Apply all tenant migrations '
          'before using this version.';
    }
  }

  Future<void> _loadTenantAccess({String? preferredTenantId}) async {
    final repository = widget.tenantRepository;
    if (repository == null) {
      return;
    }

    setState(() {
      _isLoadingTenantAccess = true;
      _tenantAccessError = null;
    });

    try {
      final access = await repository.loadAccess();
      if (!mounted) {
        return;
      }

      final activeTenants = access.tenants
          .where((tenant) => !tenant.isArchived)
          .toList(growable: false);
      final tenantIds = activeTenants.map((tenant) => tenant.id).toSet();
      final currentTenantId = _selectedTenantId;
      final fallbackTenantId = activeTenants.isEmpty
          ? null
          : activeTenants.first.id;
      final selectedTenantId = access.isSuperAdmin
          ? (preferredTenantId != null && tenantIds.contains(preferredTenantId)
                ? preferredTenantId
                : currentTenantId != null && tenantIds.contains(currentTenantId)
                ? currentTenantId
                : null)
          : preferredTenantId != null && tenantIds.contains(preferredTenantId)
          ? preferredTenantId
          : currentTenantId != null && tenantIds.contains(currentTenantId)
          ? currentTenantId
          : fallbackTenantId;
      final showAdmin = access.isSuperAdmin && widget.tenantRepository != null;
      final destinationCount = showAdmin ? 4 : 3;

      setState(() {
        _tenantAccess = access;
        _selectedTenantId = selectedTenantId;
        _selectedIndex = _selectedIndex < destinationCount ? _selectedIndex : 0;
        _isLoadingTenantAccess = false;
        _dataVersion++;
      });
    } on TenantRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingTenantAccess = false;
          _tenantAccessError = error.message;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _isLoadingTenantAccess = false;
          _tenantAccessError = 'Tenant access could not be loaded. Check your connection and retry.';
        });
      }
    }
  }

  Future<void> _handleTenantChanged(ParkingTenant? tenant) {
    return _loadTenantAccess(preferredTenantId: tenant?.id);
  }

  void _selectTenant(String? tenantId) {
    if (tenantId == _selectedTenantId) {
      return;
    }

    setState(() {
      _selectedTenantId = tenantId;
      _dataVersion++;
    });
  }

  void _selectDestination(int index) {
    if (index == _selectedIndex) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _openNewParkingEntry(
    BuildContext context,
    ParkingTenantAccess access,
  ) async {
    final repository = widget.parkingSessionRepository;
    if (repository == null) {
      return;
    }
    var tenantId = _selectedTenantId;
    if (tenantId == null) {
      if (!access.isSuperAdmin) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select a tenant before adding a vehicle.'),
          ),
        );
        return;
      }

      final activeTenants = access.tenants
          .where((tenant) => !tenant.isArchived)
          .toList(growable: false);
      if (activeTenants.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Create or restore a tenant before adding a vehicle.',
            ),
          ),
        );
        return;
      }

      final selectedTenant = await showDialog<ParkingTenant>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Select a tenant'),
          children: [
            for (final tenant in activeTenants)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(tenant),
                child: Text(tenant.name),
              ),
          ],
        ),
      );
      if (!context.mounted || selectedTenant == null) {
        return;
      }
      tenantId = selectedTenant.id;
    }

    final session = await Navigator.of(context).push<ParkingSession>(
      MaterialPageRoute(
        builder: (context) =>
            ParkingEntryPage(repository: repository, tenantId: tenantId),
      ),
    );
    if (!context.mounted || session == null) {
      return;
    }

    _notifyDataChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Parking entry for ${session.plateNumber} was saved successfully.',
        ),
      ),
    );
  }

  void _notifyDataChanged() {
    if (!mounted) {
      return;
    }

    setState(() {
      _dataVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = _tenantAccess;
    if (_isLoadingTenantAccess) {
      return const Scaffold(
        body: LoadingView(message: 'Loading workspace access…'),
      );
    }
    if (_tenantAccessError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parking Management')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorStateView(
              message: _tenantAccessError!,
              onRetry: () => unawaited(_loadTenantAccess()),
            ),
          ),
        ),
      );
    }
    if (access == null) {
      return const Scaffold(
        body: LoadingView(message: 'Preparing your workspace…'),
      );
    }
    if (!access.isSuperAdmin && access.tenants.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parking Management')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyStateView(
              icon: Icons.domain_disabled_outlined,
              title: 'No workspace assigned',
              message: 'Ask your administrator to assign your account to a parking tenant.',
              action: widget.onSignOut == null
                  ? null
                  : OutlinedButton.icon(
                      onPressed: widget.onSignOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign out'),
                    ),
            ),
          ),
        ),
      );
    }

    final scope = ParkingTenantScope(
      isSuperAdmin: access.isSuperAdmin,
      tenantId: _selectedTenantId,
    );
    final activeTenants = access.tenants
        .where((tenant) => !tenant.isArchived)
        .toList(growable: false);
    final canCreateParkingEntry =
        widget.parkingSessionRepository != null &&
        (_selectedTenantId != null ||
            (access.isSuperAdmin && activeTenants.isNotEmpty));
    final showAdmin = access.isSuperAdmin && widget.tenantRepository != null;
    final destinations = _destinations(showAdmin: showAdmin);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final content = IndexedStack(
          index: _selectedIndex,
          children: [
            DashboardPage(
              scope: scope,
              repository: widget.parkingSessionRepository,
              onNewParkingEntry: canCreateParkingEntry
                  ? () => _openNewParkingEntry(context, access)
                  : null,
              onViewHistory: () => _selectDestination(1),
              onDataChanged: _notifyDataChanged,
              refreshToken: _dataVersion,
            ),
            HistoryPage(
              scope: scope,
              repository: widget.parkingSessionRepository,
              onDataChanged: _notifyDataChanged,
              refreshToken: _dataVersion,
            ),
            if (showAdmin)
              TenantAdminPage(
                access: access,
                repository: widget.tenantRepository!,
                onTenantChanged: _handleTenantChanged,
              ),
            SettingsPage(onSignOut: widget.onSignOut),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Parking Management'),
            actions: [_buildTenantSelector(access)],
          ),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectDestination,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final destination in destinations)
                          NavigationRailDestination(
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(destination.selectedIcon),
                            label: Text(destination.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectDestination,
                  destinations: [
                    for (final destination in destinations)
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: destination.label,
                      ),
                  ],
                ),
        );
      },
    );
  }

  List<_AppDestination> _destinations({required bool showAdmin}) {
    return [
      const _AppDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
      ),
      const _AppDestination(
        label: 'History',
        icon: Icons.history_outlined,
        selectedIcon: Icons.history,
      ),
      if (showAdmin)
        const _AppDestination(
          label: 'Admin',
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
        ),
      const _AppDestination(
        label: 'Settings',
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
    ];
  }

  Widget _buildTenantSelector(ParkingTenantAccess access) {
    final activeTenants = access.tenants
        .where((tenant) => !tenant.isArchived)
        .toList(growable: false);
    ParkingTenant? tenant;
    for (final candidate in activeTenants) {
      if (candidate.id == _selectedTenantId) {
        tenant = candidate;
        break;
      }
    }
    final label = _selectedTenantId == null
        ? 'All tenants'
        : tenant?.name ?? 'Workspace';
    final canChoose = access.isSuperAdmin || activeTenants.length > 1;
    if (!canChoose) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Chip(
          avatar: const Icon(Icons.apartment_outlined, size: 18),
          label: Text(label, overflow: TextOverflow.ellipsis),
        ),
      );
    }

    return PopupMenuButton<String>(
      tooltip: 'Select tenant',
      initialValue: _selectedTenantId ?? _allTenantsValue,
      onSelected: (value) =>
          _selectTenant(value == _allTenantsValue ? null : value),
      itemBuilder: (context) => [
        if (access.isSuperAdmin)
          const PopupMenuItem(
            value: _allTenantsValue,
            child: Text('All tenants'),
          ),
        for (final tenant in activeTenants)
          PopupMenuItem(value: tenant.id, child: Text(tenant.name)),
      ],
      child: Container(
        constraints: const BoxConstraints(maxWidth: 190),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.apartment_outlined, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
