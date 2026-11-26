import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/navigation/app_root_navigation.dart';
import '../../../core/widgets/navigation/role_dock.dart';
import '../../../core/widgets/navigation/role_navigation_drawer.dart';

enum WasteDockTab { receive, warehouses, profile }

class WasteDock extends StatelessWidget {
  const WasteDock({super.key, this.activeTab});

  final WasteDockTab? activeTab;

  @override
  Widget build(BuildContext context) {
    return RoleDock(
      selectionVisible: activeTab != null,
      selectedIndex: activeTab?.index ?? 0,
      destinations: [
        for (final (tab, label, icon, selectedIcon, route) in _destinations)
          RoleDockDestination(
            id: 'waste-${tab.name}',
            label: label,
            icon: icon,
            selectedIcon: selectedIcon,
            active: activeTab == tab,
            routeName: route,
            onTap: () {
              if (activeTab == tab) return;
              AppRootNavigation.replaceRootRoute(context, route);
            },
          ),
      ],
    );
  }
}

class WasteDrawer extends StatelessWidget {
  const WasteDrawer({super.key, this.activeTab});

  final WasteDockTab? activeTab;

  @override
  Widget build(BuildContext context) => RoleNavigationDrawer(
        selectedIndex: activeTab?.index ?? 0,
        headerLabel: 'Chiqindi qabul qiluvchi',
        onNavigate: (route) =>
            AppRootNavigation.replaceRootRoute(context, route),
        destinations: [
          for (final (_, label, icon, selectedIcon, route) in _destinations)
            RoleNavigationDrawerDestination(
              label: label,
              icon: icon,
              selectedIcon: selectedIcon,
              routeName: route,
            ),
        ],
      );
}

const _destinations = [
  (
    WasteDockTab.receive,
    'Qabul',
    Icons.qr_code_scanner_outlined,
    Icons.qr_code_scanner_rounded,
    AppRoutes.wasteReceiving,
  ),
  (
    WasteDockTab.warehouses,
    'Omborlar',
    Icons.warehouse_outlined,
    Icons.warehouse_rounded,
    AppRoutes.wasteWarehouses,
  ),
  (
    WasteDockTab.profile,
    'Profil',
    Icons.person_outline,
    Icons.person,
    AppRoutes.profile,
  ),
];
