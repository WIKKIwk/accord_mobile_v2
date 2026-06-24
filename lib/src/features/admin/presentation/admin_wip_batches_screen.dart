import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_drawer_navigation.dart';
import 'widgets/admin_navigation_drawer.dart';
import 'widgets/admin_surface_tab_bar.dart';
import 'package:flutter/material.dart';

const double _wipPanelGap = 4;
const double _wipPanelTopGap = 8;
const int _wipFetchLimit = 250;

enum _WipBatchStatus { waiting, inUse, processed }

extension _WipBatchStatusX on _WipBatchStatus {
  String get apiValue {
    return switch (this) {
      _WipBatchStatus.waiting => 'waiting',
      _WipBatchStatus.inUse => 'in_use',
      _WipBatchStatus.processed => 'processed',
    };
  }

  String get title {
    return switch (this) {
      _WipBatchStatus.waiting => 'Kutmoqda',
      _WipBatchStatus.inUse => 'Ishda',
      _WipBatchStatus.processed => 'Tugadi',
    };
  }

  String get emptyText {
    return switch (this) {
      _WipBatchStatus.waiting => 'Kutayotgan mahsulot yo‘q',
      _WipBatchStatus.inUse => 'Ishlayotgan mahsulot yo‘q',
      _WipBatchStatus.processed => 'Tugagan mahsulot yo‘q',
    };
  }
}

class AdminWipBatchesScreen extends StatefulWidget {
  const AdminWipBatchesScreen({super.key});

  @override
  State<AdminWipBatchesScreen> createState() => _AdminWipBatchesScreenState();
}

class _AdminWipBatchesScreenState extends State<AdminWipBatchesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Future<_WipBatchesData> _future;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _WipBatchStatus.values.length,
      vsync: this,
    );
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_WipBatchesData> _load() async {
    final results = await Future.wait([
      for (final status in _WipBatchStatus.values)
        MobileApi.instance.adminWipBatches(
          status: status.apiValue,
          limit: _wipFetchLimit,
        ),
    ]);
    return _WipBatchesData({
      for (var i = 0; i < _WipBatchStatus.values.length; i++)
        _WipBatchStatus.values[i]: results[i],
    });
  }

  Future<void> _reload() async {
    final nextFuture = _load();
    setState(() {
      _future = nextFuture;
    });
    await nextFuture;
  }

  void _openDrawerRoute(String routeName) {
    if (routeName == AppRoutes.adminWipBatches) {
      Navigator.of(context).pop();
      return;
    }
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return AppShell(
      drawer: AdminNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.adminWipBatches,
        onNavigate: _openDrawerRoute,
      ),
      title: 'Oraliq mahsulotlar',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      bottom: const AdminDock(activeTab: AdminDockTab.home),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: FutureBuilder<_WipBatchesData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData) {
              return const Center(child: AppLoadingIndicator());
            }
            if (snapshot.hasError) {
              return AppRetryState(onRetry: _reload);
            }
            final data = snapshot.data ?? _WipBatchesData.empty;
            return Column(
              children: [
                AdminSurfaceTabBar(
                  controller: _tabController,
                  tabs: [
                    for (final status in _WipBatchStatus.values)
                      Tab(
                        height: 38,
                        text: '${status.title} ${data.count(status)}',
                      ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      for (final status in _WipBatchStatus.values)
                        _WipBatchTab(
                          status: status,
                          data: data,
                          bottomPadding: bottomPadding,
                          onRefresh: _reload,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WipBatchesData {
  const _WipBatchesData(this.byStatus);

  static const empty = _WipBatchesData({});

  final Map<_WipBatchStatus, List<AdminProgressBatch>> byStatus;

  List<AdminProgressBatch> batches(_WipBatchStatus status) {
    return byStatus[status] ?? const [];
  }

  int count(_WipBatchStatus status) {
    return batches(status).length;
  }
}

class _WipBatchTab extends StatelessWidget {
  const _WipBatchTab({
    required this.status,
    required this.data,
    required this.bottomPadding,
    required this.onRefresh,
  });

  final _WipBatchStatus status;
  final _WipBatchesData data;
  final double bottomPadding;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final batches = data.batches(status);
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      allowRefreshOnShortContent: true,
      child: ListView(
        physics: const TopRefreshScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          _wipPanelGap,
          _wipPanelTopGap,
          _wipPanelGap,
          bottomPadding,
        ),
        children: [
          const _WipIntroText(),
          const SizedBox(height: 10),
          if (batches.isEmpty)
            _WipEmptyCard(text: status.emptyText)
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < batches.length; index++)
                  _WipBatchTile(
                    batch: batches[index],
                    status: status,
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      batches.length,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _WipIntroText extends StatelessWidget {
  const _WipIntroText();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Bu yerda mahsulot qaysi aparatdan chiqqani, hozir qayerda turgani '
        'va keyingi bosqichga o‘tgan-o‘tmagani ko‘rinadi.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.3,
            ),
      ),
    );
  }
}

class _WipEmptyCard extends StatelessWidget {
  const _WipEmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return M3SegmentFilledSurface(
      slot: M3SegmentVerticalSlot.top,
      cornerRadius: M3SegmentedListGeometry.cornerLarge,
      backgroundColor: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _WipBatchTile extends StatelessWidget {
  const _WipBatchTile({
    required this.batch,
    required this.status,
    required this.slot,
  });

  final AdminProgressBatch batch;
  final _WipBatchStatus status;
  final M3SegmentVerticalSlot slot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rawTitle = _firstNotEmpty([
      batch.labelItemName,
      batch.labelItemCode,
      batch.orderId,
    ]);
    final productTitle = _headlineForBatch(rawTitle);
    final currentPlace = _firstNotEmpty([
      batch.currentLocation,
      batch.currentApparatus,
      batch.apparatus,
    ]);
    final sourceApparatus = _valueOrDash(batch.apparatus);
    final worker = _firstNotEmpty([
      batch.workerDisplayName,
      batch.executorName,
      batch.workerRef,
    ]);
    final summary = _buildFriendlySummary(
      batch: batch,
      status: status,
      sourceApparatus: sourceApparatus,
      currentPlace: currentPlace,
      worker: worker,
    );
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      backgroundColor: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Zakaz: ${batch.orderId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _WipStatusPill(status: status),
              ],
            ),
            const SizedBox(height: 12),
            _WipInfoLine(
              icon: Icons.scale_outlined,
              label: 'Miqdor',
              value: formatQuantityWithUnit(
                batch.producedQty,
                batch.uom,
                trimTrailingZeros: true,
              ),
            ),
            _WipInfoLine(
              icon: Icons.output_rounded,
              label: 'Qayerdan chiqdi',
              value: sourceApparatus,
            ),
            _WipInfoLine(
              icon: Icons.place_outlined,
              label: 'Hozir qayerda',
              value: _valueOrDash(currentPlace),
            ),
            _WipInfoLine(
              icon: Icons.call_split_rounded,
              label: 'Keyingi aparat',
              value: _nextApparatusText(batch.nextApparatus, status),
            ),
            _WipInfoLine(
              icon: Icons.alt_route_rounded,
              label: 'Keyingi bosqich',
              value: _nextStepText(batch.nextApparatus, status),
            ),
            _WipInfoLine(
              icon: Icons.badge_outlined,
              label: 'Ishchi',
              value: _valueOrDash(worker),
            ),
            const SizedBox(height: 8),
            Text(
              summary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (batch.qrPayload.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                batch.qrPayload.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WipStatusPill extends StatelessWidget {
  const _WipStatusPill({required this.status});

  final _WipBatchStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color background = switch (status) {
      _WipBatchStatus.waiting => scheme.tertiaryContainer,
      _WipBatchStatus.inUse => scheme.primaryContainer,
      _WipBatchStatus.processed => scheme.secondaryContainer,
    };
    final Color foreground = switch (status) {
      _WipBatchStatus.waiting => scheme.onTertiaryContainer,
      _WipBatchStatus.inUse => scheme.onPrimaryContainer,
      _WipBatchStatus.processed => scheme.onSecondaryContainer,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          status.title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _WipInfoLine extends StatelessWidget {
  const _WipInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _firstNotEmpty(List<String> values) {
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return '-';
}

String _valueOrDash(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

String _headlineForBatch(String rawTitle) {
  final trimmed = rawTitle.trim();
  if (trimmed.isEmpty) {
    return 'Oraliq mahsulot';
  }
  final shortTitle = trimmed.split(',').first.trim();
  if (shortTitle.isEmpty) {
    return 'Oraliq mahsulot';
  }
  if (shortTitle.toLowerCase().contains('mahsulot')) {
    return shortTitle;
  }
  return '$shortTitle mahsuloti';
}

String _nextApparatusText(String nextApparatus, _WipBatchStatus status) {
  final trimmed = nextApparatus.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  return switch (status) {
    _WipBatchStatus.waiting => 'Aniqlanmagan',
    _WipBatchStatus.inUse => 'Aniqlanmagan',
    _WipBatchStatus.processed => 'Ombor',
  };
}

String _nextStepText(String nextApparatus, _WipBatchStatus status) {
  final trimmed = nextApparatus.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  return switch (status) {
    _WipBatchStatus.waiting => 'Keyingi aparat topilmadi',
    _WipBatchStatus.inUse => 'Keyingi aparat topilmadi',
    _WipBatchStatus.processed => 'Omborga ketadi',
  };
}

String _buildFriendlySummary({
  required AdminProgressBatch batch,
  required _WipBatchStatus status,
  required String sourceApparatus,
  required String currentPlace,
  required String worker,
}) {
  final product = _headlineForBatch(batch.labelItemName);
  final quantity = formatQuantityWithUnit(
    batch.producedQty,
    batch.uom,
    trimTrailingZeros: true,
  );
  final sourceText =
      sourceApparatus == '-' ? 'noma’lum aparatdan' : '${sourceApparatus}dan';
  final waitingPlace =
      currentPlace == '-' ? 'noma’lum joyda' : '$currentPlace yonida';
  final inUsePlace =
      currentPlace == '-' ? 'noma’lum joyda' : '$currentPlace ishlayapti';
  final processedPlace =
      currentPlace == '-' ? 'noma’lum joyda' : '${currentPlace}da';
  final workerText = worker == '-' ? '' : ' Ishchi: $worker.';
  return switch (status) {
    _WipBatchStatus.waiting =>
      '$product $sourceText chiqdi. Hozir $waitingPlace turibdi. '
          'Keyingi bosqich: ${_nextStepText(batch.nextApparatus, status)}. '
          'Keyingi aparat: ${_nextApparatusText(batch.nextApparatus, status)}. '
          'Miqdor: $quantity.$workerText',
    _WipBatchStatus.inUse => '$product hozir ishlanmoqda. Hozir $inUsePlace. '
        'Keyingi bosqich: ${_nextStepText(batch.nextApparatus, status)}. '
        'Keyingi aparat: ${_nextApparatusText(batch.nextApparatus, status)}. '
        'Miqdor: $quantity.$workerText',
    _WipBatchStatus.processed =>
      '$product tugagan. Qayerdan chiqdi: $sourceApparatus. '
          'Hozir: $processedPlace. Keyingi bosqich: ${_nextStepText(batch.nextApparatus, status)}. '
          'Miqdor: $quantity.$workerText',
  };
}
