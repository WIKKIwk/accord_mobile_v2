part of 'admin_production_map_orders_screen.dart';

class _SequenceModulePage extends StatefulWidget {
  const _SequenceModulePage({
    required this.bottomPadding,
    required this.apparatus,
    required this.completionRequests,
    required this.orders,
    required this.readOnly,
    required this.baseMetrajByMapId,
    required this.orderKgByMapId,
    required this.onPickApparatus,
    required this.onReorder,
  });

  final double bottomPadding;
  final AdminWarehouse? apparatus;
  final List<AdminCompletionRequestNotification> completionRequests;
  final List<ProductionMapSaved> orders;
  final bool readOnly;
  final Map<String, double> baseMetrajByMapId;
  final Map<String, double> orderKgByMapId;
  final VoidCallback onPickApparatus;
  final ReorderCallback onReorder;

  @override
  State<_SequenceModulePage> createState() => _SequenceModulePageState();
}

class _SequenceModulePageState extends State<_SequenceModulePage> {
  String? _expandedOrderId;
  String? _expandedCompletionRequestId;

  void _onExpandedChanged(ProductionMapSaved order, bool expanded) {
    setState(() {
      _expandedOrderId = expanded ? order.map.id.trim() : null;
    });
  }

  void _onCompletionRequestExpandedChanged(
    AdminCompletionRequestNotification request,
    bool expanded,
  ) {
    setState(() {
      _expandedCompletionRequestId = expanded ? request.eventId.trim() : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = widget.apparatus;
    final orders = widget.orders;
    final notifications = widget.completionRequests;
    final notificationSection = notifications.isEmpty
        ? const SizedBox.shrink()
        : _CompletionRequestsSection(
            requests: notifications,
            expandedRequestId: _expandedCompletionRequestId,
            onExpandedChanged: _onCompletionRequestExpandedChanged,
          );

    Widget buildOrderRow({
      required int index,
      required ProductionMapSaved order,
      required Key key,
    }) {
      final mapId = order.map.id.trim();
      return _SequenceExpandableOrderRow(
        key: key,
        slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
          index,
          orders.length,
        ),
        order: order,
        index: index,
        readOnly: widget.readOnly,
        expanded: _expandedOrderId == mapId,
        baseMetraj: widget.baseMetrajByMapId[mapId] ?? order.map.baseLength,
        orderKg: widget.orderKgByMapId[mapId] ?? order.map.orderKg,
        onExpandedChanged: (expanded) => _onExpandedChanged(order, expanded),
      );
    }

    if (!widget.readOnly && selected != null && orders.isNotEmpty) {
      return ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _openedOrderPanelCardGap,
                _openedOrderPanelTopGap,
                _openedOrderPanelCardGap,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  notificationSection,
                  if (notifications.isNotEmpty) const SizedBox(height: 12),
                  _SequenceHeaderSelectors(
                    apparatus: selected,
                    orderCount: orders.length,
                    onPickApparatus: widget.onPickApparatus,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                key: ValueKey(
                  'sequence-list-${selected.warehouse}-'
                  '${orders.map((order) => order.map.id).join(',')}',
                ),
                padding: EdgeInsets.fromLTRB(
                  _openedOrderPanelCardGap,
                  8,
                  _openedOrderPanelCardGap,
                  widget.bottomPadding,
                ),
                buildDefaultDragHandles: false,
                itemCount: orders.length,
                onReorderItem: widget.onReorder,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  return Padding(
                    key: ValueKey(
                      'sequence-${selected.warehouse}-${order.map.id}',
                    ),
                    padding: EdgeInsets.only(
                      bottom: index < orders.length - 1
                          ? M3SegmentedListGeometry.gap
                          : 0,
                    ),
                    child: buildOrderRow(
                      index: index,
                      order: order,
                      key: ValueKey(
                        'sequence-row-${selected.warehouse}-${order.map.id}',
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          _openedOrderPanelCardGap,
          _openedOrderPanelTopGap,
          _openedOrderPanelCardGap,
          widget.bottomPadding,
        ),
        children: [
          notificationSection,
          if (notifications.isNotEmpty) const SizedBox(height: 12),
          _SequenceHeaderSelectors(
            apparatus: selected,
            orderCount: orders.length,
            onPickApparatus: widget.onPickApparatus,
          ),
          if (selected == null)
            const _EmptyOpenedOrders(message: 'Avval aparat tanlang')
          else if (orders.isEmpty)
            _EmptyOpenedOrders(
              message: '${selected.warehouse} uchun zakaz yo‘q',
            )
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < orders.length; index++)
                  buildOrderRow(
                    index: index,
                    order: orders[index],
                    key: ValueKey(
                      'sequence-static-${selected.warehouse}-'
                      '${orders[index].map.id}',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SequenceHeaderSelectors extends StatelessWidget {
  const _SequenceHeaderSelectors({
    required this.apparatus,
    required this.orderCount,
    required this.onPickApparatus,
  });

  final AdminWarehouse? apparatus;
  final int orderCount;
  final VoidCallback onPickApparatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = apparatus?.warehouse.trim().isNotEmpty == true
        ? apparatus!.warehouse.trim()
        : 'Aparat tanlang';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: scheme.surface,
          elevation: 2,
          shadowColor: scheme.shadow.withValues(alpha: 0.16),
          surfaceTintColor: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPickApparatus,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 30,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.precision_manufacturing_rounded,
                        size: 16,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (orderCount > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$orderCount ta zakaz',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.05,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (orderCount > 0) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Tartibni o‘zgartirish uchun zakazni ushlab torting',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

class _SequenceExpandableOrderRow extends StatelessWidget {
  const _SequenceExpandableOrderRow({
    super.key,
    required this.slot,
    required this.order,
    required this.index,
    required this.readOnly,
    required this.expanded,
    required this.baseMetraj,
    required this.orderKg,
    required this.onExpandedChanged,
    this.backgroundColor,
    this.onTap,
    this.expandable = true,
  });

  final M3SegmentVerticalSlot slot;
  final ProductionMapSaved order;
  final int index;
  final bool readOnly;
  final bool expanded;
  final double? baseMetraj;
  final double? orderKg;
  final ValueChanged<bool> onExpandedChanged;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool expandable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = order.map;
    final subtitle = _openedOrderSubtitle(map);
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );

    return Material(
      color: backgroundColor ?? scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: expandable ? () => onExpandedChanged(!expanded) : onTap,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 4, expanded ? 8 : 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: expanded ? 0 : 45),
                child: Row(
                  children: [
                    _OpenedOrderIndexBadge(index: index),
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
                    if (!readOnly)
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (expandable)
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 22,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          if (expandable)
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? _OpenedOrderWorkflowDetail(
                      map: map,
                      baseMetraj: baseMetraj,
                      orderKg: orderKg,
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
