part of 'admin_production_map_orders_screen.dart';

class _OpenedOrderList extends StatelessWidget {
  const _OpenedOrderList({
    required this.orders,
    required this.customerNameByMapId,
    required this.orderStatusesByOrderId,
    required this.orderControlsByOrderId,
    required this.queueStatesByApparatus,
    required this.visibleOrderIdsByApparatus,
    required this.onInfoOrder,
    required this.onLongPressOrder,
  });

  final List<ProductionMapSaved> orders;
  final Map<String, String> customerNameByMapId;
  final Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId;
  final Map<String, AdminOrderControlState> orderControlsByOrderId;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final Map<String, List<String>> visibleOrderIdsByApparatus;
  final ValueChanged<ProductionMapSaved> onInfoOrder;
  final ValueChanged<ProductionMapSaved> onLongPressOrder;

  @override
  Widget build(BuildContext context) {
    final orderActivityStates = queueActivityStatesForOrders(
      orderIds: orders.map((order) => order.map.id),
      queueStatesByApparatus: queueStatesByApparatus,
      visibleOrderIdsByApparatus: visibleOrderIdsByApparatus,
    );
    final l10n = context.l10n;
    final children = <Widget>[];
    for (var index = 0; index < orders.length; index++) {
      final order = orders[index];
      final orderId = order.map.id.trim();
      final tone = _resolveOrderCardTone(
        orderStatus: orderStatusesByOrderId[orderId],
        orderControl: adminProductionMapOrderControlFor(
          orderControlsByOrderId,
          orderId,
        ),
        orderActivityState: orderActivityStates[orderId],
      );
      children.add(
        _OpenedOrderRow(
          key: ValueKey('opened-order-$orderId'),
          slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
            index,
            orders.length,
          ),
          order: order,
          customerName: customerNameByMapId[orderId] ?? '',
          watermarks: _orderWatermarks(
            order: order,
            tone: tone,
            queueStatesByApparatus: queueStatesByApparatus,
            l10n: l10n,
          ),
          tone: tone,
          onInfo: () => onInfoOrder(order),
          onLongPress: () => onLongPressOrder(order),
        ),
      );
    }
    return M3SegmentSpacedColumn(
      children: children,
    );
  }
}

class _OpenedOrderRow extends StatelessWidget {
  const _OpenedOrderRow({
    super.key,
    required this.slot,
    required this.order,
    required this.customerName,
    required this.watermarks,
    required this.tone,
    required this.onInfo,
    required this.onLongPress,
  });

  final M3SegmentVerticalSlot slot;
  final ProductionMapSaved order;
  final String customerName;
  final List<_OrderWatermarkData> watermarks;
  final _OrderCardTone tone;
  final VoidCallback onInfo;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = order.map;
    final subtitle = _openedOrderSubtitle(
      map,
      customerName: customerName,
      includeApparatusCount: true,
      l10n: context.l10n,
    );

    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      backgroundColor: _orderCardBackgroundColor(context, tone),
      child: InkWell(
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (watermarks.isNotEmpty)
              Positioned.fill(
                child: _OrderWatermark(
                  key: ValueKey(
                    'opened-order-active-watermark-${map.id.trim()}',
                  ),
                  apparatuses: watermarks,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _OpenedOrderTitleLine(
                          map: map,
                          theme: theme,
                          scheme: scheme,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.05,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.productionText('worker.order.info'),
                    onPressed: onInfo,
                    icon: Icon(
                      Icons.info_outline_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderWatermarkData {
  const _OrderWatermarkData({
    required this.label,
  });

  final String label;
}

List<_OrderWatermarkData> _activeApparatusWatermarks({
  required ProductionMapSaved order,
  required Map<String, Map<String, String>> queueStatesByApparatus,
}) {
  final orderId = order.map.id.trim();
  if (orderId.isEmpty) {
    return const [];
  }
  final seen = <String>{};
  final active = <_OrderWatermarkData>[];
  for (final stage in productionMapLinearWorkStages(order.map)) {
    final apparatusId = stage.apparatusId?.trim() ?? '';
    if (apparatusId.isEmpty || !seen.add(apparatusId)) {
      continue;
    }
    final rawState = queueStatesByApparatus[apparatusId]?[orderId];
    if (apparatusQueueOrderStateFromRaw(rawState) !=
        ApparatusQueueOrderState.inProgress) {
      continue;
    }
    final label = stage.displayTitle.trim().isNotEmpty
        ? stage.displayTitle.trim()
        : apparatusId;
    active.add(
      _OrderWatermarkData(
        label: label,
      ),
    );
  }
  return List.unmodifiable(active);
}

List<_OrderWatermarkData> _orderWatermarks({
  required ProductionMapSaved order,
  required _OrderCardTone tone,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required AppLocalizations l10n,
}) {
  return switch (tone) {
    _OrderCardTone.inProgress => _activeApparatusWatermarks(
        order: order,
        queueStatesByApparatus: queueStatesByApparatus,
      ),
    _OrderCardTone.waitingNextStage => _waitingNextStageWatermarks(
        order: order,
        queueStatesByApparatus: queueStatesByApparatus,
        l10n: l10n,
      ),
    _OrderCardTone.paused => _stageStatusWatermarks(
        order: order,
        queueStatesByApparatus: queueStatesByApparatus,
        l10n: l10n,
        targetState: ApparatusQueueOrderState.paused,
        statusKey: 'orders.watermark.paused',
      ),
    _OrderCardTone.frozen => _stageStatusWatermarks(
        order: order,
        queueStatesByApparatus: queueStatesByApparatus,
        l10n: l10n,
        targetState: ApparatusQueueOrderState.frozen,
        statusKey: 'orders.watermark.frozen',
      ),
    _OrderCardTone.issue => _stageStatusWatermarks(
        order: order,
        queueStatesByApparatus: queueStatesByApparatus,
        l10n: l10n,
        targetState: ApparatusQueueOrderState.frozen,
        statusKey: 'orders.watermark.issue',
      ),
    _OrderCardTone.neutral || _OrderCardTone.completed => const [],
  };
}

List<_OrderWatermarkData> _waitingNextStageWatermarks({
  required ProductionMapSaved order,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required AppLocalizations l10n,
}) {
  final orderId = order.map.id.trim();
  if (orderId.isEmpty) {
    return const [];
  }
  final seen = <String>{};
  var completedSeen = false;
  for (final stage in productionMapLinearWorkStages(order.map)) {
    final apparatusId = stage.apparatusId?.trim() ?? '';
    if (apparatusId.isEmpty || !seen.add(apparatusId)) {
      continue;
    }
    final state = apparatusQueueOrderStateFromRaw(
      queueStatesByApparatus[apparatusId]?[orderId],
    );
    if (state == ApparatusQueueOrderState.completed) {
      completedSeen = true;
      continue;
    }
    if (completedSeen && state == ApparatusQueueOrderState.pending) {
      final label = _stageApparatusLabel(stage, apparatusId);
      return [
        _OrderWatermarkData(
          label: l10n.adminText(
            'orders.watermark.waiting',
            values: {'apparatus': label},
          ),
        ),
      ];
    }
  }
  return [
    _OrderWatermarkData(
      label: l10n.adminText('orders.watermark.waiting_generic'),
    ),
  ];
}

List<_OrderWatermarkData> _stageStatusWatermarks({
  required ProductionMapSaved order,
  required Map<String, Map<String, String>> queueStatesByApparatus,
  required AppLocalizations l10n,
  required ApparatusQueueOrderState targetState,
  required String statusKey,
}) {
  final orderId = order.map.id.trim();
  if (orderId.isEmpty) {
    return const [];
  }
  final seen = <String>{};
  final matchingLabels = <String>[];
  final unfinishedLabels = <String>[];
  final allLabels = <String>[];
  for (final stage in productionMapLinearWorkStages(order.map)) {
    final apparatusId = stage.apparatusId?.trim() ?? '';
    if (apparatusId.isEmpty || !seen.add(apparatusId)) {
      continue;
    }
    final label = _stageApparatusLabel(stage, apparatusId);
    allLabels.add(label);
    final state = apparatusQueueOrderStateFromRaw(
      queueStatesByApparatus[apparatusId]?[orderId],
    );
    if (state == targetState) {
      matchingLabels.add(label);
    } else if (state != ApparatusQueueOrderState.completed) {
      unfinishedLabels.add(label);
    }
  }
  final labels = matchingLabels.isNotEmpty
      ? matchingLabels
      : unfinishedLabels.isNotEmpty
          ? [unfinishedLabels.first]
          : allLabels.isNotEmpty
              ? [allLabels.first]
              : <String>[];
  if (labels.isEmpty) {
    return [
      _OrderWatermarkData(
        label: l10n.adminText(statusKey),
      ),
    ];
  }
  return [
    for (final label in labels)
      _OrderWatermarkData(
        label: l10n.adminText(
          statusKey,
          values: {'apparatus': label},
        ),
      ),
  ];
}

String _stageApparatusLabel(
  ProductionMapChainStage stage,
  String apparatusId,
) {
  final displayTitle = stage.displayTitle.trim();
  return displayTitle.isNotEmpty ? displayTitle : apparatusId;
}

class _OrderWatermark extends StatelessWidget {
  const _OrderWatermark({
    super.key,
    required this.apparatuses,
  });

  final List<_OrderWatermarkData> apparatuses;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                for (final apparatus in apparatuses)
                  Expanded(
                    child: _OrderWatermarkLane(
                      apparatus: apparatus,
                      availableWidth: constraints.maxWidth /
                          (apparatuses.isEmpty ? 1 : apparatuses.length),
                      availableHeight: constraints.maxHeight,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderWatermarkLane extends StatelessWidget {
  const _OrderWatermarkLane({
    required this.apparatus,
    required this.availableWidth,
    required this.availableHeight,
  });

  final _OrderWatermarkData apparatus;
  final double availableWidth;
  final double availableHeight;

  @override
  Widget build(BuildContext context) {
    final stampSize = _watermarkStampSize(context, apparatus);
    final columns = _watermarkRepeatCount(
      availableWidth: availableWidth,
      itemSize: stampSize.width,
      maxCount: _maxWatermarkColumns,
    );
    final repeatCount = columns;
    final horizontalPitch = stampSize.width + _watermarkHorizontalGap;
    final occupiedWidth = stampSize.width * repeatCount +
        _watermarkHorizontalGap * (repeatCount - 1);
    final startX = (availableWidth - occupiedWidth) / 2;
    final maxStartY =
        (availableHeight - stampSize.height).clamp(0.0, double.infinity);
    final startY = ((availableHeight - stampSize.height) / 2)
        .clamp(0.0, maxStartY)
        .toDouble();
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var index = 0; index < repeatCount; index++)
            Positioned.fromRect(
              rect: Rect.fromLTWH(
                startX + horizontalPitch * index,
                startY,
                stampSize.width,
                stampSize.height,
              ),
              child: Center(
                child: _OrderWatermarkStamp(apparatus: apparatus),
              ),
            ),
        ],
      ),
    );
  }
}

const _watermarkHorizontalGap = 8.0;
const _maxWatermarkColumns = 4;
const _watermarkRotationAngle = -0.035;

int _watermarkRepeatCount({
  required double availableWidth,
  required double itemSize,
  required int maxCount,
}) {
  if (!availableWidth.isFinite ||
      availableWidth <= 0 ||
      !itemSize.isFinite ||
      itemSize <= 0) {
    return 1;
  }
  return ((availableWidth + _watermarkHorizontalGap) /
          (itemSize + _watermarkHorizontalGap))
      .floor()
      .clamp(1, maxCount);
}

Size _watermarkStampSize(
  BuildContext context,
  _OrderWatermarkData apparatus,
) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: apparatus.label,
      style: _orderWatermarkTextStyle(context),
    ),
    maxLines: 1,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final rowHeight = textPainter.height;
  final rowWidth = textPainter.width;
  final angle = _watermarkRotationAngle.abs();
  final rotatedWidth = rowWidth * cos(angle) + rowHeight * sin(angle);
  final rotatedHeight = rowWidth * sin(angle) + rowHeight * cos(angle);
  return Size(
    rotatedWidth,
    rotatedHeight,
  );
}

TextStyle? _orderWatermarkTextStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Theme.of(context).textTheme.titleSmall?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      );
}

class _OrderWatermarkStamp extends StatelessWidget {
  const _OrderWatermarkStamp({required this.apparatus});

  final _OrderWatermarkData apparatus;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.10,
      child: Transform.rotate(
        angle: _watermarkRotationAngle,
        child: Text(
          apparatus.label,
          maxLines: 1,
          style: _orderWatermarkTextStyle(context),
        ),
      ),
    );
  }
}

class _OpenedOrderCardRow extends StatelessWidget {
  const _OpenedOrderCardRow({
    required this.slot,
    required this.order,
    required this.leading,
    required this.trailing,
    this.onTap,
    this.borderRadiusOverride,
    this.disabled = false,
  });

  final M3SegmentVerticalSlot slot;
  final ProductionMapSaved order;
  final Widget leading;
  final Widget trailing;
  final VoidCallback? onTap;
  final BorderRadius? borderRadiusOverride;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = order.map;
    final subtitle = _openedOrderSubtitle(map, l10n: context.l10n);

    return M3SegmentFilledSurface(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      borderRadiusOverride: borderRadiusOverride,
      backgroundColor: disabled ? scheme.surfaceContainerHighest : null,
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.48 : 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              leading,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _OpenedOrderTitleLine(
                      map: map,
                      theme: theme,
                      scheme: scheme,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _OpenedOrderTitleLine extends StatelessWidget {
  const _OpenedOrderTitleLine({
    required this.map,
    required this.theme,
    required this.scheme,
    this.titleColor,
    this.secondaryColor,
  });

  final ProductionMapDefinition map;
  final ThemeData theme;
  final ColorScheme scheme;
  final Color? titleColor;
  final Color? secondaryColor;

  @override
  Widget build(BuildContext context) {
    final code = _openedOrderDisplayCode(map);
    final title = _openedOrderPrimaryTitle(map, l10n: context.l10n);
    final resolvedTitleStyle = theme.textTheme.titleMedium?.copyWith(
      color: titleColor,
      fontWeight: FontWeight.w700,
    );
    final resolvedCodeStyle = theme.textTheme.labelMedium?.copyWith(
      color: secondaryColor ?? scheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    );
    if (code.isEmpty) {
      return Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: resolvedTitleStyle,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: code, style: resolvedCodeStyle),
          TextSpan(
            text: ' • ',
            style: resolvedCodeStyle?.copyWith(
              color: secondaryColor ?? scheme.outline,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: title, style: resolvedTitleStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _OpenedOrderIndexBadge extends StatelessWidget {
  const _OpenedOrderIndexBadge({
    required this.index,
    this.selected = false,
    this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badge = SizedBox.square(
      dimension: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? scheme.primary : scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? scheme.onPrimary : scheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
    if (onTap == null) {
      return badge;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: badge,
      ),
    );
  }
}

class _EmptyOpenedOrders extends StatelessWidget {
  const _EmptyOpenedOrders({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 0),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
