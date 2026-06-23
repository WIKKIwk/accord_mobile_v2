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
