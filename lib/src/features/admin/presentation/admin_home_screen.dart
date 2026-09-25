import '../../../app/app_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/hub/refresh_hub.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart' show AppRefreshIndicator;
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../state/admin_store.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_shell.dart';
import 'widgets/admin_summary_card.dart';
import 'package:flutter/material.dart';

const double _adminHomePanelCardGap = 4;

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _refreshVersion = 0;
  bool _openingRoute = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canLoadSummary) {
        AdminStore.instance.bootstrapSummary();
      }
    });
    RefreshHub.instance.addListener(_handlePushRefresh);
  }

  @override
  void dispose() {
    RefreshHub.instance.removeListener(_handlePushRefresh);
    super.dispose();
  }

  void _handlePushRefresh() {
    if (!mounted || RefreshHub.instance.topic != 'admin') {
      return;
    }
    if (_refreshVersion == RefreshHub.instance.version) {
      return;
    }
    _refreshVersion = RefreshHub.instance.version;
    _reload();
  }

  Future<void> _reload() async {
    if (_canLoadSummary) {
      await AdminStore.instance.refreshSummary();
    }
  }

  bool get _canLoadSummary {
    return AppSession.instance.can('party.supplier.read');
  }

  Future<void> _openAndReload(String routeName) async {
    if (_openingRoute) {
      return;
    }
    _openingRoute = true;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushNamed(routeName);
      if (!mounted) {
        return;
      }
      await _reload();
    } finally {
      _openingRoute = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return AdminShell(
      title: context.l10n.adminRoleName,
      selectedRouteName: AppRoutes.adminHome,
      activeTab: AdminDockTab.home,
      bottomDockFadeStrength: null,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: AnimatedBuilder(
          animation: AdminStore.instance,
          builder: (context, _) {
            final store = AdminStore.instance;
            final canLoadSummary = _canLoadSummary;
            if (canLoadSummary &&
                store.loadingSummary &&
                !store.loadedSummary) {
              return const Center(child: AppLoadingIndicator());
            }
            if (canLoadSummary &&
                store.summaryError != null &&
                !store.loadedSummary) {
              return AppRetryState(onRetry: _reload);
            }

            return AppRefreshIndicator(
              onRefresh: _reload,
              allowRefreshOnShortContent: true,
              child: ListView(
                physics: const TopRefreshScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottomPadding),
                children: [
                  const SizedBox(height: _adminHomePanelCardGap),
                  if (canLoadSummary) ...[
                    _AdminHomeShortcutList(onOpenRoute: _openAndReload),
                  ] else
                    _AdminActionList(onOpenRoute: _openAndReload),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminActionList extends StatelessWidget {
  const _AdminActionList({required this.onOpenRoute});

  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final actions = _adminHomeActions(context);
    return M3SegmentSpacedColumn(
      padding: const EdgeInsets.symmetric(
        horizontal: _adminHomePanelCardGap,
      ),
      children: [
        for (var i = 0; i < actions.length; i++)
          _AdminActionCard(
            slot: _slotFor(i, actions.length),
            action: actions[i],
            onTap: () => onOpenRoute(actions[i].routeName),
          ),
      ],
    );
  }
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.slot,
    required this.action,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final _AdminHomeAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: slot == M3SegmentVerticalSlot.middle
          ? M3SegmentedListGeometry.cornerMiddle
          : M3SegmentedListGeometry.cornerLarge,
      backgroundColor: scheme.surfaceContainerLowest,
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

class _AdminHomeAction {
  const _AdminHomeAction({
    required this.title,
    required this.icon,
    required this.routeName,
  });

  final String title;
  final IconData icon;
  final String routeName;
}

List<_AdminHomeAction> _adminHomeActions(BuildContext context) {
  final l10n = context.l10n;
  final candidates = [
    _AdminHomeAction(
      title: l10n.adminCreateItemTitle,
      icon: Icons.inventory_2_outlined,
      routeName: AppRoutes.adminItemCreate,
    ),
    _AdminHomeAction(
      title: l10n.adminProductsTitle,
      icon: Icons.grid_view_rounded,
      routeName: AppRoutes.adminItemBulkMove,
    ),
    _AdminHomeAction(
      title: l10n.adminWarehousesNavTitle,
      icon: Icons.warehouse_rounded,
      routeName: AppRoutes.adminWarehouses,
    ),
    _AdminHomeAction(
      title: l10n.adminFactoryStatesNavTitle,
      icon: Icons.add_location_alt_outlined,
      routeName: AppRoutes.adminFactoryLocations,
    ),
    _AdminHomeAction(
      title: l10n.adminText('home.inventory_transfer'),
      icon: Icons.swap_horiz_rounded,
      routeName: AppRoutes.inventoryMovements,
    ),
    _AdminHomeAction(
      title: l10n.adminCreateItemGroupTitle,
      icon: Icons.account_tree_outlined,
      routeName: AppRoutes.adminItemGroupCreate,
    ),
    _AdminHomeAction(
      title: l10n.adminCreateUserTitle,
      icon: Icons.group_add_outlined,
      routeName: AppRoutes.adminUserCreate,
    ),
    _AdminHomeAction(
      title: l10n.adminUsersTitle,
      icon: Icons.groups_outlined,
      routeName: AppRoutes.adminSuppliers,
    ),
    _AdminHomeAction(
      title: l10n.adminRolesTitle,
      icon: Icons.admin_panel_settings_outlined,
      routeName: AppRoutes.adminRoles,
    ),
    _AdminHomeAction(
      title: l10n.adminTelegramTitle,
      icon: Icons.telegram,
      routeName: AppRoutes.adminTelegram,
    ),
    _AdminHomeAction(
      title: l10n.adminQuickOrdersTitle,
      icon: Icons.list_alt_rounded,
      routeName: AppRoutes.adminCalculateOrders,
    ),
    _AdminHomeAction(
      title: l10n.adminText('home.raw_material_microns'),
      icon: Icons.straighten_rounded,
      routeName: AppRoutes.adminCalculateMaterials,
    ),
    _AdminHomeAction(
      title: l10n.adminProductionMapTestTitle,
      icon: Icons.schema_rounded,
      routeName: AppRoutes.adminProductionMapTest,
    ),
    _AdminHomeAction(
      title: l10n.adminEquipmentNavTitle,
      icon: Icons.precision_manufacturing_rounded,
      routeName: AppRoutes.adminApparatusSettings,
    ),
    _AdminHomeAction(
      title: l10n.adminRawMaterialRulesNavTitle,
      icon: Icons.rule_rounded,
      routeName: AppRoutes.adminRawMaterialSettings,
    ),
    _AdminHomeAction(
      title: l10n.adminWorkMapNavTitle,
      icon: Icons.account_tree_outlined,
      routeName: AppRoutes.adminProductionMapOrders,
    ),
    _AdminHomeAction(
      title: l10n.adminSemiFinishedProductsNavTitle,
      icon: Icons.inventory_2_outlined,
      routeName: AppRoutes.adminWipBatches,
    ),
    _AdminHomeAction(
      title: l10n.adminText('home.gscale'),
      icon: Icons.scale_outlined,
      routeName: AppRoutes.gscaleMode,
    ),
    _AdminHomeAction(
      title: l10n.adminErpSettingsTitle,
      icon: Icons.settings_outlined,
      routeName: AppRoutes.adminSettings,
    ),
    _AdminHomeAction(
      title: l10n.adminText('emergency_reset.title'),
      icon: Icons.delete_sweep_outlined,
      routeName: AppRoutes.adminEmergencyReset,
    ),
    _AdminHomeAction(
      title: l10n.adminActivityTitle,
      icon: Icons.history_outlined,
      routeName: AppRoutes.adminActivity,
    ),
    _AdminHomeAction(
      title: l10n.adminServerStatusNavTitle,
      icon: Icons.monitor_heart_outlined,
      routeName: AppRoutes.adminServerMonitor,
    ),
  ];
  return candidates
      .where((action) => AppRouter.canOpenRoute(action.routeName))
      .toList(growable: false);
}

M3SegmentVerticalSlot _slotFor(int index, int length) {
  if (length <= 1) {
    return M3SegmentVerticalSlot.top;
  }
  if (index == 0) {
    return M3SegmentVerticalSlot.top;
  }
  if (index == length - 1) {
    return M3SegmentVerticalSlot.bottom;
  }
  return M3SegmentVerticalSlot.middle;
}

class _AdminHomeShortcut {
  const _AdminHomeShortcut({required this.title, required this.routeName});

  final String title;
  final String routeName;
}

/// Uy sahifasidagi 5 ta shortcut: Foydalanuvchilar, Mahsulotlar,
/// Tezkor buyurtmalar, Buyurtma ochish, Ish xaritasi (oxirida).
/// Har biri capability bo'yicha ko'rinadi.
class _AdminHomeShortcutList extends StatelessWidget {
  const _AdminHomeShortcutList({required this.onOpenRoute});

  final ValueChanged<String> onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shortcuts = [
      _AdminHomeShortcut(
        title: l10n.adminUsersTitle,
        routeName: AppRoutes.adminSuppliers,
      ),
      _AdminHomeShortcut(
        title: l10n.adminProductsTitle,
        routeName: AppRoutes.adminItemBulkMove,
      ),
      _AdminHomeShortcut(
        title: l10n.adminQuickOrdersTitle,
        routeName: AppRoutes.adminCalculateOrders,
      ),
      _AdminHomeShortcut(
        title: l10n.adminOpenOrderTitle,
        routeName: AppRoutes.adminCalculate,
      ),
      _AdminHomeShortcut(
        title: l10n.adminWorkMapNavTitle,
        routeName: AppRoutes.adminProductionMapOrders,
      ),
    ].where((s) => AppRouter.canOpenRoute(s.routeName)).toList(growable: false);
    final scheme = Theme.of(context).colorScheme;
    return M3SegmentSpacedColumn(
      padding: const EdgeInsets.symmetric(
        horizontal: _adminHomePanelCardGap,
      ),
      children: [
        for (var i = 0; i < shortcuts.length; i++)
          AdminSummaryCard(
            slot: _slotFor(i, shortcuts.length),
            cornerRadius: (i == 0 || i == shortcuts.length - 1)
                ? M3SegmentedListGeometry.cornerLarge
                : M3SegmentedListGeometry.cornerMiddle,
            backgroundColor: scheme.surfaceContainerLowest,
            title: shortcuts[i].title,
            value: '',
            onTap: () => onOpenRoute(shortcuts[i].routeName),
            elevation: 4,
          ),
      ],
    );
  }
}
