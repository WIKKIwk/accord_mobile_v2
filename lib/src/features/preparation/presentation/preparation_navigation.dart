import 'package:flutter/material.dart';
import '../../../app/app_router.dart';
import '../../../core/navigation/app_root_navigation.dart';
import '../../../core/widgets/navigation/role_dock.dart';
import '../../../core/widgets/navigation/role_navigation_drawer.dart';

class PreparationDock extends StatelessWidget {
  const PreparationDock({super.key, this.profile = false});
  final bool profile;
  @override
  Widget build(BuildContext context) => RoleDock(
          compact: true,
          tightToEdges: true,
          selectionVisible: true,
          selectedIndex: profile ? 1 : 0,
          destinations: [
            RoleDockDestination(
                id: 'preparation-home',
                label: 'Tayyorlov',
                icon: Icons.science_outlined,
                selectedIcon: Icons.science,
                active: !profile,
                routeName: AppRoutes.preparation,
                onTap: () => AppRootNavigation.replaceRootRoute(
                    context, AppRoutes.preparation)),
            RoleDockDestination(
                id: 'preparation-profile',
                label: 'Profil',
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                active: profile,
                routeName: AppRoutes.profile,
                onTap: () => AppRootNavigation.replaceRootRoute(
                    context, AppRoutes.profile)),
          ]);
}

class PreparationDrawer extends StatelessWidget {
  const PreparationDrawer({super.key, this.profile = false});
  final bool profile;
  @override
  Widget build(BuildContext context) => RoleNavigationDrawer(
          selectedIndex: profile ? 1 : 0,
          headerLabel: 'Tayyorlov masteri',
          onNavigate: (route) =>
              AppRootNavigation.replaceRootRoute(context, route),
          destinations: const [
            RoleNavigationDrawerDestination(
                label: 'Tayyorlov',
                icon: Icons.science_outlined,
                selectedIcon: Icons.science,
                routeName: AppRoutes.preparation),
            RoleNavigationDrawerDestination(
                label: 'Profil',
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                routeName: AppRoutes.profile),
          ]);
}
