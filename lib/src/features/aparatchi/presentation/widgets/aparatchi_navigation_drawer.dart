import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/navigation/role_navigation_drawer.dart';
import 'package:flutter/material.dart';

class AparatchiNavigationDrawer extends StatelessWidget {
  const AparatchiNavigationDrawer({
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
          icon: Icons.view_list_outlined,
          selectedIcon: Icons.view_list_rounded,
          label: l10n.monitoringNavTitle,
          routeName: AppRoutes.apparatusQueue,
        ),
        const RoleNavigationDrawerDestination(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book_rounded,
          label: 'App yo‘riqnomasi',
          routeName: AppRoutes.apparatusWorkInstructions,
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
        ),
      ],
    );
  }
}
