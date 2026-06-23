import '../../../../app/app_router.dart';
import '../../../../core/widgets/navigation/role_navigation_drawer.dart';
import 'package:flutter/material.dart';

class AparatchiNavigationDrawer extends StatelessWidget {
  const AparatchiNavigationDrawer({
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
          icon: Icons.view_list_outlined,
          selectedIcon: Icons.view_list_rounded,
          label: 'Kuzatish',
          routeName: AppRoutes.apparatusQueue,
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
