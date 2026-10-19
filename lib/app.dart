import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'core/config/configuration_required_page.dart';
import 'core/locale/locale_controller.dart';
import 'l10n/app_localizations.dart';
import 'shared/widgets/empty_state_view.dart';
import 'shared/widgets/error_state_view.dart';
import 'shared/widgets/loading_view.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/device_sessions/data/device_session_repository.dart';
import 'features/device_sessions/presentation/device_session_limit_page.dart';
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

class ParkingManagementApp extends StatefulWidget {
  const ParkingManagementApp({
    this.authRepository,
    this.parkingSessionRepository,
    this.tenantRepository,
    this.deviceSessionRepository,
    this.configurationError,
    this.supabaseClient,
    super.key,
  });

  final AuthRepository? authRepository;
  final ParkingSessionRepository? parkingSessionRepository;
  final TenantRepository? tenantRepository;
  final DeviceSessionRepository? deviceSessionRepository;
  final String? configurationError;
  final SupabaseClient? supabaseClient;

  @override
  State<ParkingManagementApp> createState() => _ParkingManagementAppState();
}

class _ParkingManagementAppState extends State<ParkingManagementApp> {
  static const _primaryColor = Color(0xFF176B4D);

  late final LocaleController _localeController = LocaleController(
    authClient: widget.supabaseClient,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedLocale());
  }

  Future<void> _loadSavedLocale() async {
    try {
      await _localeController.loadSaved();
    } on LocalePreferenceException catch (error, stackTrace) {
      _reportLocalePreferenceFailure(
        error,
        stackTrace,
        'while loading the saved app language',
      );
    }
  }

  Future<void> _applyUserLocalePreference(
    Map<String, dynamic>? userMetadata,
  ) async {
    try {
      await _localeController.applyUserPreference(userMetadata);
    } on LocalePreferenceException catch (error, stackTrace) {
      _reportLocalePreferenceFailure(
        error,
        stackTrace,
        'while applying the signed-in user language',
      );
    }
  }

  void _reportLocalePreferenceFailure(
    LocalePreferenceException error,
    StackTrace stackTrace,
    String contextDescription,
  ) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'parking_management',
        context: ErrorDescription(contextDescription),
      ),
    );
  }

  @override
  void dispose() {
    _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor,
      brightness: Brightness.light,
    );

    return LocaleScope(
      controller: _localeController,
      child: ListenableBuilder(
        listenable: _localeController,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          locale: _localeController.locale,
          supportedLocales: supportedAppLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          home: _buildHome(),
        ),
      ),
    );
  }

  Widget _buildHome() {
    final error = widget.configurationError;
    final repository = widget.authRepository;
    if (error != null || repository == null) {
      return ConfigurationRequiredPage(message: error);
    }

    return AuthGate(
      authRepository: repository,
      authenticatedBuilder: (context, onSignOut) {
        unawaited(
          _applyUserLocalePreference(
            widget.supabaseClient?.auth.currentUser?.userMetadata,
          ),
        );

        Future<void> releaseDeviceSessionAndSignOut() async {
          await widget.deviceSessionRepository?.releaseCurrentSession();
          await onSignOut();
        }

        return AppShell(
          onSignOut: releaseDeviceSessionAndSignOut,
          parkingSessionRepository: widget.parkingSessionRepository,
          tenantRepository: widget.tenantRepository,
          deviceSessionRepository: widget.deviceSessionRepository,
        );
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    this.initialIndex = 0,
    this.onSignOut,
    this.parkingSessionRepository,
    this.tenantRepository,
    this.deviceSessionRepository,
    this.initialTenantAccess,
    super.key,
  });

  final int initialIndex;
  final Future<void> Function()? onSignOut;
  final ParkingSessionRepository? parkingSessionRepository;
  final TenantRepository? tenantRepository;
  final DeviceSessionRepository? deviceSessionRepository;
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
  bool _tenantAccessErrorIsMigrationMissing = false;
  bool _tenantAccessErrorIsGeneric = false;
  bool _isLoadingTenantAccess = false;
  DeviceLimitReachedException? _deviceLimitError;
  String? _deviceLimitTenantId;

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
      _tenantAccessErrorIsMigrationMissing = true;
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
      _tenantAccessErrorIsMigrationMissing = false;
      _tenantAccessErrorIsGeneric = false;
      _deviceLimitError = null;
    });

    String? attemptedTenantId;
    ParkingTenantAccess? loadedAccess;
    try {
      final access = await repository.loadAccess();
      loadedAccess = access;
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
      attemptedTenantId = selectedTenantId;
      if (!access.isSuperAdmin &&
          selectedTenantId != null &&
          widget.deviceSessionRepository != null) {
        await widget.deviceSessionRepository!.registerCurrentSession(
          tenantId: selectedTenantId,
        );
      }
      final showAdmin = access.isSuperAdmin && widget.tenantRepository != null;
      final destinationCount = showAdmin ? 4 : 3;

      setState(() {
        _tenantAccess = access;
        _selectedTenantId = selectedTenantId;
        _deviceLimitTenantId = selectedTenantId;
        _selectedIndex = _selectedIndex < destinationCount ? _selectedIndex : 0;
        _isLoadingTenantAccess = false;
        _dataVersion++;
      });
    } on DeviceLimitReachedException catch (error) {
      if (mounted) {
        setState(() {
          _tenantAccess = loadedAccess;
          _deviceLimitError = error;
          _deviceLimitTenantId = attemptedTenantId;
          _isLoadingTenantAccess = false;
        });
      }
    } on DeviceSessionRepositoryException catch (error) {
      if (mounted) {
        setState(() {
          _tenantAccess = null;
          _tenantAccessError = error.message;
          _isLoadingTenantAccess = false;
        });
      }
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
          _tenantAccessError = null;
          _tenantAccessErrorIsMigrationMissing = false;
          _tenantAccessErrorIsGeneric = true;
        });
      }
    }
  }

  Future<void> _handleTenantChanged(ParkingTenant? tenant) {
    return _loadTenantAccess(preferredTenantId: tenant?.id);
  }

  Future<void> _selectTenant(String? tenantId) async {
    if (tenantId == _selectedTenantId) {
      return;
    }

    final ParkingTenantAccess? access = _tenantAccess;
    final DeviceSessionRepository? deviceSessions =
        widget.deviceSessionRepository;
    if (tenantId != null &&
        access != null &&
        !access.isSuperAdmin &&
        deviceSessions != null) {
      try {
        await deviceSessions.registerCurrentSession(tenantId: tenantId);
      } on DeviceLimitReachedException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)
                    .deviceLimitReachedMessage(error.deviceLimit),
              ),
            ),
          );
        }
        return;
      } on DeviceSessionRepositoryException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.message)));
        }
        return;
      } on Exception {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context).deviceSessionRegistrationError,
              ),
            ),
          );
        }
        return;
      }
    }

    if (!mounted) {
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
    final l10n = AppLocalizations.of(context);
    final repository = widget.parkingSessionRepository;
    if (repository == null) {
      return;
    }
    var tenantId = _selectedTenantId;
    if (tenantId == null) {
      if (!access.isSuperAdmin) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.selectTenantBeforeVehicle)));
        return;
      }

      final activeTenants = access.tenants
          .where((tenant) => !tenant.isArchived)
          .toList(growable: false);
      if (activeTenants.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.createTenantBeforeVehicle)));
        return;
      }

      final selectedTenant = await showDialog<ParkingTenant>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(l10n.selectTenantDialogTitle),
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
        content: Text(l10n.parkingEntrySavedMessage(session.plateNumber)),
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
    final l10n = AppLocalizations.of(context);
    final access = _tenantAccess;
    if (_isLoadingTenantAccess) {
      return Scaffold(
        body: LoadingView(message: l10n.workspaceAccessLoadingMessage),
      );
    }
    final DeviceLimitReachedException? deviceLimitError = _deviceLimitError;
    if (deviceLimitError != null && widget.deviceSessionRepository != null) {
      return DeviceSessionLimitPage(
        deviceLimit: deviceLimitError.deviceLimit,
        activeDeviceCount: deviceLimitError.activeDeviceCount,
        tenants:
            _tenantAccess?.tenants
                .where((tenant) => !tenant.isArchived)
                .toList(growable: false) ??
            const [],
        selectedTenantId: _deviceLimitTenantId,
        repository: widget.deviceSessionRepository!,
        onRetry: (String tenantId) =>
            _loadTenantAccess(preferredTenantId: tenantId),
        onSignOut: widget.onSignOut,
      );
    }
    if (_tenantAccessError != null ||
        _tenantAccessErrorIsMigrationMissing ||
        _tenantAccessErrorIsGeneric) {
      final message = _tenantAccessErrorIsMigrationMissing
          ? l10n.tenantAccessMigrationError
          : _tenantAccessErrorIsGeneric
          ? l10n.tenantAccessLoadError
          : _tenantAccessError!;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.appTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ErrorStateView(
              message: message,
              onRetry: () => unawaited(_loadTenantAccess()),
            ),
          ),
        ),
      );
    }
    if (access == null) {
      return Scaffold(body: LoadingView(message: l10n.workspaceLoadingMessage));
    }
    if (!access.isSuperAdmin && access.tenants.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.appTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyStateView(
              icon: Icons.domain_disabled_outlined,
              title: l10n.noWorkspaceTitle,
              message: l10n.noWorkspaceMessage,
              action: widget.onSignOut == null
                  ? null
                  : OutlinedButton.icon(
                      onPressed: widget.onSignOut,
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.navSignOut),
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
    final destinations = _destinations(context, showAdmin: showAdmin);
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
                deviceSessionAdminRepository:
                    widget.deviceSessionRepository
                        is DeviceSessionAdminRepository
                    ? widget.deviceSessionRepository!
                          as DeviceSessionAdminRepository
                    : null,
                onTenantChanged: _handleTenantChanged,
              ),
            SettingsPage(
              onSignOut: widget.onSignOut,
              deviceSessionRepository: widget.deviceSessionRepository,
            ),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.appTitle),
            actions: [_buildTenantSelector(context, access)],
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

  List<_AppDestination> _destinations(
    BuildContext context, {
    required bool showAdmin,
  }) {
    final l10n = AppLocalizations.of(context);
    return [
      _AppDestination(
        label: l10n.navDashboard,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
      ),
      _AppDestination(
        label: l10n.navHistory,
        icon: Icons.history_outlined,
        selectedIcon: Icons.history,
      ),
      if (showAdmin)
        _AppDestination(
          label: l10n.navAdmin,
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
        ),
      _AppDestination(
        label: l10n.navSettings,
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
      ),
    ];
  }

  Widget _buildTenantSelector(
    BuildContext context,
    ParkingTenantAccess access,
  ) {
    final l10n = AppLocalizations.of(context);
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
        ? l10n.navAllTenants
        : tenant?.name ?? l10n.workspaceChipLabel;
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
      tooltip: l10n.tenantSelectorTooltip,
      initialValue: _selectedTenantId ?? _allTenantsValue,
      onSelected: (value) =>
          unawaited(_selectTenant(value == _allTenantsValue ? null : value)),
      itemBuilder: (context) => [
        if (access.isSuperAdmin)
          PopupMenuItem(
            value: _allTenantsValue,
            child: Text(l10n.navAllTenants),
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
