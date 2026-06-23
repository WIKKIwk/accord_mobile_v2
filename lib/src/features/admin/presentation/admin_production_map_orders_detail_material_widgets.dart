part of 'admin_production_map_orders_screen.dart';

class _PreviousProgressQrTile extends StatelessWidget {
  const _PreviousProgressQrTile({
    required this.previousStage,
    required this.ready,
    required this.batch,
    required this.actionInFlight,
    required this.onScan,
  });

  final String previousStage;
  final bool ready;
  final AdminProgressBatch? batch;
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
      child: Row(
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
                  ready ? 'Oldingi bosqich tasdiqlandi' : 'Oldingi bosqich QR',
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
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            onPressed: actionInFlight ? null : onScan,
            icon: Icon(
              ready ? Icons.refresh_rounded : Icons.qr_code_scanner_rounded,
            ),
            label: Text(ready ? 'Qayta scan' : 'Scan'),
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
