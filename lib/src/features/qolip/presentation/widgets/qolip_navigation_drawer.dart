import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/navigation/role_navigation_drawer.dart';
import 'package:flutter/material.dart';

class QolipNavigationDrawer extends StatelessWidget {
  const QolipNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
  });

  final int selectedIndex;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RoleNavigationDrawer(
      selectedIndex: selectedIndex,
      onNavigate: onNavigate,
      destinations: [
        RoleNavigationDrawerDestination(
          icon: Icons.grid_view_outlined,
          selectedIcon: Icons.grid_view_rounded,
          label: l10n.homeNavTitle,
          routeName: AppRoutes.qolipHome,
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
