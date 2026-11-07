import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_bottom_nav.dart';
import 'routes.dart';
import 'web_frame.dart';

const List<NavTab> appTabs = [
  (icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard'),
  (icon: Icons.ac_unit_outlined, activeIcon: Icons.ac_unit, label: 'Products'),
  (icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Orders'),
  (icon: Icons.payments_outlined, activeIcon: Icons.payments, label: 'Payments'),
  (icon: Icons.menu, activeIcon: Icons.menu, label: 'Menu'),
];

/// Where each tab goes, in the same order as [appTabs].
const List<String> appTabRoutes = [Routes.home, Routes.catalog, Routes.orders, Routes.payments, Routes.menu];

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: WideLayout.of(context)
          ? null
          : AppBottomNav(
              tabs: appTabs,
              currentIndex: shell.currentIndex,
              onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
            ),
    );
  }
}
