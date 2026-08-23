part of 'admin_production_map_orders_screen.dart';

class _ReadOnlyOrderDetailContent extends StatelessWidget {
  const _ReadOnlyOrderDetailContent({
    required this.noticeAnchorKey,
    required this.onBack,
    required this.map,
    required this.apparatusCatalog,
    required this.baseMetraj,
    required this.orderKg,
    required this.customerName,
    required this.steps,
    required this.uiState,
    required this.showContractWarning,
    required this.pauseLabel,
    required this.queueStates,
    required this.queueStatesByApparatus,
    required this.materialsLoading,
    required this.materialsError,
    required this.actionInFlight,
    required this.materialIntakeInFlight,
    required this.materialIntakeMode,
    required this.intakeCandidatesExpanded,
    required this.onToggleIntakeCandidatesExpanded,
    required this.previousProgressBatch,
    required this.inputProgressBatches,
    required this.inputProgressLoading,
    required this.inputProgressError,
    required this.quickScanStatus,
    required this.quickScanInFlight,
    required this.showQuickScanner,
    required this.allowConcurrentQuickScanner,
    required this.onQuickScan,
    required this.summaryExpanded,
    required this.onToggleSummaryExpanded,
    required this.requiresQolipScan,
    required this.qolipScanned,
    required this.qolipCodes,
    required this.requiredQolips,
    required this.qolipRequirementsStatusText,
    required this.startMaterialsExpanded,
    required this.onToggleStartMaterialsExpanded,
    required this.materialsExpanded,
    required this.onToggleMaterialsExpanded,
    required this.qolipsExpanded,
    required this.onToggleQolipsExpanded,
    required this.mapExpanded,
    required this.onToggleMapExpanded,
    required this.onScan,
    required this.onMaterialIntake,
    required this.onProgressScan,
    required this.onQolipScan,
    required this.onStart,
    required this.onPause,
    required this.onRollComplete,
    required this.onComplete,
    required this.onResume,
    required this.orderControlState,
    required this.allowMaterialUnlink,
    required this.onUnlinkMaterial,
    required this.unlinkingMaterialBarcode,
  });

  final GlobalKey noticeAnchorKey;
  final VoidCallback onBack;
  final ProductionMapDefinition map;
  final List<AdminApparatus> apparatusCatalog;
  final double? baseMetraj;
  final double? orderKg;
  final String? customerName;
  final List<ProductionMapNode> steps;
  final _ReadOnlyOrderDetailUiState uiState;
  final bool showContractWarning;
  final String pauseLabel;
  final Map<String, String> queueStates;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final bool materialsLoading;
  final String materialsError;
  final bool actionInFlight;
  final bool materialIntakeInFlight;
  final bool materialIntakeMode;
  final bool intakeCandidatesExpanded;
  final VoidCallback onToggleIntakeCandidatesExpanded;
  final AdminProgressBatch? previousProgressBatch;
  final List<AdminProgressBatch> inputProgressBatches;
  final bool inputProgressLoading;
  final String inputProgressError;
  final String quickScanStatus;
  final bool quickScanInFlight;
  final bool showQuickScanner;
  final bool allowConcurrentQuickScanner;
  final Future<void> Function(String rawValue) onQuickScan;
  final bool summaryExpanded;
  final VoidCallback onToggleSummaryExpanded;
  final bool requiresQolipScan;
  final bool qolipScanned;
  final List<String> qolipCodes;
  final List<AdminProductionMapRequiredQolip> requiredQolips;
  final String qolipRequirementsStatusText;
  final bool startMaterialsExpanded;
  final VoidCallback onToggleStartMaterialsExpanded;
  final bool materialsExpanded;
  final VoidCallback onToggleMaterialsExpanded;
  final bool qolipsExpanded;
  final VoidCallback onToggleQolipsExpanded;
  final bool mapExpanded;
  final VoidCallback onToggleMapExpanded;
  final VoidCallback onScan;
  final VoidCallback onMaterialIntake;
  final VoidCallback? onProgressScan;
  final VoidCallback onQolipScan;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onRollComplete;
  final VoidCallback onComplete;
  final VoidCallback onResume;
  final AdminOrderControlState orderControlState;
  final bool allowMaterialUnlink;
  final void Function(AdminRawMaterialAssignment assignment)? onUnlinkMaterial;
  final String unlinkingMaterialBarcode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rezkaInstructionLines = _rezkaWipSplitInstructionLines(
      map: map,
      station: uiState.station,
      l10n: context.l10n,
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, controller) {
        return ColoredBox(
          key: noticeAnchorKey,
          color: scheme.surfaceContainerHighest,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton.filledTonal(
                  tooltip: context.l10n.productionText(
                    'worker.action.back_to_order',
                  ),
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              if (showQuickScanner) ...[
                ProductionQuickScannerPanel(
                  statusText: quickScanStatus,
                  busy: quickScanInFlight,
                  allowConcurrentDetections: allowConcurrentQuickScanner,
                  onCodeDetected: onQuickScan,
                ),
                const SizedBox(height: 10),
              ],
              _OrderStartUnifiedCard(
                apparatusCatalog: apparatusCatalog,
                orderCode: _openedOrderDisplayCode(map),
                productTitle: _openedOrderPrimaryTitle(
                  map,
                  l10n: context.l10n,
                ),
                customerName: customerName,
                contractSynchronized: uiState.contractSynchronized,
                showContractWarning: showContractWarning,
                blockingReasonCode: uiState.blockingReasonCode,
                showBackendBlockingState: uiState.showBackendBlockingState,
                startAssignments: uiState.materialAssignments,
                intakeCandidateAssignments: uiState.intakeCandidateAssignments,
                assignedAssignments: uiState.assignedMaterialAssignments,
                showStartMaterials: uiState.showStartMaterials,
                showIntakeCandidates: uiState.showIntakeCandidates,
                materialIntakeAllowed: uiState.materialIntakeAllowed,
                materialsLoading: materialsLoading,
                materialsError: materialsError,
                scannedBarcodes: uiState.confirmedMaterialBarcodes,
                scannedCount: uiState.scannedCount,
                requiredCount: uiState.materialRequiredCount,
                showStart: uiState.showStart,
                hasMaterialAssignments: uiState.hasMaterialAssignments,
                allMaterialsScanned: uiState.allMaterialsScanned,
                actionInFlight: actionInFlight,
                materialIntakeInFlight: materialIntakeInFlight,
                materialIntakeMode: materialIntakeMode,
                intakeCandidatesExpanded: intakeCandidatesExpanded,
                onToggleIntakeCandidatesExpanded:
                    onToggleIntakeCandidatesExpanded,
                showPause: uiState.showPause,
                pauseLabel: pauseLabel,
                showRollComplete: uiState.showRollComplete,
                showComplete: uiState.showComplete,
                showResume: uiState.showResume,
                showWaitingForPrevious: uiState.showWaitingForPrevious,
                showWaitingForSequence: uiState.showWaitingForSequence,
                previousStage: uiState.previousStage,
                previousProgressRequired: uiState.previousProgressRequired,
                previousProgressReady: uiState.previousProgressReady,
                previousProgressBatch: previousProgressBatch,
                inputProgressBatches: inputProgressBatches,
                inputProgressLoading: inputProgressLoading,
                inputProgressError: inputProgressError,
                showEmbeddedQuickScanner: showQuickScanner,
                requiresQolipScan: requiresQolipScan,
                qolipScanned: qolipScanned,
                qolipCodes: qolipCodes,
                requiredQolips: requiredQolips,
                qolipRequirementsStatusText: qolipRequirementsStatusText,
                startMaterialsExpanded: startMaterialsExpanded,
                onToggleStartMaterialsExpanded: onToggleStartMaterialsExpanded,
                materialsExpanded: materialsExpanded,
                onToggleMaterialsExpanded: onToggleMaterialsExpanded,
                qolipsExpanded: qolipsExpanded,
                onToggleQolipsExpanded: onToggleQolipsExpanded,
                rezkaInstructionLines: rezkaInstructionLines,
                onScan: onScan,
                onMaterialIntake: onMaterialIntake,
                onProgressScan: onProgressScan,
                onQolipScan: onQolipScan,
                onStart: onStart,
                onPause: onPause,
                onRollComplete: onRollComplete,
                onComplete: onComplete,
                onResume: onResume,
                orderControlState: orderControlState,
                allowMaterialUnlink: allowMaterialUnlink,
                onUnlinkMaterial: onUnlinkMaterial,
                unlinkingMaterialBarcode: unlinkingMaterialBarcode,
              ),
              const SizedBox(height: 10),
              _OrderSummaryCard(
                map: map,
                baseMetraj: baseMetraj,
                orderKg: orderKg,
                expanded: summaryExpanded,
                onToggleExpanded: onToggleSummaryExpanded,
              ),
              const SizedBox(height: 10),
              _OrderMapProgressCard(
                steps: steps,
                apparatusCatalog: apparatusCatalog,
                orderId: uiState.orderId,
                currentStation: uiState.station,
                queueStates: queueStates,
                queueStatesByApparatus: queueStatesByApparatus,
                expanded: mapExpanded,
                onToggleExpanded: onToggleMapExpanded,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.map,
    this.baseMetraj,
    this.orderKg,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final ProductionMapDefinition map;
  final double? baseMetraj;
  final double? orderKg;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rows = <Widget>[];
    final baseLength = baseMetraj ?? map.baseLength;
    if (baseLength != null && baseLength > 0) {
      final roundedMetraj = ((baseLength / 500).ceil() * 500).toString();
      rows.add(
        AppInfoRow(
          label: context.l10n.productionText('worker.summary.length'),
          value: context.l10n.productionText(
            'worker.summary.length_value',
            values: {'value': roundedMetraj},
          ),
          icon: Icons.straighten_rounded,
        ),
      );
    }
    final resolvedOrderKg = orderKg ?? map.orderKg;
    if (resolvedOrderKg != null && resolvedOrderKg > 0) {
      rows.add(
        AppInfoRow(
          label: context.l10n.productionText('worker.summary.weight'),
          value: context.l10n.productionText(
            'worker.summary.weight_value',
            values: {'value': formatRawQuantity(resolvedOrderKg)},
          ),
          icon: Icons.scale_outlined,
        ),
      );
    }
    final rollCount = map.rollCount;
    final widthMm = map.widthMm;
    if (rollCount != null && rollCount > 0) {
      rows.add(
        AppInfoRow(
          label: context.l10n.productionText('worker.summary.shafts'),
          value: context.l10n.productionText(
            'worker.summary.shaft_value',
            values: {
              'count': formatRawQuantity(rollCount),
              'width': widthMm != null && widthMm > 0
                  ? formatRawQuantity(widthMm)
                  : '—',
            },
          ),
          icon: Icons.view_column_outlined,
        ),
      );
    }
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
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
                    Icons.analytics_outlined,
                    color: scheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.productionText(
                            'worker.summary.expected.title',
                          ),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.productionText(
                            'worker.summary.expected.subtitle',
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
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(children: rows),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SequenceStepTile extends StatelessWidget {
  const _SequenceStepTile({
    required this.node,
    required this.operation,
    required this.index,
    required this.isLast,
    required this.status,
    required this.current,
    required this.isDone,
  });

  final ProductionMapNode node;
  final String operation;
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
                      label: context.l10n.productionText(
                        'worker.detail.current_machine',
                      ),
                      foreground: scheme.onPrimaryContainer,
                      background: scheme.primaryContainer,
                    ),
                  ),
                Text(
                  node.title.trim().isEmpty
                      ? context.l10n.productionText(
                          'worker.detail.step',
                          values: {'step': index + 1},
                        )
                      : node.title.trim(),
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
                  _kindLabel(context, node),
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
              label: _statusLabel(context, status!),
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
      'apparatus' => operation == 'laminate'
          ? Icons.layers_outlined
          : operation == 'cut'
              ? Icons.content_cut_outlined
              : Icons.print_outlined,
      _ => Icons.account_tree_outlined,
    };
  }

  Color _statusForeground(ColorScheme scheme) {
    return switch (status) {
      ApparatusQueueOrderState.inProgress => const Color(0xFF8A4B00),
      ApparatusQueueOrderState.paused => const Color(0xFF9B1C1C),
      ApparatusQueueOrderState.frozen => const Color(0xFF1565C0),
      ApparatusQueueOrderState.completed => _completedGreen,
      ApparatusQueueOrderState.pending => scheme.onPrimaryContainer,
      null => scheme.onSurfaceVariant,
    };
  }

  Color _statusBackground(ColorScheme scheme) {
    return switch (status) {
      ApparatusQueueOrderState.inProgress => const Color(0xFFFFECB3),
      ApparatusQueueOrderState.paused => const Color(0xFFFFCDD2),
      ApparatusQueueOrderState.frozen => const Color(0xFFBBDEFB),
      ApparatusQueueOrderState.completed => const Color(0xFFC8E6C9),
      ApparatusQueueOrderState.pending => scheme.primaryContainer,
      null => scheme.surfaceContainerHighest,
    };
  }

  String _statusLabel(
    BuildContext context,
    ApparatusQueueOrderState status,
  ) {
    return switch (status) {
      ApparatusQueueOrderState.inProgress => context.l10n.productionText(
          'worker.queue.status.in_progress',
        ),
      ApparatusQueueOrderState.paused => context.l10n.productionText(
          'worker.queue.status.paused',
        ),
      ApparatusQueueOrderState.frozen => context.l10n.productionText(
          'worker.freeze.active',
        ),
      ApparatusQueueOrderState.completed => context.l10n.productionText(
          'worker.queue.status.completed',
        ),
      ApparatusQueueOrderState.pending => context.l10n.productionText(
          'worker.queue.status.pending',
        ),
    };
  }

  String _kindLabel(BuildContext context, ProductionMapNode node) {
    return switch (node.kind) {
      'start' => context.l10n.productionText('worker.detail.kind.start'),
      'apparatus' => operation == 'laminate'
          ? context.l10n.productionText('worker.detail.kind.lamination')
          : operation == 'cut'
              ? context.l10n.productionText('worker.detail.kind.cutting')
              : context.l10n.productionText('worker.detail.kind.machine'),
      'end' => context.l10n.productionText('worker.detail.kind.end'),
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
    required this.apparatusCatalog,
    required this.orderCode,
    required this.productTitle,
    required this.customerName,
    required this.contractSynchronized,
    required this.showContractWarning,
    required this.blockingReasonCode,
    required this.showBackendBlockingState,
    required this.startAssignments,
    required this.intakeCandidateAssignments,
    required this.assignedAssignments,
    required this.showStartMaterials,
    required this.showIntakeCandidates,
    required this.materialIntakeAllowed,
    required this.materialsLoading,
    required this.materialsError,
    required this.scannedBarcodes,
    required this.scannedCount,
    required this.requiredCount,
    required this.showStart,
    required this.hasMaterialAssignments,
    required this.allMaterialsScanned,
    required this.actionInFlight,
    required this.materialIntakeInFlight,
    required this.materialIntakeMode,
    required this.intakeCandidatesExpanded,
    required this.onToggleIntakeCandidatesExpanded,
    required this.showPause,
    required this.pauseLabel,
    required this.showRollComplete,
    required this.showComplete,
    required this.showResume,
    required this.showWaitingForPrevious,
    required this.showWaitingForSequence,
    required this.previousStage,
    required this.previousProgressRequired,
    required this.previousProgressReady,
    required this.previousProgressBatch,
    required this.inputProgressBatches,
    required this.inputProgressLoading,
    required this.inputProgressError,
    required this.showEmbeddedQuickScanner,
    required this.requiresQolipScan,
    required this.qolipScanned,
    required this.qolipCodes,
    required this.requiredQolips,
    required this.qolipRequirementsStatusText,
    required this.startMaterialsExpanded,
    required this.onToggleStartMaterialsExpanded,
    required this.materialsExpanded,
    required this.onToggleMaterialsExpanded,
    required this.qolipsExpanded,
    required this.onToggleQolipsExpanded,
    required this.rezkaInstructionLines,
    required this.onScan,
    required this.onMaterialIntake,
    required this.onProgressScan,
    required this.onQolipScan,
    required this.onStart,
    required this.onPause,
    required this.onRollComplete,
    required this.onComplete,
    required this.onResume,
    required this.orderControlState,
    required this.allowMaterialUnlink,
    required this.onUnlinkMaterial,
    required this.unlinkingMaterialBarcode,
  });

  final List<AdminApparatus> apparatusCatalog;
  final String orderCode;
  final String productTitle;
  final String? customerName;
  final bool contractSynchronized;
  final bool showContractWarning;
  final String blockingReasonCode;
  final bool showBackendBlockingState;
  final List<AdminRawMaterialAssignment> startAssignments;
  final List<AdminRawMaterialAssignment> intakeCandidateAssignments;
  final List<AdminRawMaterialAssignment> assignedAssignments;
  final bool showStartMaterials;
  final bool showIntakeCandidates;
  final bool materialIntakeAllowed;
  final bool materialsLoading;
  final String materialsError;
  final Set<String> scannedBarcodes;
  final int scannedCount;
  final int requiredCount;
  final bool showStart;
  final bool hasMaterialAssignments;
  final bool allMaterialsScanned;
  final bool actionInFlight;
  final bool materialIntakeInFlight;
  final bool materialIntakeMode;
  final bool intakeCandidatesExpanded;
  final VoidCallback onToggleIntakeCandidatesExpanded;
  final bool showPause;
  final String pauseLabel;
  final bool showRollComplete;
  final bool showComplete;
  final bool showResume;
  final bool showWaitingForPrevious;
  final bool showWaitingForSequence;
  final String? previousStage;
  final bool previousProgressRequired;
  final bool previousProgressReady;
  final AdminProgressBatch? previousProgressBatch;
  final List<AdminProgressBatch> inputProgressBatches;
  final bool inputProgressLoading;
  final String inputProgressError;
  final bool showEmbeddedQuickScanner;
  final bool requiresQolipScan;
  final bool qolipScanned;
  final List<String> qolipCodes;
  final List<AdminProductionMapRequiredQolip> requiredQolips;
  final String qolipRequirementsStatusText;
  final bool startMaterialsExpanded;
  final VoidCallback onToggleStartMaterialsExpanded;
  final bool materialsExpanded;
  final VoidCallback onToggleMaterialsExpanded;
  final bool qolipsExpanded;
  final VoidCallback onToggleQolipsExpanded;
  final List<String> rezkaInstructionLines;
  final VoidCallback onScan;
  final VoidCallback onMaterialIntake;
  final VoidCallback? onProgressScan;
  final VoidCallback onQolipScan;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onRollComplete;
  final VoidCallback onComplete;
  final VoidCallback onResume;
  final AdminOrderControlState orderControlState;
  final bool allowMaterialUnlink;
  final void Function(AdminRawMaterialAssignment assignment)? onUnlinkMaterial;
  final String unlinkingMaterialBarcode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scannedQolipKeys = qolipCodes
        .map((code) => code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    final qolipProgressText = requiredQolips.isEmpty
        ? context.l10n.productionCount(qolipCodes.length, kind: 'molds')
        : context.l10n.productionText(
            'worker.mold.progress',
            values: {
              'scanned': qolipCodes.length,
              'required': requiredQolips.length,
            },
          );
    final orderControlBlocked =
        orderControlState != AdminOrderControlState.active;
    final hasActions = showStart ||
        showPause ||
        showRollComplete ||
        showComplete ||
        showResume ||
        showWaitingForPrevious ||
        showWaitingForSequence;
    final showContractSyncNotice = showContractWarning && !contractSynchronized;
    final showBackendBlockingNotice = showBackendBlockingState &&
        !orderControlBlocked &&
        !showWaitingForPrevious &&
        !showWaitingForSequence;
    final backendBlockingText = switch (blockingReasonCode.trim()) {
      'raw_material_assignment_required' => context.l10n.productionText(
          'worker.error.incomplete_material_groups',
        ),
      'order_frozen' => context.l10n.productionText('worker.freeze.active'),
      _ => context.l10n.productionText('worker.error.sync'),
    };
    final showRezkaInputProgressScan = previousProgressRequired && showStart;
    final showMaterialIntake = materialIntakeAllowed;
    final attachedMaterialsExpandable = materialsLoading ||
        materialsError.trim().isNotEmpty ||
        assignedAssignments.isNotEmpty;
    final qolipsExpandable = requiredQolips.isNotEmpty;
    final customer = customerName?.trim() ?? '';
    final product = productTitle.trim();
    final orderProductLabel = customer.isEmpty
        ? product
        : product.isEmpty
            ? customer
            : '$customer • $product';

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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 94,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.productionText('worker.order.code'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            orderCode.trim().isEmpty ? '-' : orderCode.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(
                          orderProductLabel.isEmpty ? '-' : orderProductLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(
              height: 28, color: scheme.outlineVariant.withValues(alpha: 0.5)),
          if (orderControlBlocked) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                orderControlState == AdminOrderControlState.frozen
                    ? context.l10n.productionText('worker.freeze.active')
                    : context.l10n.productionText('worker.freeze.requested'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showContractSyncNotice) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                context.l10n.productionText('worker.error.sync'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showBackendBlockingNotice) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                backendBlockingText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showStartMaterials) ...[
            _ScannedItemsExpansionHeader(
              key: const ValueKey('production-start-materials-expansion'),
              title: context.l10n.productionText(
                'worker.materials.start',
              ),
              countText:
                  materialsLoading ? '...' : '$scannedCount/$requiredCount',
              expanded: startMaterialsExpanded,
              complete: requiredCount > 0 && allMaterialsScanned,
              onTap: onToggleStartMaterialsExpanded,
            ),
            if (startMaterialsExpanded) ...[
              const SizedBox(height: 12),
              _RawMaterialAssignmentsExpansionBody(
                assignments: startAssignments,
                apparatusCatalog: apparatusCatalog,
                loading: materialsLoading,
                error: materialsError,
                emptyText: context.l10n.productionText(
                  'worker.materials.start.empty',
                ),
                scannedBarcodes: scannedBarcodes,
                allowUnlink: allowMaterialUnlink,
                onUnlink: onUnlinkMaterial,
                unlinkingBarcode: unlinkingMaterialBarcode,
              ),
            ],
            Divider(
              height: 28,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ] else if (showIntakeCandidates) ...[
            _ScannedItemsExpansionHeader(
              key: const ValueKey('production-intake-materials-expansion'),
              title: context.l10n.productionText(
                'worker.materials.pending',
              ),
              countText: materialsLoading
                  ? '...'
                  : context.l10n.productionCount(
                      intakeCandidateAssignments.length,
                      kind: 'materials',
                    ),
              expanded: intakeCandidatesExpanded,
              complete: false,
              onTap: onToggleIntakeCandidatesExpanded,
            ),
            if (intakeCandidatesExpanded) ...[
              const SizedBox(height: 12),
              _RawMaterialAssignmentsExpansionBody(
                assignments: intakeCandidateAssignments,
                apparatusCatalog: apparatusCatalog,
                loading: materialsLoading,
                error: materialsError,
                emptyText: context.l10n.productionText(
                  'worker.materials.pending.empty',
                ),
                scannedBarcodes: const {},
                allowUnlink: allowMaterialUnlink,
                onUnlink: onUnlinkMaterial,
                unlinkingBarcode: unlinkingMaterialBarcode,
              ),
            ],
            Divider(
              height: 28,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ],
          _ScannedItemsExpansionHeader(
            key: const ValueKey('production-materials-expansion'),
            title: context.l10n.productionText(
              attachedMaterialsExpandable
                  ? 'worker.materials.attached'
                  : 'worker.materials.attached.empty',
            ),
            countText: materialsLoading
                ? '...'
                : context.l10n.productionCount(
                    assignedAssignments.length,
                    kind: 'materials',
                  ),
            expanded: attachedMaterialsExpandable && materialsExpanded,
            complete: false,
            onTap:
                attachedMaterialsExpandable ? onToggleMaterialsExpanded : null,
          ),
          if (attachedMaterialsExpandable && materialsExpanded) ...[
            const SizedBox(height: 12),
            _RawMaterialAssignmentsExpansionBody(
              assignments: assignedAssignments,
              apparatusCatalog: apparatusCatalog,
              loading: materialsLoading,
              error: materialsError,
              emptyText: context.l10n.productionText(
                'worker.materials.attached.empty',
              ),
              scannedBarcodes: scannedBarcodes,
              allowUnlink: allowMaterialUnlink,
              onUnlink: onUnlinkMaterial,
              unlinkingBarcode: unlinkingMaterialBarcode,
            ),
          ],
          if (showStart && requiresQolipScan) ...[
            Divider(
              height: 28,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            _ScannedItemsExpansionHeader(
              key: const ValueKey('production-qolips-expansion'),
              title: qolipsExpandable
                  ? context.l10n.productionText('worker.molds')
                  : qolipRequirementsStatusText,
              countText: qolipProgressText,
              expanded: qolipsExpandable && qolipsExpanded,
              complete: qolipScanned,
              onTap: qolipsExpandable ? onToggleQolipsExpanded : null,
            ),
            if (qolipsExpandable && qolipsExpanded) ...[
              const SizedBox(height: 12),
              Column(
                children: [
                  for (var index = 0;
                      index < requiredQolips.length;
                      index++) ...[
                    if (index > 0) const SizedBox(height: 8),
                    _ScannedQolipTile(
                      qolip: requiredQolips[index],
                      scanned: scannedQolipKeys.contains(
                        requiredQolips[index].qolipCode.trim().toLowerCase(),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
          if (hasActions) ...[
            Divider(
                height: 28,
                color: scheme.outlineVariant.withValues(alpha: 0.5)),
            if (showStart &&
                hasMaterialAssignments &&
                !showEmbeddedQuickScanner)
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
                      ? context.l10n.productionText(
                          'worker.action.material_confirmed',
                        )
                      : context.l10n.productionText(
                          'worker.action.scan_material',
                        ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            if (showStart &&
                hasMaterialAssignments &&
                !showEmbeddedQuickScanner)
              const SizedBox(height: 10),
            if (showStart &&
                requiresQolipScan &&
                !showEmbeddedQuickScanner) ...[
              FilledButton.tonalIcon(
                onPressed: actionInFlight ? null : onQolipScan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(
                  qolipCodes.isEmpty
                      ? context.l10n.productionText(
                          'worker.action.scan_mold',
                        )
                      : context.l10n.productionText(
                          'worker.action.scan_more_molds',
                          values: {'progress': qolipProgressText},
                        ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (showRezkaInputProgressScan) ...[
              _PreviousProgressQrTile(
                previousStage: previousStage ?? '',
                apparatusCatalog: apparatusCatalog,
                ready: previousProgressReady,
                batch: previousProgressBatch,
                availableBatches: inputProgressBatches,
                loading: inputProgressLoading,
                error: inputProgressError,
                actionInFlight: actionInFlight,
                embeddedScanner: showEmbeddedQuickScanner,
                onScan: onProgressScan,
              ),
              const SizedBox(height: 10),
            ],
            if (showMaterialIntake) ...[
              FilledButton.tonalIcon(
                key: const ValueKey('receive-additional-raw-material'),
                onPressed: actionInFlight || materialIntakeInFlight
                    ? null
                    : onMaterialIntake,
                icon: materialIntakeInFlight
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        materialIntakeMode
                            ? Icons.close_rounded
                            : Icons.add_box_outlined,
                      ),
                label: Text(
                  materialIntakeMode
                      ? context.l10n.productionText(
                          'worker.action.close_scanner',
                        )
                      : context.l10n.productionText(
                          'worker.action.receive_material',
                        ),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (rezkaInstructionLines.isNotEmpty) ...[
              _RezkaWipSplitInstruction(lines: rezkaInstructionLines),
              const SizedBox(height: 10),
            ],
            if (showStart)
              FilledButton.icon(
                onPressed: actionInFlight ||
                        (hasMaterialAssignments && !allMaterialsScanned) ||
                        (requiresQolipScan && !qolipScanned) ||
                        !previousProgressReady
                    ? null
                    : onStart,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  context.l10n.productionText('worker.action.start'),
                ),
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
                  if (showPause)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: actionInFlight ? null : onPause,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(pauseLabel),
                      ),
                    ),
                  if (showPause && showComplete) const SizedBox(width: 10),
                  if (showComplete)
                    Expanded(
                      child: FilledButton(
                        onPressed: actionInFlight ? null : onComplete,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          context.l10n.productionText('worker.action.complete'),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (showRollComplete) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: actionInFlight ? null : onRollComplete,
                icon: const Icon(Icons.call_made_rounded),
                label: Text(
                  context.l10n.productionText('worker.action.roll_complete'),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
            if (showResume) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: actionInFlight ? null : onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(
                  context.l10n.productionText('worker.action.resume'),
                ),
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
                      context.l10n.productionText(
                        'worker.waiting.previous',
                        values: {
                          'stage': canonicalApparatusDisplayLabel(
                            previousStage!,
                            apparatusCatalog,
                          ),
                        },
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (showWaitingForSequence) ...[
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
                      context.l10n.productionText('worker.waiting.sequence'),
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

class _RawMaterialAssignmentsExpansionBody extends StatelessWidget {
  const _RawMaterialAssignmentsExpansionBody({
    required this.assignments,
    required this.apparatusCatalog,
    required this.loading,
    required this.error,
    required this.emptyText,
    required this.scannedBarcodes,
    required this.allowUnlink,
    required this.onUnlink,
    required this.unlinkingBarcode,
  });

  final List<AdminRawMaterialAssignment> assignments;
  final List<AdminApparatus> apparatusCatalog;
  final bool loading;
  final String error;
  final String emptyText;
  final Set<String> scannedBarcodes;
  final bool allowUnlink;
  final void Function(AdminRawMaterialAssignment assignment)? onUnlink;
  final String unlinkingBarcode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (loading) {
      return Row(
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
            context.l10n.loading,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    if (error.trim().isNotEmpty) {
      return Text(
        error,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.error,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (assignments.isEmpty) {
      return Text(
        emptyText,
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final balances = _rawMaterialBalances(assignments);
    final role = AppSession.instance.profile?.role;
    final groupedAssignments =
        role == UserRole.admin || role == UserRole.materialTaminotchi
            ? _adminRawMaterialAssignmentGroups(
                assignments,
                apparatusCatalog,
              )
            : [
                _AdminRawMaterialAssignmentGroup(
                  label: '',
                  assignments: assignments,
                ),
              ];
    return Column(
      children: [
        if (balances.isNotEmpty) ...[
          _RawMaterialBalanceSummary(balances: balances),
          const SizedBox(height: 10),
        ],
        for (var groupIndex = 0;
            groupIndex < groupedAssignments.length;
            groupIndex++) ...[
          if (groupIndex > 0) const SizedBox(height: 14),
          if (groupedAssignments[groupIndex].label.isNotEmpty) ...[
            _AdminRawMaterialAssignmentGroupHeader(
              label: groupedAssignments[groupIndex].label,
              count: groupedAssignments[groupIndex].assignments.length,
            ),
            const SizedBox(height: 8),
          ],
          for (var index = 0;
              index < groupedAssignments[groupIndex].assignments.length;
              index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _AssignedMaterialTile(
              assignment: groupedAssignments[groupIndex].assignments[index],
              scanned: scannedBarcodes.contains(
                groupedAssignments[groupIndex]
                    .assignments[index]
                    .barcode
                    .trim()
                    .toUpperCase(),
              ),
              allowUnlink: allowUnlink,
              onUnlink: onUnlink == null
                  ? null
                  : () => onUnlink!(
                        groupedAssignments[groupIndex].assignments[index],
                      ),
              unlinking: unlinkingBarcode ==
                  groupedAssignments[groupIndex]
                      .assignments[index]
                      .barcode
                      .trim()
                      .toUpperCase(),
            ),
          ],
        ],
      ],
    );
  }
}

class _AdminRawMaterialAssignmentGroup {
  const _AdminRawMaterialAssignmentGroup({
    required this.label,
    required this.assignments,
  });

  final String label;
  final List<AdminRawMaterialAssignment> assignments;
}

List<_AdminRawMaterialAssignmentGroup> _adminRawMaterialAssignmentGroups(
  List<AdminRawMaterialAssignment> assignments,
  List<AdminApparatus> apparatusCatalog,
) {
  final grouped = <String, List<AdminRawMaterialAssignment>>{};
  for (final assignment in assignments) {
    final label = _adminRawMaterialAssignmentGroupLabel(
      assignment.apparatus,
      apparatusCatalog,
    );
    grouped.putIfAbsent(label, () => []).add(assignment);
  }
  final entries = grouped.entries.toList()
    ..sort(
      (left, right) => _adminRawMaterialAssignmentGroupRank(left.key)
          .compareTo(_adminRawMaterialAssignmentGroupRank(right.key)),
    );
  return [
    for (final entry in entries)
      _AdminRawMaterialAssignmentGroup(
        label: entry.key,
        assignments: List<AdminRawMaterialAssignment>.unmodifiable(
          entry.value,
        ),
      ),
  ];
}

String _adminRawMaterialAssignmentGroupLabel(
  String apparatusId,
  List<AdminApparatus> apparatusCatalog,
) {
  final normalized = apparatusId.trim();
  final apparatus = _canonicalApparatusForId(apparatusCatalog, normalized);
  final operation = apparatus?.operation.trim().toLowerCase();
  if (operation == 'print') {
    return 'Bosma uchun biriktirilgan';
  }
  if (operation == 'laminate') {
    return 'Laminatsiya uchun biriktirilgan';
  }
  if (operation == 'cut') {
    return 'Rezka uchun biriktirilgan';
  }
  final displayTitle = apparatus?.name.trim() ?? '';
  return normalized.isEmpty
      ? 'Bosqichi ko‘rsatilmagan homashyolar'
      : '${displayTitle.isEmpty ? normalized : displayTitle} uchun biriktirilgan';
}

int _adminRawMaterialAssignmentGroupRank(String label) {
  return switch (label) {
    'Bosma uchun biriktirilgan' => 0,
    'Laminatsiya uchun biriktirilgan' => 1,
    'Rezka uchun biriktirilgan' => 2,
    _ => 3,
  };
}

String _localizedRawMaterialGroupLabel(BuildContext context, String label) {
  return switch (label) {
    'Bosma uchun biriktirilgan' => context.l10n.productionText(
        'worker.material.group.print',
      ),
    'Laminatsiya uchun biriktirilgan' => context.l10n.productionText(
        'worker.material.group.lamination',
      ),
    'Rezka uchun biriktirilgan' => context.l10n.productionText(
        'worker.material.group.cutting',
      ),
    'Bosqichi ko‘rsatilmagan homashyolar' => context.l10n.productionText(
        'worker.material.group.unknown',
      ),
    _ => label.endsWith(' uchun biriktirilgan')
        ? context.l10n.productionText(
            'worker.material.group.dynamic',
            values: {
              'apparatus': label.substring(
                0,
                label.length - ' uchun biriktirilgan'.length,
              ),
            },
          )
        : label,
  };
}

class _AdminRawMaterialAssignmentGroupHeader extends StatelessWidget {
  const _AdminRawMaterialAssignmentGroupHeader({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.layers_outlined,
            size: 20,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _localizedRawMaterialGroupLabel(context, label),
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            context.l10n.productionCount(count, kind: 'materials'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RezkaWipSplitInstruction extends StatelessWidget {
  const _RezkaWipSplitInstruction({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.content_cut_rounded,
                  size: 20,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Map bo‘yicha rezka',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < lines.length; index++) ...[
              if (index > 0) const SizedBox(height: 4),
              Text(
                lines[index],
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: index == 0 ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
