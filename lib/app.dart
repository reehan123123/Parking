import 'package:flutter/material.dart';

import 'features/dashboard/presentation/dashboard_page.dart';
import 'features/history/presentation/history_page.dart';
import 'features/settings/presentation/settings_page.dart';

class ParkingManagementApp extends StatelessWidget {
  const ParkingManagementApp({super.key});

  static const _primaryColor = Color(0xFF176B4D);

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
      initialRoute: '/',
      routes: {
        '/': (_) => const AppShell(initialIndex: 0),
        '/dashboard': (_) => const AppShell(initialIndex: 0),
        '/history': (_) => const AppShell(initialIndex: 1),
        '/settings': (_) => const AppShell(initialIndex: 2),
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({required this.initialIndex, super.key});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final int _selectedIndex = widget.initialIndex;

  static const _destinations = [
    _AppDestination(
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      route: '/dashboard',
    ),
    _AppDestination(
      label: 'History',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      route: '/history',
    ),
    _AppDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      route: '/settings',
    ),
  ];

  static const _pages = [DashboardPage(), HistoryPage(), SettingsPage()];

  void _selectDestination(int index) {
    if (index == _selectedIndex) {
      return;
    }

    Navigator.of(context).pushReplacementNamed(_destinations[index].route);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final content = IndexedStack(index: _selectedIndex, children: _pages);

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
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}
