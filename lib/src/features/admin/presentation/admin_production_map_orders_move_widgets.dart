part of 'admin_production_map_orders_screen.dart';

class _MoveDragPayload {
  const _MoveDragPayload({required this.orders, required this.source});

  final List<ProductionMapSaved> orders;
  final AdminWarehouse source;
}

class _MoveOrderCard extends StatelessWidget {
  const _MoveOrderCard({
    required this.order,
    required this.index,
    required this.slot,
    this.selected = false,
    this.onToggleSelect,
    this.trailing,
    this.borderRadiusOverride,
  });

  final ProductionMapSaved order;
  final int index;
  final M3SegmentVerticalSlot slot;
  final bool selected;
  final VoidCallback? onToggleSelect;
  final Widget? trailing;
  final BorderRadius? borderRadiusOverride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _OpenedOrderCardRow(
      slot: slot,
      order: order,
      onTap: onToggleSelect,
      borderRadiusOverride: borderRadiusOverride,
      leading: _OpenedOrderIndexBadge(
        index: index,
        selected: selected,
        onTap: onToggleSelect,
      ),
      trailing: trailing ?? _MoveDragHandle(color: scheme.onSurfaceVariant),
    );
  }
}

class _MoveDragHandle extends StatelessWidget {
  const _MoveDragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(Icons.drag_handle_rounded, color: color),
    );
  }
}

class _MoveEmptyZone extends StatelessWidget {
  const _MoveEmptyZone({required this.apparatus});

  final AdminWarehouse apparatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = _isMoveUnassignedApparatus(apparatus)
        ? 'Tanlanmagan zakaz yo‘q'
        : '${apparatus.warehouse} uchun zakaz yo‘q';
    return Center(
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

class _MoveDropZone extends StatelessWidget {
  const _MoveDropZone({
    required this.apparatus,
    required this.orders,
    required this.selectedOrderIds,
    required this.draggingOrders,
    required this.draggingSource,
    required this.canMoveTo,
    required this.onToggleSelect,
    required this.buildDragPayload,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onMove,
  });

  final AdminWarehouse apparatus;
  final List<ProductionMapSaved> orders;
  final Set<String> selectedOrderIds;
  final List<ProductionMapSaved> draggingOrders;
  final AdminWarehouse? draggingSource;
  final bool Function(
    ProductionMapSaved order,
    AdminWarehouse target,
    AdminWarehouse source,
  ) canMoveTo;
  final ValueChanged<String> onToggleSelect;
  final _MoveDragPayload Function({
    required ProductionMapSaved order,
    required AdminWarehouse source,
    required List<ProductionMapSaved> zoneOrders,
  }) buildDragPayload;
  final ValueChanged<_MoveDragPayload> onDragStarted;
  final VoidCallback onDragEnded;
  final Future<void> Function({
    required List<ProductionMapSaved> orders,
    required AdminWarehouse from,
    required AdminWarehouse to,
  }) onMove;

  @override
  Widget build(BuildContext context) {
    final draggingIds = {
      for (final order in draggingOrders) order.map.id.trim(),
    };
    final dragSource = draggingSource;
    final isDropTarget = dragSource != null &&
        dragSource.warehouse.trim() != apparatus.warehouse.trim();
    final blocked = isDropTarget &&
        draggingOrders.isNotEmpty &&
        draggingOrders.any((order) => !canMoveTo(order, apparatus, dragSource));
    return DragTarget<_MoveDragPayload>(
      onWillAcceptWithDetails: (details) {
        if (details.data.source.warehouse.trim() ==
            apparatus.warehouse.trim()) {
          return false;
        }
        return details.data.orders.every(
          (order) => canMoveTo(order, apparatus, details.data.source),
        );
      },
      onAcceptWithDetails: (details) {
        onMove(
          orders: details.data.orders,
          from: details.data.source,
          to: apparatus,
        );
      },
      builder: (context, candidate, rejected) {
        final showBlocked = blocked || rejected.isNotEmpty;
        final zoneBody = orders.isEmpty
            ? _MoveEmptyZone(apparatus: apparatus)
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final orderId = order.map.id.trim();
                  final isDragging = draggingIds.contains(orderId);
                  final slot =
                      M3SegmentedListGeometry.standaloneListSlotForIndex(
                    index,
                    orders.length,
                  );
                  if (isDragging) {
                    return const AnimatedSize(
                      duration: Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox.shrink(),
                    );
                  }
                  final payload = buildDragPayload(
                    order: order,
                    source: apparatus,
                    zoneOrders: orders,
                  );
                  return Padding(
                    key: ValueKey(
                      'move-order-${apparatus.warehouse}-${order.map.id}',
                    ),
                    padding: EdgeInsets.only(
                      bottom: index < orders.length - 1
                          ? M3SegmentedListGeometry.gap
                          : 0,
                    ),
                    child: _MoveOrderTile(
                      order: order,
                      source: apparatus,
                      index: index,
                      slot: slot,
                      selected: selectedOrderIds.contains(orderId),
                      payload: payload,
                      onToggleSelect: () => onToggleSelect(orderId),
                      onDragStarted: () => onDragStarted(payload),
                      onDragEnded: onDragEnded,
                    ),
                  );
                },
              );
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: showBlocked
                ? ImageFiltered(
                    key: const ValueKey('move-zone-blocked'),
                    imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Opacity(
                      opacity: 0.42,
                      child: IgnorePointer(child: zoneBody),
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('move-zone-active'),
                    child: zoneBody,
                  ),
          ),
        );
      },
    );
  }
}

class _MoveApparatusHeader extends StatelessWidget {
  const _MoveApparatusHeader({
    super.key,
    required this.apparatus,
    required this.alignment,
    required this.onTap,
  });

  final AdminWarehouse apparatus;
  final Alignment alignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: alignment,
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.precision_manufacturing_rounded,
                  size: 16,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    apparatus.warehouse,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveBoundary extends StatelessWidget {
  const _MoveBoundary({
    required this.apparatus,
    required this.onTap,
    required this.onVerticalDragUpdate,
  });

  final AdminWarehouse apparatus;
  final VoidCallback onTap;
  final ValueChanged<double> onVerticalDragUpdate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Listener(
      key: const ValueKey('move-boundary-apparatus-picker'),
      behavior: HitTestBehavior.opaque,
      onPointerMove: (event) => onVerticalDragUpdate(event.delta.dy),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Expanded(child: Divider(color: scheme.outlineVariant)),
            IgnorePointer(
              child: _MoveApparatusHeader(
                apparatus: apparatus,
                alignment: Alignment.center,
                onTap: onTap,
              ),
            ),
            Expanded(child: Divider(color: scheme.outlineVariant)),
          ],
        ),
      ),
    );
  }
}

class _MoveOrderTile extends StatelessWidget {
  const _MoveOrderTile({
    required this.order,
    required this.source,
    required this.index,
    required this.slot,
    required this.selected,
    required this.payload,
    required this.onToggleSelect,
    required this.onDragStarted,
    required this.onDragEnded,
  });

  final ProductionMapSaved order;
  final AdminWarehouse source;
  final int index;
  final M3SegmentVerticalSlot slot;
  final bool selected;
  final _MoveDragPayload payload;
  final VoidCallback onToggleSelect;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final feedbackRadius = BorderRadius.circular(
          M3SegmentedListGeometry.cornerLarge,
        );
        final scheme = Theme.of(context).colorScheme;
        final batchCount = payload.orders.length;
        return _MoveOrderCard(
          order: order,
          index: index,
          slot: slot,
          selected: selected,
          onToggleSelect: onToggleSelect,
          trailing: LongPressDraggable<_MoveDragPayload>(
            data: payload,
            axis: Axis.vertical,
            childWhenDragging: const SizedBox.shrink(),
            dragAnchorStrategy: (_, handleContext, position) {
              final box = handleContext.findRenderObject()! as RenderBox;
              final local = box.globalToLocal(position);
              return Offset(cardWidth - 28, local.dy);
            },
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: cardWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MoveOrderCard(
                      order: order,
                      index: index,
                      slot: M3SegmentVerticalSlot.top,
                      selected: selected,
                      borderRadiusOverride: feedbackRadius,
                    ),
                    if (batchCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '$batchCount ta zakaz',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            onDragStarted: onDragStarted,
            onDragEnd: (_) => onDragEnded(),
            onDraggableCanceled: (_, __) => onDragEnded(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleSelect,
              child: _MoveDragHandle(color: scheme.onSurfaceVariant),
            ),
          ),
        );
      },
    );
  }
}
