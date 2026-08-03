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
    required this.embeddedScanner,
    required this.onScan,
  });

  final String previousStage;
  final bool ready;
  final AdminProgressBatch? batch;
  final List<AdminProgressBatch> availableBatches;
  final bool loading;
  final String error;
  final bool actionInFlight;
  final bool embeddedScanner;
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
          if (!embeddedScanner)
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
    final openCount = batches.where(_progressBatchCanBeScanned).length;
    final usedCount = batches.length - openCount;
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
            'Oldingi bosqichdan kelgan mahsulotlar',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _inputProgressSummaryText(
              previousStage: previousStage,
              total: batches.length,
              open: openCount,
              used: usedCount,
            ),
            maxLines: 3,
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
              '$previousStage hali bu order uchun mahsulot chiqarmagan.',
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
    final canScan = _progressBatchCanBeScanned(batch);
    final statusLabel = canScan ? 'Scan qilish kerak' : 'Ishlatilgan';
    final statusColor = canScan ? scheme.primary : scheme.onSurfaceVariant;
    final title = _inputProgressBatchTitle(batch);
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
              selected
                  ? Icons.check_rounded
                  : canScan
                      ? Icons.qr_code_scanner_rounded
                      : Icons.done_all_rounded,
              color: selected
                  ? scheme.primary
                  : canScan
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$statusLabel • Miqdor: $qty ${batch.uom}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'QR: ${batch.qrPayload}',
                  maxLines: 1,
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
    );
  }
}

String _inputProgressSummaryText({
  required String previousStage,
  required int total,
  required int open,
  required int used,
}) {
  if (total == 0) {
    return '$previousStage chiqargan mahsulotlar shu yerda ko‘rinadi.';
  }
  if (used == 0) {
    return '$previousStage chiqargan $total ta mahsulot bor. $open tasini scan qilish kerak.';
  }
  if (open == 0) {
    return '$previousStage chiqargan $total ta mahsulotning hammasi ishlatilgan.';
  }
  return '$previousStage chiqargan $total ta mahsulot bor: $open tasi scan qilinadi, $used tasi ishlatilgan.';
}

String _inputProgressBatchTitle(AdminProgressBatch batch) {
  final itemName = batch.labelItemName.trim();
  final action = batch.action.trim().toLowerCase();
  final source = batch.apparatus.trim();
  final actionText = switch (action) {
    'complete' => 'tugatib chiqargan',
    'pause' => 'pauzada chiqargan',
    'roll_complete' => 'rulonni tugatib chiqargan',
    _ => 'chiqargan',
  };
  final base = itemName.isEmpty ? batch.orderId.trim() : itemName;
  if (source.isEmpty) {
    return base.isEmpty ? batch.batchId : base;
  }
  return '$source $actionText mahsulot';
}

class _ScannedItemsExpansionHeader extends StatelessWidget {
  const _ScannedItemsExpansionHeader({
    super.key,
    required this.title,
    required this.countText,
    required this.expanded,
    required this.complete,
    required this.onTap,
  });

  final String title;
  final String countText;
  final bool expanded;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: complete
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  countText,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: complete
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  Icons.expand_more_rounded,
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

class _ScannedQolipTile extends StatelessWidget {
  const _ScannedQolipTile({
    required this.qolip,
    required this.scanned,
  });

  final AdminProductionMapRequiredQolip qolip;
  final bool scanned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = qolip.qolipCode.trim();
    final exactColor = _exactQolipHexColor(qolip.color);
    return Container(
      key: ValueKey(
        scanned
            ? 'production-scanned-qolip-${code.toLowerCase()}'
            : 'production-required-qolip-${code.toLowerCase()}',
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scanned
            ? scheme.primaryContainer.withValues(alpha: 0.45)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scanned
                  ? scheme.primary.withValues(alpha: 0.14)
                  : scheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              scanned ? Icons.check_rounded : Icons.qr_code_rounded,
              color: scanned ? scheme.primary : scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Qolip kodi: $code',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (exactColor != null) ...[
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: exactColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        qolip.color.isEmpty
                            ? 'Rang: kiritilmagan'
                            : 'Rang: ${qolip.color}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color? _exactQolipHexColor(String value) {
  final normalized = value.trim();
  if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(normalized)) {
    return null;
  }
  final rgb = int.parse(normalized.substring(1), radix: 16);
  return Color(0xFF000000 | rgb);
}

class _RawMaterialBalanceSummary extends StatelessWidget {
  const _RawMaterialBalanceSummary({required this.balances});

  final List<_RawMaterialBalance> balances;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Homashyo balansi',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (var index = 0; index < balances.length; index++) ...[
            if (index > 0) const SizedBox(height: 4),
            Text(
              'Qabul: ${formatRawQuantity(balances[index].receivedQty)} '
              '${balances[index].uom}  •  Sarf: '
              '${formatRawQuantity(balances[index].consumedQty)} '
              '${balances[index].uom}  •  Qoldiq: '
              '${formatRawQuantity(balances[index].remainingQty)} '
              '${balances[index].uom}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AssignedMaterialTile extends StatelessWidget {
  const _AssignedMaterialTile({
    required this.assignment,
    required this.scanned,
    required this.allowUnlink,
    required this.onUnlink,
    required this.unlinking,
  });

  final AdminRawMaterialAssignment assignment;
  final bool scanned;
  final bool allowUnlink;
  final VoidCallback? onUnlink;
  final bool unlinking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = assignment.itemName.trim().isEmpty
        ? assignment.itemCode.trim()
        : assignment.itemName.trim();
    final details = <String>[];
    void addDetail(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty ||
          details.any(
            (item) => item.toLowerCase() == normalized.toLowerCase(),
          )) {
        return;
      }
      details.add(normalized);
    }

    final itemCode = assignment.itemCode.trim();
    if (itemCode.isNotEmpty && itemCode.toLowerCase() != title.toLowerCase()) {
      final titlePrefix = title.toLowerCase();
      final codeLower = itemCode.toLowerCase();
      final remainder = title.isNotEmpty && codeLower.startsWith(titlePrefix)
          ? itemCode.substring(title.length).trim()
          : itemCode;
      addDetail(remainder.replaceFirst(RegExp(r'^[•·|,/-]+\s*'), ''));
    }
    addDetail(assignment.itemGroup);
    addDetail(assignment.barcode);
    final materialStateVisible = allowUnlink;
    final statusText = materialStateVisible
        ? _rawMaterialAssignmentStatusText(assignment)
        : '';

    var primary = title;
    if (primary.isEmpty && details.isNotEmpty) {
      primary = details.removeAt(0);
    }
    final consumed =
        materialStateVisible && _rawMaterialAssignmentIsConsumed(assignment);
    final locked =
        materialStateVisible && _rawMaterialAssignmentIsLocked(assignment);
    final canUnlink = allowUnlink &&
        onUnlink != null &&
        _rawMaterialAssignmentCanBeUnlinked(assignment);
    final muted = consumed || (locked && !scanned);
    final normalizedBarcode = assignment.barcode.trim().toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: muted
            ? scheme.surface.withValues(alpha: 0.5)
            : scanned
                ? scheme.primaryContainer.withValues(alpha: 0.45)
                : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: muted
                  ? scheme.surface.withValues(alpha: 0.7)
                  : scanned
                      ? scheme.primary.withValues(alpha: 0.14)
                      : scheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              consumed
                  ? Icons.check_circle_outline_rounded
                  : scanned
                      ? Icons.check_rounded
                      : Icons.science_outlined,
              color: consumed
                  ? scheme.onSurfaceVariant.withValues(alpha: 0.65)
                  : scanned
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      if (primary.isNotEmpty)
                        TextSpan(
                          text: primary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: muted
                                ? scheme.onSurface.withValues(alpha: 0.55)
                                : null,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (details.isNotEmpty)
                        TextSpan(
                          text:
                              '${primary.isEmpty ? '' : ' • '}${details.join(' • ')}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (statusText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: muted
                          ? scheme.onSurfaceVariant.withValues(alpha: 0.65)
                          : scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (allowUnlink) ...[
            const SizedBox(width: 4),
            IconButton(
              key: ValueKey('raw-material-unlink-$normalizedBarcode'),
              tooltip: canUnlink
                  ? 'Ulanishni uzish'
                  : '${statusText.isEmpty ? 'Homashyo' : statusText}: uzib bo‘lmaydi',
              onPressed: canUnlink && !unlinking ? onUnlink : null,
              icon: unlinking
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link_off_rounded),
            ),
          ],
        ],
      ),
    );
  }
}
