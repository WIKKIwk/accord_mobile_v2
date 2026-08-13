import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/navigation/app_root_navigation.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/widgets/navigation/role_dock.dart';
import 'package:flutter/material.dart';

enum QolipDockTab { home, products, profile }

class QolipDock extends StatelessWidget {
  const QolipDock({
    super.key,
    required this.activeTab,
    this.onTabSelected,
    this.compact = true,
    this.tightToEdges = true,
    this.showPrimaryFab = false,
    this.onPrimaryFabTap,
  });

  final QolipDockTab? activeTab;
  final ValueChanged<QolipDockTab>? onTabSelected;
  final bool compact;
  final bool tightToEdges;
  final bool showPrimaryFab;
  final VoidCallback? onPrimaryFabTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NativeDockBridge.instance,
      builder: (context, _) {
        final l10n = context.l10n;
        final bool selectionVisible = activeTab != null;

        void selectTab(QolipDockTab tab, String route) {
          if (activeTab == tab) {
            return;
          }
          if (onTabSelected != null) {
            onTabSelected!(tab);
          } else {
            AppRootNavigation.replaceRootRoute(context, route);
          }
        }

        final destinations = <RoleDockDestination>[
          RoleDockDestination(
            id: 'qolip-home',
            label: l10n.homeNavTitle,
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_filled,
            active: activeTab == QolipDockTab.home,
            routeName: onTabSelected == null ? AppRoutes.qolipHome : null,
            replaceStack: onTabSelected == null,
            onTap: () => selectTab(QolipDockTab.home, AppRoutes.qolipHome),
          ),
          RoleDockDestination(
            id: 'qolip-products',
            label: l10n.qolipText('nav.molds'),
            icon: Icons.inventory_2_outlined,
            selectedIcon: Icons.inventory_2_rounded,
            active: activeTab == QolipDockTab.products,
            routeName: onTabSelected == null ? AppRoutes.qolipProducts : null,
            replaceStack: onTabSelected == null,
            onTap: () =>
                selectTab(QolipDockTab.products, AppRoutes.qolipProducts),
          ),
          if (showPrimaryFab && onPrimaryFabTap != null)
            RoleDockDestination(
              id: 'qolip-create',
              label: l10n.qolipText('action.add'),
              icon: Icons.add_rounded,
              selectedIcon: Icons.add_rounded,
              active: false,
              primary: true,
              onTap: onPrimaryFabTap!,
            ),
          RoleDockDestination(
            id: 'qolip-profile',
            label: l10n.profileTitle,
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            active: activeTab == QolipDockTab.profile,
            routeName: onTabSelected == null ? AppRoutes.profile : null,
            replaceStack: onTabSelected == null,
            onTap: () => selectTab(QolipDockTab.profile, AppRoutes.profile),
          ),
        ];
        final selectedIndex = activeTab == null
            ? 0
            : destinations.indexWhere((destination) => destination.active);

        return RoleDock(
          compact: compact,
          tightToEdges: tightToEdges,
          selectionVisible: selectionVisible,
          selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
          primaryVisible: showPrimaryFab && onPrimaryFabTap != null,
          destinations: destinations,
        );
      },
    );
  }
}
