import '../../../../app/app_router.dart';
import '../../../../core/navigation/app_root_navigation.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/widgets/navigation/role_dock.dart';
import 'package:flutter/material.dart';

enum QolipDockTab { home, profile }

class QolipDock extends StatelessWidget {
  const QolipDock({
    super.key,
    required this.activeTab,
    this.onTabSelected,
    this.compact = true,
    this.tightToEdges = true,
  });

  final QolipDockTab? activeTab;
  final ValueChanged<QolipDockTab>? onTabSelected;
  final bool compact;
  final bool tightToEdges;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NativeDockBridge.instance,
      builder: (context, _) {
        final bool selectionVisible = activeTab != null;
        final int selectedIndex = switch (activeTab) {
          QolipDockTab.home => 0,
          QolipDockTab.profile => 1,
          null => 0,
        };

        void handleSelection(int index) {
          if (index == 0) {
            if (activeTab == QolipDockTab.home) {
              return;
            }
            if (onTabSelected != null) {
              onTabSelected!(QolipDockTab.home);
            } else {
              AppRootNavigation.replaceRootRoute(context, AppRoutes.qolipHome);
            }
            return;
          }
          if (index == 1) {
            if (activeTab == QolipDockTab.profile) {
              return;
            }
            if (onTabSelected != null) {
              onTabSelected!(QolipDockTab.profile);
            } else {
              AppRootNavigation.replaceRootRoute(context, AppRoutes.profile);
            }
          }
        }

        return RoleDock(
          compact: compact,
          tightToEdges: tightToEdges,
          selectionVisible: selectionVisible,
          selectedIndex: selectedIndex,
          destinations: [
            RoleDockDestination(
              id: 'qolip-home',
              label: 'Uy',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_filled,
              active: activeTab == QolipDockTab.home,
              routeName: onTabSelected == null ? AppRoutes.qolipHome : null,
              replaceStack: onTabSelected == null,
              onTap: () => handleSelection(0),
            ),
            RoleDockDestination(
              id: 'qolip-profile',
              label: 'Profil',
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              active: activeTab == QolipDockTab.profile,
              routeName: onTabSelected == null ? AppRoutes.profile : null,
              replaceStack: onTabSelected == null,
              onTap: () => handleSelection(1),
            ),
          ],
        );
      },
    );
  }
}
