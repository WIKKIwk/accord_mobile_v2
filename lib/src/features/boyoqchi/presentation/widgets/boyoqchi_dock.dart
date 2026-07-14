import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/navigation/app_root_navigation.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/widgets/navigation/role_dock.dart';
import 'package:flutter/material.dart';

enum BoyoqchiDockTab { home, astatka, profile }

class BoyoqchiDock extends StatelessWidget {
  const BoyoqchiDock({
    super.key,
    required this.activeTab,
    this.compact = true,
    this.tightToEdges = true,
  });

  final BoyoqchiDockTab? activeTab;
  final bool compact;
  final bool tightToEdges;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NativeDockBridge.instance,
      builder: (context, _) {
        final l10n = context.l10n;
        final selectedIndex = switch (activeTab) {
          BoyoqchiDockTab.home => 0,
          BoyoqchiDockTab.astatka => 1,
          BoyoqchiDockTab.profile => 2,
          null => 0,
        };

        void handleSelection(int index) {
          if (index == 0) {
            if (activeTab == BoyoqchiDockTab.home) return;
            AppRootNavigation.replaceRootRoute(
              context,
              AppRoutes.boyoqchiHome,
            );
            return;
          }
          if (index == 1) {
            if (activeTab == BoyoqchiDockTab.astatka) return;
            AppRootNavigation.replaceRootRoute(
              context,
              AppRoutes.boyoqchiAstatka,
            );
            return;
          }
          if (activeTab == BoyoqchiDockTab.profile) return;
          AppRootNavigation.replaceRootRoute(context, AppRoutes.profile);
        }

        return RoleDock(
          compact: compact,
          tightToEdges: tightToEdges,
          selectionVisible: activeTab != null,
          selectedIndex: selectedIndex,
          destinations: [
            RoleDockDestination(
              id: 'boyoqchi-home',
              label: l10n.homeNavTitle,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              active: activeTab == BoyoqchiDockTab.home,
              routeName: AppRoutes.boyoqchiHome,
              onTap: () => handleSelection(0),
            ),
            RoleDockDestination(
              id: 'boyoqchi-astatka',
              label: 'Astatka',
              icon: Icons.inventory_2_outlined,
              selectedIcon: Icons.inventory_2_rounded,
              active: activeTab == BoyoqchiDockTab.astatka,
              routeName: AppRoutes.boyoqchiAstatka,
              onTap: () => handleSelection(1),
            ),
            RoleDockDestination(
              id: 'boyoqchi-profile',
              label: l10n.profileTitle,
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              active: activeTab == BoyoqchiDockTab.profile,
              routeName: AppRoutes.profile,
              onTap: () => handleSelection(2),
            ),
          ],
        );
      },
    );
  }
}
