import '../../../app/app_router.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/hub/refresh_hub.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../../core/widgets/display/motion_widgets.dart';
import '../../../core/widgets/lists/lists.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../shared/models/app_models.dart';
import '../state/supplier_store.dart';
import 'widgets/supplier_dock.dart';
import 'widgets/supplier_navigation_drawer.dart';
import 'package:flutter/material.dart';

class SupplierHomeScreen extends StatefulWidget {
  const SupplierHomeScreen({super.key});

  @override
  State<SupplierHomeScreen> createState() => _SupplierHomeScreenState();
}

class _SupplierHomeScreenState extends State<SupplierHomeScreen>
    with WidgetsBindingObserver {
  int _refreshVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SupplierStore.instance.bootstrapSummary();
    SupplierStore.instance.bootstrapHistory();
    RefreshHub.instance.addListener(_handlePushRefresh);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RefreshHub.instance.removeListener(_handlePushRefresh);
    super.dispose();
  }

  void _handlePushRefresh() {
    if (!mounted || RefreshHub.instance.topic != 'supplier') {
      return;
    }
    if (_refreshVersion == RefreshHub.instance.version) {
      return;
    }
    _refreshVersion = RefreshHub.instance.version;
    _reload();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _reload();
    }
  }

  Future<void> _reload() async {
    await SupplierStore.instance.refreshAll();
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return AppShell(
      title: context.l10n.supplierRoleName,
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: SupplierNavigationDrawer(
        selectedIndex: 0,
        onNavigate: _openDrawerRoute,
      ),
      preferNativeTitle: true,
      bottom: const SupplierDock(activeTab: SupplierDockTab.home),
      contentPadding: EdgeInsets.zero,
      child: AnimatedBuilder(
        animation: SupplierStore.instance,
        builder: (context, _) {
          final store = SupplierStore.instance;
          if (store.loadingHistory && !store.loadedHistory) {
            return const Center(child: AppLoadingIndicator());
          }
          if (store.historyError != null && !store.loadedHistory) {
            return AppRefreshIndicator(
              onRefresh: _reload,
              allowRefreshOnShortContent: true,
              child: ListView(
                physics: const TopRefreshScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [AppRetryState(onRetry: _reload)],
              ),
            );
          }
          final current = store.summary;
          final pendingItems = store.historyItems
              .where(
                (item) =>
                    item.status == DispatchStatus.pending ||
                    item.status == DispatchStatus.draft,
              )
              .toList();

          return AppRefreshIndicator(
            onRefresh: _reload,
            allowRefreshOnShortContent: true,
            child: ListView(
              physics: const TopRefreshScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPadding),
              children: [
                const SizedBox(height: 4),
                _SupplierSummaryCard(summary: current),
                if (pendingItems.isNotEmpty) const SizedBox(height: 16),
                if (pendingItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _SupplierPendingSection(items: pendingItems),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SupplierSummaryCard extends StatelessWidget {
  const _SupplierSummaryCard({required this.summary});

  final SupplierHomeSummary summary;

  @override
  Widget build(BuildContext context) {
    return SmoothAppear(
      child: M3SegmentSpacedColumn(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        children: [
          AppSummarySegmentCard(
            slot: M3SegmentVerticalSlot.top,
            cornerRadius: M3SegmentedListGeometry.cornerLarge,
            label: context.l10n.pendingStatus,
            value: summary.pendingCount.toString(),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.supplierStatusBreakdown,
              arguments: SupplierStatusKind.pending,
            ),
          ),
          AppSummarySegmentCard(
            slot: M3SegmentVerticalSlot.middle,
            cornerRadius: M3SegmentedListGeometry.cornerMiddle,
            label: context.l10n.submittedStatus,
            value: summary.submittedCount.toString(),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.supplierStatusBreakdown,
              arguments: SupplierStatusKind.submitted,
            ),
          ),
          AppSummarySegmentCard(
            slot: M3SegmentVerticalSlot.bottom,
            cornerRadius: M3SegmentedListGeometry.cornerLarge,
            label: context.l10n.returnedStatus,
            value: summary.returnedCount.toString(),
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.supplierStatusBreakdown,
              arguments: SupplierStatusKind.returned,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierPendingSection extends StatelessWidget {
  const _SupplierPendingSection({required this.items});

  final List<DispatchRecord> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return SmoothAppear(
      delay: const Duration(milliseconds: 90),
      offset: const Offset(0, 18),
      child: Card.filled(
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  context.l10n.inProgressItemsTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 14),
              Card.filled(
                margin: EdgeInsets.zero,
                color:
                    isDark ? const Color(0xFF2A2931) : scheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    for (int index = 0; index < items.length; index++) ...[
                      _SupplierPendingRow(
                        record: items[index],
                        isFirst: index == 0,
                        isLast: index == items.length - 1,
                      ),
                      if (index != items.length - 1)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: scheme.outlineVariant.withValues(alpha: 0.55),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierPendingRow extends StatelessWidget {
  const _SupplierPendingRow({
    required this.record,
    required this.isFirst,
    required this.isLast,
  });

  final DispatchRecord record;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableScale(
      onTap: () => Navigator.of(
        context,
      ).pushNamed(AppRoutes.notificationDetail, arguments: record.id),
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(isFirst ? 24 : 0),
              topRight: Radius.circular(isFirst ? 24 : 0),
              bottomLeft: Radius.circular(isLast ? 24 : 0),
              bottomRight: Radius.circular(isLast ? 24 : 0),
            ),
            onTap: () => Navigator.of(
              context,
            ).pushNamed(AppRoutes.notificationDetail, arguments: record.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          record.itemCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${record.sentQty.toStringAsFixed(0)} ${record.uom}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        record.createdLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
