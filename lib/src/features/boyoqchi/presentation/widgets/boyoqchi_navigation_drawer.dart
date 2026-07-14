import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/navigation/role_navigation_drawer.dart';
import 'package:flutter/material.dart';

class BoyoqchiNavigationDrawer extends StatelessWidget {
  const BoyoqchiNavigationDrawer({
    super.key,
    required this.onNavigate,
    this.selectedRouteName,
  });

  final ValueChanged<String> onNavigate;
  final String? selectedRouteName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RoleNavigationDrawer(
      selectedIndex: 0,
      selectedRouteName: selectedRouteName,
      headerLabel: 'Bo‘yoqchi bo‘limlari',
      onNavigate: onNavigate,
      destinations: [
        RoleNavigationDrawerDestination(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: l10n.homeNavTitle,
          routeName: AppRoutes.boyoqchiHome,
        ),
        const RoleNavigationDrawerDestination(
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
          label: 'Chat',
          routeName: AppRoutes.chat,
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
