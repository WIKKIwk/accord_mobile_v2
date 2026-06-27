import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/navigation/app_root_navigation.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/widgets/navigation/role_dock.dart';
import 'package:flutter/material.dart';

enum AparatchiDockTab { home, profile }

class AparatchiDock extends StatelessWidget {
  const AparatchiDock({
    super.key,
    required this.activeTab,
    this.onTabSelected,
    this.compact = true,
    this.tightToEdges = true,
  });

  final AparatchiDockTab? activeTab;
  final ValueChanged<AparatchiDockTab>? onTabSelected;
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
          AparatchiDockTab.home => 0,
          AparatchiDockTab.profile => 1,
          null => 0,
        };

        void handleSelection(int index) {
          if (index == 0) {
            if (activeTab == AparatchiDockTab.home) {
              return;
            }
            if (onTabSelected != null) {
              onTabSelected!(AparatchiDockTab.home);
            } else {
              AppRootNavigation.replaceRootRoute(
                context,
                AppRoutes.apparatusQueue,
              );
            }
            return;
          }
          if (index == 1) {
            if (activeTab == AparatchiDockTab.profile) {
              return;
            }
            if (onTabSelected != null) {
              onTabSelected!(AparatchiDockTab.profile);
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
              id: 'aparatchi-home',
              label: l10n.homeNavTitle,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_filled,
              active: activeTab == AparatchiDockTab.home,
              routeName:
                  onTabSelected == null ? AppRoutes.apparatusQueue : null,
              replaceStack: onTabSelected == null,
              onTap: () => handleSelection(0),
            ),
            RoleDockDestination(
              id: 'aparatchi-profile',
              label: l10n.profileTitle,
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              active: activeTab == AparatchiDockTab.profile,
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
