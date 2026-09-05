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
    this.interactionHint,
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
  final String? interactionHint;
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
            apparatusCatalog: widget.availableApparatus,
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
          orderControl: adminProductionMapOrderControlFor(
            widget.orderControlsByOrderId,
            order.map.id.trim(),
          ),
          apparatusState: apparatusQueueOrderStateFromRaw(
            widget.queueStates[order.map.id.trim()],
          ),
        ),
        onTap: widget.onInfoOrder == null
            ? null
            : () => widget.onInfoOrder!(order),
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
                    interactionHint: widget.interactionHint,
                    showInteractionHint: widget.onInfoOrder != null,
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
                  'sequence-list-${selected.id}-'
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
                      'sequence-${selected.id}-${order.map.id}',
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
                        'sequence-row-${selected.id}-${order.map.id}',
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
            interactionHint: widget.interactionHint,
            showInteractionHint: widget.onInfoOrder != null,
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
            _EmptyOpenedOrders(
              message: context.l10n.productionText(
                'worker.queue.empty.select_apparatus',
              ),
            )
          else if (orders.isEmpty)
            _EmptyOpenedOrders(
              message: context.l10n.productionText(
                'worker.queue.empty.for_apparatus',
                values: {
                  'apparatus': selected.name.trim(),
                },
              ),
            )
          else if (orders.isNotEmpty)
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < orders.length; index++)
                  buildOrderRow(
                    index: index,
                    order: orders[index],
                    key: ValueKey(
                      'sequence-static-${selected.id}-'
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
    this.interactionHint,
    required this.showInteractionHint,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onSelectApparatus,
  });
  final List<AdminApparatus> availableApparatus;
  final AdminApparatus? apparatus;
  final int orderCount;
  final bool readOnly;
  final String? interactionHint;
  final bool showInteractionHint;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<AdminApparatus> onSelectApparatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selectedValue = apparatus?.id.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminExpandableFilterChip<String>(
          label: context.l10n.productionText('worker.queue.filter.apparatus'),
          emptyLabel: context.l10n.productionText(
            'worker.queue.filter.unselected',
          ),
          icon: Icons.precision_manufacturing_rounded,
          selectedValue: selectedValue?.isEmpty == true ? null : selectedValue,
          options: [
            for (final item in availableApparatus)
              if (item.id.trim().isNotEmpty && item.name.trim().isNotEmpty)
                AdminFilterChipOption(
                  value: item.id.trim(),
                  label: item.name.trim(),
                ),
          ],
          expanded: expanded,
          onToggle: onToggleExpanded,
          onSelect: (value) {
            for (final item in availableApparatus) {
              if (item.id.trim() == value) {
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
              context.l10n.productionText(
                'worker.queue.orders_count',
                values: {'count': orderCount},
              ),
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
              context.l10n.productionText('worker.queue.reorder_hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
        if (orderCount > 0 && readOnly && showInteractionHint)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              interactionHint ??
                  context.l10n.productionText(
                    'worker.queue.interaction_hint',
                  ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
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
    this.titleColor,
    this.secondaryColor,
    this.statusLabel,
    this.statusBackgroundColor,
    this.statusForegroundColor,
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
  final Color? titleColor;
  final Color? secondaryColor;
  final String? statusLabel;
  final Color? statusBackgroundColor;
  final Color? statusForegroundColor;
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
      l10n: context.l10n,
    );
    final resolvedStatusLabel = statusLabel?.trim();
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
                        titleColor: titleColor,
                        secondaryColor: secondaryColor,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: secondaryColor ?? scheme.onSurfaceVariant,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (resolvedStatusLabel != null &&
                    resolvedStatusLabel.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color:
                            statusBackgroundColor ?? scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        child: Text(
                          resolvedStatusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusForegroundColor ??
                                scheme.onSecondaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
                    tooltip: context.l10n.productionText('worker.order.info'),
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
