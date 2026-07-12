import '../../../../app/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/navigation/app_root_navigation.dart';
import '../../../../core/navigation/profile_route_overlay_notifier.dart';
import '../../../../core/native_dock_bridge.dart';
import '../../../../core/widgets/navigation/role_dock.dart';
import 'admin_create_hub_sheet.dart';
import 'package:flutter/material.dart';

enum AdminDockTab { home, profile, suppliers, settings, activity }

class AdminDock extends StatelessWidget {
  const AdminDock({
    super.key,
    required this.activeTab,
    this.compact = true,
    this.tightToEdges = true,
    this.showPrimaryFab = true,
    this.primaryFabActions,
  });

  final AdminDockTab? activeTab;
  final bool compact;
  final bool tightToEdges;
  final bool showPrimaryFab;
  final List<AdminFabMenuAction>? primaryFabActions;

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final homeLabel = l10n?.adminHomeNavTitle ?? 'Uy';
    final profileLabel = l10n?.profileTitle ?? 'Profil';
    final createLabel = l10n?.adminCreateTitle ?? 'Yangi';
    final activityLabel = l10n?.adminActivityNavTitle ?? 'Faoliyat';
    return AnimatedBuilder(
      animation: Listenable.merge([
        NativeDockBridge.instance,
        ProfileRouteOverlayNotifier.instance,
      ]),
      builder: (context, _) {
        final destinations = _visibleDestinations(
          homeLabel: homeLabel,
          profileLabel: profileLabel,
          createLabel: createLabel,
          activityLabel: activityLabel,
        );
        final effectiveShowPrimaryFab = showPrimaryFab &&
            !ProfileRouteOverlayNotifier.instance.obscuresDockPrimaryFab &&
            destinations.any((destination) => destination.primary);
        final selectedIndex = destinations.indexWhere(
          (destination) => destination.tab == activeTab,
        );
        final bool selectionVisible = selectedIndex >= 0;
        final effectiveSelectedIndex = selectedIndex >= 0 ? selectedIndex : 0;

        return ValueListenableBuilder<bool>(
          valueListenable: adminCreateHubMenuOpen,
          builder: (context, menuOpen, _) {
            void handleSelection(int index) {
              if (index < 0 || index >= destinations.length) {
                return;
              }
              final destination = destinations[index];
              if (destination.primary) {
                showAdminCreateHubSheet(
                  context,
                  actions: primaryFabActions,
                );
                return;
              }
              final currentRoute = ModalRoute.of(context)?.settings.name;
              if (activeTab == destination.tab &&
                  !(destination.tab == AdminDockTab.home &&
                      currentRoute != AppRoutes.adminHome)) {
                return;
              }
              AppRootNavigation.replaceRootRoute(
                context,
                destination.routeName,
              );
            }

            return RoleDock(
              compact: compact,
              tightToEdges: tightToEdges,
              selectionVisible: selectionVisible,
              selectedIndex: effectiveSelectedIndex,
              primaryVisible: !menuOpen && effectiveShowPrimaryFab,
              destinations: [
                for (var i = 0; i < destinations.length; i++)
                  RoleDockDestination(
                    id: destinations[i].id,
                    label: destinations[i].label,
                    icon: destinations[i].icon,
                    selectedIcon: destinations[i].selectedIcon,
                    active: activeTab == destinations[i].tab,
                    primary: destinations[i].primary,
                    routeName: destinations[i].primary
                        ? null
                        : destinations[i].routeName,
                    replaceStack: !destinations[i].primary,
                    onTap: () => handleSelection(i),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AdminDockDestination {
  const _AdminDockDestination({
    required this.id,
    required this.tab,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.routeName,
    this.primary = false,
  });

  final String id;
  final AdminDockTab? tab;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String routeName;
  final bool primary;
}

List<_AdminDockDestination> _visibleDestinations({
  required String homeLabel,
  required String profileLabel,
  required String createLabel,
  required String activityLabel,
}) {
  final candidates = [
    _AdminDockDestination(
      id: 'admin-home',
      tab: AdminDockTab.home,
      label: homeLabel,
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      routeName: AppRoutes.adminHome,
    ),
    _AdminDockDestination(
      id: 'admin-profile',
      tab: AdminDockTab.profile,
      label: profileLabel,
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      routeName: AppRoutes.profile,
    ),
    _AdminDockDestination(
      id: 'admin-create',
      // The plus button is an action, not a selected navigation tab.
      tab: null,
      label: createLabel,
      icon: Icons.add_rounded,
      selectedIcon: Icons.add_rounded,
      routeName: AppRoutes.adminCreateHub,
      primary: true,
    ),
    _AdminDockDestination(
      id: 'admin-activity',
      tab: AdminDockTab.activity,
      label: activityLabel,
      icon: Icons.history_outlined,
      selectedIcon: Icons.history_rounded,
      routeName: AppRoutes.adminActivity,
    ),
  ];
  return candidates
      .where((destination) => AppRouter.canOpenRoute(destination.routeName))
      .toList(growable: false);
}
