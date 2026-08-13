import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/session/state/app_session.dart';
import '../../../../core/widgets/navigation/role_navigation_drawer.dart';
import '../../../admin/logic/production_map_pechat_rules.dart';
import '../../../shared/models/app_models.dart';
import 'package:flutter/material.dart';

class AparatchiNavigationDrawer extends StatelessWidget {
  const AparatchiNavigationDrawer({
    super.key,
    required this.selectedIndex,
    required this.onNavigate,
    this.selectedRouteName,
  });

  final int selectedIndex;
  final ValueChanged<String> onNavigate;
  final String? selectedRouteName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = AppSession.instance.profile;
    final showDailyWork = profile != null &&
        profile.role == UserRole.aparatchi &&
        profile.assignedApparatus.any(
          (apparatus) =>
              productionMapIsPechatApparatus(apparatus) ||
              productionMapIsRezkaApparatus(apparatus) ||
              productionMapIsLaminatsiyaApparatus(apparatus),
        );
    return RoleNavigationDrawer(
      selectedIndex: selectedIndex,
      selectedRouteName: selectedRouteName,
      onNavigate: onNavigate,
      destinations: [
        RoleNavigationDrawerDestination(
          icon: Icons.view_list_outlined,
          selectedIcon: Icons.view_list_rounded,
          label: l10n.monitoringNavTitle,
          routeName: AppRoutes.apparatusQueue,
        ),
        if (showDailyWork)
          RoleNavigationDrawerDestination(
            icon: Icons.today_outlined,
            selectedIcon: Icons.today_rounded,
            label: l10n.productionText('worker.daily'),
            routeName: AppRoutes.apparatusDailyWork,
          ),
        if (showDailyWork)
          RoleNavigationDrawerDestination(
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2_rounded,
            label: l10n.productionText('worker.paddons'),
            routeName: AppRoutes.apparatusPaddons,
          ),
        RoleNavigationDrawerDestination(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book_rounded,
          label: l10n.productionText('worker.instructions'),
          routeName: AppRoutes.apparatusWorkInstructions,
        ),
        if (AppRouter.canOpenRoute(AppRoutes.inventoryMovements))
          RoleNavigationDrawerDestination(
            icon: Icons.swap_horiz_outlined,
            selectedIcon: Icons.swap_horiz_rounded,
            label: l10n.productionText('worker.transfer'),
            routeName: AppRoutes.inventoryMovements,
            push: true,
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
