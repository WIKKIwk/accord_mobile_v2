part of 'admin_production_map_orders_screen.dart';

class _OrdersModulePage extends StatelessWidget {
  const _OrdersModulePage({
    required this.bottomPadding,
    required this.orders,
    required this.visibleOrders,
    required this.customerNameByMapId,
    required this.orderStatusesByOrderId,
    required this.orderControlsByOrderId,
    required this.queueStatesByApparatus,
    required this.onInfoOrder,
    required this.onLongPressOrder,
  });

  final double bottomPadding;
  final List<ProductionMapSaved> orders;
  final List<ProductionMapSaved> visibleOrders;
  final Map<String, String> customerNameByMapId;
  final Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId;
  final Map<String, AdminOrderControlState> orderControlsByOrderId;
  final Map<String, Map<String, String>> queueStatesByApparatus;
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
          _EmptyOpenedOrders(
            message: context.l10n.adminText('production.open_empty'),
          )
        else if (visibleOrders.isEmpty)
          _EmptyOpenedOrders(
            message: context.l10n.adminText('production.search_empty'),
          )
        else
          _OpenedOrderList(
            orders: visibleOrders,
            customerNameByMapId: customerNameByMapId,
            orderStatusesByOrderId: orderStatusesByOrderId,
            orderControlsByOrderId: orderControlsByOrderId,
            queueStatesByApparatus: queueStatesByApparatus,
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
    required this.frozenOrdersByApparatus,
    required this.orderStatusesByOrderId,
    required this.qolipOrderNotesByOrderId,
    this.sequenceInteractionHint,
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
  final Map<String, List<AdminFrozenQueueOrder>> frozenOrdersByApparatus;
  final Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId;
  final Map<String, AdminQolipOrderNote> qolipOrderNotesByOrderId;
  final String? sequenceInteractionHint;
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
      _OpenedOrderModule.audit => 'Tekshiruv',
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
                      queueStatesByApparatus: queueStatesByApparatus,
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
                      frozenOrders: selectedApparatus == null
                          ? const []
                          : _productionMapFrozenOrdersForApparatus(
                              apparatus: selectedApparatus!,
                              frozenOrdersByApparatus: frozenOrdersByApparatus,
                              query: searchQuery,
                            ),
                      orderStatusesByOrderId: orderStatusesByOrderId,
                      qolipOrderNotesByOrderId: qolipOrderNotesByOrderId,
                      interactionHint: sequenceInteractionHint,
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
                      apparatusCatalog: apparatus,
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
                                ? context.l10n.adminText(
                                    'production.audit_title',
                                  )
                                : currentReport.ok
                                    ? context.l10n.adminText(
                                        'production.audit_clean',
                                      )
                                    : context.l10n.adminText(
                                        'production.audit_issues',
                                      ),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.adminText(
                              'production.audit_description',
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.adminText(
                        'production.refresh_audit',
                      ),
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
                        label: context.l10n.adminText('production.orders'),
                        value: currentReport.checkedOrderCount,
                      ),
                      _AuditCountChip(
                        icon: Icons.inventory_2_outlined,
                        label: context.l10n.adminText('production.batches'),
                        value: currentReport.checkedBatchCount,
                      ),
                      _AuditCountChip(
                        icon: Icons.play_circle_outline,
                        label: context.l10n.adminText('production.sessions'),
                        value: currentReport.checkedSessionCount,
                      ),
                      _AuditCountChip(
                        icon: Icons.report_problem_outlined,
                        label: context.l10n.adminText('production.errors'),
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
                  _workflowAuditViolationText(violation.code),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    if (violation.orderId.isNotEmpty)
                      context.l10n.adminText(
                        'production.audit_order',
                        values: {'value': violation.orderId},
                      ),
                    if (violation.subject.isNotEmpty)
                      context.l10n.adminText(
                        'production.audit_object',
                        values: {'value': violation.subject},
                      ),
                  ].join(' • '),
                ),
              ),
            ),
        if (currentReport?.ok == true)
          Card(
            child: ListTile(
              leading: Icon(Icons.check_circle_outline, color: scheme.primary),
              title: Text(
                context.l10n.adminText('production.audit_success'),
              ),
              subtitle: Text(
                context.l10n.adminText(
                  'production.audit_success_description',
                ),
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

String _workflowAuditViolationText(String code) {
  return switch (code.trim().toLowerCase()) {
    'duplicate_active_queue_assignment' =>
      'Buyurtma bir nechta aparat navbatida faol yoki pauzadagi holatda turibdi',
    'blank_progress_batch_id' =>
      'Progress partiyada identifikator ko‘rsatilmagan',
    'duplicate_progress_batch_id' =>
      'Progress partiya identifikatori takrorlangan',
    'duplicate_qr_payload' =>
      'Bir progress QR kodi bir nechta partiyada ishlatilgan',
    'duplicate_active_order_session' =>
      'Buyurtma uchun bir nechta faol yoki pauzadagi sessiya mavjud',
    'blank_queue_apparatus' => 'Navbat guruhida aparat ko‘rsatilmagan',
    'blank_queue_order' => 'Navbatda buyurtma identifikatori bo‘sh',
    'unknown_order_queue_state' =>
      'Navbat holati mavjud bo‘lmagan buyurtmaga tegishli',
    'invalid_queue_state' => 'Navbat holati noto‘g‘ri',
    'queue_order_apparatus_mismatch' =>
      'Navbat holati buyurtma yo‘nalishida bo‘lmagan aparatga saqlangan',
    'blank_queue_sequence_order' =>
      'Aparat ketma-ketligida buyurtma identifikatori bo‘sh',
    'duplicate_queue_sequence_order' =>
      'Aparat ketma-ketligida buyurtma takrorlangan',
    'unknown_order_queue_sequence' =>
      'Ketma-ketlik mavjud bo‘lmagan buyurtmaga tegishli',
    'queue_sequence_apparatus_mismatch' =>
      'Ketma-ketlikdagi buyurtma bu aparat bosqichiga tegishli emas',
    'blank_run_session_id' => 'Ish sessiyasida identifikator ko‘rsatilmagan',
    'blank_run_session_apparatus' => 'Ish sessiyasida aparat ko‘rsatilmagan',
    'unknown_order_run_session' =>
      'Ish sessiyasi mavjud bo‘lmagan buyurtmaga tegishli',
    'run_session_apparatus_mismatch' =>
      'Faol yoki pauzadagi sessiya buyurtma yo‘nalishidan tashqaridagi aparatga biriktirilgan',
    'session_queue_state_mismatch' => 'Sessiya holati navbat holatiga mos emas',
    'completed_session_active_queue' =>
      'Tugallangan sessiya faol navbat holatini qoldirgan',
    'unknown_order_progress_batch' =>
      'Progress partiya mavjud bo‘lmagan buyurtmaga tegishli',
    'blank_progress_batch_apparatus' =>
      'Progress partiyada aparat ko‘rsatilmagan',
    'blank_progress_batch_session' =>
      'Progress partiyada sessiya ko‘rsatilmagan',
    'progress_batch_session_order_mismatch' =>
      'Progress partiya sessiyasi buyurtmaga mos emas',
    'progress_batch_session_not_found' =>
      'Progress partiya sessiyasi topilmadi',
    'progress_batch_apparatus_mismatch' =>
      'Progress partiya aparati sessiya yoki buyurtma bosqichiga mos emas',
    'progress_batch_status_action_mismatch' =>
      'Progress partiya holati va amali bir-biriga mos emas',
    'waiting_wip_has_owner' =>
      'Kutilayotgan WIP foydalanish yoki qayta ishlash egasiga biriktirilgan',
    'waiting_wip_missing_location' =>
      'Kutilayotgan WIP uchun joriy aparat ko‘rsatilmagan',
    'in_use_wip_missing_usage' =>
      'Ishlatilayotgan WIP uchun sessiya yoki aparat ko‘rsatilmagan',
    'in_use_wip_location_mismatch' =>
      'Ishlatilayotgan WIPning joriy aparati foydalanish egasiga mos emas',
    'in_use_wip_session_not_found' => 'Ishlatilayotgan WIP sessiyasi topilmadi',
    'processed_wip_missing_processor' =>
      'Qayta ishlangan WIP uchun sessiya yoki aparat ko‘rsatilmagan',
    'processed_wip_session_not_found' =>
      'Qayta ishlangan WIP sessiyasi topilmadi',
    'accepted_wip_missing_stock_id' =>
      'Ombor qabul qilgan WIP uchun tayyor mahsulot identifikatori ko‘rsatilmagan',
    'progress_batch_self_parent' =>
      'Progress partiya o‘zini ota partiya sifatida ko‘rsatgan',
    'progress_batch_parent_order_mismatch' =>
      'Progress partiya boshqa buyurtma partiyasiga ulanib qolgan',
    'progress_batch_parent_apparatus_mismatch' =>
      'Farzand progress partiya ota partiyaning keyingi aparatiga kirmaydi',
    'progress_batch_parent_not_found' =>
      'Progress partiyaning ota partiyasi topilmadi',
    'paused_session_progress_mismatch' =>
      'Pauzadagi sessiyaga mos pauza progress partiyasi topilmadi',
    'invalid_apparatus_transfer_receipt' =>
      'Aparat ko‘chirish qaydi to‘liq emas',
    'unknown_order_apparatus_transfer' =>
      'Aparat ko‘chirish qaydi mavjud bo‘lmagan buyurtmaga tegishli',
    'invalid_apparatus_transfer_route' =>
      'Aparat ko‘chirish yo‘nalishi noto‘g‘ri',
    'apparatus_transfer_missing_reason' =>
      'Aparat ko‘chirish sababi ko‘rsatilmagan',
    'apparatus_transfer_map_mismatch' =>
      'Aparat ko‘chirish qaydi buyurtma xaritasiga mos emas',
    'apparatus_transfer_session_mismatch' =>
      'Aparat ko‘chirish sessiyasi maqsadli aparatdagi pauza holatiga mos emas',
    'apparatus_transfer_progress_mismatch' =>
      'Aparat ko‘chirish progress partiyasi maqsadli aparatdagi pauza holatiga mos emas',
    'apparatus_transfer_queue_mismatch' =>
      'Aparat ko‘chirishdan keyin navbat holati noto‘g‘ri',
    'duplicate_capacity_profile' => 'Aparat uchun quvvat profili takrorlangan',
    'invalid_capacity_profile' =>
      'Aparat quvvati yoki samaradorlik qiymati noto‘g‘ri',
    'invalid_apparatus_downtime' =>
      'Aparat ishlamay qolish vaqti ma’lumotlari noto‘g‘ri',
    'unknown_order_schedule_reservation' =>
      'Rejalashtirilgan navbat mavjud bo‘lmagan buyurtmaga tegishli',
    'invalid_schedule_reservation' =>
      'Rejalashtirilgan navbat ma’lumotlari to‘liq yoki noto‘g‘ri',
    'duplicate_schedule_idempotency_key' =>
      'Rejalashtirilgan navbat amal kaliti takrorlangan',
    'capacity_overbooked' =>
      'Aparat quvvati bir vaqtdagi buyurtmalar bilan oshirib yuborilgan',
    _ => 'Ish jarayoni ma’lumotlarida nomuvofiqlik aniqlandi',
  };
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
    required this.frozenOrdersByApparatus,
    required this.orderStatusesByOrderId,
    required this.orderControlsByOrderId,
    required this.searchQuery,
    required this.bottomPadding,
    required this.tabController,
    required this.onTapCompletedOrder,
    required this.onTapWatchOrder,
    required this.onLongPressWatchOrder,
  });

  final List<AdminApparatus> apparatus;
  final List<String> assignedApparatus;
  final List<ProductionMapSaved> orders;
  final List<AdminCompletedQueueOrder> completedOrders;
  final Map<String, List<String>> sequenceByApparatus;
  final Map<String, List<String>> visibleOrderIdsByApparatus;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final Map<String, List<AdminFrozenQueueOrder>> frozenOrdersByApparatus;
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
  final Future<void> Function({
    required AdminApparatus apparatus,
    required ProductionMapSaved order,
  }) onLongPressWatchOrder;

  String _tabLabel(BuildContext context, _WorkerWatchTab tab) {
    if (tab.isCompleted) {
      return context.l10n.productionText('worker.queue.tab.completed');
    }
    return tab.apparatus!.name.trim();
  }

  List<ProductionMapSaved> _ordersForApparatus(AdminApparatus item) {
    return _productionMapOrdersForApparatus(
      orders: orders,
      apparatus: item,
      visibleOrderIdsByApparatus: visibleOrderIdsByApparatus,
      sequenceByApparatus: sequenceByApparatus,
      queueStatesByApparatus: queueStatesByApparatus,
      orderControlsByOrderId: orderControlsByOrderId,
      workerMode: true,
      query: searchQuery,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (apparatus.isEmpty) {
      return Center(
        child: _EmptyOpenedOrders(
          message: context.l10n.productionText('worker.queue.empty.apparatus'),
        ),
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
              for (final tab in tabs)
                Tab(height: 38, text: _tabLabel(context, tab)),
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
                    frozenOrders: _productionMapFrozenOrdersForApparatus(
                      apparatus: tab.apparatus!,
                      frozenOrdersByApparatus: frozenOrdersByApparatus,
                      query: searchQuery,
                    ),
                    orderStatusesByOrderId: orderStatusesByOrderId,
                    orderControlsByOrderId: orderControlsByOrderId,
                    onTapOrder: (order) => onTapWatchOrder(
                      apparatus: tab.apparatus!,
                      order: order,
                    ),
                    onLongPressOrder: (order) => unawaited(
                      onLongPressWatchOrder(
                        apparatus: tab.apparatus!,
                        order: order,
                      ),
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
    required this.frozenOrders,
    required this.orderStatusesByOrderId,
    required this.orderControlsByOrderId,
    required this.onTapOrder,
    required this.onLongPressOrder,
  });

  final AdminApparatus apparatus;
  final List<ProductionMapSaved> orders;
  final double bottomPadding;
  final bool isAssigned;
  final Map<String, String> queueStates;
  final List<AdminFrozenQueueOrder> frozenOrders;
  final Map<String, AdminProductionOrderStatusDetail> orderStatusesByOrderId;
  final Map<String, AdminOrderControlState> orderControlsByOrderId;
  final ValueChanged<ProductionMapSaved> onTapOrder;
  final ValueChanged<ProductionMapSaved> onLongPressOrder;

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
                context.l10n.productionText('worker.queue.your.apparatus'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (orders.isEmpty && frozenOrders.isEmpty)
            _EmptyOpenedOrders(
              message: context.l10n.productionText(
                'worker.queue.empty.orders',
                values: {
                  'apparatus': apparatus.name.trim(),
                },
              ),
            )
          else if (orders.isNotEmpty)
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
                    onLongPress: () => onLongPressOrder(orders[index]),
                    tone: _resolveOrderCardTone(
                      orderStatus:
                          orderStatusesByOrderId[orders[index].map.id.trim()],
                      orderControl: adminProductionMapOrderControlFor(
                        orderControlsByOrderId,
                        orders[index].map.id.trim(),
                      ),
                      apparatusState: apparatusQueueOrderStateFromRaw(
                        queueStates[orders[index].map.id.trim()],
                      ),
                    ),
                  ),
              ],
            ),
          if (frozenOrders.isNotEmpty) ...[
            const SizedBox(height: 18),
            _FrozenQueueOrdersSection(orders: frozenOrders),
          ],
        ],
      ),
    );
  }
}

enum _LaminatsiyaWorkerLongPressChoice {
  finishWork,
  continueRoll,
  removeRoll,
}

class _LaminatsiyaWorkerFinishSheet extends StatelessWidget {
  const _LaminatsiyaWorkerFinishSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.productionText('worker.finish.title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.productionText('worker.finish.description'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(
                _LaminatsiyaWorkerLongPressChoice.finishWork,
              ),
              icon: const Icon(Icons.logout_rounded),
              label: Text(
                context.l10n.productionText('worker.finish.title'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaminatsiyaWorkerHandoffSheet extends StatelessWidget {
  const _LaminatsiyaWorkerHandoffSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.productionText('worker.handoff.title'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.productionText('worker.handoff.description'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(
                _LaminatsiyaWorkerLongPressChoice.continueRoll,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                context.l10n.productionText('worker.handoff.continue'),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(
                _LaminatsiyaWorkerLongPressChoice.removeRoll,
              ),
              icon: const Icon(Icons.unarchive_rounded),
              label: Text(
                context.l10n.productionText('worker.handoff.detach'),
              ),
            ),
          ],
        ),
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
              context.l10n.productionText('worker.queue.completed.heading'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (orders.isEmpty)
            _EmptyOpenedOrders(
              message: context.l10n.productionText(
                'worker.queue.completed.empty',
              ),
            )
          else
            M3SegmentSpacedColumn(
              padding: EdgeInsets.zero,
              children: [
                for (var index = 0; index < orders.length; index++)
                  Builder(
                    builder: (context) {
                      final frozen = orders[index].isFrozen;
                      final partial = !frozen && orders[index].isInProgress;
                      return _SequenceOrderRow(
                        slot:
                            M3SegmentedListGeometry.standaloneListSlotForIndex(
                          index,
                          orders.length,
                        ),
                        order: orders[index].order,
                        index: index,
                        readOnly: true,
                        onTap: () => onTapOrder(orders[index]),
                        backgroundColor: frozen
                            ? const Color(0xFFBBDEFB)
                            : partial
                                ? const Color(0xFFFFECB3)
                                : const Color(0xFFC8E6C9),
                        titleColor: frozen
                            ? const Color(0xFF0D47A1)
                            : partial
                                ? const Color(0xFF6D4C00)
                                : const Color(0xFF18361B),
                        secondaryColor: frozen
                            ? const Color(0xFF1565C0)
                            : partial
                                ? const Color(0xFF8A6A00)
                                : const Color(0xFF3F6042),
                        statusLabel: frozen
                            ? context.l10n.productionText(
                                'worker.queue.status.frozen',
                              )
                            : partial
                                ? context.l10n.productionText(
                                    'worker.queue.status.completed_partial',
                                  )
                                : context.l10n.productionText(
                                    'worker.queue.status.completed',
                                  ),
                        statusBackgroundColor: frozen
                            ? const Color(0xFF64B5F6)
                            : partial
                                ? const Color(0xFFFFD54F)
                                : const Color(0xFFA5D6A7),
                        statusForegroundColor: frozen
                            ? const Color(0xFF0D47A1)
                            : partial
                                ? const Color(0xFF6D4C00)
                                : const Color(0xFF18361B),
                      );
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
