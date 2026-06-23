part of 'admin_production_map_orders_screen.dart';

class _MoveModulePage extends StatefulWidget {
  const _MoveModulePage({
    required this.topApparatus,
    required this.bottomApparatus,
    required this.topOrders,
    required this.bottomOrders,
    required this.selectedOrderIds,
    required this.draggingOrders,
    required this.draggingSource,
    required this.canMoveTo,
    required this.onPickTop,
    required this.onPickBottom,
    required this.onToggleSelect,
    required this.buildDragPayload,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onMove,
  });

  final AdminWarehouse? topApparatus;
  final AdminWarehouse? bottomApparatus;
  final List<ProductionMapSaved> topOrders;
  final List<ProductionMapSaved> bottomOrders;
  final Set<String> selectedOrderIds;
  final List<ProductionMapSaved> draggingOrders;
  final AdminWarehouse? draggingSource;
  final bool Function(
    ProductionMapSaved order,
    AdminWarehouse target,
    AdminWarehouse source,
  ) canMoveTo;
  final VoidCallback onPickTop;
  final VoidCallback onPickBottom;
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
  State<_MoveModulePage> createState() => _MoveModulePageState();
}

class _MoveModulePageState extends State<_MoveModulePage> {
  double _topZoneRatio = 0.5;

  AdminWarehouse? get topApparatus => widget.topApparatus;
  AdminWarehouse? get bottomApparatus => widget.bottomApparatus;
  List<ProductionMapSaved> get topOrders => widget.topOrders;
  List<ProductionMapSaved> get bottomOrders => widget.bottomOrders;
  Set<String> get selectedOrderIds => widget.selectedOrderIds;
  List<ProductionMapSaved> get draggingOrders => widget.draggingOrders;
  AdminWarehouse? get draggingSource => widget.draggingSource;
  bool Function(
    ProductionMapSaved order,
    AdminWarehouse target,
    AdminWarehouse source,
  ) get canMoveTo => widget.canMoveTo;
  VoidCallback get onPickTop => widget.onPickTop;
  VoidCallback get onPickBottom => widget.onPickBottom;
  ValueChanged<String> get onToggleSelect => widget.onToggleSelect;
  _MoveDragPayload Function({
    required ProductionMapSaved order,
    required AdminWarehouse source,
    required List<ProductionMapSaved> zoneOrders,
  }) get buildDragPayload => widget.buildDragPayload;
  ValueChanged<_MoveDragPayload> get onDragStarted => widget.onDragStarted;
  VoidCallback get onDragEnded => widget.onDragEnded;
  Future<void> Function({
    required List<ProductionMapSaved> orders,
    required AdminWarehouse from,
    required AdminWarehouse to,
  }) get onMove => widget.onMove;

  void _resizeMoveZones(double delta, double availableHeight) {
    if (!availableHeight.isFinite || availableHeight <= 0) {
      return;
    }
    final next = (_topZoneRatio + delta / availableHeight).clamp(0.24, 0.76);
    if (next == _topZoneRatio) {
      return;
    }
    setState(() => _topZoneRatio = next);
  }

  @override
  Widget build(BuildContext context) {
    final top = topApparatus;
    final bottom = bottomApparatus;
    if (top == null || bottom == null) {
      return const _EmptyOpenedOrders(message: 'Ko‘chirish uchun aparat yo‘q');
    }
    final viewMetrics = MediaQueryData.fromView(View.of(context));
    final dockInset = dockLayoutBottomInset(
      viewMetrics,
      thinGestureBottom: DockGestureOverlayScope.thinGestureBottomOf(context),
    );
    final bottomInset = 60 + dockInset;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _openedOrderPanelCardGap,
        _openedOrderPanelTopGap,
        _openedOrderPanelCardGap,
        bottomInset,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height * 0.7;
          final topFlex = (_topZoneRatio.clamp(0.24, 0.76) * 1000).round();
          final bottomFlex = 1000 - topFlex;
          return Column(
            children: [
              Expanded(
                flex: topFlex,
                child: Column(
                  children: [
                    _MoveApparatusHeader(
                      key: const ValueKey('move-top-apparatus-picker'),
                      apparatus: top,
                      alignment: Alignment.center,
                      onTap: onPickTop,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _MoveDropZone(
                        apparatus: top,
                        orders: topOrders,
                        selectedOrderIds: selectedOrderIds,
                        draggingOrders: draggingOrders,
                        draggingSource: draggingSource,
                        canMoveTo: canMoveTo,
                        onToggleSelect: onToggleSelect,
                        buildDragPayload: buildDragPayload,
                        onDragStarted: onDragStarted,
                        onDragEnded: onDragEnded,
                        onMove: onMove,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _MoveBoundary(
                  apparatus: bottom,
                  onTap: onPickBottom,
                  onVerticalDragUpdate: (delta) {
                    _resizeMoveZones(delta, availableHeight);
                  },
                ),
              ),
              Expanded(
                flex: bottomFlex,
                child: _MoveDropZone(
                  apparatus: bottom,
                  orders: bottomOrders,
                  selectedOrderIds: selectedOrderIds,
                  draggingOrders: draggingOrders,
                  draggingSource: draggingSource,
                  canMoveTo: canMoveTo,
                  onToggleSelect: onToggleSelect,
                  buildDragPayload: buildDragPayload,
                  onDragStarted: onDragStarted,
                  onDragEnded: onDragEnded,
                  onMove: onMove,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
