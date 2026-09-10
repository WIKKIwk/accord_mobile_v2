import 'package:flutter/material.dart';
import '../../../app/app_router.dart';
import '../../../core/localization/app_localizations.dart';
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
  const PreparationDrawer({
    super.key,
    this.profile = false,
    this.selectedRouteName,
    this.onNavigate,
  });

  final bool profile;
  final String? selectedRouteName;
  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RoleNavigationDrawer(
      selectedIndex: profile ? 2 : 0,
      selectedRouteName: selectedRouteName ??
          (profile ? AppRoutes.profile : AppRoutes.preparation),
      headerLabel: 'Tayyorlov bo‘limlari',
      onNavigate: onNavigate ??
          (route) => AppRootNavigation.replaceRootRoute(context, route),
      destinations: [
        const RoleNavigationDrawerDestination(
          label: 'Tayyorlov',
          icon: Icons.science_outlined,
          selectedIcon: Icons.science,
          routeName: AppRoutes.preparation,
        ),
        const RoleNavigationDrawerDestination(
          icon: Icons.format_list_numbered_outlined,
          selectedIcon: Icons.format_list_numbered_rounded,
          label: 'Ketma-ketlik',
          routeName: AppRoutes.supplySequence,
          push: true,
        ),
        const RoleNavigationDrawerDestination(
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
          label: 'Chat',
          routeName: AppRoutes.chat,
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
          label: l10n.profileTitle,
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          routeName: AppRoutes.profile,
        ),
      ],
    );
  }
}
