part of 'admin_production_map_orders_screen.dart';

class _SequenceModulePage extends StatefulWidget {
  const _SequenceModulePage({
    this.totalOrderCount,
    this.sequencePositions = const {},
    this.sequenceRows = const {},
    required this.bottomPadding,
    required this.availableApparatus,
    required this.apparatus,
    required this.completionRequests,
    required this.orders,
    required this.searchQuery,
    required this.readOnly,
    required this.reorderEnabled,
    required this.stageStatesByOrderId,
    required this.customerNameByMapId,
    required this.queueStates,
    required this.queueActionControls,
    required this.orderStatusesByOrderId,
    required this.orderControlsByOrderId,
    this.interactionHint,
    required this.onSelectApparatus,
    required this.onReorder,
    required this.onInfoOrder,
    required this.onLongPressOrder,
  });
  final double bottomPadding;
  final int? totalOrderCount;
  final Map<String, int> sequencePositions;
  final Map<String, AdminSequenceListRow> sequenceRows;
  final List<AdminApparatus> availableApparatus;
  final AdminApparatus? apparatus;
  final List<AdminCompletionRequestNotification> completionRequests;
  final List<ProductionMapSaved> orders;
  final String searchQuery;
  final bool readOnly;
  final bool reorderEnabled;
  final Map<String, Map<String, String>> stageStatesByOrderId;
  final Map<String, String> customerNameByMapId;
  final Map<String, String> queueStates;
  final Map<String, AdminApparatusQueueOrderActionControl> queueActionControls;
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
    final sequenceIndices = {
      for (final (index, order) in widget.orders.indexed)
        order.map.id.trim(): index,
    };
    final orders = _visibleOrders(
      orders: widget.orders,
      query: widget.searchQuery,
      customerNameByMapId: widget.customerNameByMapId,
    );
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
      final summary = widget.sequenceRows[order.map.id];
      final queueState = apparatusQueueOrderStateFromRaw(
        widget.queueStates[order.map.id.trim()],
      );
      final apparatusState = summary == null && !widget.reorderEnabled && selected != null
          ? _apparatusOrderCardState(
              map: order.map,
              apparatusId: selected.id,
              queueState: queueState,
              stageStates:
                  widget.stageStatesByOrderId[order.map.id.trim()] ?? const {},
              control: widget.queueActionControls[order.map.id.trim()],
            )
          : queueState;
      final isFrozen = summary != null ? summary.frozen : adminProductionMapOrderControlFor(
            widget.orderControlsByOrderId,
            order.map.id.trim(),
          ).isFrozen ||
          apparatusState == ApparatusQueueOrderState.frozen;
      final canReorder = (summary?.canReorder ?? true) &&
          widget.reorderEnabled &&
          !widget.readOnly &&
          !apparatusState.isActive &&
          !isFrozen;

      return _SequenceOrderRow(
        key: key,
        slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
          index,
          orders.length,
        ),
        order: order,
        showApparatusCount: false,
        index: index,
        position: widget.sequencePositions[order.map.id.trim()] ??
            (sequenceIndices[order.map.id.trim()] ?? index) + 1,
        readOnly: widget.readOnly,
        canReorder: canReorder,
        customerName: widget.customerNameByMapId[order.map.id.trim()] ?? '',
        tone: summary != null
            ? _adminSequenceTone(summary.displayState)
            : _resolveApparatusOrderCardTone(
                printPreflightPassed: _orderPrintPreflightPassed(
                  orderId: order.map.id,
                  apparatusId: selected?.id ?? '',
                  queueStates: {selected?.id ?? '': widget.queueStates},
                  controls: {selected?.id ?? '': widget.queueActionControls},
                ),
                orderStatus: widget.orderStatusesByOrderId[order.map.id.trim()],
                orderControl: adminProductionMapOrderControlFor(
                  widget.orderControlsByOrderId,
                  order.map.id.trim(),
                ),
                apparatusState: apparatusState,
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
      final indexByKey = widget.reorderEnabled
          ? const <Key, int>{}
          : <Key, int>{
              for (var index = 0; index < orders.length; index++)
                ValueKey('sequence-${selected.id}-${orders[index].map.id}'):
                    index,
            };
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
                    orderCount: widget.totalOrderCount ?? orders.length,
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
              child: !widget.reorderEnabled
                  ? ListView.builder(
                      key: ValueKey('sequence-list-${selected.id}'),
                      padding: EdgeInsets.fromLTRB(
                        _openedOrderPanelCardGap,
                        8,
                        _openedOrderPanelCardGap,
                        widget.bottomPadding,
                      ),
                      itemCount: orders.length,
                      findChildIndexCallback: (key) => indexByKey[key],
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
                    )
                  : M3SequenceList(
                      listKey: ValueKey('sequence-list-${selected.id}'),
                      padding: EdgeInsets.fromLTRB(
                        _openedOrderPanelCardGap,
                        8,
                        _openedOrderPanelCardGap,
                        widget.bottomPadding,
                      ),
                      itemCount: orders.length,
                      itemKey: (index) => ValueKey(
                        'sequence-${selected.id}-${orders[index].map.id}',
                      ),
                      onReorder: widget.onReorder,
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return buildOrderRow(
                          index: index,
                          order: order,
                          key: ValueKey(
                            'sequence-row-${selected.id}-${order.map.id}',
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
            orderCount: widget.totalOrderCount ?? orders.length,
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
                widget.searchQuery.trim().isEmpty
                    ? 'worker.queue.empty.for_apparatus'
                    : 'production.search_empty',
                values: widget.searchQuery.trim().isEmpty
                    ? {'apparatus': selected.name.trim()}
                    : const {},
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
    final profile = AppSession.instance.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminSequenceApparatusFilter(
          apparatus: availableApparatus,
          selectedId: apparatus?.id,
          editableProfileRef:
              profile?.role == UserRole.admin ? profile?.ref : null,
          expanded: expanded,
          onToggle: onToggleExpanded,
          onSelect: onSelectApparatus,
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

class _SequenceOrderRow extends StatefulWidget {
  const _SequenceOrderRow({
    super.key,
    required this.slot,
    required this.order,
    this.showApparatusCount = true,
    required this.index,
    this.position,
    required this.readOnly,
    this.canReorder = true,
    this.customerName = '',
    this.apparatusLabel = '',
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
  final bool showApparatusCount;
  final int index;
  final int? position;
  final bool readOnly;
  final bool canReorder;
  final String customerName;
  final String apparatusLabel;
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
  State<_SequenceOrderRow> createState() => _SequenceOrderRowState();

  Object get _visualIdentity => (
        slot,
        order.map,
        showApparatusCount,
        index,
        position,
        readOnly,
        canReorder,
        customerName,
        apparatusLabel,
        tone,
        backgroundColor,
        titleColor,
        secondaryColor,
        statusLabel,
        statusBackgroundColor,
        statusForegroundColor,
        onTap != null,
        onInfo != null,
        onLongPress != null,
      );

  Widget _buildVisual(BuildContext context, {
    required VoidCallback? tap, required VoidCallback? longPress,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final map = order.map;
    final orderSubtitle = _openedOrderSubtitle(
      map,
      customerName: customerName,
      includeApparatusCount: showApparatusCount,
      l10n: context.l10n,
    );
    final subtitle = [
      if (apparatusLabel.trim().isNotEmpty) apparatusLabel.trim(),
      if (orderSubtitle.isNotEmpty) orderSubtitle,
    ].join(' • ');
    final resolvedStatusLabel = statusLabel?.trim();
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );

    final resolvedGradient = _orderCardBackgroundGradient(tone);
    final passed = tone == _OrderCardTone.printPreflightPassed;
    final passedForeground = passed ? const Color(0xFF102A0B) : null;
    return Material(
      color: backgroundColor ??
          (resolvedGradient == null
              ? _orderCardBackgroundColor(context, tone) ??
                  scheme.surfaceContainerLowest
              : Colors.transparent),
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tap,
        onLongPress: longPress,
        child: Stack(
          children: [
            if (resolvedGradient != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: resolvedGradient),
                ),
              ),
            // Cover chapda suzadi (Positioned): qator balandligini faqat
            // matn belgilaydi, rasm o'lchami ta'sir qilmaydi.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: kAdminOrderCoverWidth,
              child: _ProductionMapOrderCoverImage(map: map),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kAdminOrderCoverWidth + 12,
                8,
                12,
                8,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 45),
                child: Row(
                  children: [
                    _OpenedOrderIndexBadge(index: (position ?? index + 1) - 1),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _OpenedOrderTitleLine(
                            map: map,
                            theme: theme,
                            scheme: scheme,
                            titleColor: titleColor ?? passedForeground,
                            secondaryColor: secondaryColor ?? passedForeground,
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            OverflowMarqueeText(
                              text: subtitle,
                              startDelay: Duration(
                                milliseconds:
                                    1000 + (map.id.hashCode.abs() % 5) * 350,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: secondaryColor ??
                                    passedForeground ??
                                    scheme.onSurfaceVariant,
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
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: statusBackgroundColor ??
                                scheme.secondaryContainer,
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
                    if (!readOnly && canReorder)
                      M3SequenceDragHandle(index: index),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Stable descendants avoid rebuilding image/title/marquee trees when only a
/// different order changes. Callback forwarding always reads the current row.
class _SequenceOrderRowState extends State<_SequenceOrderRow> {
  Widget? _visual;

  @override
  void didUpdateWidget(covariant _SequenceOrderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._visualIdentity != widget._visualIdentity) _visual = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visual = null;
  }

  void _tap() => (widget.onTap ?? widget.onInfo)?.call();
  void _longPress() => widget.onLongPress?.call();

  @override
  Widget build(BuildContext context) => _visual ??= widget._buildVisual(context,
    tap: widget.onTap == null && widget.onInfo == null ? null : _tap,
    longPress: widget.onLongPress == null ? null : _longPress,
  );
}
