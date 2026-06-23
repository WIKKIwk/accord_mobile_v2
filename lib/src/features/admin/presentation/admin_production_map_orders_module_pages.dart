part of 'admin_production_map_orders_screen.dart';

class _OrdersModulePage extends StatefulWidget {
  const _OrdersModulePage({
    required this.bottomPadding,
    required this.orders,
    required this.visibleOrders,
    required this.baseMetrajByMapId,
    required this.orderKgByMapId,
  });

  final double bottomPadding;
  final List<ProductionMapSaved> orders;
  final List<ProductionMapSaved> visibleOrders;
  final Map<String, double> baseMetrajByMapId;
  final Map<String, double> orderKgByMapId;

  @override
  State<_OrdersModulePage> createState() => _OrdersModulePageState();
}

class _OrdersModulePageState extends State<_OrdersModulePage> {
  String? _expandedOrderId;

  void _onExpandedChanged(ProductionMapSaved order, bool expanded) {
    setState(() {
      _expandedOrderId = expanded ? order.map.id.trim() : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        _openedOrderPanelCardGap,
        _openedOrderPanelTopGap,
        _openedOrderPanelCardGap,
        widget.bottomPadding,
      ),
      children: [
        if (widget.orders.isEmpty)
          const _EmptyOpenedOrders(message: 'Ochilgan zakaz yo‘q')
        else if (widget.visibleOrders.isEmpty)
          const _EmptyOpenedOrders(message: 'Zakaz topilmadi')
        else
          _OpenedOrderExpandableList(
            orders: widget.visibleOrders,
            expandedOrderId: _expandedOrderId,
            baseMetrajByMapId: widget.baseMetrajByMapId,
            orderKgByMapId: widget.orderKgByMapId,
            onExpandedChanged: _onExpandedChanged,
          ),
      ],
    );
  }
}

class _AparatchiWatchSequencePage extends StatelessWidget {
  const _AparatchiWatchSequencePage({
    required this.apparatus,
    required this.orders,
    required this.bottomPadding,
    required this.isAssigned,
    required this.queueStates,
    required this.onTapOrder,
  });

  final AdminWarehouse apparatus;
  final List<ProductionMapSaved> orders;
  final double bottomPadding;
  final bool isAssigned;
  final Map<String, String> queueStates;
  final ValueChanged<ProductionMapSaved> onTapOrder;

  Color? _cardBackground(ApparatusQueueOrderState state) {
    return switch (state) {
      ApparatusQueueOrderState.inProgress => const Color(0xFFFFECB3),
      ApparatusQueueOrderState.paused => const Color(0xFFFFCDD2),
      ApparatusQueueOrderState.completed => const Color(0xFFC8E6C9),
      ApparatusQueueOrderState.pending => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          _openedOrderPanelCardGap,
          _openedOrderPanelTopGap,
          _openedOrderPanelCardGap,
          bottomPadding,
        ),
        children: [
          if (isAssigned)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text(
                'Sizning aparatingiz',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (orders.isEmpty)
            _EmptyOpenedOrders(
                message: '${apparatus.warehouse} uchun zakaz yo‘q')
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < orders.length; index++)
                  _SequenceExpandableOrderRow(
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      orders.length,
                    ),
                    order: orders[index],
                    index: index,
                    readOnly: true,
                    expanded: false,
                    baseMetraj: orders[index].map.baseLength,
                    orderKg: orders[index].map.orderKg,
                    onExpandedChanged: (_) {},
                    expandable: false,
                    onTap: () => onTapOrder(orders[index]),
                    backgroundColor: _cardBackground(
                      apparatusQueueOrderStateFromRaw(
                        queueStates[orders[index].map.id.trim()],
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AparatchiCompletedOrdersPage extends StatelessWidget {
  const _AparatchiCompletedOrdersPage({
    required this.orders,
    required this.bottomPadding,
    required this.onTapOrder,
  });

  final List<_WorkerCompletedOrderEntry> orders;
  final double bottomPadding;
  final ValueChanged<_WorkerCompletedOrderEntry> onTapOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          _openedOrderPanelCardGap,
          _openedOrderPanelTopGap,
          _openedOrderPanelCardGap,
          bottomPadding,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              'Tugallangan zakazlar',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (orders.isEmpty)
            const _EmptyOpenedOrders(message: 'Tugallangan zakaz yo‘q')
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < orders.length; index++)
                  _SequenceExpandableOrderRow(
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      orders.length,
                    ),
                    order: orders[index].order,
                    index: index,
                    readOnly: true,
                    expanded: false,
                    baseMetraj: orders[index].order.map.baseLength,
                    orderKg: orders[index].order.map.orderKg,
                    onExpandedChanged: (_) {},
                    expandable: false,
                    onTap: () => onTapOrder(orders[index]),
                    backgroundColor: const Color(0xFFC8E6C9),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
