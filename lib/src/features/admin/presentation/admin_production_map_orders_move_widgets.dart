part of 'admin_production_map_orders_screen.dart';

class _MoveDragPayload
    extends TransferDragPayload<ProductionMapSaved, AdminApparatus> {
  const _MoveDragPayload(
      {required List<ProductionMapSaved> orders, required super.source})
      : super(items: orders);
  List<ProductionMapSaved> get orders => items;
}

class _MoveOrderCard extends StatelessWidget {
  const _MoveOrderCard({
    required this.order,
    required this.index,
    required this.slot,
    this.selected = false,
    this.disabled = false,
    this.onToggleSelect,
    this.trailing,
    this.borderRadiusOverride,
  });
  final ProductionMapSaved order;
  final int index;
  final M3SegmentVerticalSlot slot;
  final bool selected;
  final bool disabled;
  final VoidCallback? onToggleSelect;
  final Widget? trailing;
  final BorderRadius? borderRadiusOverride;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _OpenedOrderCardRow(
      slot: slot,
      order: order,
      onTap: disabled ? null : onToggleSelect,
      borderRadiusOverride: borderRadiusOverride,
      disabled: disabled,
      leading: _OpenedOrderIndexBadge(
        index: index,
        selected: selected,
        onTap: disabled ? null : onToggleSelect,
      ),
      trailing: trailing ?? _MoveDragHandle(color: scheme.onSurfaceVariant),
    );
  }
}

typedef _MoveDragHandle = TransferDragHandle;

class _MoveEmptyZone extends StatelessWidget {
  const _MoveEmptyZone({required this.apparatus});
  final AdminApparatus apparatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message = _isMoveUnassignedApparatus(apparatus)
        ? 'Tanlanmagan zakaz yo‘q'
        : '${apparatus.name} uchun zakaz yo‘q';
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
    required this.allowUnassignedAlternativeMove,
    required this.onToggleSelect,
    required this.buildDragPayload,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onMove,
  });
  final AdminApparatus apparatus;
  final List<ProductionMapSaved> orders;
  final Set<String> selectedOrderIds;
  final List<ProductionMapSaved> draggingOrders;
  final AdminApparatus? draggingSource;
  final bool Function(
    ProductionMapSaved order,
    AdminApparatus target,
    AdminApparatus source,
  ) canMoveTo;
  final bool allowUnassignedAlternativeMove;
  final ValueChanged<String> onToggleSelect;
  final _MoveDragPayload Function({
    required ProductionMapSaved order,
    required AdminApparatus source,
    required List<ProductionMapSaved> zoneOrders,
  }) buildDragPayload;
  final ValueChanged<_MoveDragPayload> onDragStarted;
  final VoidCallback onDragEnded;
  final Future<void> Function({
    required List<ProductionMapSaved> orders,
    required AdminApparatus from,
    required AdminApparatus to,
  }) onMove;

  @override
  Widget build(BuildContext context) =>
      TransferDropZone<ProductionMapSaved, AdminApparatus, _MoveDragPayload>(
        zone: apparatus,
        items: orders,
        selectedItemIds: selectedOrderIds,
        draggingItems: draggingOrders,
        draggingSource: draggingSource,
        canMoveTo: canMoveTo,
        sameZone: _sameMoveApparatusIdentity,
        itemId: (order) => order.map.id.trim(),
        itemKey: (order, apparatus, disabled) => ValueKey(
            '${disabled ? 'move-order-disabled' : 'move-order'}-${apparatus.name}-${order.map.id}'),
        isItemDisabled: (order, apparatus) =>
            !allowUnassignedAlternativeMove &&
            _isUnassignedAlternativeCandidateForApparatus(
                order: order, apparatus: apparatus),
        emptyState: _MoveEmptyZone(apparatus: apparatus),
        batchLabel: (count) => '$count ta buyurtma',
        onToggleSelect: onToggleSelect,
        buildDragPayload: (
                {required item, required source, required zoneItems}) =>
            buildDragPayload(
                order: item, source: source, zoneOrders: zoneItems),
        onDragStarted: onDragStarted,
        onDragEnded: onDragEnded,
        onMove: ({required items, required from, required to}) =>
            onMove(orders: items, from: from, to: to),
        itemCardBuilder: (
                {required item,
                required index,
                required slot,
                required selected,
                required disabled,
                required onToggleSelect,
                required trailing,
                required borderRadiusOverride}) =>
            _MoveOrderCard(
                order: item,
                index: index,
                slot: slot,
                selected: selected,
                disabled: disabled,
                onToggleSelect: onToggleSelect,
                trailing: trailing,
                borderRadiusOverride: borderRadiusOverride),
      );
}

class _MoveApparatusHeader extends StatelessWidget {
  const _MoveApparatusHeader({
    super.key,
    required this.apparatus,
    required this.alignment,
    required this.onTap,
  });
  final AdminApparatus apparatus;
  final Alignment alignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TransferPickerHeader(
        title: apparatus.name,
        icon: Icons.precision_manufacturing_rounded,
        alignment: alignment,
        onTap: onTap,
      );
}
