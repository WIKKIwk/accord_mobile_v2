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

class _SequenceStepTile extends StatelessWidget {
  const _SequenceStepTile({
    required this.node,
    required this.index,
    required this.isLast,
    required this.status,
    required this.current,
    required this.isDone,
  });

  final ProductionMapNode node;
  final int index;
  final bool isLast;
  final ApparatusQueueOrderState? status;
  final bool current;
  final bool isDone;

  static const _completedGreen = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = _nodeIcon(node);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            _StepNodeCircle(
              icon: icon,
              current: current,
              isDone: isDone,
              status: status,
            ),
            if (!isLast)
              Container(
                width: 2.5,
                height: 30,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isDone ? _completedGreen : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (current)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _MapStatusChip(
                      label: 'Joriy bosqich',
                      foreground: scheme.onPrimaryContainer,
                      background: scheme.primaryContainer,
                    ),
                  ),
                Text(
                  node.title.trim().isEmpty ? 'Qadam ${index + 1}' : node.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDone && !current
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _kindLabel(node),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (status != null && node.kind == 'apparatus')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _MapStatusChip(
              label: _statusLabel(status!),
              foreground: _statusForeground(scheme),
              background: _statusBackground(scheme),
            ),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              current ? scheme.primaryContainer.withValues(alpha: 0.28) : null,
          borderRadius: BorderRadius.circular(14),
          border:
              current ? Border.all(color: scheme.primary, width: 1.5) : null,
        ),
        child: Padding(
          padding: current
              ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
              : EdgeInsets.zero,
          child: content,
        ),
      ),
    );
  }

  IconData _nodeIcon(ProductionMapNode node) {
    return switch (node.kind) {
      'start' => Icons.play_circle_outline_rounded,
      'end' => Icons.flag_circle_outlined,
      'apparatus' => productionMapIsLaminatsiyaApparatus(node.title)
          ? Icons.layers_outlined
          : productionMapIsRezkaApparatus(node.title)
              ? Icons.content_cut_outlined
              : Icons.print_outlined,
      _ => Icons.account_tree_outlined,
    };
  }

  Color _statusForeground(ColorScheme scheme) {
    return switch (status) {
      ApparatusQueueOrderState.inProgress => const Color(0xFF8A4B00),
      ApparatusQueueOrderState.paused => const Color(0xFF9B1C1C),
      ApparatusQueueOrderState.completed => _completedGreen,
      ApparatusQueueOrderState.pending => scheme.onPrimaryContainer,
      null => scheme.onSurfaceVariant,
    };
  }

  Color _statusBackground(ColorScheme scheme) {
    return switch (status) {
      ApparatusQueueOrderState.inProgress => const Color(0xFFFFECB3),
      ApparatusQueueOrderState.paused => const Color(0xFFFFCDD2),
      ApparatusQueueOrderState.completed => const Color(0xFFC8E6C9),
      ApparatusQueueOrderState.pending => scheme.primaryContainer,
      null => scheme.surfaceContainerHighest,
    };
  }

  String _statusLabel(ApparatusQueueOrderState status) {
    return switch (status) {
      ApparatusQueueOrderState.inProgress => 'Jarayonda',
      ApparatusQueueOrderState.paused => 'Pauzada',
      ApparatusQueueOrderState.completed => 'Tugagan',
      ApparatusQueueOrderState.pending => 'Kutmoqda',
    };
  }

  String _kindLabel(ProductionMapNode node) {
    return switch (node.kind) {
      'start' => 'Boshlanish',
      'apparatus' => productionMapIsLaminatsiyaApparatus(node.title)
          ? 'Laminatsiya mashinasi'
          : productionMapIsRezkaApparatus(node.title)
              ? 'Rezka mashinasi'
              : 'Aparat',
      'end' => 'Yakun',
      _ => node.kind,
    };
  }
}

class _StepNodeCircle extends StatelessWidget {
  const _StepNodeCircle({
    required this.icon,
    required this.current,
    required this.isDone,
    required this.status,
  });

  final IconData icon;
  final bool current;
  final bool isDone;
  final ApparatusQueueOrderState? status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inProgress = status == ApparatusQueueOrderState.inProgress;
    final paused = status == ApparatusQueueOrderState.paused;

    Color background;
    Color foreground;
    BoxBorder? border;

    if (isDone) {
      background = const Color(0xFFC8E6C9);
      foreground = const Color(0xFF2E7D32);
    } else if (current && inProgress) {
      background = const Color(0xFFFFECB3);
      foreground = const Color(0xFF8A4B00);
      border = Border.all(color: const Color(0xFFB26A00), width: 2);
    } else if (current && paused) {
      background = const Color(0xFFFFCDD2);
      foreground = const Color(0xFF9B1C1C);
      border = Border.all(color: const Color(0xFFC62828), width: 2);
    } else if (current) {
      background = scheme.primary;
      foreground = scheme.onPrimary;
    } else {
      background = scheme.surfaceContainerHighest;
      foreground = scheme.onSurfaceVariant;
      border = Border.all(color: scheme.outlineVariant);
    }

    return SizedBox.square(
      dimension: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: border,
        ),
        child: Icon(
          isDone ? Icons.check_rounded : icon,
          size: 18,
          color: foreground,
        ),
      ),
    );
  }
}

class _MapStatusChip extends StatelessWidget {
  const _MapStatusChip({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
