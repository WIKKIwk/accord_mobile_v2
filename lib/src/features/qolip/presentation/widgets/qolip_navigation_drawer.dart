import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/navigation/role_navigation_drawer.dart';
import 'package:flutter/material.dart';

class QolipNavigationDrawer extends StatelessWidget {
  const QolipNavigationDrawer({
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
    return RoleNavigationDrawer(
      selectedIndex: selectedIndex,
      selectedRouteName: selectedRouteName,
      onNavigate: onNavigate,
      destinations: [
        RoleNavigationDrawerDestination(
          icon: Icons.grid_view_outlined,
          selectedIcon: Icons.grid_view_rounded,
          label: l10n.homeNavTitle,
          routeName: AppRoutes.qolipHome,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.view_module_outlined,
          selectedIcon: Icons.view_module_rounded,
          label: l10n.qolipText('nav.blocks'),
          routeName: AppRoutes.qolipBlocks,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
          label: l10n.qolipText('nav.molds'),
          routeName: AppRoutes.qolipProducts,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.assignment_return_outlined,
          selectedIcon: Icons.assignment_return_rounded,
          label: l10n.qolipText('nav.ledger'),
          routeName: AppRoutes.qolipCheckouts,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.swap_horiz_outlined,
          selectedIcon: Icons.swap_horiz_rounded,
          label: l10n.qolipText('nav.transfer'),
          routeName: AppRoutes.qolipLocationTransfer,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.format_list_numbered_outlined,
          selectedIcon: Icons.format_list_numbered_rounded,
          label: l10n.qolipText('nav.sequence'),
          routeName: AppRoutes.supplySequence,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: l10n.profileTitle,
          routeName: AppRoutes.profile,
        ),
      ],
    );
  }
}
