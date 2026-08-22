import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart' show AppRefreshIndicator;
import '../../shared/models/app_models.dart';
import '../logic/canonical_apparatus_display.dart';
import 'widgets/admin_dock.dart';
import 'widgets/admin_expandable_filter_chip.dart';
import 'widgets/admin_shell.dart';
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

  String title(AppLocalizations l10n) {
    return switch (this) {
      _WipBatchStatus.waiting => l10n.adminText('wip.status.waiting'),
      _WipBatchStatus.inUse => l10n.adminText('wip.status.in_use'),
      _WipBatchStatus.processed => l10n.adminText('wip.status.processed'),
    };
  }

  String emptyText(AppLocalizations l10n) {
    return switch (this) {
      _WipBatchStatus.waiting => l10n.adminText('wip.empty.waiting'),
      _WipBatchStatus.inUse => l10n.adminText('wip.empty.in_use'),
      _WipBatchStatus.processed => l10n.adminText('wip.empty.processed'),
    };
  }
}

class AdminWipBatchesScreen extends StatefulWidget {
  const AdminWipBatchesScreen({super.key});

  @override
  State<AdminWipBatchesScreen> createState() => _AdminWipBatchesScreenState();
}

class _AdminWipBatchesScreenState extends State<AdminWipBatchesScreen> {
  late Future<_WipBatchesData> _future;
  String _locationFilter = '';
  bool _locationMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WipBatchesData> _load([String? locationFilter]) async {
    final location = (locationFilter ?? _locationFilter).trim();
    final results = await Future.wait<Object>([
      MobileApi.instance.adminWipBatches(
        status: _WipBatchStatus.waiting.apiValue,
        limit: _wipFetchLimit,
      ),
      MobileApi.instance.adminApparatus(limit: 10000),
    ]);
    final allWaitingBatches = results[0] as List<AdminProgressBatch>;
    final apparatus = results[1] as List<AdminApparatus>;
    final verifiedWaitingBatches = filterWipBatchesForWaitingDisplay(
      allWaitingBatches,
      '',
    );
    final availableLocations = _locationOptions(verifiedWaitingBatches);
    final loadedBatches = location.isEmpty
        ? verifiedWaitingBatches
        : await MobileApi.instance.adminWipBatches(
            status: _WipBatchStatus.waiting.apiValue,
            currentLocation: location,
            limit: _wipFetchLimit,
          );
    final visibleBatches = filterWipBatchesForWaitingDisplay(
      loadedBatches,
      location,
    );
    return _WipBatchesData({
      _WipBatchStatus.waiting: visibleBatches,
    }, availableLocations: availableLocations, apparatusCatalog: apparatus);
  }

  Future<void> _reload() async {
    final nextFuture = _load();
    setState(() {
      _future = nextFuture;
    });
    await nextFuture;
  }

  void _setLocationFilter(String location) {
    final next = location.trim();
    if (_locationFilter == next) {
      setState(() => _locationMenuOpen = false);
      return;
    }
    final nextFuture = _load(next);
    setState(() {
      _locationFilter = next;
      _locationMenuOpen = false;
      _future = nextFuture;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    return AdminShell(
      title: context.l10n.adminText('wip.title'),
      selectedRouteName: AppRoutes.adminWipBatches,
      activeTab: AdminDockTab.home,
      bottomDockFadeStrength: null,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
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
                _WipLocationFilterBar(
                  selectedLocation: _locationFilter,
                  locations: data.availableLocations,
                  apparatusCatalog: data.apparatusCatalog,
                  expanded: _locationMenuOpen,
                  onToggle: () {
                    setState(() => _locationMenuOpen = !_locationMenuOpen);
                  },
                  onChanged: _setLocationFilter,
                ),
                Expanded(
                  child: _WipBatchTab(
                    status: _WipBatchStatus.waiting,
                    data: data,
                    bottomPadding: bottomPadding,
                    onRefresh: _reload,
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
  const _WipBatchesData(
    this.byStatus, {
    this.availableLocations = const [],
    this.apparatusCatalog = const [],
  });

  static const empty = _WipBatchesData({});

  final Map<_WipBatchStatus, List<AdminProgressBatch>> byStatus;
  final List<String> availableLocations;
  final List<AdminApparatus> apparatusCatalog;

  List<AdminProgressBatch> batches(_WipBatchStatus status) {
    return byStatus[status] ?? const [];
  }

  int count(_WipBatchStatus status) {
    return batches(status).length;
  }
}

class _WipLocationFilterBar extends StatelessWidget {
  const _WipLocationFilterBar({
    required this.selectedLocation,
    required this.locations,
    required this.apparatusCatalog,
    required this.expanded,
    required this.onToggle,
    required this.onChanged,
  });

  final String selectedLocation;
  final List<String> locations;
  final List<AdminApparatus> apparatusCatalog;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = selectedLocation.trim();
    return AdminExpandableFilterChip<String>(
      chipKey: const ValueKey('admin-wip-location-filter-chip'),
      label: context.l10n.adminText('wip.location'),
      emptyLabel: context.l10n.adminText('wip.all_locations'),
      icon: Icons.place_outlined,
      selectedValue: selected,
      expanded: expanded,
      onToggle: onToggle,
      onSelect: onChanged,
      optionKeyPrefix: 'admin-wip-location-option-chip',
      options: [
        AdminFilterChipOption(
          value: '',
          label: context.l10n.adminText('wip.all_locations'),
          key: ValueKey('admin-wip-location-option-chip-all'),
        ),
        for (final location in locations)
          AdminFilterChipOption(
            value: location,
            label: canonicalApparatusDisplayLabel(
              location,
              apparatusCatalog,
            ),
            key: ValueKey('admin-wip-location-option-chip-$location'),
          ),
      ],
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
    );
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
            _WipEmptyCard(text: status.emptyText(context.l10n))
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < batches.length; index++)
                  _WipBatchTile(
                    batch: batches[index],
                    apparatusCatalog: data.apparatusCatalog,
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
        context.l10n.adminText('wip.intro'),
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
      backgroundColor: scheme.surfaceContainerLowest,
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
    required this.apparatusCatalog,
    required this.status,
    required this.slot,
  });

  final AdminProgressBatch batch;
  final List<AdminApparatus> apparatusCatalog;
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
    final productTitle = _headlineForBatch(rawTitle, context.l10n);
    final currentPlaceId = _firstNotEmpty([
      canonicalWaitingLocation(batch),
      batch.currentLocation,
      batch.currentApparatus,
      batch.apparatus,
    ]);
    final currentPlace = canonicalApparatusDisplayLabel(
      currentPlaceId,
      apparatusCatalog,
    );
    final sourceApparatus = _valueOrDash(
      canonicalApparatusDisplayLabel(batch.apparatus, apparatusCatalog),
    );
    final finalFreeWip = isFinalFreeWip(batch);
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
      apparatusCatalog: apparatusCatalog,
      l10n: context.l10n,
    );
    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      backgroundColor: scheme.surfaceContainerLowest,
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
                        context.l10n.adminText(
                          'wip.order',
                          values: {'order': batch.orderId},
                        ),
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
              label: context.l10n.adminText('wip.quantity'),
              value: formatQuantityWithUnit(
                batch.producedQty,
                batch.uom,
                trimTrailingZeros: true,
              ),
            ),
            _WipInfoLine(
              icon: Icons.output_rounded,
              label: context.l10n.adminText('wip.source'),
              value: sourceApparatus,
            ),
            _WipInfoLine(
              icon: Icons.place_outlined,
              label: context.l10n.adminText('wip.current_location'),
              value: _valueOrDash(currentPlace),
            ),
            if (finalFreeWip)
              _WipInfoLine(
                icon: Icons.inventory_2_outlined,
                label: context.l10n.adminText('wip.product_status'),
                value: context.l10n.adminText('wip.free'),
              )
            else ...[
              _WipInfoLine(
                icon: Icons.call_split_rounded,
                label: context.l10n.adminText('wip.next_apparatus'),
                value: _nextApparatusText(
                  batch.nextApparatus,
                  apparatusCatalog,
                  context.l10n,
                ),
              ),
              _WipInfoLine(
                icon: Icons.alt_route_rounded,
                label: context.l10n.adminText('wip.next_step'),
                value: _nextStepText(
                  batch.nextApparatus,
                  apparatusCatalog,
                  context.l10n,
                ),
              ),
            ],
            _WipInfoLine(
              icon: Icons.badge_outlined,
              label: context.l10n.adminText('wip.worker'),
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
          status.title(context.l10n),
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

List<String> _locationOptions(Iterable<AdminProgressBatch> batches) {
  final values = <String>{};
  for (final batch in batches) {
    final location = canonicalWaitingLocation(batch);
    if (location.isNotEmpty) {
      values.add(location);
    }
  }
  final sorted = values.toList(growable: false);
  sorted
      .sort((left, right) => left.toLowerCase().compareTo(right.toLowerCase()));
  return sorted;
}

List<AdminProgressBatch> filterWipBatchesForWaitingDisplay(
  List<AdminProgressBatch> batches,
  String location,
) {
  final normalized = location.trim();
  return [
    for (final batch in batches)
      if (batch.wipStatus.trim() == _WipBatchStatus.waiting.apiValue &&
          (normalized.isEmpty || canonicalWaitingLocation(batch) == normalized))
        batch,
  ];
}

bool isFinalFreeWip(AdminProgressBatch batch) {
  final flowStatus = batch.statusDetail.flowStatus.trim();
  if (flowStatus == 'free_wip' || flowStatus == 'finished_pending_acceptance') {
    return true;
  }
  return adminProgressBatchIsFinishedGoodsOutput(
        action: batch.action,
        status: batch.status,
        nextApparatus: batch.nextApparatus,
      ) &&
      batch.wipStatus.trim() == _WipBatchStatus.waiting.apiValue &&
      batch.nextApparatus.trim().isEmpty;
}

String canonicalWaitingLocation(AdminProgressBatch batch) {
  final location = batch.currentLocation.trim();
  if (location.isNotEmpty) {
    return location;
  }
  final apparatus = batch.currentApparatus.trim().isNotEmpty
      ? batch.currentApparatus.trim()
      : batch.apparatus.trim();
  return apparatus;
}

String _valueOrDash(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

String _headlineForBatch(String rawTitle, AppLocalizations l10n) {
  final trimmed = rawTitle.trim();
  if (trimmed.isEmpty) {
    return l10n.adminText('wip.product_fallback');
  }
  final shortTitle = trimmed.split(',').first.trim();
  if (shortTitle.isEmpty) {
    return l10n.adminText('wip.product_fallback');
  }
  if (shortTitle.toLowerCase().contains('mahsulot')) {
    return shortTitle;
  }
  return l10n.adminText(
    'wip.product_suffix',
    values: {'title': shortTitle},
  );
}

String _nextApparatusText(
  String nextApparatus,
  List<AdminApparatus> apparatusCatalog,
  AppLocalizations l10n,
) {
  final trimmed = nextApparatus.trim();
  if (trimmed.isNotEmpty) {
    return canonicalApparatusDisplayLabel(trimmed, apparatusCatalog);
  }
  return l10n.adminText('wip.unspecified');
}

String _nextStepText(
  String nextApparatus,
  List<AdminApparatus> apparatusCatalog,
  AppLocalizations l10n,
) {
  final trimmed = nextApparatus.trim();
  if (trimmed.isNotEmpty) {
    return canonicalApparatusDisplayLabel(trimmed, apparatusCatalog);
  }
  return l10n.adminText('wip.unspecified');
}

String _buildFriendlySummary({
  required AdminProgressBatch batch,
  required _WipBatchStatus status,
  required String sourceApparatus,
  required String currentPlace,
  required String worker,
  required List<AdminApparatus> apparatusCatalog,
  required AppLocalizations l10n,
}) {
  final product = _headlineForBatch(batch.labelItemName, l10n);
  final quantity = formatQuantityWithUnit(
    batch.producedQty,
    batch.uom,
    trimTrailingZeros: true,
  );
  final sourceText = sourceApparatus == '-'
      ? (l10n.locale.languageCode == 'en'
          ? 'an unknown machine'
          : 'noma’lum aparatdan')
      : l10n.locale.languageCode == 'en'
          ? sourceApparatus
          : '${sourceApparatus}dan';
  final waitingPlace = currentPlace == '-'
      ? (l10n.locale.languageCode == 'en'
          ? 'an unknown location'
          : 'noma’lum joyda')
      : l10n.locale.languageCode == 'en'
          ? 'at $currentPlace'
          : '$currentPlace yonida';
  final inUsePlace = currentPlace == '-'
      ? (l10n.locale.languageCode == 'en'
          ? 'an unknown location'
          : 'noma’lum joyda')
      : l10n.locale.languageCode == 'en'
          ? currentPlace
          : '$currentPlace ishlayapti';
  final processedPlace = currentPlace == '-'
      ? (l10n.locale.languageCode == 'en'
          ? 'an unknown location'
          : 'noma’lum joyda')
      : l10n.locale.languageCode == 'en'
          ? currentPlace
          : '${currentPlace}da';
  final workerText = worker == '-'
      ? ''
      : l10n.locale.languageCode == 'en'
          ? ' Worker: $worker.'
          : ' Ishchi: $worker.';
  if (isFinalFreeWip(batch)) {
    return l10n.adminText(
      'wip.summary.free',
      values: {
        'product': product,
        'source': sourceText,
        'place': waitingPlace,
        'quantity': quantity,
        'worker': workerText,
      },
    );
  }
  return switch (status) {
    _WipBatchStatus.waiting => l10n.adminText(
        'wip.summary.waiting',
        values: {
          'product': product,
          'source': sourceText,
          'place': waitingPlace,
          'step': _nextStepText(
            batch.nextApparatus,
            apparatusCatalog,
            l10n,
          ),
          'apparatus': _nextApparatusText(
            batch.nextApparatus,
            apparatusCatalog,
            l10n,
          ),
          'quantity': quantity,
          'worker': workerText,
        },
      ),
    _WipBatchStatus.inUse => l10n.adminText(
        'wip.summary.in_use',
        values: {
          'product': product,
          'place': inUsePlace,
          'step': _nextStepText(
            batch.nextApparatus,
            apparatusCatalog,
            l10n,
          ),
          'apparatus': _nextApparatusText(
            batch.nextApparatus,
            apparatusCatalog,
            l10n,
          ),
          'quantity': quantity,
          'worker': workerText,
        },
      ),
    _WipBatchStatus.processed => l10n.adminText(
        'wip.summary.processed',
        values: {
          'product': product,
          'source': sourceApparatus,
          'place': processedPlace,
          'step': _nextStepText(
            batch.nextApparatus,
            apparatusCatalog,
            l10n,
          ),
          'quantity': quantity,
          'worker': workerText,
        },
      ),
  };
}
