import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/assistant/presentation/assistant_screen.dart';
import '../../features/energy/presentation/energy_calculator_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/maintenance/presentation/add_service_dialog.dart';
import '../../features/maintenance/presentation/maintenance_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/vehicle/presentation/edit_profile_screen.dart';
import '../../features/vehicle/presentation/my_car_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'shell',
);

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainNavigationScaffold(child: child);
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/assistant',
          builder: (context, state) => const AssistantScreen(),
        ),
        GoRoute(
          path: '/my-car',
          builder: (context, state) => const MyCarScreen(),
        ),
        GoRoute(
          path: '/maintenance',
          builder: (context, state) => const MaintenanceScreen(),
        ),
      ],
    ),
    // Nested/Modal routes
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/energy-calculator',
      builder: (context, state) => const EnergyCalculatorScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/add-service',
      builder: (context, state) => const AddServiceScreen(),
    ),
  ],
);

/// Persistent bottom navigation bar scaffold
class MainNavigationScaffold extends StatelessWidget {
  final Widget child;

  const MainNavigationScaffold({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/assistant')) return 1;
    if (location.startsWith('/my-car')) return 2;
    if (location.startsWith('/maintenance')) return 3;
    return 0; // Home
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/assistant');
        break;
      case 2:
        context.go('/my-car');
        break;
      case 3:
        context.go('/maintenance');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy),
            label: 'AI Assistant',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_car_outlined),
            selectedIcon: Icon(Icons.directions_car),
            label: 'My Car',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_circle_outlined),
            selectedIcon: Icon(Icons.build_circle),
            label: 'Maintenance',
          ),
        ],
      ),
    );
  }
}
