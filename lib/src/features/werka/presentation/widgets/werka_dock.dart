import '../../../../app/app_router.dart';
import '../../../../core/navigation/profile_route_overlay_notifier.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/notifications/store/notification_unread_store.dart';
import '../../../../core/session/session.dart';
import '../../../../core/widgets/navigation/role_dock.dart';
import 'werka_create_hub_sheet.dart';
import 'package:flutter/material.dart';

enum WerkaDockTab { home, notifications, create, archive }

class WerkaDock extends StatelessWidget {
  const WerkaDock({
    super.key,
    required this.activeTab,
    this.compact = true,
    this.tightToEdges = true,
    this.showPrimaryFab = true,
  });

  final WerkaDockTab? activeTab;
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
        final effectiveShowPrimaryFab = showPrimaryFab &&
            !ProfileRouteOverlayNotifier.instance.obscuresDockPrimaryFab;
        final showBadge = NotificationUnreadStore.instance.hasUnreadForProfile(
              AppSession.instance.profile,
            ) &&
            activeTab != WerkaDockTab.notifications;
        final bool selectionVisible = activeTab != null;
        final int selectedIndex = switch (activeTab) {
          WerkaDockTab.home => 0,
          WerkaDockTab.notifications => 1,
          WerkaDockTab.create => 2,
          WerkaDockTab.archive => 3,
          null => 0,
        };
        return ValueListenableBuilder<bool>(
          valueListenable: werkaCreateHubMenuOpen,
          builder: (context, menuOpen, child) {
            void handleSelection(int index) {
              if (index == 0) {
                if (activeTab == WerkaDockTab.home) return;
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.werkaHome,
                  (route) => false,
                );
                return;
              }
              if (index == 1) {
                if (activeTab == WerkaDockTab.notifications) return;
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.werkaNotifications,
                  (route) => false,
                );
                return;
              }
              if (index == 2) {
                showWerkaCreateHubSheet(context);
                return;
              }
              if (index == 3) {
                if (activeTab == WerkaDockTab.archive) return;
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.werkaArchive,
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
              primaryVisible: !menuOpen && effectiveShowPrimaryFab,
              destinations: [
                RoleDockDestination(
                  id: 'werka-home',
                  label: 'Uy',
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  active: activeTab == WerkaDockTab.home,
                  routeName: AppRoutes.werkaHome,
                  onTap: () => handleSelection(0),
                ),
                RoleDockDestination(
                  id: 'werka-notifications',
                  label: 'Bildirish',
                  icon: Icons.notifications_outlined,
                  selectedIcon: Icons.notifications_rounded,
                  active: activeTab == WerkaDockTab.notifications,
                  showBadge: showBadge,
                  routeName: AppRoutes.werkaNotifications,
                  onTap: () => handleSelection(1),
                ),
                RoleDockDestination(
                  id: 'werka-create',
                  label: 'Yangi',
                  icon: Icons.add_rounded,
                  selectedIcon: Icons.add_rounded,
                  active: activeTab == WerkaDockTab.create,
                  primary: true,
                  onTap: () => handleSelection(2),
                ),
                RoleDockDestination(
                  id: 'werka-archive',
                  label: 'Arxiv',
                  icon: Icons.archive_outlined,
                  selectedIcon: Icons.archive_rounded,
                  nativeIcon: Icons.playlist_add_check_rounded,
                  nativeSelectedIcon: Icons.playlist_add_check_rounded,
                  active: activeTab == WerkaDockTab.archive,
                  routeName: AppRoutes.werkaArchive,
                  onTap: () => handleSelection(3),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
