import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/navigation/role_navigation_drawer.dart';
import 'package:flutter/material.dart';

class MaterialTaminotchiNavigationDrawer extends StatelessWidget {
  const MaterialTaminotchiNavigationDrawer({
    super.key,
    required this.onNavigate,
    this.selectedRouteName,
  });

  final ValueChanged<String> onNavigate;
  final String? selectedRouteName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RoleNavigationDrawer(
      selectedIndex: 0,
      selectedRouteName: selectedRouteName,
      headerLabel: 'Material bo‘limlari',
      onNavigate: onNavigate,
      destinations: [
        RoleNavigationDrawerDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: l10n.homeNavTitle,
          routeName: AppRoutes.materialHome,
        ),
        const RoleNavigationDrawerDestination(
          icon: Icons.format_list_numbered_outlined,
          selectedIcon: Icons.format_list_numbered_rounded,
          label: 'Ketma-ketlik',
          routeName: AppRoutes.supplySequence,
          push: true,
        ),
        const RoleNavigationDrawerDestination(
          icon: Icons.scale_outlined,
          selectedIcon: Icons.scale_rounded,
          label: 'Kirim',
          routeName: AppRoutes.gscaleMode,
          push: true,
        ),
        const RoleNavigationDrawerDestination(
          icon: Icons.history_outlined,
          selectedIcon: Icons.history_rounded,
          label: 'Harakatlar tarixi',
          routeName: AppRoutes.materialHistory,
          push: true,
        ),
        if (AppRouter.canOpenRoute(AppRoutes.adminRawMaterialAssignments))
          const RoleNavigationDrawerDestination(
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2_rounded,
            label: 'Homashyo biriktirish',
            routeName: AppRoutes.adminRawMaterialAssignments,
            push: true,
          ),
        if (AppRouter.canOpenRoute(AppRoutes.inventoryMovements))
          const RoleNavigationDrawerDestination(
            icon: Icons.swap_horiz_outlined,
            selectedIcon: Icons.swap_horiz_rounded,
            label: 'Joylashtirish va transfer',
            routeName: AppRoutes.inventoryMovements,
            push: true,
          ),
        RoleNavigationDrawerDestination(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: l10n.profileTitle,
          routeName: AppRoutes.profile,
          push: true,
        ),
      ],
    );
  }
}
