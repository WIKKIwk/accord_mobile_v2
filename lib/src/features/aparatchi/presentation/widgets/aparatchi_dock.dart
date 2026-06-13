import '../../../../app/app_router.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/widgets/navigation/app_navigation_bar.dart';
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
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.apparatusQueue,
                (route) => false,
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
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.profile, (route) => false);
            }
          }
        }

        final useNativeDock =
            NativeDockBridge.isSupportedPlatform &&
            NativeDockBridge.instance.supportsSystemDock;
        if (useNativeDock) {
          NativeDockBridge.instance.register(
            NativeDockState(
              visible: true,
              compact: compact,
              tightToEdges: tightToEdges,
              items: [
                NativeDockItem(
                  id: 'aparatchi-home',
                  label: 'Uy',
                  iconCodePoint: Icons.home_outlined.codePoint,
                  selectedIconCodePoint: Icons.home_filled.codePoint,
                  active: activeTab == AparatchiDockTab.home,
                  primary: false,
                  showBadge: false,
                  routeName: onTabSelected == null
                      ? AppRoutes.apparatusQueue
                      : null,
                  replaceStack: onTabSelected == null,
                  onTap: () => handleSelection(0),
                ),
                NativeDockItem(
                  id: 'aparatchi-profile',
                  label: 'Profil',
                  iconCodePoint: Icons.person_outline_rounded.codePoint,
                  selectedIconCodePoint: Icons.person_rounded.codePoint,
                  active: activeTab == AparatchiDockTab.profile,
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
