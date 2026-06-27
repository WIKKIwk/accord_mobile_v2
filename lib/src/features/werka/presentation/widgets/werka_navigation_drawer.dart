import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/navigation/role_navigation_drawer.dart';
import 'package:flutter/material.dart';

class WerkaNavigationDrawer extends StatelessWidget {
  const WerkaNavigationDrawer({
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
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: l10n.homeNavTitle,
          routeName: AppRoutes.werkaHome,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.notifications_outlined,
          selectedIcon: Icons.notifications_rounded,
          label: l10n.notificationsShortTitle,
          routeName: AppRoutes.werkaNotifications,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.archive_outlined,
          selectedIcon: Icons.archive_rounded,
          label: l10n.archiveNavTitle,
          routeName: AppRoutes.werkaArchive,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: l10n.profileTitle,
          routeName: AppRoutes.profile,
        ),
        RoleNavigationDrawerDestination(
          icon: Icons.swap_horiz_rounded,
          selectedIcon: Icons.swap_horiz_rounded,
          label: l10n.adminScalesModeNavTitle,
          routeName: AppRoutes.gscaleMode,
          push: true,
        ),
      ],
    );
  }
}
