part of 'admin_production_map_orders_screen.dart';

class _ReadOnlyOrderDetailContent extends StatelessWidget {
  const _ReadOnlyOrderDetailContent({
    required this.noticeAnchorKey,
    required this.map,
    required this.baseMetraj,
    required this.orderKg,
    required this.customerName,
    required this.steps,
    required this.uiState,
    required this.queueStates,
    required this.queueStatesByApparatus,
    required this.materialsLoading,
    required this.materialsError,
    required this.actionInFlight,
    required this.materialIntakeInFlight,
    required this.materialIntakeMode,
    required this.previousProgressBatch,
    required this.inputProgressBatches,
    required this.inputProgressLoading,
    required this.inputProgressError,
    required this.quickScanStatus,
    required this.quickScanInFlight,
    required this.showQuickScanner,
    required this.onQuickScan,
    required this.summaryExpanded,
    required this.onToggleSummaryExpanded,
    required this.requiresQolipScan,
    required this.qolipScanned,
    required this.qolipCodes,
    required this.requiredQolips,
    required this.qolipRequirementsStatusText,
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
    required this.onComplete,
    required this.onResume,
    required this.orderControlState,
  });

  final GlobalKey noticeAnchorKey;
  final ProductionMapDefinition map;
  final double? baseMetraj;
  final double? orderKg;
  final String? customerName;
  final List<ProductionMapNode> steps;
  final _ReadOnlyOrderDetailUiState uiState;
  final Map<String, String> queueStates;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final bool materialsLoading;
  final String materialsError;
  final bool actionInFlight;
  final bool materialIntakeInFlight;
  final bool materialIntakeMode;
  final AdminProgressBatch? previousProgressBatch;
  final List<AdminProgressBatch> inputProgressBatches;
  final bool inputProgressLoading;
  final String inputProgressError;
  final String quickScanStatus;
  final bool quickScanInFlight;
  final bool showQuickScanner;
  final Future<void> Function(String rawValue) onQuickScan;
  final bool summaryExpanded;
  final VoidCallback onToggleSummaryExpanded;
  final bool requiresQolipScan;
  final bool qolipScanned;
  final List<String> qolipCodes;
  final List<AdminProductionMapRequiredQolip> requiredQolips;
  final String qolipRequirementsStatusText;
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
  final VoidCallback onComplete;
  final VoidCallback onResume;
  final AdminOrderControlState orderControlState;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rezkaInstructionLines = _rezkaWipSplitInstructionLines(
      map: map,
      station: uiState.station,
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
              if (showQuickScanner) ...[
                ProductionQuickScannerPanel(
                  statusText: quickScanStatus,
                  busy: quickScanInFlight,
                  onCodeDetected: onQuickScan,
                ),
                const SizedBox(height: 10),
              ],
              _OrderStartUnifiedCard(
                orderCode: _openedOrderDisplayCode(map),
                productTitle: _openedOrderPrimaryTitle(map),
                customerName: customerName,
                assignments: uiState.materialAssignments,
                materialsLoading: materialsLoading,
                materialsError: materialsError,
                scannedBarcodes: uiState.confirmedMaterialBarcodes,
                scannedCount: uiState.scannedCount,
                showStart: uiState.showStart,
                hasMaterialAssignments: uiState.hasMaterialAssignments,
                allMaterialsScanned: uiState.allMaterialsScanned,
                actionInFlight: actionInFlight,
                materialIntakeInFlight: materialIntakeInFlight,
                materialIntakeMode: materialIntakeMode,
                showPause: uiState.showPause,
                showComplete: uiState.showComplete,
                showResume: uiState.showResume,
                showWaitingForPrevious: uiState.showWaitingForPrevious,
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
                onComplete: onComplete,
                onResume: onResume,
                orderControlState: orderControlState,
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
          label: 'Metraj',
          value: '$roundedMetraj metr',
          icon: Icons.straighten_rounded,
        ),
      );
    }
    final resolvedOrderKg = orderKg ?? map.orderKg;
    if (resolvedOrderKg != null && resolvedOrderKg > 0) {
      rows.add(
        AppInfoRow(
          label: 'Og‘irlik',
          value: '${formatRawQuantity(resolvedOrderKg)} kg',
          icon: Icons.scale_outlined,
        ),
      );
    }
    final rollCount = map.rollCount;
    final widthMm = map.widthMm;
    if (rollCount != null && rollCount > 0) {
      final width = widthMm != null && widthMm > 0
          ? ' ${formatRawQuantity(widthMm)} mm eniga ega bo‘lgan'
          : '';
      rows.add(
        AppInfoRow(
          label: 'Val',
          value: '${formatRawQuantity(rollCount)} ta$width val ishlatiladi',
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
                          'Kutilayotgan buyurtma ko‘rsatkichlari',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Buyurtma bo‘yicha taxminiy ma’lumotlar',
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
    required this.customerName,
    required this.assignments,
    required this.materialsLoading,
    required this.materialsError,
    required this.scannedBarcodes,
    required this.scannedCount,
    required this.showStart,
    required this.hasMaterialAssignments,
    required this.allMaterialsScanned,
    required this.actionInFlight,
    required this.materialIntakeInFlight,
    required this.materialIntakeMode,
    required this.showPause,
    required this.showComplete,
    required this.showResume,
    required this.showWaitingForPrevious,
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
    required this.onComplete,
    required this.onResume,
    required this.orderControlState,
  });

  final String orderCode;
  final String productTitle;
  final String? customerName;
  final List<AdminRawMaterialAssignment> assignments;
  final bool materialsLoading;
  final String materialsError;
  final Set<String> scannedBarcodes;
  final int scannedCount;
  final bool showStart;
  final bool hasMaterialAssignments;
  final bool allMaterialsScanned;
  final bool actionInFlight;
  final bool materialIntakeInFlight;
  final bool materialIntakeMode;
  final bool showPause;
  final bool showComplete;
  final bool showResume;
  final bool showWaitingForPrevious;
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
  final VoidCallback onComplete;
  final VoidCallback onResume;
  final AdminOrderControlState orderControlState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalCount = assignments.length;
    final materialBalances = _rawMaterialBalances(assignments);
    final scannedQolipKeys = qolipCodes
        .map((code) => code.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
    final qolipProgressText = requiredQolips.isEmpty
        ? '${qolipCodes.length} ta'
        : '${qolipCodes.length}/${requiredQolips.length} ta';
    final orderControlBlocked =
        orderControlState != AdminOrderControlState.active;
    final orderFrozen = orderControlState == AdminOrderControlState.frozen;
    final hasActions = showStart ||
        showPause ||
        showComplete ||
        showResume ||
        showWaitingForPrevious;
    final showMaterialIntake = showPause || showResume;
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
                      width: 78,
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
                orderFrozen
                    ? 'Buyurtma muzlatilgan. Admin aktiv qilmaguncha '
                        'davom ettirib bo‘lmaydi.'
                    : 'Admin buyurtmani muzlatishni so‘radi. '
                        'Pauza qiling.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _ScannedItemsExpansionHeader(
            key: const ValueKey('production-materials-expansion'),
            title: 'Biriktirilgan homashyolar',
            countText: materialsLoading ? '...' : '$scannedCount/$totalCount',
            expanded: materialsExpanded,
            complete: totalCount > 0 && scannedCount == totalCount,
            onTap: onToggleMaterialsExpanded,
          ),
          if (materialsExpanded) ...[
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
                  if (materialBalances.isNotEmpty) ...[
                    _RawMaterialBalanceSummary(balances: materialBalances),
                    const SizedBox(height: 10),
                  ],
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
          ],
          if (showStart && requiresQolipScan) ...[
            Divider(
              height: 28,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            _ScannedItemsExpansionHeader(
              key: const ValueKey('production-qolips-expansion'),
              title: 'Qoliplar',
              countText: qolipProgressText,
              expanded: qolipsExpanded,
              complete: qolipScanned,
              onTap: onToggleQolipsExpanded,
            ),
            if (qolipsExpanded) ...[
              const SizedBox(height: 12),
              if (requiredQolips.isEmpty)
                Text(
                  qolipRequirementsStatusText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
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
                    actionInFlight || orderControlBlocked || allMaterialsScanned
                        ? null
                        : onScan,
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
            if (showStart &&
                hasMaterialAssignments &&
                !showEmbeddedQuickScanner)
              const SizedBox(height: 10),
            if (showStart &&
                requiresQolipScan &&
                !showEmbeddedQuickScanner) ...[
              FilledButton.tonalIcon(
                onPressed:
                    actionInFlight || orderControlBlocked ? null : onQolipScan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(
                  qolipCodes.isEmpty
                      ? 'Qolip QR scan'
                      : 'Yana qolip scan qilish ($qolipProgressText)',
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
            if (showStart && previousProgressRequired) ...[
              _PreviousProgressQrTile(
                previousStage: previousStage ?? '',
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
                onPressed: actionInFlight ||
                        materialIntakeInFlight ||
                        orderControlBlocked
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
                      ? 'Scannerni yopish'
                      : 'Yana homashyo olish',
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
                        orderControlBlocked ||
                        (hasMaterialAssignments && !allMaterialsScanned) ||
                        (requiresQolipScan && !qolipScanned) ||
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
                      onPressed: actionInFlight || orderFrozen ? null : onPause,
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
                      onPressed: actionInFlight ||
                              orderControlState != AdminOrderControlState.active
                          ? null
                          : onComplete,
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
                onPressed:
                    actionInFlight || orderControlBlocked ? null : onResume,
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
