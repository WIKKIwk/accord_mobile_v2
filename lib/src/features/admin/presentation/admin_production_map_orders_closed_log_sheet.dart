part of 'admin_production_map_orders_screen.dart';

void _showClosedOrderLogDetails(
  BuildContext context, {
  required AdminClosedProductionOrder order,
  required AdminProductionOrderLogEntry log,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _ClosedOrderLogDetailsSheet(
      order: order,
      log: log,
    ),
  );
}

List<AdminProgressBatch> _closedProgressBatchesForLog(
  AdminClosedProductionOrder order,
  AdminProductionOrderLogEntry log,
) {
  final freezeSessionId = log.freeze?.targetSessionId.trim() ?? '';
  if (freezeSessionId.isNotEmpty) {
    final sessionMatches = order.progressBatches
        .where((batch) => batch.sessionId.trim() == freezeSessionId)
        .toList(growable: false);
    if (sessionMatches.isNotEmpty) {
      return sessionMatches;
    }
  }
  final transferBatchId = log.transfer?.progressBatchId.trim() ?? '';
  if (transferBatchId.isNotEmpty) {
    return order.progressBatches
        .where((batch) => batch.batchId.trim() == transferBatchId)
        .toList(growable: false);
  }

  final action = log.action.trim().toLowerCase();
  final apparatus = log.apparatus.trim();
  final matches = order.progressBatches.where((batch) {
    if (batch.action.trim().toLowerCase() != action) {
      return false;
    }
    if (apparatus.isEmpty) {
      return true;
    }
    return productionMapWarehouseTitlesMatch(batch.apparatus, apparatus) ||
        productionMapWarehouseTitlesMatch(batch.currentApparatus, apparatus);
  }).toList();
  matches.sort((left, right) {
    final leftDistance = _closedLogBatchTimeDistance(left, log.createdAtUnix);
    final rightDistance = _closedLogBatchTimeDistance(right, log.createdAtUnix);
    return leftDistance.compareTo(rightDistance);
  });
  return matches;
}

int _closedLogBatchTimeDistance(AdminProgressBatch batch, int timestamp) {
  final candidates = [batch.startedAtUnix, batch.completedAtUnix]
      .where((value) => value > 0)
      .toList(growable: false);
  if (candidates.isEmpty || timestamp <= 0) {
    return 1 << 30;
  }
  return candidates
      .map((value) => (value - timestamp).abs())
      .reduce((left, right) => left < right ? left : right);
}

class _ClosedOrderLogDetailsSheet extends StatelessWidget {
  const _ClosedOrderLogDetailsSheet({required this.order, required this.log});

  final AdminClosedProductionOrder order;
  final AdminProductionOrderLogEntry log;

  @override
  Widget build(BuildContext context) {
    final freeze = log.freeze;
    final transfer = log.transfer;
    final batches = _closedProgressBatchesForLog(order, log);
    final actor = _closedActorLabel(
      displayName: log.actorDisplayName,
      role: log.actorRole,
      ref: log.actorRef,
    );
    final apparatus = _closedLogApparatusLabel(log);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ClosedLogDetailsHeader(log: log, apparatus: apparatus),
              const SizedBox(height: 18),
              _ClosedLogDetailsSection(
                title: 'Hodisa tafsilotlari',
                icon: Icons.info_outline_rounded,
                children: [
                  _ClosedLogDetailRow(
                      label: 'Hodisa', value: _closedLogTitle(log)),
                  if (apparatus.isNotEmpty)
                    _ClosedLogDetailRow(label: 'Apparat', value: apparatus),
                  _ClosedLogDetailRow(
                    label: 'Vaqt',
                    value: _closedLogTimeLabel(log.createdAtUnix),
                  ),
                  _ClosedLogDetailRow(label: 'Bajaruvchi', value: actor),
                  if (log.fromState.trim().isNotEmpty ||
                      log.toState.trim().isNotEmpty)
                    _ClosedLogDetailRow(
                      label: 'Holat',
                      value: _closedLogStateLabel(log),
                    ),
                  if (log.eventId.trim().isNotEmpty)
                    _ClosedLogDetailRow(
                      label: 'Event ID',
                      value: log.eventId.trim(),
                      selectable: true,
                    ),
                  if (log.completedWithIssue && log.issueNote.trim().isNotEmpty)
                    _ClosedLogDetailRow(
                      label: 'Muammo izohi',
                      value: log.issueNote.trim(),
                    ),
                ],
              ),
              if (freeze != null) ...[
                const SizedBox(height: 16),
                _ClosedLogDetailsSection(
                  title: 'Muzlatish tafsilotlari',
                  icon: Icons.lock_clock_rounded,
                  children: [
                    _ClosedLogDetailRow(
                      label: 'Holat',
                      value: _closedLogFreezeStatusLabel(freeze.status),
                    ),
                    if (freeze.targetApparatus.trim().isNotEmpty)
                      _ClosedLogDetailRow(
                        label: 'Apparat',
                        value: freeze.targetApparatus.trim(),
                      ),
                    if (freeze.targetWorkerDisplayName.trim().isNotEmpty ||
                        freeze.targetWorkerRef.trim().isNotEmpty ||
                        freeze.targetWorkerRole.trim().isNotEmpty)
                      _ClosedLogDetailRow(
                        label: 'Maqsad ishchi',
                        value: _closedActorLabel(
                          displayName: freeze.targetWorkerDisplayName,
                          role: freeze.targetWorkerRole,
                          ref: freeze.targetWorkerRef,
                        ),
                      ),
                    if (freeze.targetSessionId.trim().isNotEmpty)
                      _ClosedLogDetailRow(
                        label: 'Target session',
                        value: freeze.targetSessionId.trim(),
                        selectable: true,
                      ),
                    if (freeze.requestId.trim().isNotEmpty)
                      _ClosedLogDetailRow(
                        label: 'Freeze request ID',
                        value: freeze.requestId.trim(),
                        selectable: true,
                      ),
                    if (freeze.requestedAtUnix > 0)
                      _ClosedLogDetailRow(
                        label: 'So‘rov vaqti',
                        value: _closedLogTimeLabel(freeze.requestedAtUnix),
                      ),
                    if (freeze.transitionedAtUnix > 0)
                      _ClosedLogDetailRow(
                        label: 'Holat o‘zgarishi',
                        value: _closedLogTimeLabel(freeze.transitionedAtUnix),
                      ),
                  ],
                ),
              ],
              if (transfer != null) ...[
                const SizedBox(height: 16),
                _ClosedLogDetailsSection(
                  title: 'Apparat almashtirish tafsilotlari',
                  icon: Icons.swap_horiz_rounded,
                  children: [
                    _ClosedLogDetailRow(
                      label: 'Qayerdan',
                      value: transfer.fromApparatus,
                    ),
                    _ClosedLogDetailRow(
                      label: 'Qayerga',
                      value: transfer.toApparatus,
                    ),
                    if (transfer.reason.trim().isNotEmpty)
                      _ClosedLogDetailRow(
                        label: 'Sabab',
                        value: transfer.reason.trim(),
                      ),
                    if (transfer.transferId.trim().isNotEmpty)
                      _ClosedLogDetailRow(
                        label: 'Transfer ID',
                        value: transfer.transferId.trim(),
                        selectable: true,
                      ),
                    if (transfer.sessionId.trim().isNotEmpty)
                      _ClosedLogDetailRow(
                        label: 'Session ID',
                        value: transfer.sessionId.trim(),
                        selectable: true,
                      ),
                    if (transfer.progressBatchId.trim().isNotEmpty)
                      _ClosedLogDetailRow(
                        label: 'Progress batch',
                        value: transfer.progressBatchId.trim(),
                        selectable: true,
                      ),
                    if (transfer.materialBarcodes.isNotEmpty)
                      _ClosedLogDetailRow(
                        label: 'Material QR/barcode',
                        value: transfer.materialBarcodes.join(', '),
                        selectable: true,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _ClosedLogDetailsSection(
                title: batches.isEmpty
                    ? 'Progress ma’lumoti'
                    : 'Progress ma’lumotlari',
                icon: Icons.analytics_outlined,
                children: [
                  if (batches.isEmpty)
                    const _ClosedLogMutedText(
                      text:
                          'Bu hodisa uchun qo‘shimcha progress ma’lumoti yo‘q.',
                    )
                  else
                    for (var index = 0; index < batches.length; index++) ...[
                      if (index > 0) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                      ],
                      _ClosedLogProgressDetails(batch: batches[index]),
                    ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosedLogDetailsHeader extends StatelessWidget {
  const _ClosedLogDetailsHeader({required this.log, required this.apparatus});

  final AdminProductionOrderLogEntry log;
  final String apparatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              log.transfer != null
                  ? Icons.swap_horiz_rounded
                  : log.freeze != null
                      ? Icons.lock_clock_rounded
                      : Icons.history_rounded,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _closedLogTitle(log),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (apparatus.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  apparatus,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ClosedLogDetailsSection extends StatelessWidget {
  const _ClosedLogDetailsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ClosedLogDetailRow extends StatelessWidget {
  const _ClosedLogDetailRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final valueWidget = selectable
        ? SelectableText(value)
        : Text(value, maxLines: 8, overflow: TextOverflow.ellipsis);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: DefaultTextStyle(
              style: theme.textTheme.bodySmall ?? const TextStyle(),
              child: valueWidget,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClosedLogMutedText extends StatelessWidget {
  const _ClosedLogMutedText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _ClosedLogProgressDetails extends StatelessWidget {
  const _ClosedLogProgressDetails({required this.batch});

  final AdminProgressBatch batch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final worker = _closedActorLabel(
      displayName: batch.workerDisplayName,
      role: batch.workerRole,
      ref: batch.workerRef,
    );
    final metrics = <String>[
      if (batch.producedQty > 0 || batch.uom.trim().isNotEmpty)
        'Ishlab chiqarildi: ${_closedLogNumber(batch.producedQty)} ${batch.uom}'
            .trim(),
      if (batch.returnInkKg != null)
        'Qaytgan bo‘yoq: ${_closedLogNumber(batch.returnInkKg!)} kg',
      if (batch.laminationPrintLeftoverRolls != null)
        'Bosma rulon qoldig‘i: ${_closedLogNumber(batch.laminationPrintLeftoverRolls!)}',
      if (batch.laminationFilmLeftoverRolls != null)
        'Plyonka qoldig‘i: ${_closedLogNumber(batch.laminationFilmLeftoverRolls!)}',
      if (batch.rezkaBosmaWaste != null)
        'Bosma chiqindi: ${_closedLogNumber(batch.rezkaBosmaWaste!)}',
      if (batch.rezkaLaminationWaste != null)
        'Laminatsiya chiqindisi: ${_closedLogNumber(batch.rezkaLaminationWaste!)}',
      if (batch.rezkaEdgeWaste != null)
        'Chekka chiqindi: ${_closedLogNumber(batch.rezkaEdgeWaste!)}',
      if (batch.totalWaste != null)
        'Jami chiqindi: ${_closedLogNumber(batch.totalWaste!)}',
      if (batch.finishedGoodsKg != null)
        'Tayyor mahsulot: ${_closedLogNumber(batch.finishedGoodsKg!)} kg',
      if (batch.finishedGoodsMeter != null)
        'Tayyor metr: ${_closedLogNumber(batch.finishedGoodsMeter!)} m',
    ];
    final status = [
      if (batch.status.trim().isNotEmpty) batch.status.trim(),
      if (batch.wipStatus.trim().isNotEmpty) 'WIP: ${batch.wipStatus.trim()}',
      if (batch.statusDetail.flowStatus.trim().isNotEmpty)
        'Flow: ${batch.statusDetail.flowStatus.trim()}',
      if (batch.statusDetail.stockStatus.trim().isNotEmpty)
        'Stock: ${batch.statusDetail.stockStatus.trim()}',
    ].join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            if (batch.action.trim().isNotEmpty) batch.action.trim(),
            if (batch.apparatus.trim().isNotEmpty) batch.apparatus.trim(),
          ].join(' • '),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (status.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (batch.batchId.trim().isNotEmpty)
          _ClosedLogDetailRow(
            label: 'Batch ID',
            value: batch.batchId.trim(),
            selectable: true,
          ),
        if (batch.sessionId.trim().isNotEmpty)
          _ClosedLogDetailRow(
            label: 'Session ID',
            value: batch.sessionId.trim(),
            selectable: true,
          ),
        _ClosedLogDetailRow(label: 'Ijrochi', value: worker),
        if (batch.executorName.trim().isNotEmpty)
          _ClosedLogDetailRow(
            label: 'Executor',
            value: batch.executorName.trim(),
          ),
        if (batch.labelItemCode.trim().isNotEmpty ||
            batch.labelItemName.trim().isNotEmpty)
          _ClosedLogDetailRow(
            label: 'Mahsulot',
            value: [
              batch.labelItemCode.trim(),
              batch.labelItemName.trim(),
            ].where((value) => value.isNotEmpty).join(' • '),
          ),
        if (batch.currentLocation.trim().isNotEmpty)
          _ClosedLogDetailRow(
            label: 'Joylashuvi',
            value: batch.currentLocation.trim(),
          ),
        if (batch.nextApparatus.trim().isNotEmpty)
          _ClosedLogDetailRow(
            label: 'Keyingi aparat',
            value: batch.nextApparatus.trim(),
          ),
        if (batch.parentBatchId.trim().isNotEmpty)
          _ClosedLogDetailRow(
            label: 'Parent batch',
            value: batch.parentBatchId.trim(),
            selectable: true,
          ),
        if (metrics.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (final metric in metrics)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                metric,
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
        if (batch.description.trim().isNotEmpty)
          _ClosedLogDetailRow(
            label: 'Izoh',
            value: batch.description.trim(),
          ),
        if (batch.qrPayload.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _ClosedLogQrPayload(payload: batch.qrPayload.trim()),
        ],
      ],
    );
  }
}

class _ClosedLogQrPayload extends StatelessWidget {
  const _ClosedLogQrPayload({required this.payload});

  final String payload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.qr_code_2_rounded, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QR kodi / payload',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  payload,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Nusxalash',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: payload));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR payload nusxalandi')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}

String _closedLogNumber(double value) {
  final text = value.toStringAsFixed(3);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
