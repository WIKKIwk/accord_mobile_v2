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
      icon: Icons.manage_accounts_outlined,
      selectedIcon: Icons.manage_accounts_rounded,
      label: l10n.adminUsersTitle,
      routeName: AppRoutes.adminSuppliers,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.admin_panel_settings_outlined,
      selectedIcon: Icons.admin_panel_settings_rounded,
      label: l10n.adminRolesTitle,
      routeName: AppRoutes.adminRoles,
    ),
    const RoleNavigationDrawerDestination(
      icon: Icons.account_tree_outlined,
      selectedIcon: Icons.account_tree_rounded,
      label: 'Item Group yaratish',
      routeName: AppRoutes.adminItemGroupCreate,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
      label: l10n.adminActivityTitle,
      routeName: AppRoutes.adminActivity,
    ),
    RoleNavigationDrawerDestination(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: l10n.profileTitle,
      routeName: AppRoutes.profile,
      push: true,
    ),
    const RoleNavigationDrawerDestination(
      icon: Icons.swap_horiz_rounded,
      selectedIcon: Icons.swap_horiz_rounded,
      label: 'GScale Mode',
      routeName: AppRoutes.gscaleMode,
      push: true,
    ),
  ];
  return candidates
      .where((destination) => AppRouter.canOpenRoute(destination.routeName))
      .toList(growable: false);
}
