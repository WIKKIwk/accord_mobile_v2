part of 'admin_production_map_orders_screen.dart';

class _ClosedOrdersModulePage extends StatelessWidget {
  const _ClosedOrdersModulePage({
    required this.bottomPadding,
    required this.closedOrders,
    required this.visibleClosedOrders,
  });

  final double bottomPadding;
  final List<AdminClosedProductionOrder> closedOrders;
  final List<AdminClosedProductionOrder> visibleClosedOrders;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        _openedOrderPanelCardGap,
        _openedOrderPanelTopGap,
        _openedOrderPanelCardGap,
        bottomPadding,
      ),
      children: [
        if (closedOrders.isEmpty)
          const _EmptyOpenedOrders(message: 'Yopilgan zakaz yo‘q')
        else if (visibleClosedOrders.isEmpty)
          const _EmptyOpenedOrders(message: 'Zakaz topilmadi')
        else
          M3SegmentSpacedColumn(
            padding: EdgeInsets.zero,
            children: [
              for (var index = 0; index < visibleClosedOrders.length; index++)
                _ClosedOrderTile(
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    visibleClosedOrders.length,
                  ),
                  order: visibleClosedOrders[index],
                  index: index,
                ),
            ],
          ),
      ],
    );
  }
}

class _ClosedOrderTile extends StatelessWidget {
  const _ClosedOrderTile({
    required this.slot,
    required this.order,
    required this.index,
  });

  final M3SegmentVerticalSlot slot;
  final AdminClosedProductionOrder order;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final code = _closedOrderDisplayCode(order);
    final title = _closedOrderTitle(order);
    final closedBy = _closedActorLabel(
      displayName: order.closedByDisplayName,
      role: order.closedByRole,
      ref: order.closedByRef,
    );
    final closedAt = _closedLogTimeLabel(order.completedAtUnix);
    final subtitle = [
      if (order.productCode.trim().isNotEmpty) order.productCode.trim(),
      if (closedBy.isNotEmpty) 'Yopdi: $closedBy',
      if (closedAt.isNotEmpty) closedAt,
    ].join(' • ');
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );

    return Material(
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: _OpenedOrderIndexBadge(index: index),
          title: Text(
            code.isEmpty ? title : '$code • $title',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.15,
                  ),
                ),
          children: [
            if (order.logs.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Log yo‘q',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              _ClosedOrderLogList(logs: order.logs),
          ],
        ),
      ),
    );
  }
}

class _ClosedOrderLogList extends StatelessWidget {
  const _ClosedOrderLogList({required this.logs});

  final List<AdminProductionOrderLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < logs.length; index++) ...[
          if (index > 0) const Divider(height: 16),
          _ClosedOrderLogRow(log: logs[index]),
        ],
      ],
    );
  }
}

class _ClosedOrderLogRow extends StatelessWidget {
  const _ClosedOrderLogRow({required this.log});

  final AdminProductionOrderLogEntry log;

  IconData get _icon {
    return switch (log.action.trim()) {
      'start' => Icons.play_arrow_rounded,
      'pause' => Icons.pause_rounded,
      'resume' => Icons.replay_rounded,
      'complete' => Icons.check_rounded,
      _ => Icons.history_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actor = _closedActorLabel(
      displayName: log.actorDisplayName,
      role: log.actorRole,
      ref: log.actorRef,
    );
    final state = _closedLogStateLabel(log);
    final time = _closedLogTimeLabel(log.createdAtUnix);
    final apparatus = log.apparatus.trim();
    final subtitle = [
      actor,
      if (state.isNotEmpty) state,
      if (time.isNotEmpty) time,
    ].join(' • ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(
          dimension: 34,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 18, color: scheme.onSecondaryContainer),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  _closedLogTitle(log),
                  if (apparatus.isNotEmpty) apparatus,
                ].join(' • '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
