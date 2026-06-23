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

class _AdminModulesBody extends StatelessWidget {
  const _AdminModulesBody({
    required this.modules,
    required this.currentModule,
    required this.tabController,
    required this.bottomPadding,
    required this.orders,
    required this.searchQuery,
    required this.baseMetrajByMapId,
    required this.orderKgByMapId,
    required this.selectedApparatus,
    required this.completionRequests,
    required this.readOnly,
    required this.moveTopApparatus,
    required this.moveBottomApparatus,
    required this.selectedMoveOrderIds,
    required this.draggingMoveOrders,
    required this.draggingMoveSource,
    required this.closedOrders,
    required this.onSetModule,
    required this.ordersForApparatus,
    required this.moveOrdersForApparatus,
    required this.canMoveTo,
    required this.onPickSequenceApparatus,
    required this.onReorder,
    required this.onPickMoveTop,
    required this.onPickMoveBottom,
    required this.onToggleMoveSelection,
    required this.buildMoveDragPayload,
    required this.onMoveDragStarted,
    required this.onMoveDragEnded,
    required this.onMove,
  });

  final List<_OpenedOrderModule> modules;
  final _OpenedOrderModule currentModule;
  final TabController tabController;
  final double bottomPadding;
  final List<ProductionMapSaved> orders;
  final String searchQuery;
  final Map<String, double> baseMetrajByMapId;
  final Map<String, double> orderKgByMapId;
  final AdminWarehouse? selectedApparatus;
  final List<AdminCompletionRequestNotification> completionRequests;
  final bool readOnly;
  final AdminWarehouse? moveTopApparatus;
  final AdminWarehouse? moveBottomApparatus;
  final Set<String> selectedMoveOrderIds;
  final List<ProductionMapSaved> draggingMoveOrders;
  final AdminWarehouse? draggingMoveSource;
  final List<AdminClosedProductionOrder> closedOrders;
  final ValueChanged<_OpenedOrderModule> onSetModule;
  final List<ProductionMapSaved> Function(AdminWarehouse apparatus)
      ordersForApparatus;
  final List<ProductionMapSaved> Function({
    required AdminWarehouse source,
    required AdminWarehouse target,
  }) moveOrdersForApparatus;
  final bool Function(
    ProductionMapSaved order,
    AdminWarehouse target, {
    required AdminWarehouse source,
  }) canMoveTo;
  final VoidCallback onPickSequenceApparatus;
  final ReorderCallback onReorder;
  final VoidCallback onPickMoveTop;
  final VoidCallback onPickMoveBottom;
  final ValueChanged<String> onToggleMoveSelection;
  final _MoveDragPayload Function({
    required ProductionMapSaved order,
    required AdminWarehouse source,
    required List<ProductionMapSaved> zoneOrders,
  }) buildMoveDragPayload;
  final ValueChanged<_MoveDragPayload> onMoveDragStarted;
  final VoidCallback onMoveDragEnded;
  final Future<void> Function({
    required List<ProductionMapSaved> orders,
    required AdminWarehouse from,
    required AdminWarehouse to,
  }) onMove;

  String _moduleLabel(_OpenedOrderModule module) {
    return switch (module) {
      _OpenedOrderModule.orders => 'Buyurtmalar',
      _OpenedOrderModule.sequence => 'Ketma-ketlik',
      _OpenedOrderModule.move => 'Ko‘chirish',
      _OpenedOrderModule.closed => 'Yopilgan',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (modules.length > 1)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: TabBar(
              controller: tabController,
              onTap: (index) => onSetModule(modules[index]),
              tabs: [
                for (final module in modules)
                  Tab(height: 38, text: _moduleLabel(module)),
              ],
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              for (final module in modules)
                switch (module) {
                  _OpenedOrderModule.orders => _OrdersModulePage(
                      bottomPadding: bottomPadding,
                      orders: orders,
                      visibleOrders: _visibleOrders(
                        orders: orders,
                        query: searchQuery,
                      ),
                      baseMetrajByMapId: baseMetrajByMapId,
                      orderKgByMapId: orderKgByMapId,
                    ),
                  _OpenedOrderModule.sequence => _SequenceModulePage(
                      bottomPadding: bottomPadding,
                      apparatus: selectedApparatus,
                      completionRequests: completionRequests,
                      orders: selectedApparatus == null
                          ? const []
                          : ordersForApparatus(selectedApparatus!),
                      readOnly: readOnly,
                      baseMetrajByMapId: baseMetrajByMapId,
                      orderKgByMapId: orderKgByMapId,
                      onPickApparatus: onPickSequenceApparatus,
                      onReorder: onReorder,
                    ),
                  _OpenedOrderModule.move => _MoveModulePage(
                      topApparatus: moveTopApparatus,
                      bottomApparatus: moveBottomApparatus,
                      topOrders: moveTopApparatus == null ||
                              moveBottomApparatus == null
                          ? const []
                          : moveOrdersForApparatus(
                              source: moveTopApparatus!,
                              target: moveBottomApparatus!,
                            ),
                      bottomOrders: moveTopApparatus == null ||
                              moveBottomApparatus == null
                          ? const []
                          : moveOrdersForApparatus(
                              source: moveBottomApparatus!,
                              target: moveTopApparatus!,
                            ),
                      selectedOrderIds: selectedMoveOrderIds,
                      draggingOrders: draggingMoveOrders,
                      draggingSource: draggingMoveSource,
                      canMoveTo: (order, target, source) => canMoveTo(
                        order,
                        target,
                        source: source,
                      ),
                      onPickTop: onPickMoveTop,
                      onPickBottom: onPickMoveBottom,
                      onToggleSelect: onToggleMoveSelection,
                      buildDragPayload: buildMoveDragPayload,
                      onDragStarted: onMoveDragStarted,
                      onDragEnded: onMoveDragEnded,
                      onMove: onMove,
                    ),
                  _OpenedOrderModule.closed => _ClosedOrdersModulePage(
                      bottomPadding: bottomPadding,
                      closedOrders: closedOrders,
                      visibleClosedOrders: _visibleClosedOrders(
                        orders: closedOrders,
                        query: searchQuery,
                      ),
                    ),
                },
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkerWatchBody extends StatelessWidget {
  const _WorkerWatchBody({
    required this.apparatus,
    required this.assignedApparatus,
    required this.orders,
    required this.completedOrders,
    required this.sequenceByApparatus,
    required this.queueStatesByApparatus,
    required this.searchQuery,
    required this.bottomPadding,
    required this.tabController,
    required this.onTapCompletedOrder,
    required this.onTapWatchOrder,
  });

  final List<AdminWarehouse> apparatus;
  final List<String> assignedApparatus;
  final List<ProductionMapSaved> orders;
  final List<AdminCompletedQueueOrder> completedOrders;
  final Map<String, List<String>> sequenceByApparatus;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final String searchQuery;
  final double bottomPadding;
  final TabController tabController;
  final ValueChanged<_WorkerCompletedOrderEntry> onTapCompletedOrder;
  final void Function({
    required AdminWarehouse apparatus,
    required ProductionMapSaved order,
  }) onTapWatchOrder;

  String _tabLabel(_WorkerWatchTab tab) {
    if (tab.isCompleted) {
      return 'Tugallangan';
    }
    return productionMapPechatTabLabel(tab.apparatus!.warehouse);
  }

  List<ProductionMapSaved> _ordersForApparatus(AdminWarehouse item) {
    return _productionMapOrdersForApparatus(
      orders: orders,
      apparatus: item,
      sequenceByApparatus: sequenceByApparatus,
      queueStatesByApparatus: queueStatesByApparatus,
      workerMode: true,
      query: searchQuery,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (apparatus.isEmpty) {
      return const Center(
        child: _EmptyOpenedOrders(message: 'Aparatlar topilmadi'),
      );
    }
    final tabs = _workerWatchTabs(
      apparatus: apparatus,
      assignedApparatus: assignedApparatus,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: TabBar(
            controller: tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: [
              for (final tab in tabs) Tab(height: 38, text: _tabLabel(tab)),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              for (final tab in tabs)
                if (tab.isCompleted)
                  _AparatchiCompletedOrdersPage(
                    orders: _workerCompletedOrders(
                      orders: orders,
                      completedOrders: completedOrders,
                      apparatus: apparatus,
                      query: searchQuery,
                    ),
                    bottomPadding: bottomPadding,
                    onTapOrder: onTapCompletedOrder,
                  )
                else
                  _AparatchiWatchSequencePage(
                    apparatus: tab.apparatus!,
                    orders: _ordersForApparatus(tab.apparatus!),
                    bottomPadding: bottomPadding,
                    isAssigned: _isAssignedWatchApparatus(
                      tab.apparatus!,
                      assignedApparatus: assignedApparatus,
                    ),
                    queueStates: _queueStatesForApparatus(
                      tab.apparatus!,
                      queueStatesByApparatus: queueStatesByApparatus,
                    ),
                    onTapOrder: (order) => onTapWatchOrder(
                      apparatus: tab.apparatus!,
                      order: order,
                    ),
                  ),
            ],
          ),
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
