import 'package:flutter/material.dart';
import '../../../app/app_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/navigation/app_root_navigation.dart';
import '../../../core/widgets/navigation/role_dock.dart';
import '../../../core/widgets/navigation/role_navigation_drawer.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';

class PreparationDock extends StatelessWidget {
  const PreparationDock({
    super.key,
    this.profile = false,
    this.showPrimaryFab = true,
    this.primaryFabActions,
  });
  final bool profile;
  final bool showPrimaryFab;
  final List<AdminFabMenuAction>? primaryFabActions;

  @override
  Widget build(BuildContext context) {
    final hasActions =
        showPrimaryFab && (primaryFabActions?.isNotEmpty ?? false);
    return ValueListenableBuilder<bool>(
      valueListenable: adminCreateHubMenuOpen,
      builder: (context, menuOpen, _) => RoleDock(
        compact: true,
        tightToEdges: true,
        selectionVisible: true,
        selectedIndex: profile ? (hasActions ? 2 : 1) : 0,
        primaryVisible: !menuOpen && hasActions,
        destinations: [
          RoleDockDestination(
              id: 'preparation-home',
              label: 'Tayyorlov',
              icon: Icons.science_outlined,
              selectedIcon: Icons.science,
              active: !profile,
              routeName: AppRoutes.preparation,
              onTap: () => AppRootNavigation.replaceRootRoute(
                  context, AppRoutes.preparation)),
          if (hasActions)
            RoleDockDestination(
              id: 'preparation-primary',
              label: 'Amallar',
              icon: Icons.add_rounded,
              selectedIcon: Icons.add_rounded,
              active: false,
              primary: true,
              onTap: () => showAdminCreateHubSheet(
                context,
                actions: primaryFabActions,
              ),
            ),
          RoleDockDestination(
              id: 'preparation-profile',
              label: 'Profil',
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              active: profile,
              routeName: AppRoutes.profile,
              onTap: () => AppRootNavigation.replaceRootRoute(
                  context, AppRoutes.profile)),
        ],
      ),
    );
  }
}

class PreparationProductionSections extends StatelessWidget {
  const PreparationProductionSections({super.key, required this.journal});
  final bool journal;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: SegmentedButton<bool>(
          expandedInsets: EdgeInsets.zero,
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
                value: false, label: Text(context.l10n.uiText('Navbat'))),
            ButtonSegment(
                value: true, label: Text(context.l10n.uiText('Jurnal'))),
          ],
          selected: {journal},
          onSelectionChanged: (value) {
            if (value.single == journal) return;
            Navigator.of(context).pushReplacementNamed(
              value.single
                  ? AppRoutes.preparationProduction
                  : AppRoutes.supplySequence,
            );
          },
        ),
      );
}

class PreparationDrawer extends StatelessWidget {
  const PreparationDrawer({
    super.key,
    this.profile = false,
    this.selectedRouteName,
    this.onNavigate,
  });

  final bool profile;
  final String? selectedRouteName;
  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RoleNavigationDrawer(
      selectedIndex: profile ? 2 : 0,
      selectedRouteName: selectedRouteName == AppRoutes.preparationProduction &&
              AppRouter.canOpenRoute(AppRoutes.supplySequence)
          ? AppRoutes.supplySequence
          : selectedRouteName ??
              (profile ? AppRoutes.profile : AppRoutes.preparation),
      headerLabel: 'Tayyorlov bo‘limlari',
      onNavigate: onNavigate ??
          (route) => AppRootNavigation.replaceRootRoute(context, route),
      destinations: [
        const RoleNavigationDrawerDestination(
          label: 'Tayyorlov',
          icon: Icons.science_outlined,
          selectedIcon: Icons.science,
          routeName: AppRoutes.preparation,
        ),
        const RoleNavigationDrawerDestination(
          label: 'Ombor',
          icon: Icons.warehouse_outlined,
          selectedIcon: Icons.warehouse,
          routeName: AppRoutes.preparationWarehouse,
        ),
        RoleNavigationDrawerDestination(
          label: 'Ishlab chiqarish',
          icon: Icons.precision_manufacturing_outlined,
          selectedIcon: Icons.precision_manufacturing,
          routeName: AppRouter.canOpenRoute(AppRoutes.supplySequence)
              ? AppRoutes.supplySequence
              : AppRoutes.preparationProduction,
        ),
        const RoleNavigationDrawerDestination(
          label: 'Formulalar',
          icon: Icons.functions_outlined,
          selectedIcon: Icons.functions_rounded,
          routeName: AppRoutes.preparationFormulas,
        ),
        const RoleNavigationDrawerDestination(
          icon: Icons.chat_bubble_outline_rounded,
          selectedIcon: Icons.chat_bubble_rounded,
          label: 'Chat',
          routeName: AppRoutes.chat,
        ),
        RoleNavigationDrawerDestination(
          label: l10n.profileTitle,
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          routeName: AppRoutes.profile,
        ),
      ],
    );
  }
}
