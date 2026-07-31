part of 'admin_production_map_orders_screen.dart';

class _SequenceModulePage extends StatefulWidget {
  const _SequenceModulePage({
    required this.bottomPadding,
    required this.availableApparatus,
    required this.apparatus,
    required this.completionRequests,
    required this.orders,
    required this.readOnly,
    required this.customerNameByMapId,
    required this.queueStates,
    required this.orderStatusesByOrderId,
    required this.orderControlsByOrderId,
    required this.onSelectApparatus,
    required this.onReorder,
    required this.onInfoOrder,
    required this.onLongPressOrder,
  });

  final double bottomPadding;
  final List<AdminApparatus> availableApparatus;
  final AdminApparatus? apparatus;
  final List<AdminCompletionRequestNotification> completionRequests;
  final List<ProductionMapSaved> orders;
  final bool readOnly;
  final Map<String, String> customerNameByMapId;
  final Map<String, String> queueStates;
  final Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId;
  final Map<String, AdminOrderControlState> orderControlsByOrderId;
  final ValueChanged<AdminApparatus> onSelectApparatus;
  final ReorderCallback onReorder;
  final ValueChanged<ProductionMapSaved>? onInfoOrder;
  final ValueChanged<ProductionMapSaved> onLongPressOrder;

  @override
  State<_SequenceModulePage> createState() => _SequenceModulePageState();
}

class _SequenceModulePageState extends State<_SequenceModulePage> {
  String? _expandedCompletionRequestId;
  bool _apparatusFilterExpanded = false;

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
      return _SequenceOrderRow(
        key: key,
        slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
          index,
          orders.length,
        ),
        order: order,
        index: index,
        readOnly: widget.readOnly,
        customerName: widget.customerNameByMapId[order.map.id.trim()] ?? '',
        tone: _resolveOrderCardTone(
          orderStatus: widget.orderStatusesByOrderId[order.map.id.trim()],
          orderControl: widget.orderControlsByOrderId[order.map.id.trim()] ??
              AdminOrderControlState.active,
          apparatusState: apparatusQueueOrderStateFromRaw(
            widget.queueStates[order.map.id.trim()],
          ),
        ),
        onInfo: widget.onInfoOrder == null
            ? null
            : () => widget.onInfoOrder!(order),
        onLongPress: () => widget.onLongPressOrder(order),
      );
    }

    if (!widget.readOnly && selected != null && orders.isNotEmpty) {
      return ColoredBox(
        color: AppTheme.shellStart(context),
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
                    availableApparatus: widget.availableApparatus,
                    apparatus: selected,
                    orderCount: orders.length,
                    readOnly: widget.readOnly,
                    expanded: _apparatusFilterExpanded,
                    onToggleExpanded: () {
                      setState(() {
                        _apparatusFilterExpanded = !_apparatusFilterExpanded;
                      });
                    },
                    onSelectApparatus: (apparatus) {
                      setState(() {
                        _apparatusFilterExpanded = false;
                      });
                      widget.onSelectApparatus(apparatus);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                key: ValueKey(
                  'sequence-list-${selected.name}-'
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
                      'sequence-${selected.name}-${order.map.id}',
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
                        'sequence-row-${selected.name}-${order.map.id}',
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
      color: AppTheme.shellStart(context),
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
            availableApparatus: widget.availableApparatus,
            apparatus: selected,
            orderCount: orders.length,
            readOnly: widget.readOnly,
            expanded: _apparatusFilterExpanded,
            onToggleExpanded: () {
              setState(() {
                _apparatusFilterExpanded = !_apparatusFilterExpanded;
              });
            },
            onSelectApparatus: (apparatus) {
              setState(() {
                _apparatusFilterExpanded = false;
              });
              widget.onSelectApparatus(apparatus);
            },
          ),
          if (selected == null)
            const _EmptyOpenedOrders(message: 'Avval aparat tanlang')
          else if (orders.isEmpty)
            _EmptyOpenedOrders(
              message: '${selected.name} uchun zakaz yo‘q',
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
                      'sequence-static-${selected.name}-'
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
    required this.availableApparatus,
    required this.apparatus,
    required this.orderCount,
    required this.readOnly,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSelectApparatus,
  });

  final List<AdminApparatus> availableApparatus;
  final AdminApparatus? apparatus;
  final int orderCount;
  final bool readOnly;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<AdminApparatus> onSelectApparatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedValue = apparatus?.name.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminExpandableFilterChip<String>(
          label: 'Aparat',
          emptyLabel: 'Tanlanmagan',
          icon: Icons.precision_manufacturing_rounded,
          selectedValue: selectedValue?.isEmpty == true ? null : selectedValue,
          options: [
            for (final item in availableApparatus)
              if (item.name.trim().isNotEmpty)
                AdminFilterChipOption(
                  value: item.name.trim(),
                  label: item.name.trim(),
                ),
          ],
          expanded: expanded,
          onToggle: onToggleExpanded,
          onSelect: (value) {
            for (final item in availableApparatus) {
              if (item.name.trim() == value) {
                onSelectApparatus(item);
                return;
              }
            }
          },
          padding: EdgeInsets.zero,
        ),
        if (orderCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              '$orderCount ta zakaz',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.05,
                  ),
            ),
          ),
        if (orderCount > 0 && !readOnly) ...[
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

class _SequenceOrderRow extends StatelessWidget {
  const _SequenceOrderRow({
    super.key,
    required this.slot,
    required this.order,
    required this.index,
    required this.readOnly,
    this.customerName = '',
    this.tone = _OrderCardTone.neutral,
    this.backgroundColor,
    this.onTap,
    this.onInfo,
    this.onLongPress,
  });

  final M3SegmentVerticalSlot slot;
  final ProductionMapSaved order;
  final int index;
  final bool readOnly;
  final String customerName;
  final _OrderCardTone tone;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final VoidCallback? onInfo;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = order.map;
    final subtitle = _openedOrderSubtitle(
      map,
      customerName: customerName,
      includeApparatusCount: true,
    );
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );

    return Material(
      color: backgroundColor ??
          _orderCardBackgroundColor(context, tone) ??
          scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 45),
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
                if (onInfo != null)
                  IconButton(
                    tooltip: 'Buyurtma ma’lumotlari',
                    onPressed: onInfo,
                    icon: Icon(
                      Icons.info_outline_rounded,
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
    );
  }
}
