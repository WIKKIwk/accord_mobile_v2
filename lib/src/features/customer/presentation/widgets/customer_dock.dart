import '../../../../app/app_router.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/notifications/store/notification_unread_store.dart';
import '../../../../core/session/session.dart';
import '../../../../core/widgets/navigation/role_dock.dart';
import 'package:flutter/material.dart';

enum CustomerDockTab { home, notifications }

class CustomerDock extends StatelessWidget {
  const CustomerDock({
    super.key,
    required this.activeTab,
    this.onTabSelected,
    this.compact = true,
    this.tightToEdges = true,
  });

  final CustomerDockTab? activeTab;
  final ValueChanged<CustomerDockTab>? onTabSelected;
  final bool compact;
  final bool tightToEdges;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        NotificationUnreadStore.instance,
        NativeDockBridge.instance,
      ]),
      builder: (context, _) {
        final showBadge = NotificationUnreadStore.instance.hasUnreadForProfile(
              AppSession.instance.profile,
            ) &&
            activeTab != CustomerDockTab.notifications;
        final bool selectionVisible = activeTab != null;
        final int selectedIndex = switch (activeTab) {
          CustomerDockTab.home => 0,
          CustomerDockTab.notifications => 1,
          null => 0,
        };

        void handleSelection(int index) {
          if (index == 0) {
            if (activeTab == CustomerDockTab.home) return;
            if (onTabSelected != null) {
              onTabSelected!(CustomerDockTab.home);
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.customerHome,
                (route) => false,
              );
            }
            return;
          }
          if (index == 1) {
            if (activeTab == CustomerDockTab.notifications) return;
            if (onTabSelected != null) {
              onTabSelected!(CustomerDockTab.notifications);
            } else {
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.customerNotifications,
                (route) => false,
              );
            }
            return;
          }
        }

        return RoleDock(
          compact: compact,
          tightToEdges: tightToEdges,
          selectionVisible: selectionVisible,
          selectedIndex: selectedIndex,
          destinations: [
            RoleDockDestination(
              id: 'customer-home',
              label: 'Uy',
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_filled,
              active: activeTab == CustomerDockTab.home,
              routeName: onTabSelected == null ? AppRoutes.customerHome : null,
              replaceStack: onTabSelected == null,
              onTap: () => handleSelection(0),
            ),
            RoleDockDestination(
              id: 'customer-notifications',
              label: 'Bildirish',
              icon: Icons.notifications_outlined,
              selectedIcon: Icons.notifications,
              active: activeTab == CustomerDockTab.notifications,
              showBadge: showBadge,
              routeName: onTabSelected == null
                  ? AppRoutes.customerNotifications
                  : null,
              replaceStack: onTabSelected == null,
              onTap: () => handleSelection(1),
            ),
          ],
        );
      },
    );
  }
}
