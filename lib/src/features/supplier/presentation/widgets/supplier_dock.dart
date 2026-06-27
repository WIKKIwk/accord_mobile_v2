import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/navigation/profile_route_overlay_notifier.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/notifications/store/notification_unread_store.dart';
import '../../../../core/session/session.dart';
import '../../../../core/widgets/navigation/role_dock.dart';
import 'package:flutter/material.dart';

enum SupplierDockTab { home, notifications, recent }

class SupplierDock extends StatelessWidget {
  const SupplierDock({
    super.key,
    required this.activeTab,
    this.centerActive = false,
    this.compact = true,
    this.tightToEdges = true,
    this.showPrimaryFab = true,
  });

  final SupplierDockTab? activeTab;
  final bool centerActive;
  final bool compact;
  final bool tightToEdges;
  final bool showPrimaryFab;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        NotificationUnreadStore.instance,
        NativeDockBridge.instance,
        ProfileRouteOverlayNotifier.instance,
      ]),
      builder: (context, _) {
        final l10n = context.l10n;
        final effectiveShowPrimaryFab = showPrimaryFab &&
            !ProfileRouteOverlayNotifier.instance.obscuresDockPrimaryFab;
        final showBadge = NotificationUnreadStore.instance.hasUnreadForProfile(
              AppSession.instance.profile,
            ) &&
            activeTab != SupplierDockTab.notifications;
        final bool selectionVisible = activeTab != null || centerActive;
        final int selectedIndex = switch (activeTab) {
          SupplierDockTab.home => 0,
          SupplierDockTab.notifications => 1,
          SupplierDockTab.recent => 3,
          null => centerActive ? 2 : 0,
        };

        void handleSelection(int index) {
          if (index == 0) {
            if (activeTab == SupplierDockTab.home && !centerActive) {
              return;
            }
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil(AppRoutes.supplierHome, (route) => false);
            return;
          }
          if (index == 1) {
            if (activeTab == SupplierDockTab.notifications) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.supplierNotifications,
              (route) => false,
            );
            return;
          }
          if (index == 2) {
            if (centerActive) return;
            Navigator.of(context).pushNamed(AppRoutes.supplierItemPicker);
            return;
          }
          if (index == 3) {
            if (activeTab == SupplierDockTab.recent) return;
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.supplierRecent,
              (route) => false,
            );
            return;
          }
        }

        return RoleDock(
          compact: compact,
          tightToEdges: tightToEdges,
          selectionVisible: selectionVisible,
          selectedIndex: selectedIndex,
          primaryVisible: effectiveShowPrimaryFab,
          destinations: [
            RoleDockDestination(
              id: 'supplier-home',
              label: l10n.homeNavTitle,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              active: activeTab == SupplierDockTab.home && !centerActive,
              routeName: AppRoutes.supplierHome,
              onTap: () => handleSelection(0),
            ),
            RoleDockDestination(
              id: 'supplier-notifications',
              label: l10n.notificationsShortTitle,
              icon: Icons.notifications_outlined,
              selectedIcon: Icons.notifications_rounded,
              active: activeTab == SupplierDockTab.notifications,
              showBadge: showBadge,
              routeName: AppRoutes.supplierNotifications,
              onTap: () => handleSelection(1),
            ),
            RoleDockDestination(
              id: 'supplier-create',
              label: l10n.createNavTitle,
              icon: Icons.add_rounded,
              selectedIcon: Icons.add_rounded,
              active: centerActive,
              primary: true,
              onTap: () => handleSelection(2),
            ),
            RoleDockDestination(
              id: 'supplier-recent',
              label: l10n.historyNavTitle,
              icon: Icons.history_outlined,
              selectedIcon: Icons.history_rounded,
              active: activeTab == SupplierDockTab.recent,
              routeName: AppRoutes.supplierRecent,
              onTap: () => handleSelection(3),
            ),
          ],
        );
      },
    );
  }
}
