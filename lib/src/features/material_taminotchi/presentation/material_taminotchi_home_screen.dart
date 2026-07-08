import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/display/motion_widgets.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_shell.dart';
import 'widgets/material_taminotchi_dock.dart';
import 'widgets/material_taminotchi_navigation_drawer.dart';
import 'package:flutter/material.dart';

class MaterialTaminotchiHomeScreen extends StatefulWidget {
  const MaterialTaminotchiHomeScreen({super.key});

  @override
  State<MaterialTaminotchiHomeScreen> createState() =>
      _MaterialTaminotchiHomeScreenState();
}

class _MaterialTaminotchiHomeScreenState
    extends State<MaterialTaminotchiHomeScreen> {
  Future<void> _refreshProfile() async {
    try {
      await MobileApi.instance.profile();
      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _openRoute(String route) {
    if (route == AppRoutes.profile || route == AppRoutes.gscaleMode) {
      Navigator.of(context).pushNamed(route);
      return;
    }
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppSession.instance.profile;
    final groups = profile?.assignedItemGroups ?? const <String>[];
    final hasMaterialGroupScope = groups.isNotEmpty;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;

    return AppShell(
      title: 'Material ta’minotchisi',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: MaterialTaminotchiNavigationDrawer(
        selectedRouteName: AppRoutes.materialHome,
        onNavigate: _openDrawerRoute,
      ),
      preferNativeTitle: true,
      contentPadding: EdgeInsets.zero,
      bottom: const MaterialTaminotchiDock(
        activeTab: MaterialTaminotchiDockTab.home,
      ),
      child: AppRefreshIndicator(
        onRefresh: _refreshProfile,
        allowRefreshOnShortContent: true,
        child: ListView(
          physics: const TopRefreshScrollPhysics(),
          padding: EdgeInsets.fromLTRB(0, 8, 0, bottomPadding),
          children: [
            if (!hasMaterialGroupScope) ...[
              const SmoothAppear(
                delay: Duration(milliseconds: 20),
                child: _MaterialScopeNotice(),
              ),
              const SizedBox(height: 14),
            ],
            SmoothAppear(
              delay: const Duration(milliseconds: 40),
              child: _MaterialActionPanel(
                hasMaterialGroupScope: hasMaterialGroupScope,
                onOpenRoute: _openRoute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialActionPanel extends StatelessWidget {
  const _MaterialActionPanel({
    required this.hasMaterialGroupScope,
    required this.onOpenRoute,
  });

  final bool hasMaterialGroupScope;
  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final actions = _materialHomeActions(hasMaterialGroupScope);
    return M3SegmentSpacedColumn(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      children: [
        for (var i = 0; i < actions.length; i++)
          _MaterialActionCard(
            slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
              i,
              actions.length,
            ),
            action: actions[i],
            onTap: () => actions[i].open(context, onOpenRoute),
          ),
      ],
    );
  }
}

class _MaterialHomeAction {
  const _MaterialHomeAction({
    required this.icon,
    required this.title,
    required this.routeName,
    this.requiresMaterialGroupScope = false,
  });

  final IconData icon;
  final String title;
  final String routeName;
  final bool requiresMaterialGroupScope;

  void open(BuildContext context, ValueChanged<String> onOpenRoute) {
    if (requiresMaterialGroupScope) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avval material guruhlari biriktirilishi kerak'),
        ),
      );
      return;
    }
    onOpenRoute(routeName);
  }
}

List<_MaterialHomeAction> _materialHomeActions(bool hasMaterialGroupScope) {
  final candidates = [
    const _MaterialHomeAction(
      icon: Icons.scale_outlined,
      title: 'Tarozilar rejimi',
      routeName: AppRoutes.gscaleMode,
    ),
    _MaterialHomeAction(
      icon: Icons.inventory_2_outlined,
      title: 'Homashyo biriktirish',
      routeName: AppRoutes.adminRawMaterialAssignments,
      requiresMaterialGroupScope: !hasMaterialGroupScope,
    ),
    const _MaterialHomeAction(
      icon: Icons.warehouse_outlined,
      title: 'Omborlarim',
      routeName: AppRoutes.adminWarehouses,
    ),
    const _MaterialHomeAction(
      icon: Icons.person_outline_rounded,
      title: 'Profil',
      routeName: AppRoutes.profile,
    ),
  ];
  return candidates
      .where((action) => AppRouter.canOpenRoute(action.routeName))
      .toList(growable: false);
}

class _MaterialActionCard extends StatelessWidget {
  const _MaterialActionCard({
    required this.slot,
    required this.action,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final _MaterialHomeAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final backgroundColor = theme.brightness == Brightness.dark
        ? AppTheme.actionSurface(context)
        : scheme.surfaceContainerLowest;
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: slot == M3SegmentVerticalSlot.middle
          ? M3SegmentedListGeometry.cornerMiddle
          : M3SegmentedListGeometry.cornerLarge,
      backgroundColor: backgroundColor,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(action.icon, size: 23, color: scheme.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(
              child: Text(action.title, style: theme.textTheme.titleMedium),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialScopeNotice extends StatelessWidget {
  const _MaterialScopeNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mahsulot guruhi biriktirilmagan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Homashyo qabul qilish va zakazga ulash uchun admin avval material guruhini biriktirishi kerak.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
