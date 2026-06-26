part of 'admin_production_map_orders_screen.dart';

class _PreviousProgressQrTile extends StatelessWidget {
  const _PreviousProgressQrTile({
    required this.previousStage,
    required this.ready,
    required this.batch,
    required this.availableBatches,
    required this.loading,
    required this.error,
    required this.actionInFlight,
    required this.onScan,
  });

  final String previousStage;
  final bool ready;
  final AdminProgressBatch? batch;
  final List<AdminProgressBatch> availableBatches;
  final bool loading;
  final String error;
  final bool actionInFlight;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progressBatch = batch;
    final batchQty = progressBatch == null
        ? ''
        : _productionMapQtyLabel(progressBatch.producedQty);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: ready
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ready
                      ? scheme.primary.withValues(alpha: 0.14)
                      : scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  ready ? Icons.check_rounded : Icons.qr_code_scanner_rounded,
                  color: ready ? scheme.primary : scheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ready
                          ? 'Oldingi bosqich tasdiqlandi'
                          : 'Oldingi bosqich QR',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ready && progressBatch != null
                          ? '${progressBatch.apparatus} • $batchQty ${progressBatch.uom}'
                          : previousStage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: actionInFlight ? null : onScan,
            icon: Icon(
              ready ? Icons.refresh_rounded : Icons.qr_code_scanner_rounded,
            ),
            label: Text(ready ? 'Qayta scan' : 'Scan'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InputProgressBatchList(
            previousStage: previousStage,
            selectedBatch: progressBatch,
            batches: availableBatches,
            loading: loading,
            error: error,
          ),
        ],
      ),
    );
  }
}

class _InputProgressBatchList extends StatelessWidget {
  const _InputProgressBatchList({
    required this.previousStage,
    required this.selectedBatch,
    required this.batches,
    required this.loading,
    required this.error,
  });

  final String previousStage;
  final AdminProgressBatch? selectedBatch;
  final List<AdminProgressBatch> batches;
  final bool loading;
  final String error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bu orderda ${batches.length} ta WIP bor',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '$previousStage chiqargan WIPlardan birini scan qiling',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (loading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(color: scheme.primary),
          ] else if (error.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else if (batches.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'WIP topilmadi',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            for (var index = 0; index < batches.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _InputProgressBatchTile(
                batch: batches[index],
                selected: selectedBatch != null &&
                    (selectedBatch!.batchId.trim() ==
                            batches[index].batchId.trim() ||
                        selectedBatch!.qrPayload.trim().toUpperCase() ==
                            batches[index].qrPayload.trim().toUpperCase()),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _InputProgressBatchTile extends StatelessWidget {
  const _InputProgressBatchTile({
    required this.batch,
    required this.selected,
  });

  final AdminProgressBatch batch;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final qty = _productionMapQtyLabel(batch.producedQty);
    final status =
        batch.wipStatus.trim().isEmpty ? 'kutmoqda' : batch.wipStatus;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: selected
            ? scheme.primaryContainer.withValues(alpha: 0.62)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: selected ? Border.all(color: scheme.primary, width: 1.4) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.14)
                  : scheme.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              selected ? Icons.check_rounded : Icons.inventory_2_outlined,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.labelItemName.trim().isEmpty
                      ? batch.batchId
                      : batch.labelItemName.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$qty ${batch.uom} • $status • ${batch.qrPayload}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedMaterialTile extends StatelessWidget {
  const _AssignedMaterialTile({
    required this.assignment,
    required this.scanned,
  });

  final AdminRawMaterialAssignment assignment;
  final bool scanned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = assignment.itemName.trim().isEmpty
        ? assignment.itemCode.trim()
        : assignment.itemName.trim();
    final meta = [
      if (assignment.itemCode.trim().isNotEmpty) assignment.itemCode.trim(),
      if (assignment.itemGroup.trim().isNotEmpty) assignment.itemGroup.trim(),
      assignment.barcode.trim(),
    ].where((item) => item.isNotEmpty).join(' • ');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: scanned
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: scanned
                  ? scheme.primary.withValues(alpha: 0.14)
                  : scheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              scanned ? Icons.check_rounded : Icons.science_outlined,
              color: scanned ? scheme.primary : scheme.onSurfaceVariant,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? assignment.barcode : title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
