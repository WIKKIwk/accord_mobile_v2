part of 'admin_production_map_orders_screen.dart';

class _WorkerFrozenOrderDetailsSheet extends StatelessWidget {
  const _WorkerFrozenOrderDetailsSheet({required this.entry});

  final _WorkerCompletedOrderEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = entry.order.map;
    final title = _workerWipFirstNotEmpty([
      map.orderNumber,
      map.code,
      map.title,
      map.id,
    ]);
    final product = _workerWipFirstNotEmpty([map.title, map.productCode]);
    final apparatus = entry.apparatus?.name.trim() ?? '';
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.adminText('production.freeze_details'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  if (title.isNotEmpty) title,
                  if (product.isNotEmpty && product != title) product,
                  if (apparatus.isNotEmpty) apparatus,
                ].join(' • '),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Card.filled(
                color: scheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.lock_clock_rounded, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.isFrozen
                              ? context.l10n.productionText(
                                  'worker.queue.status.frozen',
                                )
                              : context.l10n.adminText(
                                  'production.unfreeze',
                                ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (entry.issueNote.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Card.filled(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.l10n.adminText('production.issue_note'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(entry.issueNote.trim()),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerWipHistorySheet extends StatefulWidget {
  const _WorkerWipHistorySheet({
    required this.order,
    required this.apparatus,
  });

  final ProductionMapSaved order;
  final AdminApparatus? apparatus;

  @override
  State<_WorkerWipHistorySheet> createState() => _WorkerWipHistorySheetState();
}

class _WorkerWipHistorySheetState extends State<_WorkerWipHistorySheet> {
  late Future<List<AdminProgressBatch>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AdminProgressBatch>> _load() async {
    final orderId = widget.order.map.id.trim();
    final batches = await MobileApi.instance.adminProgressQrHistory(limit: 200);
    return batches
        .where((batch) => batch.orderId.trim() == orderId)
        .toList(growable: false);
  }

  void _retry() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = widget.order.map;
    final title = _workerWipFirstNotEmpty([
      map.orderNumber,
      map.code,
      map.title,
      map.id,
    ]);
    final product = _workerWipFirstNotEmpty([map.title, map.productCode]);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.productionText('worker.wip.history.title'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  if (title.isNotEmpty) title,
                  if (product.isNotEmpty && product != title) product,
                  if (widget.apparatus?.name.trim().isNotEmpty == true)
                    context.l10n.productionApparatusName(
                      widget.apparatus!.name,
                    ),
                ].join(' • '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<AdminProgressBatch>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: AppLoadingIndicator());
                    }
                    if (snapshot.hasError) {
                      return _WorkerWipHistoryError(onRetry: _retry);
                    }
                    final batches =
                        snapshot.data ?? const <AdminProgressBatch>[];
                    if (batches.isEmpty) {
                      return _WorkerWipHistoryEmpty();
                    }
                    return _WorkerWipHistoryList(batches: batches);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerWipHistoryList extends StatelessWidget {
  const _WorkerWipHistoryList({required this.batches});

  final List<AdminProgressBatch> batches;

  @override
  Widget build(BuildContext context) {
    final waitingCount = batches
        .where((batch) => _workerWipKind(batch) == _WorkerWipKind.waiting)
        .length;
    final inUseCount = batches
        .where((batch) => _workerWipKind(batch) == _WorkerWipKind.inUse)
        .length;
    final processedCount = batches
        .where((batch) => _workerWipKind(batch) == _WorkerWipKind.processed)
        .length;

    return ListView(
      key: const ValueKey('worker-wip-history-sheet'),
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        _WorkerWipHistorySummary(
          count: batches.length,
          waitingCount: waitingCount,
          inUseCount: inUseCount,
          processedCount: processedCount,
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < batches.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _WorkerWipHistoryCard(
              key: ValueKey('worker-wip-item-$index'),
              batch: batches[index],
              index: index,
            ),
          ),
      ],
    );
  }
}

class _WorkerWipHistorySummary extends StatelessWidget {
  const _WorkerWipHistorySummary({
    required this.count,
    required this.waitingCount,
    required this.inUseCount,
    required this.processedCount,
  });

  final int count;
  final int waitingCount;
  final int inUseCount;
  final int processedCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card.filled(
      key: const ValueKey('worker-wip-count'),
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.productionText(
                'worker.wip.history.summary',
                values: {'count': count},
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.productionText(
                'worker.wip.history.description',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _WorkerWipCountChip(
                  label: context.l10n.productionText(
                    'worker.wip.status.waiting',
                  ),
                  value: waitingCount,
                ),
                _WorkerWipCountChip(
                  label: context.l10n.productionText(
                    'worker.wip.status.in_progress',
                  ),
                  value: inUseCount,
                ),
                _WorkerWipCountChip(
                  label: context.l10n.productionText(
                    'worker.wip.status.used',
                  ),
                  value: processedCount,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerWipCountChip extends StatelessWidget {
  const _WorkerWipCountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.onTertiaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          '$label: $value',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _WorkerWipHistoryCard extends StatelessWidget {
  const _WorkerWipHistoryCard({
    super.key,
    required this.batch,
    required this.index,
  });

  final AdminProgressBatch batch;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final kind = _workerWipKind(batch);
    final statusLabel = _workerWipStatusLabel(batch, context.l10n);
    final product = _workerWipFirstNotEmpty([
      batch.labelItemName,
      batch.labelItemCode,
      '${context.l10n.productionText('worker.daily.wip')} ${index + 1}',
    ]);
    final current = context.l10n.productionApparatusName(
      _workerWipFirstNotEmpty([
        batch.currentLocation,
        batch.currentApparatus,
        batch.apparatus,
      ]),
    );
    final worker = _workerWipFirstNotEmpty([
      batch.workerDisplayName,
      batch.executorName,
      batch.workerRef,
    ]);
    final next = context.l10n.productionApparatusName(batch.nextApparatus);
    final action = _workerWipActionLabel(batch.action, context.l10n);

    return Card.filled(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 15),
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
                  child: Text('${index + 1}'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    product,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _WorkerWipStatusChip(label: statusLabel, kind: kind),
              ],
            ),
            const SizedBox(height: 10),
            _WorkerWipInfoRow(
              label: context.l10n.productionText('worker.wip.info.quantity'),
              value: formatQuantityWithUnit(
                batch.producedQty,
                batch.uom,
                trimTrailingZeros: true,
              ),
            ),
            if (batch.startedAtUnix > 0)
              _WorkerWipInfoRow(
                label: context.l10n.productionText('worker.wip.info.started'),
                value: formatUnixSecondsLocalDateTime(batch.startedAtUnix),
              ),
            if (batch.completedAtUnix > 0)
              _WorkerWipInfoRow(
                label: context.l10n.productionText('worker.wip.info.finished'),
                value: formatUnixSecondsLocalDateTime(batch.completedAtUnix),
              ),
            _WorkerWipInfoRow(
              label: context.l10n.productionText('worker.wip.info.source'),
              value: context.l10n.productionApparatusName(
                _workerWipValue(batch.apparatus),
              ),
            ),
            if (action.isNotEmpty)
              _WorkerWipInfoRow(
                label: context.l10n.productionText('worker.wip.info.action'),
                value: action,
              ),
            _WorkerWipInfoRow(
              label: context.l10n.productionText('worker.wip.info.location'),
              value: current,
            ),
            _WorkerWipInfoRow(
              label: context.l10n.productionText(
                'worker.wip.info.next_machine',
              ),
              value: _workerWipValue(next),
            ),
            _WorkerWipInfoRow(
              label: context.l10n.productionText('worker.wip.info.worker'),
              value: worker,
            ),
            if (batch.batchId.trim().isNotEmpty)
              _WorkerWipInfoRow(
                label: context.l10n.productionText('worker.wip.info.id'),
                value: batch.batchId,
              ),
            if (batch.qrPayload.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${context.l10n.productionText('worker.wip.info.qr')} ${batch.qrPayload.trim()}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (batch.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '${context.l10n.productionText('worker.wip.info.note')}: ${batch.description.trim()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkerWipInfoRow extends StatelessWidget {
  const _WorkerWipInfoRow({required this.label, required this.value});

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
          SizedBox(
            width: 108,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerWipStatusChip extends StatelessWidget {
  const _WorkerWipStatusChip({required this.label, required this.kind});

  final String label;
  final _WorkerWipKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = switch (kind) {
      _WorkerWipKind.waiting => scheme.tertiaryContainer,
      _WorkerWipKind.inUse => scheme.primaryContainer,
      _WorkerWipKind.processed => scheme.secondaryContainer,
    };
    final foreground = switch (kind) {
      _WorkerWipKind.waiting => scheme.onTertiaryContainer,
      _WorkerWipKind.inUse => scheme.onPrimaryContainer,
      _WorkerWipKind.processed => scheme.onSecondaryContainer,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
    );
  }
}

class _WorkerWipHistoryError extends StatelessWidget {
  const _WorkerWipHistoryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.productionText('worker.wip.history.error')),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            child: Text(context.l10n.productionText('worker.action.retry')),
          ),
        ],
      ),
    );
  }
}

class _WorkerWipHistoryEmpty extends StatelessWidget {
  const _WorkerWipHistoryEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        context.l10n.productionText('worker.wip.history.empty'),
      ),
    );
  }
}

enum _WorkerWipKind { waiting, inUse, processed }

_WorkerWipKind _workerWipKind(AdminProgressBatch batch) {
  final flow = batch.statusDetail.flowStatus.trim();
  final wipStatus = batch.wipStatus.trim();
  if (flow == 'in_progress' || wipStatus == 'in_use') {
    return _WorkerWipKind.inUse;
  }
  if (flow == 'consumed_by_next_stage' ||
      flow == 'accepted_to_stock' ||
      wipStatus == 'processed') {
    return _WorkerWipKind.processed;
  }
  return _WorkerWipKind.waiting;
}

String _workerWipStatusLabel(
  AdminProgressBatch batch,
  AppLocalizations l10n,
) {
  final flow = batch.statusDetail.flowStatus.trim();
  if (flow == 'free_wip') {
    return l10n.productionText('worker.wip.status.free');
  }
  if (flow == 'accepted_to_stock') {
    return l10n.productionText('worker.wip.status.accepted');
  }
  if (flow == 'waiting_next_stage') {
    return l10n.productionText('worker.wip.status.waiting_next');
  }
  if (flow == 'consumed_by_next_stage') {
    return l10n.productionText('worker.wip.status.consumed_next');
  }
  if (flow == 'in_progress') {
    return l10n.productionText('worker.wip.status.in_progress');
  }
  return switch (batch.wipStatus.trim()) {
    'waiting' => l10n.productionText('worker.wip.status.waiting'),
    'in_use' => l10n.productionText('worker.wip.status.in_progress'),
    'processed' => l10n.productionText('worker.wip.status.used'),
    _ => switch (batch.statusDetail.workStatus.trim().isNotEmpty
          ? batch.statusDetail.workStatus.trim()
          : batch.status.trim()) {
        'paused' => l10n.productionText('worker.wip.status.paused'),
        'resumed' ||
        'in_progress' =>
          l10n.productionText('worker.wip.status.in_progress'),
        'completed' ||
        'complete' =>
          l10n.productionText('worker.wip.status.finished'),
        _ => l10n.productionText('worker.daily.wip'),
      },
  };
}

String _workerWipFirstNotEmpty(Iterable<String> values) {
  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return '';
}

String _workerWipValue(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '—' : trimmed;
}

String _workerWipActionLabel(String value, AppLocalizations l10n) {
  return switch (value.trim().toLowerCase()) {
    'pause' => l10n.productionText('worker.wip.action.pause'),
    'detach_roll' => l10n.productionText('worker.wip.action.detach_roll'),
    'roll_complete' => l10n.productionText('worker.wip.action.roll_complete'),
    'complete' => l10n.productionText('worker.wip.action.complete'),
    'resume' => l10n.productionText('worker.wip.action.resume'),
    _ => value.trim(),
  };
}
