part of 'admin_production_map_orders_screen.dart';

class _OrdersModulePage extends StatelessWidget {
  const _OrdersModulePage({
    required this.bottomPadding,
    required this.orders,
    required this.visibleOrders,
    required this.customerNameByMapId,
    required this.orderStatusesByOrderId,
    required this.orderControlsByOrderId,
    required this.onInfoOrder,
    required this.onLongPressOrder,
  });

  final double bottomPadding;
  final List<ProductionMapSaved> orders;
  final List<ProductionMapSaved> visibleOrders;
  final Map<String, String> customerNameByMapId;
  final Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId;
  final Map<String, AdminOrderControlState> orderControlsByOrderId;
  final ValueChanged<ProductionMapSaved> onInfoOrder;
  final ValueChanged<ProductionMapSaved> onLongPressOrder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        _openedOrderPanelCardGap,
        _openedOrderPanelTopGap,
        _openedOrderPanelCardGap,
        bottomPadding,
      ),
      children: [
        if (orders.isEmpty)
          const _EmptyOpenedOrders(message: 'Ochilgan zakaz yo‘q')
        else if (visibleOrders.isEmpty)
          const _EmptyOpenedOrders(message: 'Zakaz topilmadi')
        else
          _OpenedOrderList(
            orders: visibleOrders,
            customerNameByMapId: customerNameByMapId,
            orderStatusesByOrderId: orderStatusesByOrderId,
            orderControlsByOrderId: orderControlsByOrderId,
            onInfoOrder: onInfoOrder,
            onLongPressOrder: onLongPressOrder,
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
    required this.apparatus,
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
    required this.onSelectSequenceApparatus,
    required this.onReorder,
    required this.onPickMoveTop,
    required this.onPickMoveBottom,
    required this.onToggleMoveSelection,
    required this.buildMoveDragPayload,
    required this.onMoveDragStarted,
    required this.onMoveDragEnded,
    required this.onMove,
    required this.customerNameByMapId,
    required this.queueStatesByApparatus,
    required this.orderStatusesByOrderId,
    required this.orderControlsByOrderId,
    required this.workflowAudit,
    required this.workflowAuditError,
    required this.workflowAuditLoading,
    required this.onRefreshWorkflowAudit,
    required this.onInfoOrder,
    required this.onInfoSequenceOrder,
    required this.onLongPressOrder,
  });

  final List<_OpenedOrderModule> modules;
  final _OpenedOrderModule currentModule;
  final TabController tabController;
  final double bottomPadding;
  final List<ProductionMapSaved> orders;
  final String searchQuery;
  final List<AdminApparatus> apparatus;
  final AdminApparatus? selectedApparatus;
  final List<AdminCompletionRequestNotification> completionRequests;
  final bool readOnly;
  final AdminApparatus? moveTopApparatus;
  final AdminApparatus? moveBottomApparatus;
  final Set<String> selectedMoveOrderIds;
  final List<ProductionMapSaved> draggingMoveOrders;
  final AdminApparatus? draggingMoveSource;
  final List<AdminClosedProductionOrder> closedOrders;
  final ValueChanged<_OpenedOrderModule> onSetModule;
  final List<ProductionMapSaved> Function(AdminApparatus apparatus)
      ordersForApparatus;
  final List<ProductionMapSaved> Function({
    required AdminApparatus source,
    required AdminApparatus target,
  }) moveOrdersForApparatus;
  final bool Function(
    ProductionMapSaved order,
    AdminApparatus target, {
    required AdminApparatus source,
  }) canMoveTo;
  final ValueChanged<AdminApparatus> onSelectSequenceApparatus;
  final ReorderCallback onReorder;
  final VoidCallback onPickMoveTop;
  final VoidCallback onPickMoveBottom;
  final ValueChanged<String> onToggleMoveSelection;
  final _MoveDragPayload Function({
    required ProductionMapSaved order,
    required AdminApparatus source,
    required List<ProductionMapSaved> zoneOrders,
  }) buildMoveDragPayload;
  final ValueChanged<_MoveDragPayload> onMoveDragStarted;
  final VoidCallback onMoveDragEnded;
  final Future<void> Function({
    required List<ProductionMapSaved> orders,
    required AdminApparatus from,
    required AdminApparatus to,
  }) onMove;
  final ValueChanged<ProductionMapSaved> onInfoOrder;
  final void Function({
    required AdminApparatus apparatus,
    required ProductionMapSaved order,
  })? onInfoSequenceOrder;
  final Map<String, String> customerNameByMapId;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId;
  final Map<String, AdminOrderControlState> orderControlsByOrderId;
  final AdminProductionWorkflowAuditReport? workflowAudit;
  final String? workflowAuditError;
  final bool workflowAuditLoading;
  final Future<void> Function() onRefreshWorkflowAudit;
  final ValueChanged<ProductionMapSaved> onLongPressOrder;

  String _moduleLabel(_OpenedOrderModule module) {
    return switch (module) {
      _OpenedOrderModule.orders => 'Buyurtmalar',
      _OpenedOrderModule.sequence => 'Ketma-ketlik',
      _OpenedOrderModule.move => 'Ko‘chirish',
      _OpenedOrderModule.closed => 'Yopilgan',
      _OpenedOrderModule.audit => 'Audit',
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
                      customerNameByMapId: customerNameByMapId,
                      orderStatusesByOrderId: orderStatusesByOrderId,
                      orderControlsByOrderId: orderControlsByOrderId,
                      onInfoOrder: onInfoOrder,
                      onLongPressOrder: onLongPressOrder,
                    ),
                  _OpenedOrderModule.sequence => _SequenceModulePage(
                      bottomPadding: bottomPadding,
                      availableApparatus: apparatus,
                      apparatus: selectedApparatus,
                      completionRequests: completionRequests,
                      orders: selectedApparatus == null
                          ? const []
                          : ordersForApparatus(selectedApparatus!),
                      readOnly: readOnly,
                      onSelectApparatus: onSelectSequenceApparatus,
                      onReorder: onReorder,
                      customerNameByMapId: customerNameByMapId,
                      queueStates: selectedApparatus == null
                          ? const {}
                          : _queueStatesForApparatus(
                              selectedApparatus!,
                              queueStatesByApparatus: queueStatesByApparatus,
                            ),
                      orderStatusesByOrderId: orderStatusesByOrderId,
                      orderControlsByOrderId: orderControlsByOrderId,
                      onInfoOrder: onInfoSequenceOrder == null
                          ? null
                          : (order) => onInfoSequenceOrder!(
                                apparatus: selectedApparatus!,
                                order: order,
                              ),
                      onLongPressOrder: onLongPressOrder,
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
                  _OpenedOrderModule.audit => _WorkflowAuditModulePage(
                      bottomPadding: bottomPadding,
                      report: workflowAudit,
                      errorMessage: workflowAuditError,
                      loading: workflowAuditLoading,
                      onRefresh: onRefreshWorkflowAudit,
                    ),
                },
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkflowAuditModulePage extends StatelessWidget {
  const _WorkflowAuditModulePage({
    required this.bottomPadding,
    required this.report,
    required this.errorMessage,
    required this.loading,
    required this.onRefresh,
  });

  final double bottomPadding;
  final AdminProductionWorkflowAuditReport? report;
  final String? errorMessage;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentReport = report;
    return ListView(
      padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPadding),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      currentReport?.ok == true
                          ? Icons.verified_outlined
                          : Icons.warning_amber_rounded,
                      color: currentReport?.ok == true
                          ? scheme.primary
                          : scheme.error,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentReport == null
                                ? 'Workflow audit'
                                : currentReport.ok
                                    ? 'Workflow audit toza'
                                    : 'Workflow audit violationlari bor',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Queue, WIP, session, transfer va capacity invariantlari tekshiriladi.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Auditni yangilash',
                      onPressed: loading ? null : onRefresh,
                      icon: loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                  ],
                ),
                if (currentReport != null) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AuditCountChip(
                        icon: Icons.receipt_long_outlined,
                        label: 'Order',
                        value: currentReport.checkedOrderCount,
                      ),
                      _AuditCountChip(
                        icon: Icons.inventory_2_outlined,
                        label: 'Batch',
                        value: currentReport.checkedBatchCount,
                      ),
                      _AuditCountChip(
                        icon: Icons.play_circle_outline,
                        label: 'Session',
                        value: currentReport.checkedSessionCount,
                      ),
                      _AuditCountChip(
                        icon: Icons.report_problem_outlined,
                        label: 'Violation',
                        value: currentReport.violations.length,
                      ),
                    ],
                  ),
                ],
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage!,
                    style: TextStyle(color: scheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (currentReport?.violations.isNotEmpty == true)
          for (final violation in currentReport!.violations)
            Card(
              child: ListTile(
                leading: Icon(Icons.error_outline, color: scheme.error),
                title: Text(
                  violation.code.isEmpty
                      ? 'Workflow violation'
                      : violation.code,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    if (violation.orderId.isNotEmpty) violation.orderId,
                    if (violation.subject.isNotEmpty) violation.subject,
                    if (violation.detail.isNotEmpty) violation.detail,
                  ].join(' • '),
                ),
              ),
            ),
        if (currentReport?.ok == true)
          Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline, color: scheme.primary),
              title: const Text('Barcha tekshiruvlar muvaffaqiyatli'),
              subtitle: const Text(
                'Yashirin queue/WIP nomuvofiqligi aniqlanmadi.',
              ),
            ),
          ),
        if (currentReport == null && errorMessage == null)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _AuditCountChip extends StatelessWidget {
  const _AuditCountChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text('$label: $value'),
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
    required this.visibleOrderIdsByApparatus,
    required this.queueStatesByApparatus,
    required this.orderStatusesByOrderId,
    required this.orderControlsByOrderId,
    required this.searchQuery,
    required this.bottomPadding,
    required this.tabController,
    required this.onTapCompletedOrder,
    required this.onTapWatchOrder,
  });

  final List<AdminApparatus> apparatus;
  final List<String> assignedApparatus;
  final List<ProductionMapSaved> orders;
  final List<AdminCompletedQueueOrder> completedOrders;
  final Map<String, List<String>> sequenceByApparatus;
  final Map<String, List<String>> visibleOrderIdsByApparatus;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId;
  final Map<String, AdminOrderControlState> orderControlsByOrderId;
  final String searchQuery;
  final double bottomPadding;
  final TabController tabController;
  final ValueChanged<_WorkerCompletedOrderEntry> onTapCompletedOrder;
  final void Function({
    required AdminApparatus apparatus,
    required ProductionMapSaved order,
  }) onTapWatchOrder;

  String _tabLabel(_WorkerWatchTab tab) {
    if (tab.isCompleted) {
      return 'Tugallangan';
    }
    return productionMapPechatTabLabel(tab.apparatus!.name);
  }

  List<ProductionMapSaved> _ordersForApparatus(AdminApparatus item) {
    return _productionMapOrdersForApparatus(
      orders: orders,
      apparatus: item,
      visibleOrderIdsByApparatus: visibleOrderIdsByApparatus,
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
                    orderStatusesByOrderId: orderStatusesByOrderId,
                    orderControlsByOrderId: orderControlsByOrderId,
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
    required this.orderStatusesByOrderId,
    required this.orderControlsByOrderId,
    required this.onTapOrder,
  });

  final AdminApparatus apparatus;
  final List<ProductionMapSaved> orders;
  final double bottomPadding;
  final bool isAssigned;
  final Map<String, String> queueStates;
  final Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId;
  final Map<String, AdminOrderControlState> orderControlsByOrderId;
  final ValueChanged<ProductionMapSaved> onTapOrder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ColoredBox(
      color: AppTheme.shellStart(context),
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
            _EmptyOpenedOrders(message: '${apparatus.name} uchun zakaz yo‘q')
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < orders.length; index++)
                  _SequenceOrderRow(
                    key: ValueKey(
                      'worker-order-${orders[index].map.id.trim()}',
                    ),
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      orders.length,
                    ),
                    order: orders[index],
                    index: index,
                    readOnly: true,
                    onTap: () => onTapOrder(orders[index]),
                    tone: _resolveOrderCardTone(
                      orderStatus:
                          orderStatusesByOrderId[orders[index].map.id.trim()],
                      orderControl:
                          orderControlsByOrderId[orders[index].map.id.trim()] ??
                              AdminOrderControlState.active,
                      apparatusState: apparatusQueueOrderStateFromRaw(
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
      color: AppTheme.shellStart(context),
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
                  _SequenceOrderRow(
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index,
                      orders.length,
                    ),
                    order: orders[index].order,
                    index: index,
                    readOnly: true,
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
