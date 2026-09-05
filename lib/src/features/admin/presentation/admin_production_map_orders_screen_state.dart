part of 'admin_production_map_orders_screen.dart';

class _AdminProductionMapOrdersScreenState
    extends State<AdminProductionMapOrdersScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late TabController _tabController;
  bool _loading = true;
  String? _loadError;
  bool _liveRefreshInFlight = false;
  bool _liveRefreshQueued = false;
  bool _mapsRefreshInFlight = false;
  bool _queueSnapshotRefreshInFlight = false;
  bool _queueSnapshotRefreshQueued = false;
  bool _queueSnapshotContractError = false;
  String? _queueSnapshotErrorMessage;
  bool _workerCompletedHistoryError = false;
  String? _workerCompletedHistoryErrorMessage;
  String? _closedOrdersErrorMessage;
  String? _completionRequestsErrorMessage;
  int _liveStreamGeneration = 0;
  int _queueSnapshotGeneration = 0;

  StreamSubscription<AdminProductionMapLiveSnapshot>? _liveStreamSubscription;

  Timer? _queueSnapshotPollTimer;
  int? _lastAppliedSnapshotRevision;
  int _liveReconnectAttempt = 0;
  String _searchQuery = '';

  _OpenedOrderModule _module = _OpenedOrderModule.orders;

  AdminApparatus? _selectedApparatus;
  bool _userChangedSequenceApparatus = false;

  AdminApparatus? _moveTopApparatus;

  AdminApparatus? _moveBottomApparatus;
  final Set<String> _selectedMoveOrderIds = {};
  List<ProductionMapSaved> _draggingMoveOrders = const [];

  AdminApparatus? _draggingMoveSource;
  List<ProductionMapSaved> _orders = const [];
  List<AdminApparatus> _apparatus = const [];
  final Map<String, List<String>> _sequenceByApparatus = {};
  final Map<String, List<String>> _visibleOrderIdsByApparatus = {};
  final Map<String, Map<String, String>> _queueStatesByApparatus = {};
  final Map<String, Map<String, String>> _stageStatesByOrderId = {};
  final Map<String, AdminApparatusQueuePolicy> _queuePoliciesByApparatus = {};
  final Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      _queueActionControlsByApparatus = {};
  final Map<String, List<AdminFrozenQueueOrder>> _frozenOrdersByApparatus = {};
  final Map<String, AdminOrderControlState> _orderControlsByOrderId = {};
  final Map<String, AdminProductionOrderStatusDetail> _orderStatusesByOrderId =
      {};
  List<AdminCompletedQueueOrder> _completedWorkerOrders = const [];
  List<AdminCompletionRequestNotification> _completionRequests = const [];
  final Set<String> _shownCompletionDecisionIds = {};
  List<AdminClosedProductionOrder> _closedOrders = const [];

  AdminProductionWorkflowAuditReport? _workflowAudit;
  String? _workflowAuditError;
  bool _workflowAuditLoading = false;
  final Set<String> _queueActionsInFlight = {};
  final Set<String> _orderControlActionsInFlight = {};
  Map<String, double> _baseMetrajByMapId = const {};
  Map<String, double> _orderKgByMapId = const {};
  Map<String, String> _customerByMapId = const {};

  @override
  void initState() {
    super.initState();
    if (widget.supplyViewerMode) {
      _module = _OpenedOrderModule.sequence;
    }
    if (widget.workerMode) {
      _tabController = TabController(length: 1, vsync: this);
    } else {
      _tabController = TabController(
        length: _modules.length,
        vsync: this,
        initialIndex: _modules.indexOf(_module).clamp(0, _modules.length - 1),
      );
      _tabController.addListener(_syncModuleFromTab);
    }
    if (widget.workerMode) {
      WidgetsBinding.instance.addObserver(this);
      unawaited(_startWorkerLive());
    } else {
      unawaited(_restoreSavedSequenceApparatusPreference());
      unawaited(_startAdminLive());
    }
  }

  @override
  void dispose() {
    if (widget.workerMode) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _stopWorkerLiveStream();
    _queueSnapshotPollTimer?.cancel();
    _queueSnapshotPollTimer = null;
    if (!widget.workerMode) {
      _tabController.removeListener(_syncModuleFromTab);
    }
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.workerMode && state == AppLifecycleState.resumed) {
      unawaited(_startWorkerLive());
    }
  }

  List<_OpenedOrderModule> get _modules {
    return widget.workerMode || widget.supplyViewerMode
        ? const [_OpenedOrderModule.sequence]
        : _OpenedOrderModule.values;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    final role = AppSession.instance.profile?.role;
    final isQolipchi = role == UserRole.qolipchi;
    final isMaterialTaminotchi = role == UserRole.materialTaminotchi;
    final canViewSupplyOrderInfo =
        role == UserRole.qolipchi || isMaterialTaminotchi;
    final supplyDrawer = switch (role) {
      UserRole.qolipchi => QolipNavigationDrawer(
          selectedIndex: 0,
          selectedRouteName: AppRoutes.supplySequence,
          onNavigate: _openDrawerRoute,
        ),
      UserRole.materialTaminotchi => MaterialTaminotchiNavigationDrawer(
          selectedRouteName: AppRoutes.supplySequence,
          onNavigate: _openDrawerRoute,
        ),
      _ => null,
    };
    final supplyDock = switch (role) {
      UserRole.qolipchi => const QolipDock(activeTab: null),
      UserRole.materialTaminotchi =>
        const MaterialTaminotchiDock(activeTab: null),
      _ => null,
    };
    return AppShell(
      drawer: widget.supplyViewerMode
          ? supplyDrawer
          : widget.workerMode
              ? AparatchiNavigationDrawer(
                  selectedIndex: 0,
                  selectedRouteName: AppRoutes.apparatusQueue,
                  onNavigate: _openDrawerRoute,
                )
              : AdminNavigationDrawer(
                  selectedIndex: 0,
                  selectedRouteName: AppRoutes.adminProductionMapOrders,
                  onNavigate: _openDrawerRoute,
                ),
      title: '',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: widget.supplyViewerMode
            ? context.l10n.productionText('worker.queue.search.sequence')
            : context.l10n.productionText('worker.queue.search.open'),
        onChanged: (value) => setState(() => _searchQuery = value),
        onClear: () {
          _searchController.clear();
          setState(() => _searchQuery = '');
        },
        onBack: widget.workerMode || widget.supplyViewerMode
            ? null
            : () {
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.pop();
                  return;
                }
                nav.pushNamedAndRemoveUntil(
                  AppRoutes.adminHome,
                  (route) => false,
                );
              },
        onBackWithContext: widget.workerMode || widget.supplyViewerMode
            ? (context) => AppShellDrawerScope.maybeOf(context)?.openDrawer()
            : null,
        leadingIcon: widget.workerMode || widget.supplyViewerMode
            ? Icons.menu_rounded
            : Icons.arrow_back_rounded,
        leadingTooltip: widget.workerMode || widget.supplyViewerMode
            ? MaterialLocalizations.of(context).openAppDrawerTooltip
            : null,
      ),
      bottom: widget.supplyViewerMode
          ? supplyDock
          : widget.workerMode
              ? AparatchiDock(
                  activeTab: AparatchiDockTab.home,
                  onQrScanRequested: _openWorkerQrScanner,
                )
              : AdminDock(
                  activeTab: AdminDockTab.home,
                  showPrimaryFab: _module != _OpenedOrderModule.sequence &&
                      _module != _OpenedOrderModule.move,
                ),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : _loadError != null
              ? _OpenedOrdersLoadErrorBody(
                  message: _loadError!,
                  bottomPadding: bottomPadding,
                  onRefresh: _load,
                )
              : Column(
                  children: [
                    if (_queueSnapshotContractError)
                      _QueueSnapshotWarningBanner(
                        message: _queueSnapshotErrorMessage ??
                            context.l10n.productionText('worker.error.sync'),
                        onRetry: _refreshQueueSnapshot,
                      ),
                    if (widget.workerMode && _workerCompletedHistoryError)
                      _QueueSnapshotWarningBanner(
                        message: _workerCompletedHistoryErrorMessage ??
                            context.l10n.productionText('worker.error.sync'),
                        onRetry: _refreshWorkerCompletedOrders,
                      ),
                    if (!widget.workerMode &&
                        _completionRequestsErrorMessage != null)
                      _QueueSnapshotWarningBanner(
                        message: _completionRequestsErrorMessage!,
                        onRetry: _refreshCompletionRequests,
                      ),
                    if (!widget.workerMode && _closedOrdersErrorMessage != null)
                      _QueueSnapshotWarningBanner(
                        message: _closedOrdersErrorMessage!,
                        onRetry: _refreshClosedOrders,
                      ),
                    Expanded(
                      child: widget.workerMode
                          ? _WorkerWatchBody(
                              apparatus: _apparatus,
                              assignedApparatus: AppSession
                                      .instance.profile?.assignedApparatus ??
                                  const <String>[],
                              orders: _orders,
                              completedOrders: _completedWorkerOrders,
                              sequenceByApparatus: _sequenceByApparatus,
                              visibleOrderIdsByApparatus:
                                  _visibleOrderIdsByApparatus,
                              queueStatesByApparatus: _queueStatesByApparatus,
                              orderStatusesByOrderId: _orderStatusesByOrderId,
                              orderControlsByOrderId: _orderControlsByOrderId,
                              searchQuery: _searchQuery,
                              bottomPadding: bottomPadding,
                              tabController: _tabController,
                              onTapCompletedOrder: _showCompletedOrderDetail,
                              onTapWatchOrder: _showWatchOrderInfo,
                              onLongPressWatchOrder: _showWatchOrderLongPress,
                            )
                          : _AdminModulesBody(
                              modules: _modules,
                              currentModule: _module,
                              tabController: _tabController,
                              bottomPadding: bottomPadding,
                              orders: _orders,
                              searchQuery: _searchQuery,
                              apparatus: _apparatus,
                              selectedApparatus: _selectedApparatus,
                              completionRequests: _completionRequests,
                              readOnly:
                                  widget.readOnly || widget.supplyViewerMode,
                              moveTopApparatus: _moveTopApparatus,
                              moveBottomApparatus: _moveBottomApparatus,
                              selectedMoveOrderIds: _selectedMoveOrderIds,
                              draggingMoveOrders: _draggingMoveOrders,
                              draggingMoveSource: _draggingMoveSource,
                              closedOrders: _closedOrders,
                              onSetModule: _setModule,
                              ordersForApparatus: _ordersForApparatus,
                              moveOrdersForApparatus: _moveOrdersForApparatus,
                              canMoveTo: _canMoveOrderToApparatus,
                              onSelectSequenceApparatus: (apparatus) {
                                _userChangedSequenceApparatus = true;
                                unawaited(
                                  AdminSequenceApparatusStore.instance
                                      .saveApparatus(apparatus),
                                );
                                setState(() => _selectedApparatus = apparatus);
                              },
                              onReorder: (oldIndex, newIndex) {
                                unawaited(
                                  _reorderSelectedApparatusOrders(
                                      oldIndex, newIndex),
                                );
                              },
                              onPickMoveTop: () =>
                                  _pickMoveApparatus(top: true),
                              onPickMoveBottom: () =>
                                  _pickMoveApparatus(top: false),
                              onToggleMoveSelection: _toggleMoveOrderSelection,
                              buildMoveDragPayload: _buildMoveDragPayload,
                              onMoveDragStarted: (payload) {
                                setState(() {
                                  _draggingMoveOrders = payload.orders;
                                  _draggingMoveSource = payload.source;
                                });
                              },
                              onMoveDragEnded: () {
                                setState(() {
                                  _draggingMoveOrders = const [];
                                  _draggingMoveSource = null;
                                });
                              },
                              onMove: _moveOrdersBetweenApparatus,
                              onInfoOrder: _showOrderDetail,
                              onInfoSequenceOrder: widget.supplyViewerMode &&
                                      !canViewSupplyOrderInfo
                                  ? null
                                  : _showWatchOrderDetail,
                              customerNameByMapId: _customerByMapId,
                              queueStatesByApparatus: _queueStatesByApparatus,
                              visibleOrderIdsByApparatus:
                                  _visibleOrderIdsByApparatus,
                              orderStatusesByOrderId: _orderStatusesByOrderId,
                              sequenceInteractionHint: isQolipchi
                                  ? 'Bir marta bosing — ma’lumot. Uzoq bosing — order qoliplarini ochish.'
                                  : null,
                              orderControlsByOrderId: _orderControlsByOrderId,
                              workflowAudit: _workflowAudit,
                              workflowAuditError: _workflowAuditError,
                              workflowAuditLoading: _workflowAuditLoading,
                              onRefreshWorkflowAudit: () =>
                                  _refreshWorkflowAudit(force: true),
                              onLongPressOrder: (order) {
                                unawaited(
                                  widget.supplyViewerMode && isQolipchi
                                      ? _showQolipsForOrder(order)
                                      : widget.supplyViewerMode &&
                                              isMaterialTaminotchi
                                          ? _showSupplyRawMaterialAssignment(
                                              order)
                                          : _showOrderActions(order),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  void _updateScreenState(VoidCallback callback) {
    setState(callback);
  }

  void _recreateWorkerTabController(List<AdminApparatus> apparatus) {
    final length = _workerWatchTabCount(apparatus);
    if (_tabController.length == length) {
      return;
    }
    _tabController.dispose();
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: 0,
    );
  }

  Future<AdminApparatusQueueActionResult?> _handleQueueAction(
    _ReadOnlyQueueActionRequest request,
  ) async {
    final apparatusKey = request.apparatus.id.trim();
    final actionKey = '$apparatusKey|${request.order.map.id.trim()}';
    if (!_queueActionsInFlight.add(actionKey)) {
      return null;
    }
    if (mounted) {
      setState(() {});
    }
    try {
      final result = await _submitAdminApparatusQueueAction(
        request,
        apparatusKey: apparatusKey,
      );
      if (!mounted) {
        return null;
      }
      _applyQueueActionResult(
        apparatusKey: apparatusKey,
        orderId: request.order.map.id.trim(),
        completionRequestNote: request.completionRequestNote,
        result: result,
      );
      return result;
    } finally {
      _queueActionsInFlight.remove(actionKey);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _applyQueueActionResult({
    required String apparatusKey,
    required String orderId,
    required String completionRequestNote,
    required AdminApparatusQueueActionResult result,
  }) {
    setState(() {
      _queueSnapshotGeneration++;
      _queueActionControlsByApparatus.clear();
      _queueStatesByApparatus[apparatusKey] = result.states;
      _orderStatusesByOrderId[orderId] = result.orderStatus;
      if (result.orderControl != null) {
        _orderControlsByOrderId[orderId] = result.orderControl!;
      }
    });
    if (_queueActionSentCompletionRequest(
      completionRequestNote: completionRequestNote,
      result: result,
    )) {
      showAdminTopNotice(
        context,
        context.l10n.productionText(
          'worker.notice.completion_request_sent',
        ),
      );
    }
    unawaited(_refreshLive());
  }

  void _openDrawerRoute(String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) {
      return;
    }
    if (widget.supplyViewerMode) {
      Navigator.of(context).pushReplacementNamed(routeName);
      return;
    }
    AdminDrawerNavigation.openRoute(context, routeName);
  }

  void _showOrderDetail(ProductionMapSaved order) {
    final mapId = order.map.id.trim();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      shape: _orderDetailSheetShape,
      clipBehavior: Clip.antiAlias,
      sheetAnimationStyle: AppMotion.sheetEaseOut,
      builder: (context) => _ReadOnlyOrderDetailSheet(
        order: order,
        apparatusCatalog: _apparatus,
        baseMetraj: _baseMetrajByMapId[mapId] ?? order.map.baseLength,
        orderKg: _orderKgByMapId[mapId] ?? order.map.orderKg,
        customerName: _customerByMapId[mapId] ?? order.map.customerName,
        queueStatesByApparatus: _queueStatesByApparatus,
        stageStatesByOrderId: _stageStatesByOrderId,
        allowWipQrReprint: !widget.supplyViewerMode,
        progressDriverUrlPicker: widget.progressDriverUrlPicker,
        initialOrderControls: _orderControlsByOrderId,
      ),
    );
  }

  void _showWatchOrderDetail({
    required AdminApparatus apparatus,
    required ProductionMapSaved order,
    bool startWorkerHandoffOnOpen = false,
    bool startAstatkaOnOpen = false,
    bool startRollRemovalOnOpen = false,
    bool startResumeOnOpen = false,
    AdminProgressBatch? initialOrderSwitchBatch,
  }) {
    final mapId = order.map.id.trim();
    final sheetFuture = showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      shape: _orderDetailSheetShape,
      clipBehavior: Clip.antiAlias,
      sheetAnimationStyle: AppMotion.sheetEaseOut,
      builder: (context) => _ReadOnlyOrderDetailSheet(
        order: order,
        apparatus: apparatus,
        apparatusCatalog: _apparatus,
        workerMode: widget.workerMode,
        customerName: _customerByMapId[mapId] ?? order.map.customerName,
        canManageQueue: widget.workerMode &&
            _isAssignedWatchApparatus(
              apparatus,
              assignedApparatus:
                  AppSession.instance.profile?.assignedApparatus ??
                      const <String>[],
            ),
        initialQueueStates: _queueStatesForApparatus(
          apparatus,
          queueStatesByApparatus: _queueStatesByApparatus,
        ),
        queueStatesByApparatus: _queueStatesByApparatus,
        stageStatesByOrderId: _stageStatesByOrderId,
        queueActionControl: _queueActionControlForApparatus(
          apparatus: apparatus,
          orderId: mapId,
        ),
        queuePolicy: _queuePolicyForApparatus(
          apparatus,
          queuePoliciesByApparatus: _queuePoliciesByApparatus,
        ),
        sequenceOrderIds: _sequenceOrderIdsForApparatus(
          apparatus,
          sequenceByApparatus: _sequenceByApparatus,
        ),
        visibleOrderIds: _ordersForApparatus(
          apparatus,
        ).map((item) => item.map.id).toList(growable: false),
        onQueueAction: _handleQueueAction,
        progressDriverUrlPicker: widget.progressDriverUrlPicker,
        initialOrderControls: _orderControlsByOrderId,
        initialOrderSwitchBatch: initialOrderSwitchBatch,
        startWorkerHandoffOnOpen: startWorkerHandoffOnOpen,
        startAstatkaOnOpen: startAstatkaOnOpen,
        startRollRemovalOnOpen: startRollRemovalOnOpen,
        startResumeOnOpen: startResumeOnOpen,
      ),
    );
    unawaited(
      sheetFuture.then((result) {
        if (mounted && result == true) {
          unawaited(_refreshLive());
        }
      }),
    );
  }

  AdminApparatusQueueOrderActionControl? _queueActionControlForApparatus({
    required AdminApparatus apparatus,
    required String orderId,
  }) {
    return _queueActionControlsByApparatus[apparatus.id.trim()]
        ?[orderId.trim()];
  }

  void _showWatchOrderInfo({
    required AdminApparatus apparatus,
    required ProductionMapSaved order,
  }) {
    _showWatchOrderDetail(
      apparatus: apparatus,
      order: order,
    );
  }

  Future<void> _openWorkerQrScanner() async {
    final result = await Navigator.of(context).pushNamed(
      AppRoutes.adminProgressQrScan,
      arguments: const AdminProgressQrScanArgs(scanOnly: true),
    );
    if (!mounted || result is! String || result.trim().isEmpty) {
      return;
    }
    await _handleWorkerFabQr(result.trim());
  }

  Future<void> _handleWorkerFabQr(String qrPayload) async {
    try {
      final batch = await MobileApi.instance.adminProgressQrLookup(qrPayload);
      if (!mounted) return;
      final targetOrderId = batch.orderId.trim();
      final stationId = batch.nextApparatus.trim();
      if (targetOrderId.isEmpty || stationId.isEmpty) {
        showAdminTopNotice(
          context,
          context.l10n.productionText('worker.error.qr_other_order'),
        );
        return;
      }
      AdminApparatus? station;
      for (final candidate in _apparatus) {
        if (candidate.id.trim() == stationId) {
          station = candidate;
          break;
        }
      }
      if (station == null ||
          !_isAssignedWatchApparatus(
            station,
            assignedApparatus: AppSession.instance.profile?.assignedApparatus ??
                const <String>[],
          )) {
        showAdminTopNotice(
          context,
          context.l10n.productionText('worker.error.assigned_machine'),
        );
        return;
      }
      await _refreshLive();
      if (!mounted) return;
      final targetControl = _queueActionControlForApparatus(
        apparatus: station,
        orderId: targetOrderId,
      );
      final targetOrderControl = adminProductionMapOrderControlFor(
        _orderControlsByOrderId,
        targetOrderId,
      );
      final targetQueueState = _queueStatesForApparatus(
        station,
        queueStatesByApparatus: _queueStatesByApparatus,
      )[targetOrderId];
      if (targetControl?.isConsistentWith(
                targetOrderControl,
                queueState: targetQueueState,
              ) !=
              true ||
          targetControl?.allows('start') != true) {
        showAdminTopNotice(
          context,
          context.l10n.productionText('worker.error.sync'),
        );
        return;
      }
      final hasInProgressOrder = _orders.any(
        (order) {
          final control = _queueActionControlForApparatus(
            apparatus: station!,
            orderId: order.map.id,
          );
          return control?.interaction?.mode ==
                  AdminQueueInteractionMode.inProgress ||
              control?.interaction?.mode ==
                  AdminQueueInteractionMode.freezeRequested;
        },
      );
      if (!hasInProgressOrder) {
        await _refreshWorkerCompletedOrders();
        if (!mounted) return;
      }
      final currentOrder = _workerCurrentOrderForApparatus(
        apparatus: station,
      );
      if (currentOrder == null) {
        showAdminTopNotice(
          context,
          context.l10n.productionText('worker.error.current_order_missing'),
        );
        return;
      }
      if (currentOrder.map.id.trim() == targetOrderId) {
        showAdminTopNotice(
          context,
          context.l10n.productionText('worker.error.current_order_qr'),
        );
        return;
      }
      _showWatchOrderDetail(
        apparatus: station,
        order: currentOrder,
        initialOrderSwitchBatch: batch,
      );
    } catch (error) {
      if (!mounted) return;
      showAdminTopNotice(
        context,
        error is MobileApiException
            ? context.l10n.productionErrorMessage(
                error.code,
                fallback: error.message,
              )
            : context.l10n.productionText('worker.error.other_order_lookup'),
      );
    }
  }

  ProductionMapSaved? _workerCurrentOrderForApparatus({
    required AdminApparatus apparatus,
  }) {
    AdminQueueInteractionMode? modeFor(ProductionMapSaved order) {
      final orderId = order.map.id.trim();
      final control = _queueActionControlForApparatus(
        apparatus: apparatus,
        orderId: orderId,
      );
      final orderControl = adminProductionMapOrderControlFor(
        _orderControlsByOrderId,
        orderId,
      );
      final queueState = _queueStatesForApparatus(
        apparatus,
        queueStatesByApparatus: _queueStatesByApparatus,
      )[orderId];
      return control?.isConsistentWith(
                orderControl,
                queueState: queueState,
              ) ==
              true
          ? control?.interaction?.mode
          : null;
    }

    ProductionMapSaved? firstOrderInMode(
      Set<AdminQueueInteractionMode> expected,
    ) {
      for (final order in _orders) {
        if (expected.contains(modeFor(order))) {
          return order;
        }
      }
      return null;
    }

    final activeOrder = firstOrderInMode({
      AdminQueueInteractionMode.inProgress,
      AdminQueueInteractionMode.freezeRequested,
    });
    if (activeOrder != null) {
      return activeOrder;
    }

    final ordersById = <String, ProductionMapSaved>{
      for (final order in _orders) order.map.id.trim(): order,
    };
    final history = _completedWorkerOrders
        .where(
          (entry) => entry.apparatus.trim() == apparatus.id.trim(),
        )
        .toList()
      ..sort(
        (left, right) => right.completedAtUnix.compareTo(left.completedAtUnix),
      );
    for (final entry in history) {
      final order = ordersById[entry.orderId.trim()];
      if (order == null) {
        continue;
      }
      final mode = modeFor(order);
      if (mode == AdminQueueInteractionMode.paused ||
          mode == AdminQueueInteractionMode.completed) {
        return order;
      }
    }
    return null;
  }

  Future<AdminProgressBatch?> _laminatsiyaWorkerHandoffBatch({
    required AdminApparatus apparatus,
    required ProductionMapSaved order,
  }) async {
    final station = apparatus.id.trim();
    try {
      final batches = await MobileApi.instance.adminWipBatches(
        status: 'all',
        apparatus: station,
        orderId: order.map.id.trim(),
        limit: 250,
      );
      for (final batch in batches) {
        final usedBy = batch.usedByApparatus.trim().isEmpty
            ? batch.currentApparatus
            : batch.usedByApparatus;
        if (batch.orderId.trim() == order.map.id.trim() &&
            batch.wipStatus.trim().toLowerCase() == 'in_use' &&
            usedBy.trim() == station &&
            batch.payloadJson['worker_handoff'] == true) {
          return batch;
        }
      }
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? context.l10n.productionErrorMessage(
                  error.code,
                  fallback: error.message,
                )
              : context.l10n.productionText('worker.error.machine_roll'),
        );
      }
    }
    return null;
  }

  Future<void> _showWatchOrderLongPress({
    required AdminApparatus apparatus,
    required ProductionMapSaved order,
  }) async {
    final operation = apparatus.operation.trim().toLowerCase();
    final isLaminatsiya = operation == 'laminate';
    final supportsAstatka = operation == 'laminate' || operation == 'cut';
    if (!widget.workerMode ||
        !_isAssignedWatchApparatus(
          apparatus,
          assignedApparatus: AppSession.instance.profile?.assignedApparatus ??
              const <String>[],
        ) ||
        !supportsAstatka) {
      return;
    }
    if (_orderControlsByOrderId[order.map.id.trim()] ==
        AdminOrderControlState.frozen) {
      return;
    }
    final queueStates = _queueStatesForApparatus(
      apparatus,
      queueStatesByApparatus: _queueStatesByApparatus,
    );
    final state = apparatusQueueOrderStateFromRaw(
      queueStates[order.map.id.trim()],
    );
    if (isLaminatsiya && state == ApparatusQueueOrderState.paused) {
      final handoffBatch = await _laminatsiyaWorkerHandoffBatch(
        apparatus: apparatus,
        order: order,
      );
      if (!mounted) return;
      if (handoffBatch != null) {
        final choice =
            await showModalBottomSheet<_LaminatsiyaWorkerLongPressChoice>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => const _LaminatsiyaWorkerHandoffSheet(),
        );
        if (!mounted) return;
        switch (choice) {
          case _LaminatsiyaWorkerLongPressChoice.continueRoll:
            _showWatchOrderDetail(
              apparatus: apparatus,
              order: order,
              startResumeOnOpen: true,
            );
          case _LaminatsiyaWorkerLongPressChoice.removeRoll:
            _showWatchOrderDetail(
              apparatus: apparatus,
              order: order,
              startRollRemovalOnOpen: true,
            );
          case _LaminatsiyaWorkerLongPressChoice.finishWork:
          case null:
            break;
        }
        return;
      }
    }
    if (state == ApparatusQueueOrderState.inProgress ||
        state == ApparatusQueueOrderState.paused ||
        state == ApparatusQueueOrderState.completed) {
      final choice =
          await showModalBottomSheet<_LaminatsiyaWorkerLongPressChoice>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => const _LaminatsiyaWorkerFinishSheet(),
      );
      if (!mounted || choice != _LaminatsiyaWorkerLongPressChoice.finishWork) {
        return;
      }
      _showWatchOrderDetail(
        apparatus: apparatus,
        order: order,
        startAstatkaOnOpen: true,
      );
      return;
    }
  }

  Future<void> _showSupplyRawMaterialAssignment(
    ProductionMapSaved order,
  ) async {
    final profile = AppSession.instance.profile;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SequenceRawMaterialAssignmentSheet(
        order: order,
        initialApparatus: _selectedApparatus?.id ?? '',
        assignedApparatus: profile?.assignedApparatus ?? const <String>[],
        apparatusCatalog: _apparatus,
      ),
    );
  }

  Future<void> _showQolipsForOrder(ProductionMapSaved order) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _SequenceQolipSheet(order: order),
    );
  }

  Future<void> _openOrderProductionMapEditor(
    ProductionMapSaved selectedOrder,
  ) async {
    final orderId = selectedOrder.map.id.trim();
    try {
      final result = await Future.wait<Object>([
        MobileApi.instance.adminProductionMap(orderId),
        MobileApi.instance.adminProductionMapQueueSnapshot(),
      ]);
      if (!mounted) {
        return;
      }
      final order = result[0] as ProductionMapSaved;
      final snapshot = result[1] as AdminApparatusQueueSnapshot;
      final map = order.map;
      final lockedNodeIds = productionMapLockedNodeIds(
        map: map,
        queueStatesByApparatus: snapshot.queueStates,
      );
      await Navigator.of(context).pushNamed(
        AppRoutes.adminProductionMapTest,
        arguments: ProductionMapTestArgs(
          orderContext: ProductionMapOrderContext(
            orderCode: map.code,
            orderName: map.title,
            productName: map.title,
            itemCode: map.productCode,
            rollCount: map.rollCount,
            widthMm: map.widthMm,
          ),
          savedMap: map,
          lockedNodeIds: lockedNodeIds,
        ),
      );
      if (mounted) {
        await _refreshLive();
      }
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : context.l10n.adminText('production.open_failed'),
        );
      }
    }
  }

  Future<void> _showOrderActions(ProductionMapSaved order) async {
    final orderId = order.map.id.trim();
    if (widget.readOnly ||
        widget.workerMode ||
        widget.supplyViewerMode ||
        _orderControlActionsInFlight.contains(orderId)) {
      return;
    }
    if (_queueSnapshotContractError) {
      showAdminTopNotice(
        context,
        context.l10n.productionText('worker.error.sync'),
      );
      return;
    }
    final control = adminProductionMapOrderControlFor(
      _orderControlsByOrderId,
      orderId,
    );
    final hasFrozenQueueState = _queueStatesByApparatus.values.any(
      (states) => states[orderId]?.trim().toLowerCase() == 'frozen',
    );
    final action = await showModalBottomSheet<_OrderLongPressAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (control == AdminOrderControlState.active && hasFrozenQueueState)
              const ListTile(
                enabled: false,
                leading: Icon(Icons.sync_problem_rounded),
                title: Text('Navbat holati sinxron emas'),
                subtitle: Text('Server holati yangilanishi kutilmoqda'),
              ),
            if (control == AdminOrderControlState.active) ...[
              if (!hasFrozenQueueState)
                ListTile(
                  leading: const Icon(Icons.ac_unit_rounded),
                  title: Text(context.l10n.adminText('production.freeze')),
                  onTap: () => Navigator.pop(
                    context,
                    _OrderLongPressAction.freeze,
                  ),
                ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'O‘chirish',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () => Navigator.pop(
                  context,
                  _OrderLongPressAction.delete,
                ),
              ),
            ],
            if (control == AdminOrderControlState.freezeRequested)
              ListTile(
                leading: const Icon(Icons.cancel_outlined),
                title: Text(
                  context.l10n.adminText('production.cancel_freeze'),
                ),
                onTap: () => Navigator.pop(
                  context,
                  _OrderLongPressAction.cancelFreeze,
                ),
              ),
            if (control == AdminOrderControlState.frozen)
              ListTile(
                leading: const Icon(Icons.play_circle_outline_rounded),
                title: Text(context.l10n.adminText('production.unfreeze')),
                onTap: () => Navigator.pop(
                  context,
                  _OrderLongPressAction.unfreeze,
                ),
              ),
            ListTile(
              leading: const Icon(Icons.account_tree_outlined),
              title: Text(context.l10n.adminText('production.edit_map')),
              onTap: () => Navigator.pop(
                context,
                _OrderLongPressAction.editMap,
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _OrderLongPressAction.editMap) {
      await _openOrderProductionMapEditor(order);
      return;
    }
    final controlAction = switch (action) {
      _OrderLongPressAction.freeze => AdminOrderControlAction.freeze,
      _OrderLongPressAction.cancelFreeze =>
        AdminOrderControlAction.cancelFreeze,
      _OrderLongPressAction.unfreeze => AdminOrderControlAction.unfreeze,
      _OrderLongPressAction.delete => AdminOrderControlAction.delete,
      _OrderLongPressAction.editMap => null,
    };
    if (controlAction == null) {
      return;
    }
    if (controlAction == AdminOrderControlAction.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.adminText('production.delete_order')),
          content: Text(context.l10n.adminText('production.delete_message')),
          actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      context.l10n.adminText('production.delete_confirm'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.l10n.adminText('action.cancel')),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    await _runOrderControlAction(order, controlAction);
  }

  Future<void> _runOrderControlAction(
    ProductionMapSaved order,
    AdminOrderControlAction action,
  ) async {
    final orderId = order.map.id.trim();
    if (_queueSnapshotContractError) {
      showAdminTopNotice(
        context,
        context.l10n.productionText('worker.error.sync'),
      );
      return;
    }
    if (!_orderControlActionsInFlight.add(orderId)) {
      return;
    }
    setState(() {});
    try {
      final next = await MobileApi.instance.adminProductionMapOrderControl(
        orderId: orderId,
        action: action,
      );
      if (!mounted) return;
      setState(() {
        if (action == AdminOrderControlAction.delete) {
          _orders = [
            for (final item in _orders)
              if (item.map.id.trim() != orderId) item,
          ];
          _orderControlsByOrderId.remove(orderId);
          for (final sequence in _sequenceByApparatus.values) {
            sequence.removeWhere((id) => id.trim() == orderId);
          }
        } else if (next != null) {
          _orderControlsByOrderId[orderId] = next;
        }
      });
      showAdminTopNotice(
        context,
        switch (action) {
          AdminOrderControlAction.freeze =>
            next == AdminOrderControlState.frozen
                ? 'Buyurtma muzlatildi'
                : 'Worker pauzasi kutilmoqda',
          AdminOrderControlAction.cancelFreeze =>
            'Muzlatish so‘rovi bekor qilindi',
          AdminOrderControlAction.unfreeze => 'Buyurtma aktiv holatga qaytdi',
          AdminOrderControlAction.delete => 'Buyurtma o‘chirildi',
        },
      );
      unawaited(_refreshLive());
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : 'Buyurtma amali bajarilmadi',
        );
      }
    } finally {
      _orderControlActionsInFlight.remove(orderId);
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _showCompletedOrderDetail(_WorkerCompletedOrderEntry entry) {
    if (entry.hasFreezeIssue) {
      _showWorkerFrozenOrderDetails(entry);
      return;
    }
    if (entry.isInProgress) {
      _showWorkerWipHistory(entry);
      return;
    }
    final apparatus = entry.apparatus;
    if (apparatus == null) {
      _showOrderDetail(entry.order);
      return;
    }
    _showWatchOrderDetail(apparatus: apparatus, order: entry.order);
  }

  void _showWorkerFrozenOrderDetails(_WorkerCompletedOrderEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _WorkerFrozenOrderDetailsSheet(entry: entry),
    );
  }

  void _showWorkerWipHistory(_WorkerCompletedOrderEntry entry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _WorkerWipHistorySheet(
        order: entry.order,
        apparatus: entry.apparatus,
        apparatusCatalog: _apparatus,
        allowWipQrReprint: false,
      ),
    );
  }

  void _setModule(_OpenedOrderModule module) {
    if (_module != module) {
      setState(() => _module = module);
    }
    final index = _modules.indexOf(module);
    if (index < 0) {
      return;
    }
    if (_tabController.index != index) {
      _tabController.animateTo(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    if (module == _OpenedOrderModule.audit) {
      unawaited(_refreshWorkflowAudit());
    }
  }

  void _syncModuleFromTab() {
    final module = _modules[_tabController.index];
    if (_module != module) {
      setState(() => _module = module);
    }
    if (module == _OpenedOrderModule.audit) {
      unawaited(_refreshWorkflowAudit());
    }
  }

  List<ProductionMapSaved> _ordersForApparatus(AdminApparatus apparatus) {
    return _productionMapOrdersForApparatus(
      orders: _orders,
      apparatus: apparatus,
      visibleOrderIdsByApparatus: _visibleOrderIdsByApparatus,
      sequenceByApparatus: _sequenceByApparatus,
      queueStatesByApparatus: _queueStatesByApparatus,
      workerMode: widget.workerMode,
      query: _searchQuery,
    );
  }
}
