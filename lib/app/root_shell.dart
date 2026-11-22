import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/profile_screen.dart';
import '../features/routing/providers/favourite_provider.dart';
import '../features/routing/providers/journey_provider.dart';
import '../features/routing/screens/plan_screen.dart';
import '../features/ticketing/providers/ticket_provider.dart';
import '../features/ticketing/screens/my_trips_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().profile.id;
    await context.read<JourneyProvider>().loadRecent(userId);
    if (!mounted) return;
    await context.read<FavouriteProvider>().load(userId);
    if (!mounted) return;
    await context.read<TicketProvider>().load(userId);
  }

  void openTab(int index) {
    setState(() => _index = index);
    if (index == 1) {
      final userId = context.read<AuthProvider>().profile.id;
      context.read<TicketProvider>().load(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          PlanScreen(onOpenTrips: () => openTab(1)),
          MyTripsScreen(onPlanJourney: () => openTab(0)),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: openTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number_rounded),
            label: 'My Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
