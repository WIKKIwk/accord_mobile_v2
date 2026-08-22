import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/formatters/date_time_formatters.dart';
import '../../../core/formatters/quantity_formatters.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/print_service.dart';
import '../../../core/session/state/app_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/progress_printer_picker.dart';
import '../../admin/presentation/widgets/admin_drawer_navigation.dart';
import '../../shared/models/app_models.dart';
import 'widgets/aparatchi_dock.dart';
import 'widgets/aparatchi_navigation_drawer.dart';

typedef AparatchiDailyWorkHistoryLoader = Future<List<AdminProgressBatch>>
    Function();
typedef AparatchiDailyWorkApparatusLoader = Future<List<AdminApparatus>>
    Function();
typedef AparatchiDailyWorkCorrectionSaver = Future<AdminProgressBatch> Function(
  AdminProgressBatchCorrectionInput input,
);

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
    this.apparatusLoader,
    this.correctionSaver,
    this.initialDate,
  });

  final AparatchiDailyWorkHistoryLoader? historyLoader;
  final AparatchiDailyWorkApparatusLoader? apparatusLoader;
  final AparatchiDailyWorkCorrectionSaver? correctionSaver;
  final DateTime? initialDate;

  @override
  State<AparatchiDailyWorkScreen> createState() =>
      _AparatchiDailyWorkScreenState();
}

class _AparatchiDailyWorkScreenState extends State<AparatchiDailyWorkScreen> {
  late DateTime _selectedDate;
  late Future<List<AdminProgressBatch>> _future;
  final Map<String, AdminProgressBatch> _correctedBatches = {};
  final Set<String> _correctingBatchIds = {};
  List<AdminApparatus> _apparatus = const [];

  @override
  void initState() {
    super.initState();
    _selectedDate = _dailyWorkDateOnly(widget.initialDate ?? DateTime.now());
    _future = _loadHistory();
    unawaited(_loadApparatus());
  }

  Future<void> _loadApparatus() async {
    try {
      final loader = widget.apparatusLoader;
      final apparatus = loader == null
          ? await MobileApi.instance.adminApparatus(limit: 300)
          : await loader();
      if (mounted) setState(() => _apparatus = apparatus);
    } catch (_) {
      // Daily history remains usable; unresolved IDs are never used as names.
    }
  }

  AdminApparatus? _canonicalApparatus(String apparatusId) {
    for (final apparatus in _apparatus) {
      if (apparatus.id.trim() == apparatusId.trim()) return apparatus;
    }
    return null;
  }

  String _apparatusName(String apparatusId) =>
      _canonicalApparatus(apparatusId)?.name.trim() ?? '';

  String _apparatusOrLocationName(String value) {
    final canonicalName = _apparatusName(value);
    return canonicalName.isEmpty ? _dailyWorkValue(value) : canonicalName;
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
      helpText: context.l10n.productionText('worker.daily.choose_date.title'),
      cancelText: context.l10n.productionText('worker.action.cancel'),
      confirmText: context.l10n.productionText('worker.action.select'),
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
          title: Text(
            context.l10n.productionText('worker.daily.wip_qr_missing'),
          ),
          content: Text(
            context.l10n.productionText('worker.daily.wip_qr_missing.body'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.productionText('worker.action.close')),
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
      builder: (sheetContext) => RpsQrReprintSheet(
        title: context.l10n.productionText('worker.daily.wip_qr'),
        payload: payload,
        itemName: _dailyWorkFirstNotEmpty([
          batch.labelItemName,
          batch.labelItemCode,
          'WIP',
        ]),
        previewKey: ValueKey('daily-work-wip-preview-${batch.batchId}'),
        reprintButtonKey: ValueKey('daily-work-wip-reprint-${batch.batchId}'),
        editButtonKey: ValueKey('daily-work-wip-sheet-edit-${batch.batchId}'),
        details: [
          if (batch.orderId.trim().isNotEmpty)
            RpsQrDetail(
              context.l10n.productionText('worker.daily.order'),
              batch.orderId.trim(),
            ),
          if (batch.batchId.trim().isNotEmpty)
            RpsQrDetail(
              context.l10n.productionText('worker.wip.info.id'),
              batch.batchId.trim(),
            ),
          RpsQrDetail(
            context.l10n.productionText('worker.wip.info.quantity'),
            formatQuantityWithUnit(
              batch.producedQty,
              batch.uom,
              trimTrailingZeros: true,
            ),
          ),
          RpsQrDetail(
            context.l10n.productionText('worker.daily.status'),
            _dailyWorkStatusLabel(context, batch),
          ),
          if (batch.startedAtUnix > 0)
            RpsQrDetail(
              context.l10n.productionText('worker.wip.info.started'),
              formatUnixSecondsLocalDateTime(batch.startedAtUnix),
            ),
          if (batch.completedAtUnix > 0)
            RpsQrDetail(
              context.l10n.productionText('worker.wip.info.finished'),
              formatUnixSecondsLocalDateTime(batch.completedAtUnix),
            ),
          if (batch.apparatus.trim().isNotEmpty)
            RpsQrDetail(
              context.l10n.productionText('worker.detail.kind.machine'),
              _apparatusName(batch.apparatus).isEmpty
                  ? context.l10n.productionText('worker.daily.apparatus.worker')
                  : _apparatusName(batch.apparatus),
            ),
          if (batch.currentLocation.trim().isNotEmpty)
            RpsQrDetail(
              context.l10n.productionText('worker.wip.info.location'),
              _apparatusOrLocationName(batch.currentLocation),
            ),
        ],
        onReprint: () => _reprintWip(batch),
        onEdit: _canCorrectWip(batch) && !_isCorrecting(batch)
            ? () async {
                Navigator.of(sheetContext).pop();
                await Future<void>.delayed(Duration.zero);
                if (mounted) {
                  await _editWip(batch);
                }
              }
            : null,
        errorMessage: (error) => _dailyWorkReprintError(error, context.l10n),
        successMessage: context.l10n.productionText(
          'worker.daily.wip_qr.reprinted',
        ),
      ),
    );
  }

  bool _isCorrecting(AdminProgressBatch batch) =>
      _correctingBatchIds.contains(batch.batchId.trim());

  Future<void> _editWip(AdminProgressBatch batch) async {
    if (!_canCorrectWip(batch) || _isCorrecting(batch)) {
      return;
    }
    final draft = await showDialog<_DailyWorkWipCorrectionDraft>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _DailyWorkWipEditDialog(
        batch: batch,
        operation: _canonicalApparatus(batch.apparatus)?.operation.trim() ?? '',
      ),
    );
    if (!mounted || draft == null) {
      return;
    }
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const _DailyWorkCorrectionReasonDialog(),
    );
    if (!mounted || reason == null) {
      return;
    }
    final batchId = batch.batchId.trim();
    setState(() => _correctingBatchIds.add(batchId));
    try {
      final input = draft.toInput(batch: batch, reason: reason);
      final saver = widget.correctionSaver;
      final corrected = saver == null
          ? await MobileApi.instance.adminProgressBatchCorrect(input)
          : await saver(input);
      if (!mounted) {
        return;
      }
      setState(() => _correctedBatches[batchId] = corrected);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.productionText('worker.daily.wip_updated'),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = _dailyWorkCorrectionError(error, context.l10n);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _correctingBatchIds.remove(batchId));
      }
    }
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
      _apparatus,
      context.l10n,
    );
    final workerName = _dailyWorkFirstNotEmpty([
      profile?.displayName ?? '',
      profile?.legalName ?? '',
      apparatusLabel,
    ]);
    return AppShell(
      title: context.l10n.productionText('worker.daily'),
      subtitle: context.l10n.productionText(
        'worker.daily.subtitle',
        values: {'apparatus': apparatusLabel},
      ),
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
            message: context.l10n.productionText('worker.daily.load_failed'),
          );
        }
        final allBatches = [
          for (final batch in snapshot.data ?? const <AdminProgressBatch>[])
            _correctedBatches[batch.batchId.trim()] ?? batch,
        ];
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
                context.l10n.productionText('worker.daily.produced_wips'),
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
                      onEdit: _editWip,
                      isCorrecting: _isCorrecting,
                      apparatusLabel: _apparatusOrLocationName,
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
    required this.onEdit,
    required this.isCorrecting,
    required this.apparatusLabel,
  });

  final _DailyWorkOrderGroup group;
  final ValueChanged<AdminProgressBatch> onLongPress;
  final ValueChanged<AdminProgressBatch> onEdit;
  final bool Function(AdminProgressBatch) isCorrecting;
  final String Function(String value) apparatusLabel;

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
                              context.l10n.productionText('worker.daily.order'),
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
                            '${group.batches.length} ${context.l10n.productionText('worker.daily.wip')}',
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
                                onEdit: _canCorrectWip(group.batches[index]) &&
                                        !widget.isCorrecting(
                                          group.batches[index],
                                        )
                                    ? () => widget.onEdit(group.batches[index])
                                    : null,
                                apparatusLabel: widget.apparatusLabel,
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
                    context.l10n.productionText('worker.daily'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onChooseDate,
                  tooltip: context.l10n.productionText(
                    'worker.daily.choose_date',
                  ),
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
                  label: context.l10n.productionText('worker.daily.order'),
                  value: '${adminProgressBatchOrderCount(batches)}',
                ),
                _DailyWorkMetric(
                  label: 'WIP',
                  value: '${batches.length}',
                ),
                _DailyWorkMetric(
                  label: context.l10n.productionText('worker.daily.used'),
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
    required this.apparatusLabel,
    this.onEdit,
  });

  final AdminProgressBatch batch;
  final int index;
  final VoidCallback onLongPress;
  final String Function(String value) apparatusLabel;
  final VoidCallback? onEdit;

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
                          if (widget.onEdit != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton.filledTonal(
                                key: ValueKey(
                                  'daily-work-wip-edit-${widget.batch.batchId}',
                                ),
                                onPressed: widget.onEdit,
                                tooltip: context.l10n.productionText(
                                  'worker.daily.edit_wip',
                                ),
                                icon: const Icon(Icons.edit_rounded),
                              ),
                            ),
                          if (widget.batch.batchId.trim().isNotEmpty)
                            _DailyWorkInfoRow(
                              label: context.l10n.productionText(
                                'worker.wip.info.id',
                              ),
                              value: widget.batch.batchId.trim(),
                            ),
                          _DailyWorkInfoRow(
                            label: context.l10n.productionText(
                              'worker.wip.info.quantity',
                            ),
                            value: formatQuantityWithUnit(
                              widget.batch.producedQty,
                              widget.batch.uom,
                              trimTrailingZeros: true,
                            ),
                          ),
                          if (widget.batch.startedAtUnix > 0)
                            _DailyWorkInfoRow(
                              label: context.l10n.productionText(
                                'worker.wip.info.started',
                              ),
                              value: formatUnixSecondsLocalDateTime(
                                widget.batch.startedAtUnix,
                              ),
                            ),
                          if (widget.batch.completedAtUnix > 0)
                            _DailyWorkInfoRow(
                              label: context.l10n.productionText(
                                'worker.wip.info.finished',
                              ),
                              value: formatUnixSecondsLocalDateTime(
                                widget.batch.completedAtUnix,
                              ),
                            ),
                          _DailyWorkInfoRow(
                            label: context.l10n.productionText(
                              'worker.detail.kind.machine',
                            ),
                            value: widget.apparatusLabel(
                              widget.batch.apparatus,
                            ),
                          ),
                          _DailyWorkInfoRow(
                            label: context.l10n.productionText(
                              'worker.wip.info.location',
                            ),
                            value: widget.apparatusLabel(current),
                          ),
                          if (widget.batch.nextApparatus.trim().isNotEmpty)
                            _DailyWorkInfoRow(
                              label: context.l10n.productionText(
                                'worker.wip.info.next_machine',
                              ),
                              value: widget.apparatusLabel(
                                widget.batch.nextApparatus,
                              ),
                            ),
                          if (widget.batch.description.trim().isNotEmpty)
                            _DailyWorkInfoRow(
                              label: context.l10n.productionText(
                                'worker.wip.info.note',
                              ),
                              value: widget.batch.description.trim(),
                            ),
                        ],
                      )
                    : _DailyWorkCompactDetails(batch: widget.batch),
              ),
              const SizedBox(height: 8),
              Text(
                _expanded
                    ? context.l10n.productionText(
                        'worker.daily.card.collapse_hint',
                      )
                    : context.l10n.productionText(
                        'worker.daily.card.expand_hint',
                      ),
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
            label: context.l10n.productionText('worker.wip.info.quantity'),
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

class _DailyWorkWipCorrectionDraft {
  const _DailyWorkWipCorrectionDraft({
    required this.producedQty,
    required this.uom,
    required this.returnInkKg,
    required this.laminationPrintLeftoverRolls,
    required this.laminationFilmLeftoverRolls,
    required this.rezkaBosmaWaste,
    required this.rezkaLaminationWaste,
    required this.rezkaEdgeWaste,
    required this.totalWaste,
    required this.finishedGoodsKg,
    required this.bobinaKg,
    required this.finishedGoodsMeter,
    required this.diameter,
    required this.description,
  });

  final double producedQty;
  final String uom;
  final double? returnInkKg;
  final double? laminationPrintLeftoverRolls;
  final double? laminationFilmLeftoverRolls;
  final double? rezkaBosmaWaste;
  final double? rezkaLaminationWaste;
  final double? rezkaEdgeWaste;
  final double? totalWaste;
  final double? finishedGoodsKg;
  final double? bobinaKg;
  final double? finishedGoodsMeter;
  final double? diameter;
  final String description;

  AdminProgressBatchCorrectionInput toInput({
    required AdminProgressBatch batch,
    required String reason,
  }) {
    return AdminProgressBatchCorrectionInput(
      batchId: batch.batchId,
      expectedRevision: batch.revision,
      producedQty: producedQty,
      uom: uom,
      returnInkKg: returnInkKg,
      laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
      laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
      rezkaBosmaWaste: rezkaBosmaWaste,
      rezkaLaminationWaste: rezkaLaminationWaste,
      rezkaEdgeWaste: rezkaEdgeWaste,
      totalWaste: totalWaste,
      finishedGoodsKg: finishedGoodsKg,
      bobinaKg: bobinaKg,
      finishedGoodsMeter: finishedGoodsMeter,
      diameter: diameter,
      description: description,
      reason: reason,
    );
  }
}

class _DailyWorkWipEditDialog extends StatefulWidget {
  const _DailyWorkWipEditDialog({
    required this.batch,
    required this.operation,
  });

  final AdminProgressBatch batch;
  final String operation;

  @override
  State<_DailyWorkWipEditDialog> createState() =>
      _DailyWorkWipEditDialogState();
}

class _DailyWorkWipEditDialogState extends State<_DailyWorkWipEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _meter;
  late final TextEditingController _kg;
  late final TextEditingController _bobina;
  late final TextEditingController _diameter;
  late final TextEditingController _returnInk;
  late final TextEditingController _printLeftover;
  late final TextEditingController _filmLeftover;
  late final TextEditingController _rezkaBosmaWaste;
  late final TextEditingController _rezkaLaminationWaste;
  late final TextEditingController _rezkaEdgeWaste;
  late final TextEditingController _totalWaste;
  late final TextEditingController _description;

  AdminProgressBatch get _batch => widget.batch;
  bool get _isPechat => widget.operation.trim().toLowerCase() == 'print';
  bool get _isLaminatsiya =>
      widget.operation.trim().toLowerCase() == 'laminate';
  bool get _isRezka => widget.operation.trim().toLowerCase() == 'cut';
  bool get _showStandardWeights => _isPechat || _isLaminatsiya || _isRezka;
  bool get _showTotalWaste => _batch.totalWaste != null;
  bool get _showRezkaWaste =>
      _isRezka &&
      [
        _batch.totalWaste,
        _batch.rezkaBosmaWaste,
        _batch.rezkaLaminationWaste,
        _batch.rezkaEdgeWaste,
      ].any((value) => value != null);

  @override
  void initState() {
    super.initState();
    _meter = _numberController(_batch.finishedGoodsMeter ?? _batch.producedQty);
    _kg = _numberController(_batch.finishedGoodsKg);
    _bobina = _numberController(_batch.bobinaKg);
    _diameter = _numberController(_batch.diameter);
    _returnInk = _numberController(_batch.returnInkKg);
    _printLeftover = _numberController(_batch.laminationPrintLeftoverRolls);
    _filmLeftover = _numberController(_batch.laminationFilmLeftoverRolls);
    _rezkaBosmaWaste = _numberController(_batch.rezkaBosmaWaste);
    _rezkaLaminationWaste = _numberController(_batch.rezkaLaminationWaste);
    _rezkaEdgeWaste = _numberController(_batch.rezkaEdgeWaste);
    _totalWaste = _numberController(_batch.totalWaste);
    _description = TextEditingController(text: _batch.description);
  }

  TextEditingController _numberController(double? value) =>
      TextEditingController(
          text: value == null ? '' : formatRawQuantity(value));

  @override
  void dispose() {
    _description.dispose();
    _totalWaste.dispose();
    _rezkaEdgeWaste.dispose();
    _rezkaLaminationWaste.dispose();
    _rezkaBosmaWaste.dispose();
    _filmLeftover.dispose();
    _printLeftover.dispose();
    _returnInk.dispose();
    _diameter.dispose();
    _bobina.dispose();
    _kg.dispose();
    _meter.dispose();
    super.dispose();
  }

  double? _parse(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  Widget _quantityField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return requiredField
              ? context.l10n.productionText(
                  'worker.daily.required_field',
                  values: {'label': label},
                )
              : null;
        }
        final parsed = double.tryParse(text.replaceAll(',', '.'));
        if (parsed == null || !parsed.isFinite || parsed <= 0) {
          return context.l10n.productionText(
            'worker.daily.positive_number',
          );
        }
        return null;
      },
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final meter = _parse(_meter)!;
    Navigator.of(context).pop(
      _DailyWorkWipCorrectionDraft(
        producedQty: meter,
        uom: _batch.uom.trim().isEmpty ? 'm' : _batch.uom.trim(),
        returnInkKg: _parse(_returnInk),
        laminationPrintLeftoverRolls: _parse(_printLeftover),
        laminationFilmLeftoverRolls: _parse(_filmLeftover),
        rezkaBosmaWaste: _parse(_rezkaBosmaWaste),
        rezkaLaminationWaste: _parse(_rezkaLaminationWaste),
        rezkaEdgeWaste: _parse(_rezkaEdgeWaste),
        totalWaste: _parse(_totalWaste),
        finishedGoodsKg: _parse(_kg),
        bobinaKg: _parse(_bobina),
        finishedGoodsMeter: meter,
        diameter: _parse(_diameter),
        description: _description.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          maxWidth: 480,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n
                              .productionText('worker.daily.edit.title'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '${_batch.orderId} • ${_batch.batchId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _quantityField(
                          controller: _meter,
                          label: context.l10n.productionText(
                            _showStandardWeights
                                ? 'worker.daily.field.length'
                                : 'worker.daily.field.quantity',
                          ),
                          suffix: _batch.uom.trim().isEmpty
                              ? 'm'
                              : _batch.uom.trim(),
                          requiredField: true,
                        ),
                        if (_showStandardWeights) ...[
                          const SizedBox(height: 10),
                          _quantityField(
                            controller: _kg,
                            label: context.l10n.productionText(
                              'worker.daily.field.weight',
                            ),
                            suffix: 'kg',
                            requiredField: true,
                          ),
                          const SizedBox(height: 10),
                          _quantityField(
                            controller: _bobina,
                            label: context.l10n.productionText(
                              'worker.daily.field.roll',
                            ),
                            suffix: 'kg',
                            requiredField: true,
                          ),
                        ],
                        if (_isRezka) ...[
                          const SizedBox(height: 10),
                          _quantityField(
                            controller: _diameter,
                            label: context.l10n.productionText(
                              'worker.daily.field.diameter',
                            ),
                            suffix: 'mm',
                            requiredField: true,
                          ),
                        ],
                        if (_isPechat && _batch.returnInkKg != null) ...[
                          const SizedBox(height: 10),
                          _quantityField(
                            controller: _returnInk,
                            label: context.l10n.productionText(
                              'worker.daily.field.returned_ink',
                            ),
                            suffix: 'kg',
                            requiredField: true,
                          ),
                        ],
                        if (_isLaminatsiya &&
                            _batch.laminationPrintLeftoverRolls != null) ...[
                          const SizedBox(height: 10),
                          _quantityField(
                            controller: _printLeftover,
                            label: context.l10n.productionText(
                              'worker.daily.field.print_leftover',
                            ),
                            suffix: 'ta',
                            requiredField: true,
                          ),
                        ],
                        if (_isLaminatsiya &&
                            _batch.laminationFilmLeftoverRolls != null) ...[
                          const SizedBox(height: 10),
                          _quantityField(
                            controller: _filmLeftover,
                            label: context.l10n.productionText(
                              'worker.daily.field.film_leftover',
                            ),
                            suffix: 'ta',
                            requiredField: true,
                          ),
                        ],
                        if (_showTotalWaste) ...[
                          const SizedBox(height: 10),
                          _quantityField(
                            controller: _totalWaste,
                            label: context.l10n.productionText(
                              'worker.daily.field.total_waste',
                            ),
                            suffix: 'kg',
                            requiredField: true,
                          ),
                        ],
                        if (_showRezkaWaste) ...[
                          const SizedBox(height: 10),
                          _quantityField(
                            controller: _rezkaBosmaWaste,
                            label: context.l10n.productionText(
                              'worker.daily.field.print_waste',
                            ),
                            suffix: 'kg',
                          ),
                          const SizedBox(height: 10),
                          _quantityField(
                            controller: _rezkaLaminationWaste,
                            label: context.l10n.productionText(
                              'worker.daily.field.lamination_waste',
                            ),
                            suffix: 'kg',
                          ),
                          const SizedBox(height: 10),
                          _quantityField(
                            controller: _rezkaEdgeWaste,
                            label: context.l10n.productionText(
                              'worker.daily.field.edge_waste',
                            ),
                            suffix: 'kg',
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _description,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: context.l10n.productionText(
                              'worker.daily.field.note',
                            ),
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        context.l10n.productionText('worker.action.cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('daily-work-wip-edit-save'),
                      onPressed: _submit,
                      child: Text(context.l10n.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyWorkCorrectionReasonDialog extends StatefulWidget {
  const _DailyWorkCorrectionReasonDialog();

  @override
  State<_DailyWorkCorrectionReasonDialog> createState() =>
      _DailyWorkCorrectionReasonDialogState();
}

class _DailyWorkCorrectionReasonDialogState
    extends State<_DailyWorkCorrectionReasonDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(_reason.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.comment_rounded),
      title: Text(
        context.l10n.productionText('worker.daily.correction.title'),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('daily-work-wip-correction-reason'),
              controller: _reason,
              autofocus: true,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.l10n.noteTitle,
                hintText: context.l10n.productionText(
                  'worker.daily.correction.hint',
                ),
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.trim().isEmpty ?? true
                  ? context.l10n.productionText(
                      'worker.daily.correction.required',
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('daily-work-wip-correction-confirm'),
              onPressed: _save,
              child: Text(context.l10n.save),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.productionText('worker.action.cancel')),
            ),
          ],
        ),
      ),
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
          _dailyWorkStatusLabel(context, batch),
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
            width: 124,
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
            Text(
              context.l10n.productionText('worker.daily.empty'),
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

String _dailyWorkStatusLabel(
  BuildContext context,
  AdminProgressBatch batch,
) {
  return switch (_dailyWorkStatus(batch)) {
    'Ishlatilgan' => context.l10n.productionText('worker.daily.used'),
    'Jarayonda' => context.l10n.productionText(
        'worker.queue.status.in_progress',
      ),
    _ => context.l10n.productionText('worker.wip.waiting'),
  };
}

bool _canCorrectWip(AdminProgressBatch batch) =>
    batch.wipStatus.trim().toLowerCase() == 'waiting';

String _dailyWorkFirstNotEmpty(Iterable<String> values) {
  for (final value in values) {
    if (value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return '—';
}

String _dailyWorkApparatusLabel(
  Iterable<String> assignedApparatus,
  Iterable<AdminApparatus> catalog,
  AppLocalizations l10n,
) {
  final assignedIds = assignedApparatus.map((id) => id.trim()).toSet();
  final assigned = catalog
      .where((apparatus) => assignedIds.contains(apparatus.id.trim()))
      .toList(growable: false);
  if (assigned.any((apparatus) => apparatus.operation == 'print')) {
    return l10n.productionText('worker.daily.apparatus.print');
  }
  if (assigned.any((apparatus) => apparatus.operation == 'cut')) {
    return l10n.productionText('worker.daily.apparatus.cutting');
  }
  if (assigned.any((apparatus) => apparatus.operation == 'laminate')) {
    return l10n.productionText('worker.daily.apparatus.lamination');
  }
  for (final apparatus in assigned) {
    if (apparatus.name.trim().isNotEmpty) return apparatus.name.trim();
  }
  return l10n.productionText('worker.daily.apparatus.worker');
}

String _dailyWorkValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '—' : trimmed;
}

String _dailyWorkDateLabel(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')}. '
      '${value.month.toString().padLeft(2, '0')}. ${value.year}';
}

String _dailyWorkReprintError(Object error, AppLocalizations l10n) {
  if (error is MobileApiException) {
    return l10n.productionErrorMessage(
      error.code,
      fallback: l10n.productionText('worker.daily.reprint_failed'),
    );
  }
  return l10n.productionText('worker.daily.reprint_failed');
}

String _dailyWorkCorrectionError(Object error, AppLocalizations l10n) {
  if (error is MobileApiException) {
    return l10n.productionErrorMessage(
      error.code,
      fallback: l10n.productionText('worker.daily.correction_failed'),
    );
  }
  return l10n.productionText('worker.daily.correction_failed');
}
