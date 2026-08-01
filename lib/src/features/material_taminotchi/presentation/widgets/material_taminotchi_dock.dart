import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/navigation/app_root_navigation.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/widgets/navigation/role_dock.dart';
import 'package:flutter/material.dart';

enum MaterialTaminotchiDockTab { home, scale, profile }

class MaterialTaminotchiDock extends StatelessWidget {
  const MaterialTaminotchiDock({
    super.key,
    this.activeTab,
    this.compact = true,
    this.tightToEdges = true,
  });

  final MaterialTaminotchiDockTab? activeTab;
  final bool compact;
  final bool tightToEdges;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NativeDockBridge.instance,
      builder: (context, _) {
        final l10n = context.l10n;
        final selectedIndex = switch (activeTab) {
          MaterialTaminotchiDockTab.home => 0,
          MaterialTaminotchiDockTab.scale => 1,
          MaterialTaminotchiDockTab.profile => 2,
          null => 0,
        };

        void handleSelection(int index) {
          if (index == 0) {
            if (activeTab == MaterialTaminotchiDockTab.home) return;
            AppRootNavigation.replaceRootRoute(
              context,
              AppRoutes.materialHome,
            );
            return;
          }
          if (index == 1) {
            if (activeTab == MaterialTaminotchiDockTab.scale) return;
            AppRootNavigation.replaceRootRoute(context, AppRoutes.gscaleMode);
            return;
          }
          if (index == 2) {
            if (activeTab == MaterialTaminotchiDockTab.profile) return;
            AppRootNavigation.replaceRootRoute(context, AppRoutes.profile);
          }
        }

        return RoleDock(
          compact: compact,
          tightToEdges: tightToEdges,
          selectionVisible: activeTab != null,
          selectedIndex: selectedIndex,
          destinations: [
            RoleDockDestination(
              id: 'material-home',
              label: l10n.homeNavTitle,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              active: activeTab == MaterialTaminotchiDockTab.home,
              routeName: AppRoutes.materialHome,
              onTap: () => handleSelection(0),
            ),
            RoleDockDestination(
              id: 'material-scale',
              label: 'Kirim',
              icon: Icons.scale_outlined,
              selectedIcon: Icons.scale_rounded,
              active: activeTab == MaterialTaminotchiDockTab.scale,
              routeName: AppRoutes.gscaleMode,
              replaceStack: false,
              onTap: () => handleSelection(1),
            ),
            RoleDockDestination(
              id: 'material-profile',
              label: l10n.profileTitle,
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              active: activeTab == MaterialTaminotchiDockTab.profile,
              routeName: AppRoutes.profile,
              replaceStack: false,
              onTap: () => handleSelection(2),
            ),
          ],
        );
      },
    );
  }
}
