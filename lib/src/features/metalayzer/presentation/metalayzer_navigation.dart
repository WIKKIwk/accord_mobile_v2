import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/navigation/app_root_navigation.dart';
import '../../../core/widgets/navigation/role_dock.dart';
import '../../../core/widgets/navigation/role_navigation_drawer.dart';

class MetalayzerDock extends StatelessWidget {
  const MetalayzerDock({super.key, this.profile = false});
  final bool profile;

  @override
  Widget build(BuildContext context) => RoleDock(
        compact: true,
        tightToEdges: true,
        selectionVisible: true,
        selectedIndex: profile ? 1 : 0,
        destinations: [
          RoleDockDestination(
            id: 'metalayzer-home',
            label: 'Metalayzer',
            icon: Icons.check_circle_outline,
            selectedIcon: Icons.check_circle,
            active: !profile,
            routeName: AppRoutes.metalayzer,
            onTap: () => AppRootNavigation.replaceRootRoute(
                context, AppRoutes.metalayzer),
          ),
          RoleDockDestination(
            id: 'metalayzer-profile',
            label: 'Profil',
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            active: profile,
            routeName: AppRoutes.profile,
            onTap: () =>
                AppRootNavigation.replaceRootRoute(context, AppRoutes.profile),
          ),
        ],
      );
}

class MetalayzerDrawer extends StatelessWidget {
  const MetalayzerDrawer({super.key, this.profile = false});
  final bool profile;

  @override
  Widget build(BuildContext context) => RoleNavigationDrawer(
        selectedIndex: profile ? 1 : 0,
        headerLabel: 'Metalayzer',
        onNavigate: (route) =>
            AppRootNavigation.replaceRootRoute(context, route),
        destinations: const [
          RoleNavigationDrawerDestination(
            label: 'Metalayzer',
            icon: Icons.check_circle_outline,
            selectedIcon: Icons.check_circle,
            routeName: AppRoutes.metalayzer,
          ),
          RoleNavigationDrawerDestination(
            label: 'Profil',
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            routeName: AppRoutes.profile,
          ),
        ],
      );
}
