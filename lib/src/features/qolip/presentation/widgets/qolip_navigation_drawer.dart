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
        const RoleNavigationDrawerDestination(
          icon: Icons.view_module_outlined,
          selectedIcon: Icons.view_module_rounded,
          label: 'Bloklarim',
          routeName: AppRoutes.qolipBlocks,
        ),
        const RoleNavigationDrawerDestination(
          icon: Icons.inventory_2_outlined,
          selectedIcon: Icons.inventory_2_rounded,
          label: 'Qoliplar',
          routeName: AppRoutes.qolipProducts,
        ),
        const RoleNavigationDrawerDestination(
          icon: Icons.assignment_return_outlined,
          selectedIcon: Icons.assignment_return_rounded,
          label: 'Qarz daftari',
          routeName: AppRoutes.qolipCheckouts,
        ),
        const RoleNavigationDrawerDestination(
          icon: Icons.swap_horiz_outlined,
          selectedIcon: Icons.swap_horiz_rounded,
          label: 'Joylashuv transferi',
          routeName: AppRoutes.qolipLocationTransfer,
        ),
        const RoleNavigationDrawerDestination(
          icon: Icons.format_list_numbered_outlined,
          selectedIcon: Icons.format_list_numbered_rounded,
          label: 'Ketma-ketlik',
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
