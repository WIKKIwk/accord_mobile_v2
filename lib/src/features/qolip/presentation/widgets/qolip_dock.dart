import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/navigation/app_root_navigation.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/widgets/navigation/role_dock.dart';
import 'package:flutter/material.dart';

enum QolipDockTab { home, products, checkouts, profile }

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
        final l10n = context.l10n;
        final bool selectionVisible = activeTab != null;
        final int selectedIndex = switch (activeTab) {
          QolipDockTab.home => 0,
          QolipDockTab.products => 1,
          QolipDockTab.checkouts => 2,
          QolipDockTab.profile => 3,
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
            if (activeTab == QolipDockTab.products) {
              return;
            }
            if (onTabSelected != null) {
              onTabSelected!(QolipDockTab.products);
            } else {
              AppRootNavigation.replaceRootRoute(
                context,
                AppRoutes.qolipProducts,
              );
            }
            return;
          }
          if (index == 2) {
            if (activeTab == QolipDockTab.checkouts) {
              return;
            }
            if (onTabSelected != null) {
              onTabSelected!(QolipDockTab.checkouts);
            } else {
              AppRootNavigation.replaceRootRoute(
                context,
                AppRoutes.qolipCheckouts,
              );
            }
            return;
          }
          if (index == 3) {
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
              label: l10n.homeNavTitle,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_filled,
              active: activeTab == QolipDockTab.home,
              routeName: onTabSelected == null ? AppRoutes.qolipHome : null,
              replaceStack: onTabSelected == null,
              onTap: () => handleSelection(0),
            ),
            RoleDockDestination(
              id: 'qolip-products',
              label: 'Qoliplar',
              icon: Icons.inventory_2_outlined,
              selectedIcon: Icons.inventory_2_rounded,
              active: activeTab == QolipDockTab.products,
              routeName: onTabSelected == null ? AppRoutes.qolipProducts : null,
              replaceStack: onTabSelected == null,
              onTap: () => handleSelection(1),
            ),
            RoleDockDestination(
              id: 'qolip-checkouts',
              label: 'Qarz',
              icon: Icons.assignment_return_outlined,
              selectedIcon: Icons.assignment_return_rounded,
              active: activeTab == QolipDockTab.checkouts,
              routeName:
                  onTabSelected == null ? AppRoutes.qolipCheckouts : null,
              replaceStack: onTabSelected == null,
              onTap: () => handleSelection(2),
            ),
            RoleDockDestination(
              id: 'qolip-profile',
              label: l10n.profileTitle,
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              active: activeTab == QolipDockTab.profile,
              routeName: onTabSelected == null ? AppRoutes.profile : null,
              replaceStack: onTabSelected == null,
              onTap: () => handleSelection(3),
            ),
          ],
        );
      },
    );
  }
}
