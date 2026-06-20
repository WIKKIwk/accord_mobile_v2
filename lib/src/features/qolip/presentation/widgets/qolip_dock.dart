import '../../../../app/app_router.dart';
import '../../../../core/navigation/app_root_navigation.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/widgets/navigation/app_navigation_bar.dart';
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

        final useNativeDock = NativeDockBridge.isSupportedPlatform &&
            NativeDockBridge.instance.supportsSystemDock;
        if (useNativeDock) {
          NativeDockBridge.instance.register(
            NativeDockState(
              visible: true,
              compact: compact,
              tightToEdges: tightToEdges,
              items: [
                NativeDockItem(
                  id: 'qolip-home',
                  label: 'Uy',
                  iconCodePoint: Icons.home_outlined.codePoint,
                  selectedIconCodePoint: Icons.home_filled.codePoint,
                  active: activeTab == QolipDockTab.home,
                  primary: false,
                  showBadge: false,
                  routeName:
                      onTabSelected == null ? AppRoutes.qolipHome : null,
                  replaceStack: onTabSelected == null,
                  onTap: () => handleSelection(0),
                ),
                NativeDockItem(
                  id: 'qolip-profile',
                  label: 'Profil',
                  iconCodePoint: Icons.person_outline_rounded.codePoint,
                  selectedIconCodePoint: Icons.person_rounded.codePoint,
                  active: activeTab == QolipDockTab.profile,
                  primary: false,
                  showBadge: false,
                  routeName: onTabSelected == null ? AppRoutes.profile : null,
                  replaceStack: onTabSelected == null,
                  onTap: () => handleSelection(1),
                ),
              ],
            ),
          );
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: tightToEdges ? 0 : 8),
          child: AppNavigationBar(
            height: compact ? 60 : 64,
            selectionVisible: selectionVisible,
            selectedIndex: selectedIndex,
            destinations: const [
              AppNavigationDestination(
                label: 'Uy',
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_filled),
              ),
              AppNavigationDestination(
                label: 'Profil',
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
              ),
            ],
            onDestinationSelected: handleSelection,
          ),
        );
      },
    );
  }
}
