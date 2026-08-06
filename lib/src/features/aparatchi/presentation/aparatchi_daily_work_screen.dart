import 'package:flutter/material.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/print_service.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/logic/production_map_pechat_rules.dart';
import '../../admin/presentation/progress_printer_picker.dart';
import '../../admin/presentation/widgets/admin_drawer_navigation.dart';
import 'widgets/aparatchi_dock.dart';
import 'widgets/aparatchi_navigation_drawer.dart';

typedef AparatchiDailyWorkHistoryLoader = Future<List<AdminProgressBatch>>
    Function();

DateTime _dailyWorkDateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime _dailyWorkUnixDateTime(int unixSeconds) {
  return DateTime.fromMillisecondsSinceEpoch(
    unixSeconds * 1000,
    isUtc: true,
  ).toLocal();
}

/// Returns true when the worker's batch was active during the selected day.
bool adminProgressBatchTouchesLocalDay(
  AdminProgressBatch batch,
  DateTime day,
) {
  final dayStart = _dailyWorkDateOnly(day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final startedAt = batch.startedAtUnix > 0
      ? _dailyWorkUnixDateTime(batch.startedAtUnix)
      : null;
  final completedAt = batch.completedAtUnix > 0
      ? _dailyWorkUnixDateTime(batch.completedAtUnix)
      : null;
  if (startedAt == null && completedAt == null) {
    return false;
  }
  final intervalStart = startedAt ?? completedAt!;
  final intervalEnd = completedAt ?? startedAt!;
  final start =
      intervalStart.isBefore(intervalEnd) ? intervalStart : intervalEnd;
  final end = intervalStart.isAfter(intervalEnd) ? intervalStart : intervalEnd;
  return start.isBefore(dayEnd) && !end.isBefore(dayStart);
}

List<AdminProgressBatch> adminProgressBatchesForLocalDay(
  Iterable<AdminProgressBatch> batches,
  DateTime day,
) {
  final result = batches
      .where((batch) => adminProgressBatchTouchesLocalDay(batch, day))
      .toList(growable: true);
  result.sort(
    (left, right) => _dailyWorkActivityUnix(right).compareTo(
      _dailyWorkActivityUnix(left),
    ),
  );
  return result;
}

int adminProgressBatchOrderCount(Iterable<AdminProgressBatch> batches) {
  return {
    for (final batch in batches)
      if (batch.orderId.trim().isNotEmpty) batch.orderId.trim(),
  }.length;
}

List<_DailyWorkOrderGroup> _dailyWorkOrderGroups(
  Iterable<AdminProgressBatch> batches,
) {
  final groups = <String, _DailyWorkOrderGroup>{};
  for (final batch in batches) {
    final orderId = batch.orderId.trim();
    final groupKey =
        orderId.isEmpty ? 'batch:${batch.batchId.trim()}' : orderId;
    final group = groups.putIfAbsent(
      groupKey,
      () => _DailyWorkOrderGroup(
        key: groupKey,
        orderId: orderId.isEmpty ? '—' : orderId,
      ),
    );
    group.batches.add(batch);
  }
  return groups.values.toList(growable: false);
}

class _DailyWorkOrderGroup {
  _DailyWorkOrderGroup({required this.key, required this.orderId});

  final String key;
  final String orderId;
  final List<AdminProgressBatch> batches = [];
}

int _dailyWorkActivityUnix(AdminProgressBatch batch) {
  if (batch.completedAtUnix > 0) {
    return batch.completedAtUnix;
  }
  return batch.startedAtUnix;
}

class AparatchiDailyWorkScreen extends StatefulWidget {
  const AparatchiDailyWorkScreen({
    super.key,
    this.historyLoader,
    this.initialDate,
  });

  final AparatchiDailyWorkHistoryLoader? historyLoader;
  final DateTime? initialDate;

  @override
  State<AparatchiDailyWorkScreen> createState() =>
      _AparatchiDailyWorkScreenState();
}

class _AparatchiDailyWorkScreenState extends State<AparatchiDailyWorkScreen> {
  late DateTime _selectedDate;
  late Future<List<AdminProgressBatch>> _future;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dailyWorkDateOnly(widget.initialDate ?? DateTime.now());
    _future = _loadHistory();
  }

  Future<List<AdminProgressBatch>> _loadHistory() {
    final loader = widget.historyLoader;
    if (loader != null) {
      return loader();
    }
    return MobileApi.instance.adminProgressQrHistory(limit: 200);
  }

  Future<void> _retry() async {
    final future = _loadHistory();
    setState(() => _future = future);
    await future;
  }

  Future<void> _chooseDate() async {
    final today = _dailyWorkDateOnly(DateTime.now());
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(today) ? today : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: 'Kunlik ish kunini tanlang',
      cancelText: 'Bekor qilish',
      confirmText: 'Tanlash',
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() => _selectedDate = _dailyWorkDateOnly(selected));
  }

  Future<void> _showWip(AdminProgressBatch batch) async {
    final payload = batch.qrPayload.trim();
    if (payload.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('WIP QR topilmadi'),
          content: const Text(
            'Bu WIP uchun qayta chop qilishga kerak bo‘ladigan QR payload '
            'serverdan kelmadi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Yopish'),
            ),
          ],
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RpsQrReprintSheet(
        title: 'WIP QR',
        payload: payload,
        itemName: _dailyWorkFirstNotEmpty([
          batch.labelItemName,
          batch.labelItemCode,
          'WIP',
        ]),
        previewKey: ValueKey('daily-work-wip-preview-${batch.batchId}'),
        reprintButtonKey: ValueKey('daily-work-wip-reprint-${batch.batchId}'),
        details: [
          if (batch.orderId.trim().isNotEmpty)
            RpsQrDetail('Order', batch.orderId.trim()),
          if (batch.batchId.trim().isNotEmpty)
            RpsQrDetail('WIP ID', batch.batchId.trim()),
          RpsQrDetail(
            'Miqdor',
            formatQuantityWithUnit(
              batch.producedQty,
              batch.uom,
              trimTrailingZeros: true,
            ),
          ),
          RpsQrDetail('Holat', _dailyWorkStatus(batch)),
          if (batch.startedAtUnix > 0)
            RpsQrDetail(
              'Boshlangan',
              formatUnixSecondsLocalDateTime(batch.startedAtUnix),
            ),
          if (batch.completedAtUnix > 0)
            RpsQrDetail(
              'Tugagan',
              formatUnixSecondsLocalDateTime(batch.completedAtUnix),
            ),
          if (batch.apparatus.trim().isNotEmpty)
            RpsQrDetail('Aparat', batch.apparatus.trim()),
          if (batch.currentLocation.trim().isNotEmpty)
            RpsQrDetail('Hozirgi joyi', batch.currentLocation.trim()),
        ],
        onReprint: () => _reprintWip(batch),
        errorMessage: (error) => error is MobileApiException
            ? error.message
            : _dailyWorkReprintError(error),
        successMessage: 'WIP QR qayta chop etildi',
      ),
    );
  }

  Future<String?> _reprintWip(AdminProgressBatch batch) async {
    final printer = await pickProgressPrinter(context);
    if (printer == null) {
      throw StateError('Printer tanlanmadi yoki printer ulanmagan');
    }
    final prepared = await MobileApi.instance.adminProgressQrReprint(
      qrPayload: batch.qrPayload,
      progressBatchId: batch.batchId,
      driverUrl: printer.driverUrl,
      printer: printer.printer,
      printMode: printer.printMode,
      printTransport: printer.transport,
    );
    if (!prepared.ok) {
      final status = prepared.printStatus.trim();
      throw StateError(
        status.isEmpty ? 'Server WIP QR kodini chop etmadi' : status,
      );
    }
    if (printer.transport.isLocal) {
      final printJob = prepared.printJob;
      if (printJob == null) {
        throw StateError('WIP QR uchun local print ma’lumoti kelmadi');
      }
      final result = await PrintService.printRps(
        printJob,
        printerProfile: printer.offlinePrinter,
        bluetoothPrinter: printer.bluetoothPrinter,
        transport: printer.transport,
      );
      if (!result.ok) {
        throw StateError('Printer WIP QR kodini chop etmadi');
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final profile = AppSession.instance.profile;
    final apparatusLabel = _dailyWorkApparatusLabel(
      profile?.assignedApparatus ?? const <String>[],
    );
    final workerName = _dailyWorkFirstNotEmpty([
      profile?.displayName ?? '',
      profile?.legalName ?? '',
      apparatusLabel,
    ]);
    return AppShell(
      title: 'Kunlik ish',
      subtitle: '$apparatusLabel tomonidan chiqarilgan WIP va orderlar',
      nativeTopBar: true,
      drawer: AparatchiNavigationDrawer(
        selectedIndex: 1,
        selectedRouteName: AppRoutes.apparatusDailyWork,
        onNavigate: (routeName) =>
            AdminDrawerNavigation.openRoute(context, routeName),
      ),
      bottom: const AparatchiDock(activeTab: null),
      contentPadding: EdgeInsets.zero,
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: _buildBody(context, workerName),
      ),
    );
  }

  Widget _buildBody(BuildContext context, String workerName) {
    return FutureBuilder<List<AdminProgressBatch>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return AppRetryState(
            onRetry: _retry,
            message: 'Kunlik ish ma’lumoti yuklanmadi',
          );
        }
        final allBatches = snapshot.data ?? const <AdminProgressBatch>[];
        // The history endpoint is already scoped to the authenticated worker.
        final batches = adminProgressBatchesForLocalDay(
          allBatches,
          _selectedDate,
        );
        return RefreshIndicator(
          onRefresh: _retry,
          child: ListView(
            physics: const TopRefreshScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              MediaQuery.viewPaddingOf(context).bottom + 120,
            ),
            children: [
              _DailyWorkSummary(
                date: _selectedDate,
                workerName: workerName,
                batches: batches,
                onChooseDate: _chooseDate,
              ),
              const SizedBox(height: 16),
              Text(
                'Chop etilgan WIPlar',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              if (batches.isEmpty)
                const _DailyWorkEmpty()
              else
                for (final group in _dailyWorkOrderGroups(batches))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _DailyWorkOrderGroupCard(
                      key: ValueKey('daily-work-order-group-${group.key}'),
                      group: group,
                      onLongPress: _showWip,
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _DailyWorkOrderGroupCard extends StatefulWidget {
  const _DailyWorkOrderGroupCard({
    super.key,
    required this.group,
    required this.onLongPress,
  });

  final _DailyWorkOrderGroup group;
  final ValueChanged<AdminProgressBatch> onLongPress;

  @override
  State<_DailyWorkOrderGroupCard> createState() =>
      _DailyWorkOrderGroupCardState();
}

class _DailyWorkOrderGroupCardState extends State<_DailyWorkOrderGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final group = widget.group;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('daily-work-order-header-${group.key}'),
                onTap: () => setState(() => _expanded = !_expanded),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 4, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.receipt_long_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              group.orderId,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          child: Text(
                            '${group.batches.length} ta WIP',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        children: [
                          for (var index = 0;
                              index < group.batches.length;
                              index++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _DailyWorkWipCard(
                                key: ValueKey(
                                  'daily-work-wip-card-${group.batches[index].batchId}',
                                ),
                                batch: group.batches[index],
                                index: index,
                                onLongPress: () =>
                                    widget.onLongPress(group.batches[index]),
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyWorkSummary extends StatelessWidget {
  const _DailyWorkSummary({
    required this.date,
    required this.workerName,
    required this.batches,
    required this.onChooseDate,
  });

  final DateTime date;
  final String workerName;
  final List<AdminProgressBatch> batches;
  final VoidCallback onChooseDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final processedCount = batches
        .where((batch) => _dailyWorkStatus(batch) == 'Ishlatilgan')
        .length;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 10, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Kunlik ish',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onChooseDate,
                  tooltip: 'Kun tanlash',
                  icon: const Icon(Icons.calendar_month_rounded),
                ),
              ],
            ),
            Text(
              '${_dailyWorkDateLabel(date)} • $workerName',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DailyWorkMetric(
                  label: 'Order',
                  value: '${adminProgressBatchOrderCount(batches)}',
                ),
                _DailyWorkMetric(
                  label: 'WIP',
                  value: '${batches.length}',
                ),
                _DailyWorkMetric(
                  label: 'Ishlatilgan',
                  value: '$processedCount',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyWorkMetric extends StatelessWidget {
  const _DailyWorkMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.onPrimaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$label: $value',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _DailyWorkWipCard extends StatefulWidget {
  const _DailyWorkWipCard({
    super.key,
    required this.batch,
    required this.index,
    required this.onLongPress,
  });

  final AdminProgressBatch batch;
  final int index;
  final VoidCallback onLongPress;

  @override
  State<_DailyWorkWipCard> createState() => _DailyWorkWipCardState();
}

class _DailyWorkWipCardState extends State<_DailyWorkWipCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final itemName = _dailyWorkFirstNotEmpty([
      widget.batch.labelItemName,
      widget.batch.labelItemCode,
      'WIP ${widget.index + 1}',
    ]);
    final current = _dailyWorkFirstNotEmpty([
      widget.batch.currentLocation,
      widget.batch.currentApparatus,
      widget.batch.apparatus,
    ]);
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        onLongPress: widget.onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.secondaryContainer,
                    foregroundColor: scheme.onSecondaryContainer,
                    child: Text('${widget.index + 1}'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _DailyWorkStatusChip(batch: widget.batch),
                  const SizedBox(width: 2),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Column(
                        key: const ValueKey('daily-work-expanded-details'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.batch.batchId.trim().isNotEmpty)
                            _DailyWorkInfoRow(
                              label: 'WIP ID',
                              value: widget.batch.batchId.trim(),
                            ),
                          _DailyWorkInfoRow(
                            label: 'Miqdor',
                            value: formatQuantityWithUnit(
                              widget.batch.producedQty,
                              widget.batch.uom,
                              trimTrailingZeros: true,
                            ),
                          ),
                          if (widget.batch.startedAtUnix > 0)
                            _DailyWorkInfoRow(
                              label: 'Boshlangan',
                              value: formatUnixSecondsLocalDateTime(
                                widget.batch.startedAtUnix,
                              ),
                            ),
                          if (widget.batch.completedAtUnix > 0)
                            _DailyWorkInfoRow(
                              label: 'Tugagan',
                              value: formatUnixSecondsLocalDateTime(
                                widget.batch.completedAtUnix,
                              ),
                            ),
                          _DailyWorkInfoRow(
                            label: 'Aparat',
                            value: _dailyWorkValue(widget.batch.apparatus),
                          ),
                          _DailyWorkInfoRow(
                            label: 'Hozirgi joyi',
                            value: current,
                          ),
                          if (widget.batch.nextApparatus.trim().isNotEmpty)
                            _DailyWorkInfoRow(
                              label: 'Keyingi aparat',
                              value: widget.batch.nextApparatus.trim(),
                            ),
                          if (widget.batch.description.trim().isNotEmpty)
                            _DailyWorkInfoRow(
                              label: 'Izoh',
                              value: widget.batch.description.trim(),
                            ),
                        ],
                      )
                    : _DailyWorkCompactDetails(batch: widget.batch),
              ),
              const SizedBox(height: 8),
              Text(
                _expanded
                    ? 'Yopish uchun bosing • QR uchun uzoq bosing'
                    : 'Batafsil uchun bosing • QR uchun uzoq bosing',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyWorkCompactDetails extends StatelessWidget {
  const _DailyWorkCompactDetails({required this.batch});

  final AdminProgressBatch batch;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DailyWorkCompactValue(
            label: 'WIP',
            value: _dailyWorkValue(batch.batchId),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _DailyWorkCompactValue(
            label: 'Miqdor',
            value: formatQuantityWithUnit(
              batch.producedQty,
              batch.uom,
              trimTrailingZeros: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _DailyWorkCompactValue extends StatelessWidget {
  const _DailyWorkCompactValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DailyWorkStatusChip extends StatelessWidget {
  const _DailyWorkStatusChip({required this.batch});

  final AdminProgressBatch batch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _dailyWorkStatus(batch);
    final background = switch (status) {
      'Ishlatilgan' => scheme.secondaryContainer,
      'Jarayonda' => scheme.tertiaryContainer,
      _ => scheme.primaryContainer,
    };
    final foreground = switch (status) {
      'Ishlatilgan' => scheme.onSecondaryContainer,
      'Jarayonda' => scheme.onTertiaryContainer,
      _ => scheme.onPrimaryContainer,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          status,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _DailyWorkInfoRow extends StatelessWidget {
  const _DailyWorkInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyWorkEmpty extends StatelessWidget {
  const _DailyWorkEmpty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 42,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            const Text(
              'Bu kunda WIP chiqarilmagan',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _dailyWorkStatus(AdminProgressBatch batch) {
  final flow = batch.statusDetail.flowStatus.trim().toLowerCase();
  final wipStatus = batch.wipStatus.trim().toLowerCase();
  if (flow == 'consumed_by_next_stage' ||
      flow == 'accepted_to_stock' ||
      wipStatus == 'processed' ||
      wipStatus == 'used' ||
      wipStatus == 'consumed') {
    return 'Ishlatilgan';
  }
  if (flow == 'in_progress' ||
      wipStatus == 'in_use' ||
      wipStatus == 'in_progress' ||
      batch.statusDetail.workStatus.trim().toLowerCase() == 'paused') {
    return 'Jarayonda';
  }
  return 'Kutmoqda';
}

String _dailyWorkFirstNotEmpty(Iterable<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '—';
}

String _dailyWorkApparatusLabel(Iterable<String> assignedApparatus) {
  if (assignedApparatus.any(productionMapIsPechatApparatus)) {
    return 'Pechatchi';
  }
  if (assignedApparatus.any(productionMapIsRezkaApparatus)) {
    return 'Rezka';
  }
  if (assignedApparatus.any(productionMapIsLaminatsiyaApparatus)) {
    return 'Laminatsiya';
  }
  for (final apparatus in assignedApparatus) {
    final label = productionMapWarehouseBaseTitle(apparatus);
    if (label.trim().isNotEmpty) {
      return label;
    }
  }
  return 'Aparatchi';
}

String _dailyWorkValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '—' : trimmed;
}

String _dailyWorkDateLabel(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}. '
      '${value.month.toString().padLeft(2, '0')}. ${value.year}';
}

String _dailyWorkReprintError(Object error) {
  final message = error.toString().replaceFirst('Exception: ', '').trim();
  return message.isEmpty ? 'WIP QR kodini qayta chop etib bo‘lmadi' : message;
}
