import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_bottom_nav.dart';

const List<NavTab> _tabs = [
  (icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
  (icon: Icons.ac_unit_outlined, activeIcon: Icons.ac_unit, label: 'Products'),
  (icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Orders'),
  (icon: Icons.payments_outlined, activeIcon: Icons.payments, label: 'Payments'),
  (icon: Icons.menu, activeIcon: Icons.menu, label: 'Menu'),
];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppBottomNav(
        tabs: _tabs,
        currentIndex: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
