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

Widget _orderDetailSurfaceCard({
  required BuildContext context,
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(14, 14, 14, 14),
}) {
  final scheme = Theme.of(context).colorScheme;
  return Material(
    color: scheme.surface,
    elevation: 2,
    shadowColor: scheme.shadow.withValues(alpha: 0.16),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

class _OrderStartUnifiedCard extends StatelessWidget {
  const _OrderStartUnifiedCard({
    required this.orderCode,
    required this.productTitle,
    required this.assignments,
    required this.materialsLoading,
    required this.materialsError,
    required this.scannedBarcodes,
    required this.scannedCount,
    required this.showStart,
    required this.hasMaterialAssignments,
    required this.allMaterialsScanned,
    required this.actionInFlight,
    required this.showPause,
    required this.showComplete,
    required this.showResume,
    required this.showWaitingForPrevious,
    required this.previousStage,
    required this.previousProgressRequired,
    required this.previousProgressReady,
    required this.previousProgressBatch,
    required this.onScan,
    required this.onProgressScan,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    required this.onResume,
  });

  final String orderCode;
  final String productTitle;
  final List<AdminRawMaterialAssignment> assignments;
  final bool materialsLoading;
  final String materialsError;
  final Set<String> scannedBarcodes;
  final int scannedCount;
  final bool showStart;
  final bool hasMaterialAssignments;
  final bool allMaterialsScanned;
  final bool actionInFlight;
  final bool showPause;
  final bool showComplete;
  final bool showResume;
  final bool showWaitingForPrevious;
  final String? previousStage;
  final bool previousProgressRequired;
  final bool previousProgressReady;
  final AdminProgressBatch? previousProgressBatch;
  final VoidCallback onScan;
  final VoidCallback? onProgressScan;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalCount = assignments.length;
    final hasActions = showStart ||
        showPause ||
        showComplete ||
        showResume ||
        showWaitingForPrevious;

    return _orderDetailSurfaceCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zakaz kodi',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      orderCode.trim().isEmpty ? '-' : orderCode.trim(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Mahsulot',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      productTitle.trim().isEmpty ? '-' : productTitle.trim(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(
              height: 28, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Biriktirilgan homashyolar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!materialsLoading &&
                  materialsError.trim().isEmpty &&
                  totalCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scannedCount == totalCount
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$scannedCount/$totalCount',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scannedCount == totalCount
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (materialsLoading)
            Row(
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Yuklanmoqda',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else if (materialsError.trim().isNotEmpty)
            Text(
              materialsError,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (assignments.isEmpty)
            Text(
              'Homashyo biriktirilmagan',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Column(
              children: [
                for (var index = 0; index < assignments.length; index++) ...[
                  if (index > 0) const SizedBox(height: 8),
                  _AssignedMaterialTile(
                    assignment: assignments[index],
                    scanned: scannedBarcodes.contains(
                      assignments[index].barcode.trim().toUpperCase(),
                    ),
                  ),
                ],
              ],
            ),
          if (hasActions) ...[
            Divider(
                height: 28,
                color: scheme.outlineVariant.withValues(alpha: 0.5)),
            if (showStart && hasMaterialAssignments)
              FilledButton.tonalIcon(
                onPressed:
                    actionInFlight || allMaterialsScanned ? null : onScan,
                icon: Icon(
                  allMaterialsScanned
                      ? Icons.check_circle_rounded
                      : Icons.qr_code_scanner_rounded,
                ),
                label: Text(
                  allMaterialsScanned
                      ? 'Homashyolar tasdiqlandi'
                      : 'Homashyo QR scan',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            if (showStart && hasMaterialAssignments) const SizedBox(height: 10),
            if (showStart && previousProgressRequired) ...[
              _PreviousProgressQrTile(
                previousStage: previousStage ?? '',
                ready: previousProgressReady,
                batch: previousProgressBatch,
                actionInFlight: actionInFlight,
                onScan: onProgressScan,
              ),
              const SizedBox(height: 10),
            ],
            if (showStart)
              FilledButton.icon(
                onPressed: actionInFlight ||
                        (hasMaterialAssignments && !allMaterialsScanned) ||
                        !previousProgressReady
                    ? null
                    : onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Boshlash'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            if (showPause || showComplete) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: actionInFlight ? null : onPause,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Pauza'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: actionInFlight ? null : onComplete,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Tugatish'),
                    ),
                  ),
                ],
              ),
            ],
            if (showResume) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: actionInFlight ? null : onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Davom ettirish'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
            if (showWaitingForPrevious && previousStage != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: scheme.onSurfaceVariant,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Oldingi bosqich tugallanguncha kutilmoqda: $previousStage',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _OrderMapProgressCard extends StatelessWidget {
  const _OrderMapProgressCard({
    required this.steps,
    required this.orderId,
    required this.currentStation,
    required this.queueStates,
    required this.queueStatesByApparatus,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final List<ProductionMapNode> steps;
  final String orderId;
  final String currentStation;
  final Map<String, String> queueStates;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _orderDetailSurfaceCard(
      context: context,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Row(
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    color: scheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mapni ko‘rish',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _orderMapProgressSummary(
                            steps: steps,
                            orderId: orderId,
                            currentStation: currentStation,
                            queueStates: queueStates,
                            queueStatesByApparatus: queueStatesByApparatus,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            for (var index = 0;
                                index < steps.length;
                                index++) ...[
                              _SequenceStepTile(
                                node: steps[index],
                                index: index,
                                isLast: index == steps.length - 1,
                                status: _orderMapNodeStatus(
                                  steps[index],
                                  orderId: orderId,
                                  currentStation: currentStation,
                                  queueStates: queueStates,
                                  queueStatesByApparatus:
                                      queueStatesByApparatus,
                                ),
                                current: _orderMapNodeMatchesStation(
                                  steps[index],
                                  currentStation,
                                ),
                                isDone: _orderMapStepIsDone(
                                  steps: steps,
                                  index: index,
                                  orderId: orderId,
                                  currentStation: currentStation,
                                  queueStates: queueStates,
                                  queueStatesByApparatus:
                                      queueStatesByApparatus,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

ApparatusQueueOrderState? _orderMapNodeStatus(
  ProductionMapNode node, {
  required String orderId,
  required String currentStation,
  required Map<String, String> queueStates,
  required Map<String, Map<String, String>> queueStatesByApparatus,
}) {
  if (node.kind != 'apparatus') {
    return null;
  }
  final station = _orderMapNodeStationTitle(node);
  if (station.isEmpty) {
    return null;
  }
  if (_orderMapNodeMatchesStation(node, currentStation)) {
    return apparatusQueueOrderStateFromRaw(queueStates[orderId]);
  }
  for (final entry in queueStatesByApparatus.entries) {
    if (productionMapWarehouseTitlesMatch(entry.key, station)) {
      return apparatusQueueOrderStateFromRaw(entry.value[orderId]);
    }
  }
  return ApparatusQueueOrderState.pending;
}

bool _orderMapNodeMatchesStation(ProductionMapNode node, String station) {
  return station.trim().isNotEmpty &&
      productionMapWarehouseTitlesMatch(
          _orderMapNodeStationTitle(node), station);
}

int _orderMapCurrentStepIndex(
  List<ProductionMapNode> steps,
  String currentStation,
) {
  if (currentStation.trim().isEmpty) {
    return -1;
  }
  return steps.indexWhere(
    (node) => _orderMapNodeMatchesStation(node, currentStation),
  );
}

bool _orderMapStepIsPast({
  required List<ProductionMapNode> steps,
  required int index,
  required String currentStation,
}) {
  final currentIndex = _orderMapCurrentStepIndex(steps, currentStation);
  return currentIndex >= 0 && index < currentIndex;
}

bool _orderMapStepIsDone({
  required List<ProductionMapNode> steps,
  required int index,
  required String orderId,
  required String currentStation,
  required Map<String, String> queueStates,
  required Map<String, Map<String, String>> queueStatesByApparatus,
}) {
  if (_orderMapStepIsPast(
    steps: steps,
    index: index,
    currentStation: currentStation,
  )) {
    return true;
  }
  final status = _orderMapNodeStatus(
    steps[index],
    orderId: orderId,
    currentStation: currentStation,
    queueStates: queueStates,
    queueStatesByApparatus: queueStatesByApparatus,
  );
  return status == ApparatusQueueOrderState.completed;
}

String _orderMapProgressSummary({
  required List<ProductionMapNode> steps,
  required String orderId,
  required String currentStation,
  required Map<String, String> queueStates,
  required Map<String, Map<String, String>> queueStatesByApparatus,
}) {
  var completed = 0;
  for (var index = 0; index < steps.length; index++) {
    if (_orderMapStepIsDone(
      steps: steps,
      index: index,
      orderId: orderId,
      currentStation: currentStation,
      queueStates: queueStates,
      queueStatesByApparatus: queueStatesByApparatus,
    )) {
      completed++;
    }
  }
  return '$completed / ${steps.length} bosqich';
}

String _orderMapNodeStationTitle(ProductionMapNode node) {
  final assigned = node.alternativeAssignedTitle.trim();
  if (assigned.isNotEmpty) {
    return assigned;
  }
  return node.title.trim();
}

String _apparatusDetailLabel(String apparatus) {
  return productionMapIsLaminatsiyaApparatus(apparatus)
      ? 'Laminatsiya mashinasi'
      : productionMapIsRezkaApparatus(apparatus)
          ? 'Rezka mashinasi'
          : 'Aparat';
}
