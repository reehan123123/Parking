import 'package:flutter/material.dart';

import 'core/config/configuration_required_page.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/history/presentation/history_page.dart';
import 'features/parking/data/parking_session_repository.dart';
import 'features/parking/domain/parking_session.dart';
import 'features/parking/presentation/parking_entry_page.dart';
import 'features/settings/presentation/settings_page.dart';

class ParkingManagementApp extends StatelessWidget {
  const ParkingManagementApp({
    this.authRepository,
    this.parkingSessionRepository,
    this.configurationError,
    super.key,
  });

  static const _primaryColor = Color(0xFF176B4D);

  final AuthRepository? authRepository;
  final ParkingSessionRepository? parkingSessionRepository;
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
        scaffoldBackgroundColor: colorScheme.surface,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: colorScheme.surfaceContainerLow,
          margin: EdgeInsets.zero,
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
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    this.initialIndex = 0,
    this.onSignOut,
    this.parkingSessionRepository,
    super.key,
  });

  final int initialIndex;
  final Future<void> Function()? onSignOut;
  final ParkingSessionRepository? parkingSessionRepository;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _selectedIndex = widget.initialIndex;
  int _dataVersion = 0;

  static const _destinations = [
    _AppDestination(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    _AppDestination(
      label: 'History',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
    ),
    _AppDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  void _selectDestination(int index) {
    if (index == _selectedIndex) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _openNewParkingEntry(BuildContext context) async {
    final repository = widget.parkingSessionRepository;
    if (repository == null) {
      return;
    }

    final session = await Navigator.of(context).push<ParkingSession>(
      MaterialPageRoute(
        builder: (context) => ParkingEntryPage(repository: repository),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final content = IndexedStack(
          index: _selectedIndex,
          children: [
            DashboardPage(
              repository: widget.parkingSessionRepository,
              onNewParkingEntry: widget.parkingSessionRepository == null
                  ? null
                  : () => _openNewParkingEntry(context),
              onDataChanged: _notifyDataChanged,
              refreshToken: _dataVersion,
            ),
            HistoryPage(
              repository: widget.parkingSessionRepository,
              onDataChanged: _notifyDataChanged,
              refreshToken: _dataVersion,
            ),
            SettingsPage(onSignOut: widget.onSignOut),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Parking Management'),
            actions: [
              IconButton(
                onPressed: () {},
                tooltip: 'Help',
                icon: const Icon(Icons.help_outline),
              ),
            ],
          ),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectDestination,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final destination in _destinations)
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
                    for (final destination in _destinations)
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
