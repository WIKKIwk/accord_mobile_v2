import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
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
    final l10n = context.l10n;
    return RoleNavigationDrawer(
      selectedIndex: selectedIndex,
      onNavigate: onNavigate,
      destinations: [
        RoleNavigationDrawerDestination(
          icon: Icons.view_list_outlined,
          selectedIcon: Icons.view_list_rounded,
          label: l10n.monitoringNavTitle,
          routeName: AppRoutes.apparatusQueue,
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
