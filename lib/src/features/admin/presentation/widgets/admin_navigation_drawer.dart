import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/navigation/role_navigation_drawer.dart';
import 'package:flutter/material.dart';

class AdminNavigationDrawer extends StatelessWidget {
  const AdminNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
    this.selectedRouteName,
  });

  final int selectedIndex;
  final ValueChanged<String> onNavigate;
  final String? selectedRouteName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = _visibleAdminDrawerDestinations(context);
    final selectedRoute =
        selectedRouteName ?? _routeForLegacyIndex(selectedIndex);
    return RoleNavigationDrawer(
      selectedIndex: selectedIndex,
      selectedRouteName: selectedRoute,
      headerLabel: l10n.adminDrawerSections,
      destinations: destinations,
      onNavigate: onNavigate,
    );
  }
}

String _routeForLegacyIndex(int index) {
  return switch (index) {
    0 => AppRoutes.adminHome,
    1 => AppRoutes.adminSuppliers,
    2 => AppRoutes.adminActivity,
    3 => AppRoutes.adminRoles,
    4 => AppRoutes.profile,
    _ => AppRoutes.gscaleMode,
  };
}

List<RoleNavigationDrawerDestination> _visibleAdminDrawerDestinations(
  BuildContext context,
) {
  final l10n = context.l10n;
  final candidates = [
    RoleNavigationDrawerDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: l10n.adminHomeNavTitle,
      routeName: AppRoutes.adminHome,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.account_tree_outlined,
      selectedIcon: Icons.account_tree_rounded,
      label: l10n.adminWorkMapNavTitle,
      routeName: AppRoutes.adminProductionMapOrders,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      label: l10n.adminSemiFinishedProductsNavTitle,
      routeName: AppRoutes.adminWipBatches,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      label: l10n.adminNotificationsNavTitle,
      routeName: AppRoutes.adminNotifications,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.precision_manufacturing_outlined,
      selectedIcon: Icons.precision_manufacturing_rounded,
      label: l10n.adminEquipmentNavTitle,
      routeName: AppRoutes.adminApparatusSettings,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.warehouse_outlined,
      selectedIcon: Icons.warehouse_rounded,
      label: l10n.adminWarehousesNavTitle,
      routeName: AppRoutes.adminWarehouses,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.rule_outlined,
      selectedIcon: Icons.rule_rounded,
      label: l10n.adminRawMaterialRulesNavTitle,
      routeName: AppRoutes.adminRawMaterialSettings,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      label: l10n.adminWorkersNavTitle,
      routeName: AppRoutes.adminWorkerSettings,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings_rounded,
      label: l10n.adminRolesTitle,
      routeName: AppRoutes.adminRoles,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.account_tree_outlined,
      selectedIcon: Icons.account_tree_rounded,
      label: l10n.adminProductGroupsNavTitle,
      routeName: AppRoutes.adminItemGroupCreate,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart_rounded,
      label: l10n.adminServerStatusNavTitle,
      routeName: AppRoutes.adminServerMonitor,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.view_in_ar_outlined,
      selectedIcon: Icons.view_in_ar_rounded,
      label: l10n.adminFactoryMapNavTitle,
      routeName: AppRoutes.adminFactoryMap,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: l10n.profileTitle,
      routeName: AppRoutes.profile,
      push: true,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.swap_horiz_rounded,
      selectedIcon: Icons.swap_horiz_rounded,
      label: l10n.adminScalesModeNavTitle,
      routeName: AppRoutes.gscaleMode,
      push: true,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.content_cut_rounded,
      selectedIcon: Icons.content_cut_rounded,
      label: l10n.adminCuttingNavTitle,
      routeName: AppRoutes.rezkaSplit,
      push: true,
    ),
  ];
  return candidates
      .where((destination) => AppRouter.canOpenRoute(destination.routeName))
      .toList(growable: false);
}
