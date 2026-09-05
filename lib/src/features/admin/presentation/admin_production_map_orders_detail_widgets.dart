part of 'admin_production_map_orders_screen.dart';

class _ReadOnlyOrderDetailContent extends StatelessWidget {
  const _ReadOnlyOrderDetailContent({
    required this.noticeAnchorKey,
    required this.onClose,
    required this.map,
    required this.orderImageBytes,
    required this.orderImageLoading,
    required this.onViewOrderImage,
    required this.workerMode,
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
    required this.stageStates,
    required this.materialsLoading,
    required this.materialsError,
    required this.materialStartReady,
    required this.materialStartBlockingText,
    required this.actionInFlight,
    required this.materialIntakeInFlight,
    required this.materialIntakeMode,
    required this.intakeCandidatesExpanded,
    required this.onToggleIntakeCandidatesExpanded,
    required this.previousProgressBatch,
    required this.openingWipBatch,
    required this.openingWipBatches,
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
    required this.onTapMapApparatus,
    required this.onMaterialIntake,
    required this.onStart,
    required this.onPause,
    required this.onMerge,
    required this.onRollComplete,
    required this.onComplete,
    required this.onResume,
    required this.orderControlState,
    required this.allowMaterialUnlink,
    required this.onUnlinkMaterial,
    required this.unlinkingMaterialBarcode,
  });
  final GlobalKey noticeAnchorKey;
  final VoidCallback onClose;
  final ProductionMapDefinition map;
  final List<int>? orderImageBytes;
  final bool orderImageLoading;
  final VoidCallback onViewOrderImage;
  final bool workerMode;
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
  final Map<String, String> stageStates;
  final bool materialsLoading;
  final String materialsError;
  final bool materialStartReady;
  final String materialStartBlockingText;
  final bool actionInFlight;
  final bool materialIntakeInFlight;
  final bool materialIntakeMode;
  final bool intakeCandidatesExpanded;
  final VoidCallback onToggleIntakeCandidatesExpanded;
  final AdminProgressBatch? previousProgressBatch;
  final AdminOpeningWipBatch? openingWipBatch;
  final List<AdminOpeningWipBatch> openingWipBatches;
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
  final ValueChanged<ProductionMapNode> onTapMapApparatus;
  final VoidCallback onMaterialIntake;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onMerge;
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
      stageNodeId: uiState.stageNodeId,
      outputKadrCounts: uiState.rezkaOutputKadrCounts,
      l10n: context.l10n,
    );
    final rezkaMergeStateLines = _rezkaMergeStateLines(
      inputLineage: uiState.rezkaInputLineage,
      activePartialRolls: uiState.rezkaActivePartialRolls,
      l10n: context.l10n,
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.86,
      maxChildSize: 0.86,
      builder: (context, controller) {
        return ColoredBox(
          key: noticeAnchorKey,
          color: scheme.surfaceContainerHighest,
          child: Stack(
            children: [
              ListView(
                controller: controller,
                padding: EdgeInsets.fromLTRB(
                  4,
                  workerMode ? 4 : 56,
                  4,
                  24,
                ),
                children: [
                  if (workerMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 14, bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _productionMapOrderImageThumbnail(
                            context: context,
                            imageBytes: orderImageBytes,
                            loading: orderImageLoading,
                            onTap: onViewOrderImage,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${context.l10n.productionText('worker.qr.report.order_number')}:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  Text(
                                    _openedOrderDisplayCode(map).trim().isEmpty
                                        ? '-'
                                        : _openedOrderDisplayCode(map).trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            key: const ValueKey(
                              'production-order-detail-close',
                            ),
                            tooltip: context.l10n
                                .productionText('worker.action.close'),
                            onPressed: onClose,
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  AnimatedSize(
                    key:
                        const ValueKey('production-order-quick-scanner-motion'),
                    duration: AppMotion.medium,
                    curve: AppMotion.standardDecelerate,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: AppMotion.medium,
                      switchInCurve: AppMotion.standardDecelerate,
                      switchOutCurve: AppMotion.standardAccelerate,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SizeTransition(
                          sizeFactor: animation,
                          axisAlignment: -1,
                          child: child,
                        ),
                      ),
                      child: showQuickScanner
                          ? Column(
                              key: const ValueKey(
                                'production-order-quick-scanner-visible',
                              ),
                              children: [
                                ProductionQuickScannerPanel(
                                  statusText: quickScanStatus,
                                  busy: quickScanInFlight,
                                  allowConcurrentDetections:
                                      allowConcurrentQuickScanner,
                                  allowManualEntry: !uiState.openingWipRequired,
                                  onCodeDetected: onQuickScan,
                                ),
                                const SizedBox(height: 10),
                              ],
                            )
                          : const SizedBox(
                              key: ValueKey(
                                'production-order-quick-scanner-hidden',
                              ),
                            ),
                    ),
                  ),
                  _OrderStartUnifiedCard(
                    uiState: uiState,
                    apparatusCatalog: apparatusCatalog,
                    orderCode: _openedOrderDisplayCode(map),
                    orderImageBytes: orderImageBytes,
                    orderImageLoading: orderImageLoading,
                    onViewOrderImage: onViewOrderImage,
                    productTitle: _openedOrderPrimaryTitle(
                      map,
                      l10n: context.l10n,
                    ),
                    customerName: customerName,
                    workerMode: workerMode,
                    showContractWarning: showContractWarning,
                    materialsLoading: materialsLoading,
                    materialsError: materialsError,
                    materialStartReady: materialStartReady,
                    materialStartBlockingText: materialStartBlockingText,
                    actionInFlight: actionInFlight,
                    materialIntakeInFlight: materialIntakeInFlight,
                    materialIntakeMode: materialIntakeMode,
                    intakeCandidatesExpanded: intakeCandidatesExpanded,
                    onToggleIntakeCandidatesExpanded:
                        onToggleIntakeCandidatesExpanded,
                    pauseLabel: pauseLabel,
                    previousProgressBatch: previousProgressBatch,
                    openingWipBatch: openingWipBatch,
                    openingWipBatches: openingWipBatches,
                    inputProgressBatches: inputProgressBatches,
                    inputProgressLoading: inputProgressLoading,
                    inputProgressError: inputProgressError,
                    requiresQolipScan: requiresQolipScan,
                    qolipScanned: qolipScanned,
                    qolipCodes: qolipCodes,
                    requiredQolips: requiredQolips,
                    qolipRequirementsStatusText: qolipRequirementsStatusText,
                    startMaterialsExpanded: startMaterialsExpanded,
                    onToggleStartMaterialsExpanded:
                        onToggleStartMaterialsExpanded,
                    materialsExpanded: materialsExpanded,
                    onToggleMaterialsExpanded: onToggleMaterialsExpanded,
                    qolipsExpanded: qolipsExpanded,
                    onToggleQolipsExpanded: onToggleQolipsExpanded,
                    rezkaInstructionLines: rezkaInstructionLines,
                    rezkaMergeStateLines: rezkaMergeStateLines,
                    onMaterialIntake: onMaterialIntake,
                    onStart: onStart,
                    onPause: onPause,
                    onMerge: onMerge,
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
                    workerMode: workerMode,
                    baseMetraj: baseMetraj,
                    orderKg: orderKg,
                    expanded: summaryExpanded,
                    onToggleExpanded: onToggleSummaryExpanded,
                  ),
                  if (!workerMode || summaryExpanded)
                    const SizedBox(height: 10),
                  _OrderMapProgressCard(
                    workerMode: workerMode,
                    steps: steps,
                    apparatusCatalog: apparatusCatalog,
                    orderId: uiState.orderId,
                    currentStation: uiState.station,
                    queueStates: queueStates,
                    queueStatesByApparatus: queueStatesByApparatus,
                    stageStates: stageStates,
                    currentStageNodeId: uiState.stageNodeId,
                    expanded: workerMode ? summaryExpanded : mapExpanded,
                    onToggleExpanded: onToggleMapExpanded,
                    onTapApparatus: onTapMapApparatus,
                  ),
                ],
              ),
              if (!workerMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton.filledTonal(
                    key: const ValueKey('production-order-detail-close'),
                    tooltip: context.l10n.productionText('worker.action.close'),
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

Widget _productionMapOrderImageThumbnail({
  required BuildContext context,
  required List<int>? imageBytes,
  required bool loading,
  required VoidCallback onTap,
}) {
  final scheme = Theme.of(context).colorScheme;
  final hasImage = imageBytes != null && imageBytes.isNotEmpty;
  final placeholder = Container(
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
  );
  final child = hasImage
      ? ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ImageFade(
            image: MemoryImage(Uint8List.fromList(imageBytes)),
            key: const ValueKey('production-order-detail-photo'),
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            placeholder: placeholder,
            errorBuilder: (_, __) => Icon(
              Icons.broken_image_outlined,
              color: scheme.onSurfaceVariant,
            ),
          ),
        )
      : placeholder;
  return InkWell(
    key: const ValueKey('production-order-detail-photo-thumbnail'),
    borderRadius: BorderRadius.circular(12),
    onTap: loading ? null : onTap,
    child: SizedBox(width: 44, height: 44, child: child),
  );
}

void _showProductionMapOrderImageDialog(
  BuildContext context,
  List<int> imageBytes,
) {
  final image = Uint8List.fromList(imageBytes);
  showDialog<void>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Dialog.fullscreen(
        backgroundColor: scheme.surfaceContainerLowest,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.memory(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image_outlined,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({
    required this.map,
    required this.workerMode,
    this.baseMetraj,
    this.orderKg,
    required this.expanded,
    required this.onToggleExpanded,
  });
  final ProductionMapDefinition map;
  final bool workerMode;
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
                            workerMode
                                ? 'worker.summary.expected.result_title'
                                : 'worker.summary.expected.title',
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
    this.onTap,
  });
  final ProductionMapNode node;
  final String operation;
  final int index;
  final bool isLast;
  final ApparatusQueueOrderState? status;
  final bool current;
  final bool isDone;
  final VoidCallback? onTap;
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
        child: InkWell(
          key: node.kind == 'apparatus'
              ? ValueKey(
                  'production-map-apparatus-${_orderMapNodeStationId(node)}',
                )
              : null,
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: current
                ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
                : EdgeInsets.zero,
            child: content,
          ),
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

class _RezkaMergeStateCard extends StatelessWidget {
  const _RezkaMergeStateCard({required this.lines});
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      key: const ValueKey('production-order-rezka-merge-state'),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 20,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.productionText('worker.merge_state.title'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
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
                  color: scheme.onTertiaryContainer,
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
