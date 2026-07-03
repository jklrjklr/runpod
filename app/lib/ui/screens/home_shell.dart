import 'package:flutter/material.dart';

import 'browse_screen.dart';
import 'pods_screen.dart';

/// Post-login home: bottom nav between Browse (GPUs/templates/deploy) and
/// Pods (manage what's already running). Each tab keeps its own Scaffold;
/// IndexedStack preserves both tabs' state across switches.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [BrowseScreen(), PodsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('homeNavBar'),
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            key: Key('navBrowse'),
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Browse',
          ),
          NavigationDestination(
            key: Key('navPods'),
            icon: Icon(Icons.dns_outlined),
            selectedIcon: Icon(Icons.dns),
            label: 'Pods',
          ),
        ],
      ),
    );
  }
}
