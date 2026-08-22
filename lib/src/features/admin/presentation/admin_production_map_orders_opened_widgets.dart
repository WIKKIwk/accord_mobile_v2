part of 'admin_production_map_orders_screen.dart';

class _OpenedOrderList extends StatelessWidget {
  const _OpenedOrderList({
    required this.orders,
    required this.customerNameByMapId,
    required this.orderStatusesByOrderId,
    required this.orderControlsByOrderId,
    required this.queueStatesByApparatus,
    required this.onInfoOrder,
    required this.onLongPressOrder,
  });

  final List<ProductionMapSaved> orders;
  final Map<String, String> customerNameByMapId;
  final Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId;
  final Map<String, AdminOrderControlState> orderControlsByOrderId;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final ValueChanged<ProductionMapSaved> onInfoOrder;
  final ValueChanged<ProductionMapSaved> onLongPressOrder;

  @override
  Widget build(BuildContext context) {
    return M3SegmentSpacedColumn(
      children: [
        for (var index = 0; index < orders.length; index++)
          _OpenedOrderRow(
            key: ValueKey('opened-order-${orders[index].map.id.trim()}'),
            slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
              index,
              orders.length,
            ),
            order: orders[index],
            customerName:
                customerNameByMapId[orders[index].map.id.trim()] ?? '',
            tone: _resolveOrderCardTone(
              orderStatus: orderStatusesByOrderId[orders[index].map.id.trim()],
              orderControl: adminProductionMapOrderControlFor(
                orderControlsByOrderId,
                orders[index].map.id.trim(),
              ),
              apparatusState: queueActivityStateForOrder(
                orderId: orders[index].map.id,
                queueStatesByApparatus: queueStatesByApparatus,
              ),
            ),
            onInfo: () => onInfoOrder(orders[index]),
            onLongPress: () => onLongPressOrder(orders[index]),
          ),
      ],
    );
  }
}

class _OpenedOrderRow extends StatelessWidget {
  const _OpenedOrderRow({
    super.key,
    required this.slot,
    required this.order,
    required this.customerName,
    required this.tone,
    required this.onInfo,
    required this.onLongPress,
  });

  final M3SegmentVerticalSlot slot;
  final ProductionMapSaved order;
  final String customerName;
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          child: Row(
            children: [
              const _OpenedOrderTreeBadge(),
              const SizedBox(width: 14),
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

class _OpenedOrderTreeBadge extends StatelessWidget {
  const _OpenedOrderTreeBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.account_tree_outlined,
          color: scheme.onPrimaryContainer,
          size: 16,
        ),
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
