import 'package:flutter/material.dart';
import '../../../app/app_router.dart';
import '../../../core/navigation/app_root_navigation.dart';
import '../../../core/widgets/navigation/role_dock.dart';
import '../../../core/widgets/navigation/role_navigation_drawer.dart';

class RawMaterialSplitDock extends StatelessWidget {
  const RawMaterialSplitDock({super.key, this.profile = false});
  final bool profile;
  @override
  Widget build(BuildContext context) => RoleDock(
          compact: true,
          tightToEdges: true,
          selectionVisible: true,
          selectedIndex: profile ? 1 : 0,
          destinations: [
            RoleDockDestination(
                id: 'rawMaterialSplit-home',
                label: 'Rezka',
                icon: Icons.content_cut,
                selectedIcon: Icons.content_cut,
                active: !profile,
                routeName: AppRoutes.rawMaterialSplit,
                onTap: () => AppRootNavigation.replaceRootRoute(
                    context, AppRoutes.rawMaterialSplit)),
            RoleDockDestination(
                id: 'rawMaterialSplit-profile',
                label: 'Profil',
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                active: profile,
                routeName: AppRoutes.profile,
                onTap: () => AppRootNavigation.replaceRootRoute(
                    context, AppRoutes.profile)),
          ]);
}

class RawMaterialSplitDrawer extends StatelessWidget {
  const RawMaterialSplitDrawer({
    super.key,
    this.profile = false,
    this.history = false,
  });
  final bool profile;
  final bool history;
  @override
  Widget build(BuildContext context) => RoleNavigationDrawer(
          selectedIndex: profile
              ? 2
              : history
                  ? 1
                  : 0,
          headerLabel: 'Rezka',
          onNavigate: (route) =>
              AppRootNavigation.replaceRootRoute(context, route),
          destinations: const [
            RoleNavigationDrawerDestination(
                label: 'Rezka',
                icon: Icons.content_cut,
                selectedIcon: Icons.content_cut,
                routeName: AppRoutes.rawMaterialSplit),
            RoleNavigationDrawerDestination(
                label: 'Rezka tarixi',
                icon: Icons.history_outlined,
                selectedIcon: Icons.history_rounded,
                routeName: AppRoutes.rawMaterialSplitHistory),
            RoleNavigationDrawerDestination(
                label: 'Profil',
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                routeName: AppRoutes.profile),
          ]);
}
