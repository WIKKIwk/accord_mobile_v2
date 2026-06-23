import '../../../../app/app_router.dart';
import '../../../../core/widgets/navigation/role_navigation_drawer.dart';
import 'package:flutter/material.dart';

class SupplierNavigationDrawer extends StatelessWidget {
  const SupplierNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
  });

  final int selectedIndex;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return RoleNavigationDrawer(
      selectedIndex: selectedIndex,
      onNavigate: onNavigate,
      destinations: const [
        RoleNavigationDrawerDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Uy',
          routeName: AppRoutes.supplierHome,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.notifications_outlined,
          selectedIcon: Icons.notifications_rounded,
          label: 'Bildirish',
          routeName: AppRoutes.supplierNotifications,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.history_outlined,
          selectedIcon: Icons.history_rounded,
          label: 'Tarix',
          routeName: AppRoutes.supplierRecent,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'Profil',
          routeName: AppRoutes.profile,
        ),
      ],
    );
  }
}
