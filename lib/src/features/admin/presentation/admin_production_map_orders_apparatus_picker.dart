part of 'admin_production_map_orders_screen.dart';

class _ApparatusPickerSheet extends StatelessWidget {
  const _ApparatusPickerSheet({
    required this.apparatus,
    this.selected,
    this.orderCountFor,
    this.showUnassigned = false,
    this.unassignedOrderCount = 0,
  });

  final List<AdminWarehouse> apparatus;
  final AdminWarehouse? selected;
  final int Function(AdminWarehouse apparatus)? orderCountFor;
  final bool showUnassigned;
  final int unassignedOrderCount;

  @override
  Widget build(BuildContext context) {
    final sheetHeight = (MediaQuery.sizeOf(context).height * 0.52).clamp(
      360.0,
      520.0,
    );
    return SafeArea(
      child: SizedBox(
        height: sheetHeight.toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Aparat tanlang',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _ApparatusPickerList(
                apparatus: apparatus,
                selected: selected,
                orderCountFor: orderCountFor,
                showUnassigned: showUnassigned,
                unassignedOrderCount: unassignedOrderCount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApparatusPickerList extends StatelessWidget {
  const _ApparatusPickerList({
    required this.apparatus,
    this.selected,
    this.orderCountFor,
    this.showUnassigned = false,
    this.unassignedOrderCount = 0,
  });

  final List<AdminWarehouse> apparatus;
  final AdminWarehouse? selected;
  final int Function(AdminWarehouse apparatus)? orderCountFor;
  final bool showUnassigned;
  final int unassignedOrderCount;

  @override
  Widget build(BuildContext context) {
    final itemCount = apparatus.length + (showUnassigned ? 1 : 0);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        M3SegmentSpacedColumn(
          children: [
            if (showUnassigned)
              _ApparatusRow(
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  0,
                  itemCount,
                ),
                apparatus: _moveUnassignedWarehouse,
                selected: _isMoveUnassignedApparatus(selected),
                orderCount: unassignedOrderCount,
                onTap: () =>
                    Navigator.of(context).pop(_moveUnassignedWarehouse),
              ),
            for (var index = 0; index < apparatus.length; index++)
              _ApparatusRow(
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                  index + (showUnassigned ? 1 : 0),
                  itemCount,
                ),
                apparatus: apparatus[index],
                selected: selected?.warehouse == apparatus[index].warehouse,
                orderCount: orderCountFor?.call(apparatus[index]) ?? 0,
                onTap: () => Navigator.of(context).pop(apparatus[index]),
              ),
          ],
        ),
      ],
    );
  }
}

class _ApparatusRow extends StatelessWidget {
  const _ApparatusRow({
    required this.slot,
    required this.apparatus,
    required this.selected,
    required this.orderCount,
    required this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final AdminWarehouse apparatus;
  final bool selected;
  final int orderCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = M3SegmentedListGeometry.borderRadius(
      slot,
      M3SegmentedListGeometry.cornerRadiusForSlot(slot),
    );
    return Material(
      color: selected ? scheme.primaryContainer : scheme.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? scheme.surface.withValues(alpha: 0.72)
                        : scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.precision_manufacturing_rounded,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onPrimaryContainer,
                    size: 17,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apparatus.warehouse,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$orderCount ta zakaz',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
