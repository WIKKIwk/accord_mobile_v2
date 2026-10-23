part of 'admin_production_map_orders_screen.dart';

class _AdminProductionMapOrdersScreenState
    extends State<AdminProductionMapOrdersScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late TabController _tabController;
  int _workerTabIndex = 0;
  bool _loading = true;
  bool _adminPaging = false;
  bool _adminForeground = true;
  String _adminLiveEpoch = '';
  int _adminLiveRevision = -1;
  int _adminPageInvalidation = 0;
  int _adminWindowSerial = 0;
  bool _adminLiveStarted = false;
  bool _adminWindowLiveFallback = false;
  String _adminSubscriptionFingerprint = '';
  Future<void> _adminWindowEvents = Future.value();
  Timer? _adminSubscriptionTimer;
  int _adminNotificationGeneration = 0;
  StreamSubscription<List<AdminCompletionRequestNotification>>? _adminNotificationSubscription;
  Completer<void>? _adminNotificationFinished;
  Timer? _adminNotificationRetry;
  final Map<String, _AdminOrderWindow> _adminWindows = {};
  final Map<String, Future<AdminApparatusQueueSnapshot>> _adminDetailReads = {};
  bool _adminDetailOpening = false;
  AdminApparatusQueueSnapshot? _workerPreparedDetail;
  String? _workerPreparedDetailScope;
  final Map<String, Future<({double? base, double? kg})>>
      _adminOrderDetailMetrics = {};
  final Set<String> _adminPendingDetailReads = {};
  AdminOrderPageCacheVisit? _adminCacheVisit;
  String? _adminCacheScope;
  bool _adminCacheRestored = false;
  AdminSequenceWarmLease? _adminWarmLease;
  String? _adminWarmScope;
  bool _adminWarmAdopted = false;
  final Map<String, int> _adminMetricSignatures = {};
  final Map<String, AdminSequenceMoveResult> _adminSequenceAcks = {};
  final Map<String, _AdminOrderWindow> _adminSequenceAckWindows = {};
  final Map<String, Timer> _adminSequenceSyncTimers = {};
  final Map<String, Future<void>> _adminSequenceRecoveries = {};
  String _adminSequenceSyncAccount = '';
  String _adminPageSearch = '';
  Timer? _adminSearchDebounce;
  String? _loadError;
  final Set<_OrdersReadSection> _reconnectingOrderReads = {};
  Future<void>? _initialRefresh;
  bool _workerCatalogReady = false;
  Object? _workerWarmLease;
  bool _workerForeground = true;
  bool _workerRetryAllowed = true;
  bool _workerQrScanInFlight = false;
  bool _workerQrGuidanceOpen = false;
  Timer? _workerRecoveryTimer;
  bool _workerLiveHealthy = false;
  bool _liveRecoverySupported = false;
  String? _snapshotReadScope;
  bool _liveRefreshInFlight = false;
  bool _liveRefreshQueued = false;
  bool _mapsRefreshInFlight = false;
  bool _queueSnapshotRefreshInFlight = false;
  bool _queueSnapshotRefreshQueued = false;
  bool _queueSnapshotNeedsReconcile = false;
  bool _queueSnapshotContractError = false;
  String? _queueSnapshotErrorMessage;
  bool _workerCompletedHistoryError = false;
  String? _workerCompletedHistoryErrorMessage;
  String? _closedOrdersErrorMessage;
  Future<void>? _closedOrdersRefresh;
  bool _closedOrdersRefreshQueued = false;
  String? _completionRequestsErrorMessage;
  int _liveStreamGeneration = 0;
  int _queueSnapshotGeneration = 0;
  int _workerCompletedOrdersGeneration = 0;
  int _completionRequestsGeneration = 0;

  StreamSubscription<dynamic>? _liveStreamSubscription;
  Completer<void>? _liveStreamFinished;
  Completer<void>? _liveReconnectFinished;
  Timer? _liveReconnectTimer;

  int? _lastAppliedSnapshotRevision;
  String _lastAppliedSnapshotEpoch = '';
  AdminApparatusQueueSnapshot? _canonicalQueueSnapshot;
  String? _canonicalCacheOwner;
  bool _canonicalCacheAwaitingValidation = false;
  bool _canonicalCacheDemoMode = false;
  int _canonicalCacheRestoreGeneration = 0;
  bool _canonicalCacheHasLiveExtras = false;
  Timer? _canonicalCacheSaveTimer;
  Object? _canonicalCacheLastSavedIdentity;
  bool _canonicalCacheWriteInFlight = false;
  bool _canonicalCacheWriteQueued = false;
  List<AdminCompletionRequestDecisionNotification> _canonicalCompletionDecisions = const [];
  final _sheetQueueSnapshot =
      ValueNotifier<AdminApparatusQueueSnapshot?>(null);
  Timer? _queueActionReconcileTimer;
  int? _pendingQueueActionRevision;
  String _pendingQueueActionEpoch = '';
  final Set<String> _retiredSnapshotEpochs = {};
  final Map<String, int> _sequenceRevisions = {};
  final Set<String> _sequenceReplayInFlight = {};
  int _liveReconnectAttempt = 0;
  String _searchQuery = '';
  int _workerQueueLimit = WorkerQueueLimitStore.defaultLimit;
  int _workerQueueWindowGeneration = 0;
  String _workerServerSearch = '';
  Timer? _workerQueueSearchDebounce;

  /// Tayyorlov masteri supply-viewer filtri: backend snapshot'dagi order id'lar.
  /// null = hali yuklanmagan (fail-closed: bo'sh ko'rsatiladi).
  /// Faqat supplyViewerMode + tayyorlovMasteri'da ishlatiladi, boshqa rollarga tegmaydi.
  Set<String>? _tayyorlovAllowedOrderIds;
  List<PreparationResponsibility> _tayyorlovResponsibilities = const [];
  Object? _tayyorlovFilterError;

  _OpenedOrderModule _module = _OpenedOrderModule.sequence;

  AdminApparatus? _selectedApparatus;
  bool _userChangedSequenceApparatus = false;

  AdminApparatus? _moveTopApparatus;

  AdminApparatus? _moveBottomApparatus;
  final Set<String> _selectedMoveOrderIds = {};
  List<ProductionMapSaved> _draggingMoveOrders = const [];

  AdminApparatus? _draggingMoveSource;
  List<ProductionMapSaved> _orders = const [];
  List<PendingOrder> _pendingOrders = const [];
  bool _pendingOrdersLoading = false;
  int _pendingOrdersGeneration = 0;
  String? _pendingOrdersError;

  Future<void> _refreshPendingOrders({bool force = false}) async {
    if (_adminPaging) {
      await _loadAdminWindow(_adminWindow('orders'), force: force);
      return;
    }
    if ((_pendingOrdersLoading && !force) ||
        widget.workerMode ||
        widget.supplyViewerMode ||
        widget.readOnly) {
      return;
    }
    _pendingOrdersLoading = true;
    final generation = ++_pendingOrdersGeneration;
    try {
      final orders = await MobileApi.instance.pendingOrders();
      if (mounted && generation == _pendingOrdersGeneration) {
        setState(() {
          _pendingOrders = orders;
          _pendingOrdersError = null;
          _reconnectingOrderReads.remove(_OrdersReadSection.pending);
        });
      }
    } catch (error) {
      if (mounted && generation == _pendingOrdersGeneration) {
        setState(() {
          _pendingOrdersError = 'Chala buyurtmalar yuklanmadi';
          _markOrdersReadConnectionError(_OrdersReadSection.pending, error);
        });
      }
    } finally {
      if (generation == _pendingOrdersGeneration) _pendingOrdersLoading = false;
    }
  }

  Future<void> _showPendingOrder(PendingOrder order) async {
    final completed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        shape: _orderDetailSheetShape,
        clipBehavior: Clip.antiAlias,
        builder: (_) => PendingOrderDetailSheet(order: order));
    if (!mounted) return;
    if (completed == true) {
      setState(() => _pendingOrders =
          _pendingOrders.where((p) => p.id != order.id).toList());
    }
    await _refreshPendingOrders(force: completed == true);
    if (completed == true && mounted) await _refreshLive();
  }

  List<AdminApparatus> _apparatus = const [];
  final Map<String, List<String>> _sequenceByApparatus = {};
  final Map<String, String> _sequenceVersions = {};
  final Map<String, List<_PendingSequenceMove>> _pendingSequenceMoves = {};
  final Set<String> _sequenceWritesInFlight = {};
  final Set<String> _sequenceNeedsSnapshot = {};
  final Map<String, Timer> _sequenceRetryTimers = {};
  final Map<String, List<String>> _visibleOrderIdsByApparatus = {};
  final Map<String, Map<String, String>> _queueStatesByApparatus = {};
  // Kept separately from action permissions, which are invalidated on a
  // mutation. Other cards retain their activity until the atomic snapshot.
  final Map<String, Map<String, AdminQueueWorkActivity>>
      _workActivityByApparatus = {};
  final Map<String, Map<String, String>> _stageStatesByOrderId = {};
  final Map<String, AdminApparatusQueuePolicy> _queuePoliciesByApparatus = {};
  final Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
      _queueActionControlsByApparatus = {};
  final Map<String, List<AdminFrozenQueueOrder>> _frozenOrdersByApparatus = {};
  final Map<String, AdminOrderControlState> _orderControlsByOrderId = {};
  final List<AdminStageOrderControl> _stageOrderControls = [];
  final Set<String> _earlyClosingOrderIds = {};
  final Map<String, AdminProductionOrderStatusDetail> _orderStatusesByOrderId =
      {};
  List<AdminCompletedQueueOrder> _completedWorkerOrders = const [];
  List<AdminCompletionRequestNotification> _completionRequests = const [];
  final Set<String> _shownCompletionDecisionIds = {};
  final Set<String> _shownStageAstatkaSessions = {};
  bool _stageAstatkaPromptOpen = false;
  List<AdminClosedProductionOrder> _closedOrders = const [];

  AdminProductionWorkflowAuditReport? _workflowAudit;
  String? _workflowAuditError;
  bool _workflowAuditLoading = false;
  final Set<String> _queueActionsInFlight = {};
  final _sheetQueueActionsInFlight = ValueNotifier<Set<String>>({});
  final Set<String> _orderControlActionsInFlight = {};
  Map<String, double> _baseMetrajByMapId = const {};
  Map<String, double> _orderKgByMapId = const {};
  Map<String, String> _customerByMapId = const {};

  @override
  void initState() {
    super.initState();
    _canonicalCacheOwner = _canonicalCacheRuntimeScope;
    _adminPaging = _adminPagingCandidate;
    _restoreAdminPageCache();
    _claimAdminWarmSequence();
    WidgetsBinding.instance.addObserver(this);
    if (!_adminPaging && !widget.workerMode && !widget.supplyViewerMode && !widget.readOnly) {
      unawaited(_refreshPendingOrders());
    }
    if (widget.supplyViewerMode) {
      _module = _OpenedOrderModule.sequence;
    }
    if (widget.workerMode) {
      _tabController = TabController(length: 1, vsync: this);
      _tabController.addListener(_syncWorkerTab);
    } else {
      _tabController = TabController(
        length: _modules.length,
        vsync: this,
        initialIndex: _modules.indexOf(_module).clamp(0, _modules.length - 1),
      );
      _tabController.addListener(_syncModuleFromTab);
    }
    if (widget.workerMode) {
      _restoreWorkerWarmQueueImmediately();
      unawaited(_startWorkerWithInitialScan());
    } else {
      if (!_adminPaging) unawaited(_restoreSavedSequenceApparatusPreference());
      unawaited(_startAdminLive());
    }
  }

  Future<void> _startWorkerWithInitialScan() async {
    await _loadWorkerQueueLimit();
    if (!mounted) return;
    await _startWorkerLive();
    if (!mounted || widget.initialWorkerQrPayload.trim().isEmpty) return;
    _workerQrScanInFlight = true;
    try {
      await _handleWorkerFabQr(widget.initialWorkerQrPayload.trim());
    } finally {
      _workerQrScanInFlight = false;
    }
  }

  @override
  void dispose() {
    _releaseAdminWarmSequence();
    _releaseWorkerWarmQueue();
    _flushCanonicalCache();
    _saveAdminPageCache(flush: true);
    _cancelAdminSequenceSyncTimers();
    _adminSearchDebounce?.cancel();
    _adminSubscriptionTimer?.cancel();
    _stopAdminNotifications();
    _workerQueueSearchDebounce?.cancel();
    _queueActionReconcileTimer?.cancel();
    _sheetQueueSnapshot.dispose();
    _sheetQueueActionsInFlight.dispose();
    for (final timer in _sequenceRetryTimers.values) {
      timer.cancel();
    }
    _sequenceRetryTimers.clear();
    _pendingSequenceMoves.clear();
    _workerRecoveryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _stopWorkerLiveStream();
    if (widget.workerMode) {
      _tabController.removeListener(_syncWorkerTab);
    } else {
      _tabController.removeListener(_syncModuleFromTab);
    }
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _flushCanonicalCache();
      _saveAdminPageCache(flush: true);
    }
    if (!widget.workerMode && !_adminPaging) {
      _adminForeground = state == AppLifecycleState.resumed;
      if (_adminForeground) {
        unawaited(_startAdminLive());
      } else {
        _stopWorkerLiveStream();
      }
    }
    if (_adminPaging) {
      _adminForeground = state == AppLifecycleState.resumed;
      if (_adminForeground) {
        unawaited(_restartAdminPagedLive());
        _startAdminNotifications();
        unawaited(_ensureAdminModule(_module, refresh: _adminLiveDescriptors().isEmpty));
      } else {
        _stopAdminNotifications();
        _cancelAdminSequenceSyncTimers();
        _stopWorkerLiveStream();
      }
    }
    if (widget.workerMode && state == AppLifecycleState.resumed) {
      _workerForeground = true;
      _workerRetryAllowed = true;
      unawaited(_resumeWorkerLive());
    } else if (widget.workerMode &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached)) {
      _workerForeground = false;
      _queueActionReconcileTimer?.cancel();
      _queueActionReconcileTimer = null;
      _workerRecoveryTimer?.cancel();
      _workerRecoveryTimer = null;
      _stopWorkerLiveStream();
    }
  }

  List<_OpenedOrderModule> get _modules {
    return widget.workerMode || widget.supplyViewerMode
        ? const [_OpenedOrderModule.sequence]
        : _OpenedOrderModule.values;
  }

  bool get _tayyorlovOrderFilterActive =>
      widget.supplyViewerMode &&
      AppSession.instance.profile?.role == UserRole.tayyorlovMasteri;

  Future<void> _refreshTayyorlovOrderFilter() async {
    if (!_tayyorlovOrderFilterActive) {
      return;
    }
    try {
      final snapshot = await MobileApi.instance.preparationSnapshot();
      if (!mounted) {
        return;
      }
      setState(() {
        _tayyorlovAllowedOrderIds = {
          for (final order in snapshot.orders) order.id.trim(),
        };
        _tayyorlovResponsibilities =
            List<PreparationResponsibility>.unmodifiable(
                snapshot.responsibilities);
        _tayyorlovFilterError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _tayyorlovAllowedOrderIds = const {};
        _tayyorlovResponsibilities = const [];
        _tayyorlovFilterError = error;
      });
    }
  }

  List<ProductionMapSaved> get _supplyFilteredOrders {
    if (!_tayyorlovOrderFilterActive) {
      return _orders;
    }
    final allowed = _tayyorlovAllowedOrderIds;
    if (allowed == null || allowed.isEmpty) {
      return const [];
    }
    return _orders
        .where((order) => allowed.contains(order.map.id.trim()))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    final role = AppSession.instance.profile?.role;
    final paddonApparatus = _workerPaddonApparatus;
    final isQolipchi = role == UserRole.qolipchi;
    final isMaterialTaminotchi = role == UserRole.materialTaminotchi;
    final isTayyorlovMasteri = role == UserRole.tayyorlovMasteri;
    final canViewSupplyOrderInfo =
        role == UserRole.qolipchi || isMaterialTaminotchi || isTayyorlovMasteri;
    final supplyDrawer = switch (role) {
      UserRole.qolipchi => QolipNavigationDrawer(
          selectedIndex: 0,
          selectedRouteName: widget.qolipTasksMode
              ? AppRoutes.qolipTasks
              : AppRoutes.supplySequence,
          onNavigate: _openDrawerRoute,
        ),
      UserRole.materialTaminotchi => MaterialTaminotchiNavigationDrawer(
          selectedRouteName: widget.materialTasksMode
              ? AppRoutes.materialTasks
              : AppRoutes.supplySequence,
          onNavigate: _openDrawerRoute,
        ),
      UserRole.tayyorlovMasteri => PreparationDrawer(
          selectedRouteName: AppRoutes.supplySequence,
          onNavigate: _openDrawerRoute,
        ),
      _ => null,
    };
    final supplyDock = switch (role) {
      UserRole.qolipchi =>
        QolipDock(activeTab: widget.qolipTasksMode ? QolipDockTab.tasks : null),
      UserRole.materialTaminotchi => MaterialTaminotchiDock(
          activeTab: widget.materialTasksMode
              ? MaterialTaminotchiDockTab.tasks
              : null),
      UserRole.tayyorlovMasteri => const PreparationDock(),
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
                  // The page already owns this catalog. Opening/rebuilding a
                  // drawer must not download it again or cross an account.
                  apparatusLoader: () async =>
                      _canonicalCacheOwner == _canonicalCacheRuntimeScope
                          ? _apparatus
                          : const [],
                )
              : AdminNavigationDrawer(
                  selectedIndex: 0,
                  selectedRouteName: AppRoutes.adminProductionMapOrders,
                  onNavigate: _openDrawerRoute,
                ),
      title: '',
      subtitle: '',
      nativeTopBar: true,
      actions: [
        if (paddonApparatus != null)
          ActiveRezkaPaddonAction(
            key: ValueKey(ActiveRezkaPaddonStore.scopeKey(paddonApparatus.id)),
            apparatusId: paddonApparatus.id,
          ),
      ],
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: widget.materialTasksMode
            ? 'Material vazifalari'
            : widget.qolipTasksMode
                ? context.l10n.qolipText('nav.tasks')
                : widget.supplyViewerMode
                    ? context.l10n
                        .productionText('worker.queue.search.sequence')
                    : context.l10n.productionText('worker.queue.search.open'),
        onChanged: _onOrdersSearchChanged,
        onClear: () {
          _searchController.clear();
          _onOrdersSearchChanged('');
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
      child: _loading ||
              (_loadError != null &&
                  _reconnectingOrderReads.contains(_OrdersReadSection.initial))
          ? const Align(
              alignment: Alignment.topCenter,
              child: _OrdersConnectionProgress(),
            )
          : _loadError != null
              ? _OpenedOrdersLoadErrorBody(
                  message: _loadError!,
                  bottomPadding: bottomPadding,
                  onRefresh: _load,
                )
              : Column(
                  children: [
                    if (_reconnectingOrderReads.isNotEmpty)
                      const _OrdersConnectionProgress(),
                    if (_queueSnapshotContractError &&
                        !_reconnectingOrderReads.contains(_OrdersReadSection.queue))
                      _QueueSnapshotWarningBanner(
                        message: _queueSnapshotErrorMessage ??
                            context.l10n.productionText('worker.error.sync'),
                        onRetry: _refreshQueueSnapshot,
                      ),
                    if (_tayyorlovOrderFilterActive &&
                        _tayyorlovFilterError != null)
                      _QueueSnapshotWarningBanner(
                        message: _tayyorlovFilterError.toString(),
                        onRetry: _refreshTayyorlovOrderFilter,
                      ),
                    if (_tayyorlovOrderFilterActive &&
                        _tayyorlovFilterError == null &&
                        _tayyorlovAllowedOrderIds != null &&
                        _tayyorlovResponsibilities.isEmpty)
                      _QueueSnapshotWarningBanner(
                        message:
                            'Sizga homashyo biriktirilmagan. Admin javobgar homashyoni biriktirgach buyurtmalar ko‘rinadi.',
                        onRetry: _refreshTayyorlovOrderFilter,
                      ),
                    if (_tayyorlovOrderFilterActive &&
                        _tayyorlovFilterError == null &&
                        _tayyorlovAllowedOrderIds != null &&
                        _tayyorlovResponsibilities.isNotEmpty &&
                        _tayyorlovAllowedOrderIds!.isEmpty)
                      _QueueSnapshotWarningBanner(
                        message:
                            'Biriktirilgan (${_tayyorlovResponsibilities.map((item) => item.materialName.isEmpty ? item.materialId : item.materialName).join(', ')}) bo‘yicha faol buyurtma topilmadi.',
                        onRetry: _refreshTayyorlovOrderFilter,
                      ),
                    if (widget.workerMode && _workerCompletedHistoryError &&
                        !_reconnectingOrderReads.contains(_OrdersReadSection.completed))
                      _QueueSnapshotWarningBanner(
                        message: _workerCompletedHistoryErrorMessage ??
                            context.l10n.productionText('worker.error.sync'),
                        onRetry: _refreshWorkerCompletedOrders,
                      ),
                    if (!widget.workerMode &&
                        _completionRequestsErrorMessage != null &&
                        !_reconnectingOrderReads.contains(_OrdersReadSection.completionRequests))
                      _QueueSnapshotWarningBanner(
                        message: _completionRequestsErrorMessage!,
                        onRetry: _refreshCompletionRequests,
                      ),
                    if (!widget.workerMode && _closedOrdersErrorMessage != null &&
                        !_reconnectingOrderReads.contains(_OrdersReadSection.closed))
                      _QueueSnapshotWarningBanner(
                        message: _closedOrdersErrorMessage!,
                        onRetry: _refreshClosedOrders,
                      ),
                    if (widget.workerMode)
                      WorkerQueueLimitFilter(
                        limit: _workerQueueLimit,
                        onChanged: (limit) => unawaited(_changeWorkerQueueWindow(limit: limit)),
                      ),
                    Expanded(
                      child: widget.workerMode
                          ? _WorkerWatchBody(
                              compactList: _canonicalQueueSnapshot?.isWorkerList ?? false,
                              displayStatesByApparatus: _canonicalQueueSnapshot?.workerDisplayStates ?? const {},
                              queueLimit: _workerQueueLimit,
                              sequencePositionsByApparatus: _canonicalQueueSnapshot?.sequencePositionsByApparatus ?? const {},
                              apparatus: _workerVisibleApparatusFor(_apparatus),
                              assignedApparatus: AppSession
                                      .instance.profile?.assignedApparatus ??
                                  const <String>[],
                              orders: _orders,
                              completedOrders: _completedWorkerOrders,
                              sequenceByApparatus: _displaySequenceByApparatus,
                              visibleOrderIdsByApparatus:
                                  _visibleOrderIdsByApparatus,
                              queueStatesByApparatus: _queueStatesByApparatus,
                              stageStatesByOrderId: _stageStatesByOrderId,
                              queueActionControlsByApparatus:
                                  _queueActionControlsByApparatus,
                              workActivityByApparatus: _workActivityByApparatus,
                              queuePoliciesByApparatus:
                                  _queuePoliciesByApparatus,
                              workerRole: AppSession.instance.profile == null
                                  ? ''
                                  : userRoleToJson(
                                      AppSession.instance.profile!.role),
                              workerRef: AppSession.instance.profile?.ref ?? '',
                              orderStatusesByOrderId: _orderStatusesByOrderId,
                              orderControlsByOrderId: _orderControlsByOrderId,
                              searchQuery: _searchQuery,
                              bottomPadding: bottomPadding,
                              tabController: _tabController,
                              onTapCompletedOrder: _showCompletedOrderDetail,
                              onLongPressCompletedOrder: (entry) => unawaited(
                                  _showCompletedOrderReactivation(entry)),
                              onTapWatchOrder: _showWatchOrderInfo,
                              onLongPressWatchOrder: _showWatchOrderLongPress,
                            )
                          : widget.qolipTasksMode || widget.materialTasksMode
                              ? _buildQolipTasks(bottomPadding)
                              : _AdminModulesBody(
                                  pageLoading: _adminPaging &&
                                      _adminModuleWindows(_module)
                                          .any((window) => window.inFlight != null),
                                  pageWrapper: _adminPaging ? _wrapAdminModule : null,
                                  movePageWrapper: _adminPaging ? _wrapAdminMovePane : null,
                                  pagedOrders: _adminPaging ? _adminWindow('orders').orders : null,
                                  sequenceTotal: _adminPaging && _selectedApparatus != null
                                      ? _adminWindow('sequence', apparatus: _selectedApparatus!.id).pages.firstOrNull?.total : null,
                                  // A complete unfiltered prefix follows the optimistic local order.
                                  // Search results need ranks from the full server queue.
                                  sequenceRows: _adminSequenceRows,
                                  sequencePositions: _adminPaging &&
                                          _selectedApparatus != null &&
                                          _adminPageSearch.isNotEmpty
                                      ? _adminWindow('sequence', apparatus: _selectedApparatus!.id).sequencePositions
                                      : const {},
                                  loadClosedDetail: _adminPaging
                                      ? MobileApi.instance.adminClosedProductionOrderDetail : null,
                                  stageStatesByOrderId: _stageStatesByOrderId,
                                  queueActionControlsByApparatus:
                                      _queueActionControlsByApparatus,
                                  pendingOrders: _pendingOrders,
                                  orderRows: _adminOrdersRows,
                                  pendingRows: _adminPendingRows.values.toList(growable: false),
                                  onPendingRow: _showPendingOrderRow,
                                  pendingOrdersError: _reconnectingOrderReads
                                          .contains(_OrdersReadSection.pending)
                                      ? null
                                      : _pendingOrdersError,
                                  onPendingOrder: _showPendingOrder,
                                  onRetryPendingOrders: _refreshPendingOrders,
                                  modules: _modules,
                                  currentModule: _module,
                                  tabController: _tabController,
                                  bottomPadding: bottomPadding,
                                  orders: _supplyFilteredOrders,
                                  searchQuery: _adminPaging ? '' : _searchQuery,
                                  apparatus: _apparatus,
                                  selectedApparatus: _selectedApparatus,
                                  completionRequests: _completionRequests,
                                  readOnly: widget.readOnly ||
                                      widget.supplyViewerMode,
                                  moveTopApparatus: _moveTopApparatus,
                                  moveBottomApparatus: _moveBottomApparatus,
                                  selectedMoveOrderIds: _selectedMoveOrderIds,
                                  draggingMoveOrders: _draggingMoveOrders,
                                  draggingMoveSource: _draggingMoveSource,
                                  closedOrders: _closedOrders,
                                  onSetModule: _setModule,
                                  ordersForApparatus: _ordersForApparatus,
                                  sequenceReorderEnabled:
                                      (!_adminPaging || (_searchQuery.trim().isEmpty &&
                                          _adminModuleWindows(_OpenedOrderModule.sequence)
                                              .every((w) => w.loaded && w.error == null &&
                                                  !w.cacheNeedsValidation))) &&
                                      _selectedApparatus != null &&
                                      _queuePolicyForApparatus(
                                        _selectedApparatus!,
                                        queuePoliciesByApparatus:
                                            _queuePoliciesByApparatus,
                                      ) == ApparatusQueuePolicy.strictSequence,
                                  moveOrdersForApparatus:
                                      _moveOrdersForApparatus,
                                  canMoveTo: (order, target, {required source}) =>
                                      (!_adminPaging || (!_queueSnapshotNeedsReconcile &&
                                          !_queueSnapshotContractError)) &&
                                      _canMoveOrderToApparatus(order, target, source: source),
                                  onSelectSequenceApparatus: (apparatus) {
                                    _userChangedSequenceApparatus = true;
                                    unawaited(
                                      AdminSequenceApparatusStore.instance
                                          .saveApparatus(apparatus),
                                    );
                                    _updateScreenState(() {
                                      _selectedApparatus = apparatus;
                                      if (_adminPaging) _rebuildAdminPageState();
                                    });
                                    if (_adminPaging) {
                                      unawaited(_ensureAdminModule(_OpenedOrderModule.sequence, refresh: true));
                                    }
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
                                  onToggleMoveSelection:
                                      _toggleMoveOrderSelection,
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
                                  onInfoSequenceOrder:
                                      widget.supplyViewerMode &&
                                              !canViewSupplyOrderInfo
                                          ? null
                                          : _openAdminSequenceDetail,
                                  customerNameByMapId: _customerByMapId,
                                  queueStatesByApparatus:
                                      _queueStatesByApparatus,
                                  visibleOrderIdsByApparatus:
                                      _visibleOrderIdsByApparatus,
                                  orderStatusesByOrderId:
                                      _orderStatusesByOrderId,
                                  sequenceInteractionHint: isQolipchi
                                      ? 'Bir marta bosing — ma’lumot. Uzoq bosing — order qoliplarini ochish.'
                                      : null,
                                  orderControlsByOrderId:
                                      _orderControlsByOrderId,
                                  workflowAudit: _workflowAudit,
                                  workflowAuditError: _adminPaging
                                      ? _adminWindow('audit').error
                                      : _workflowAuditError,
                                  workflowAuditLoading: _adminPaging
                                      ? _adminWindow('audit').inFlight != null
                                      : _workflowAuditLoading,
                                  onRefreshWorkflowAudit: () =>
                                      _refreshWorkflowAudit(force: true),
                                  onLongPressSequenceOrder: (apparatus, order) {
                                    unawaited(
                                      widget.supplyViewerMode && isQolipchi
                                          ? _showQolipsForOrder(order)
                                          : widget.supplyViewerMode &&
                                                  isMaterialTaminotchi
                                              ? _showSupplyRawMaterialAssignment(order)
                                              : _showOrderActions(order,
                                                  apparatus: apparatus),
                                    );
                                  },
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
    setState(() {
      callback();
      if (_canonicalCacheAwaitingValidation) _queueSnapshotNeedsReconcile = true;
    });
    if (_pendingQueueActionRevision != null &&
        (_retiredSnapshotEpochs.contains(_pendingQueueActionEpoch) ||
            _snapshotCoversAction(_pendingQueueActionRevision!,
                _pendingQueueActionEpoch))) {
      _queueActionReconcileTimer?.cancel();
      _queueActionReconcileTimer = null;
      _pendingQueueActionRevision = null;
    }
    _sheetQueueSnapshot.value =
        _queueSnapshotNeedsReconcile || _queueSnapshotContractError ||
                _canonicalQueueSnapshot?.revision == null ||
                (_canonicalQueueSnapshot?.epoch.isEmpty ?? true)
            ? null
            : _canonicalQueueSnapshot;
    _scheduleCanonicalCacheSave();
  }

  bool _snapshotCoversAction(int revision, String epoch) =>
      !_queueSnapshotNeedsReconcile &&
      _canonicalQueueSnapshot?.epoch == epoch &&
      (_canonicalQueueSnapshot?.revision ?? -1) >= revision;

  void _awaitQueueActionDelta(AdminApparatusQueueActionResult result) {
    if (_snapshotCoversAction(result.revision!, result.epoch)) return;
    if (_pendingQueueActionEpoch != result.epoch ||
        (_pendingQueueActionRevision ?? -1) < result.revision!) {
      _pendingQueueActionRevision = result.revision;
      _pendingQueueActionEpoch = result.epoch;
    }
    _queueActionReconcileTimer ??= Timer(const Duration(seconds: 2), () {
      _queueActionReconcileTimer = null;
      if (!mounted || _pendingQueueActionRevision == null) return;
      _queueSnapshotNeedsReconcile = true;
      _sheetQueueSnapshot.value = null;
      unawaited(_refreshQueueSnapshot());
    });
  }

  List<AdminApparatus> _workerVisibleApparatusFor(
    List<AdminApparatus> apparatus,
  ) {
    if (_canonicalQueueSnapshot?.workerShowAllApparatusTabs == true) {
      return apparatus;
    }
    final assigned = AppSession.instance.profile?.assignedApparatus ??
        const <String>[];
    return apparatus
        .where((item) => _isAssignedWatchApparatus(
              item,
              assignedApparatus: assigned,
            ))
        .toList(growable: false);
  }

  void _recreateWorkerTabController(List<AdminApparatus> apparatus) {
    final length = _workerWatchTabCount(_workerVisibleApparatusFor(apparatus));
    if (_tabController.length == length) {
      return;
    }
    _tabController.removeListener(_syncWorkerTab);
    _tabController.dispose();
    _workerTabIndex = 0;
    _tabController = TabController(
      length: length,
      vsync: this,
      initialIndex: 0,
    );
    _tabController.addListener(_syncWorkerTab);
  }

  void _syncWorkerTab() {
    final index = _tabController.index;
    if (!mounted || _workerTabIndex == index) return;
    setState(() => _workerTabIndex = index);
  }

  AdminApparatus? get _workerPaddonApparatus {
    if (!widget.workerMode) return null;
    final assigned = AppSession.instance.profile?.assignedApparatus ??
        const <String>[];
    final tabs = _workerWatchTabs(
      apparatus: _workerVisibleApparatusFor(_apparatus),
      assignedApparatus: assigned,
    );
    final index = _tabController.index;
    if (index < 0 || index >= tabs.length) return null;
    final apparatus = tabs[index].apparatus;
    if (apparatus == null ||
        apparatus.operation.trim() != 'cut' ||
        !_isAssignedWatchApparatus(apparatus, assignedApparatus: assigned)) {
      return null;
    }
    return apparatus;
  }

  bool _beginQueueAction(String actionKey) {
    if (!mounted || !_queueActionsInFlight.add(actionKey)) return false;
    _sheetQueueActionsInFlight.value = Set.unmodifiable(_queueActionsInFlight);
    setState(() {});
    return true;
  }

  void _endQueueAction(String actionKey) {
    if (!_queueActionsInFlight.remove(actionKey) || !mounted) return;
    _sheetQueueActionsInFlight.value = Set.unmodifiable(_queueActionsInFlight);
    setState(() {});
  }

  Future<AdminApparatusQueueActionResult?> _handleQueueAction(
    _ReadOnlyQueueActionRequest request,
  ) async {
    final apparatusKey = request.apparatus.id.trim();
    final actionKey = '$apparatusKey|${request.order.map.id.trim()}';
    if (!_beginQueueAction(actionKey)) {
      return null;
    }
    final actionReadScope = currentSessionReadScope();
    try {
      final snapshotGeneration = _queueSnapshotGeneration;
      final result = await _submitAdminApparatusQueueAction(
        request,
        apparatusKey: apparatusKey,
      );
      if (!mounted || actionReadScope != currentSessionReadScope()) {
        return null;
      }
      _applyQueueActionResult(
        apparatusKey: apparatusKey,
        orderId: request.order.map.id.trim(),
        completionRequestNote: request.completionRequestNote,
        result: result,
        applyState: snapshotGeneration == _queueSnapshotGeneration,
      );
      return result;
    } catch (error) {
      if (mounted && widget.workerMode &&
          actionReadScope == currentSessionReadScope() &&
          (error is! MobileApiException || error.statusCode == null ||
              error.statusCode! >= 500)) {
        // A lost response can follow a committed write. Reconcile read-only.
        _queueSnapshotNeedsReconcile = true;
        _sheetQueueSnapshot.value = null;
        if (_workerForeground) unawaited(_refreshQueueSnapshot());
      }
      rethrow;
    } finally {
      _endQueueAction(actionKey);
    }
  }

  void _applyQueueActionResult({
    required String apparatusKey,
    required String orderId,
    required String completionRequestNote,
    required AdminApparatusQueueActionResult result,
    bool applyState = true,
  }) {
    final usesDelta = widget.workerMode &&
        result.hasSnapshotCursor &&
        !orderId.startsWith('training-');
    if (usesDelta && _retiredSnapshotEpochs.contains(result.epoch)) return;
    final alreadyApplied = usesDelta &&
        _snapshotCoversAction(result.revision!, result.epoch);
    setState(() {
      if (!alreadyApplied) _queueSnapshotGeneration++;
      if (!usesDelta) _queueSnapshotNeedsReconcile = true;
      if (applyState && !alreadyApplied) {
        _queueActionControlsByApparatus[apparatusKey] =
            Map<String, AdminApparatusQueueOrderActionControl>.from(
                _queueActionControlsByApparatus[apparatusKey] ?? const {})
              ..remove(orderId);
        _queueStatesByApparatus[apparatusKey] = result.states;
        if (result.hasWorkActivity) {
          final activities =
              _workActivityByApparatus.putIfAbsent(apparatusKey, () => {});
          final activity = result.workActivity;
          if (activity == null) {
            activities.remove(orderId);
          } else {
            activities[orderId] = activity;
          }
        }
        if (result.hasOrderStatus) {
          _orderStatusesByOrderId[orderId] = result.orderStatus;
        }
        if (result.orderControl != null) {
          _orderControlsByOrderId[orderId] = result.orderControl!;
        }
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
        tone: AdminTopNoticeTone.success,
      );
    }
    // Catalog/history refreshes are not prerequisites for a queue mutation.
    if (usesDelta && _workerLiveHealthy) {
      _awaitQueueActionDelta(result);
    } else if (!alreadyApplied) {
      _queueSnapshotNeedsReconcile = true;
      _sheetQueueSnapshot.value = null;
      unawaited(_refreshQueueSnapshot());
    }
    if (widget.workerMode && !usesDelta) {
      // Stage history is actor-scoped and may change even when the whole
      // order is not finished yet. Keep the worker's completed tab current.
      unawaited(_refreshWorkerCompletedOrders());
      unawaited(_refreshWorkerCompletionRequestDecisions());
    }
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

  Future<void> _showOrderDetail(ProductionMapSaved order) async {
    if (_adminOrdersRows.containsKey(order.map.id)) {
      await _showOrdersListDetail(order);
      return;
    }
    final mapId = order.map.id.trim();
    await showModalBottomSheet<void>(
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
        busyOrderTitleLookup: (orderId) {
          for (final candidate in _orders) {
            if (candidate.map.id.trim() == orderId.trim()) {
              return _busyOrderDisplayLabel(candidate, context.l10n);
            }
          }
          return null;
        },
        baseMetraj: _baseMetrajByMapId[mapId] ?? order.map.baseLength,
        orderKg: _orderKgByMapId[mapId] ?? order.map.orderKg,
        customerName: _customerByMapId[mapId] ?? order.map.customerName,
        queueStatesByApparatus: _queueStatesByApparatus,
        stageStatesByOrderId: _stageStatesByOrderId,
        allowWipQrReprint: !widget.supplyViewerMode,
        queueActionControlsByApparatus: _queueActionControlsByApparatus,
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
    String expectedReportSessionId = '',
    bool startBosmaFinishOnOpen = false,
    bool startRollRemovalOnOpen = false,
    bool startResumeOnOpen = false,
    _ScannedWorkerWip? initialOrderSwitchBatch,
    String initialScanQrPayload = '',
    AdminApparatusQueueSnapshot? initialQueueSnapshot,
    bool initialControlConfirmed = false,
    AdminSequenceListRow? initialPreview,
    _WorkerFabPreparedScan? initialFabPreparedScan,
  }) {
    final workerHydrated = widget.workerMode &&
        _canonicalQueueSnapshot?.isWorkerList == true;
    if (workerHydrated && initialQueueSnapshot == null &&
        !isWorkerListPresentationOrder(order)) {
      final prepared = _workerPreparedDetail;
      final baseline = _canonicalQueueSnapshot!;
      if (_workerPreparedDetailScope == currentSessionReadScope() &&
          prepared?.maps.length == 1 &&
          prepared!.maps.single.map.id == order.map.id &&
          prepared.epoch == baseline.epoch &&
          (prepared.revision ?? -1) >= (baseline.revision ?? -1)) {
        initialQueueSnapshot = prepared;
      }
    }
    final workerPreview = widget.workerMode &&
        (isWorkerListPresentationOrder(order) ||
            (workerHydrated && initialQueueSnapshot == null));
    if (widget.workerMode &&
        (initialQueueSnapshot == null
            ? _isWorkerOrderFrozen(order.map.id)
            : initialQueueSnapshot.orderControlFor(order.map.id) ==
                  AdminOrderControlState.frozen)) {
      showAdminTopNotice(
        context,
        _workerFrozenOrderMessage(context.l10n, order.map.title),
        icon: Icons.warning_amber_rounded,
        tone: AdminTopNoticeTone.error,
      );
      return;
    }
    if (workerPreview) {
      if (_adminDetailOpening) return;
      _adminDetailOpening = true;
    }
    final mapId = order.map.id.trim();
    final readScope = currentSessionReadScope();
    final initialStates =
        initialQueueSnapshot?.queueStates ?? _queueStatesByApparatus;
    final initialControls =
        initialQueueSnapshot?.queueActionControls ??
        _queueActionControlsByApparatus;
    final detailAccount = _adminPageAccount;
    final detailSearch = _adminPageSearch;
    final sheetFuture = showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      shape: _orderDetailSheetShape,
      clipBehavior: Clip.antiAlias,
      sheetAnimationStyle: AppMotion.sheetEaseOut,
      builder: (context) {
        Widget detailBuilder(
          AdminApparatusQueueSnapshot? detail,
          ValueNotifier<AdminApparatusQueueSnapshot?> authority, {
          bool detailPending = false,
          String? detailError,
          VoidCallback? onRetryDetail,
        }) {
          final detailOrder =
              detail?.maps
                  .where((saved) => saved.map.id.trim() == mapId)
                  .firstOrNull ??
              order;
          final states = detailPending
              ? const <String, Map<String, String>>{}
              : detail?.queueStates ?? initialStates;
          final controls = detailPending
              ? const <String,
                  Map<String, AdminApparatusQueueOrderActionControl>>{}
              : detail?.queueActionControls ?? initialControls;
          Widget buildSheet(({double? base, double? kg})? metrics) =>
              _ReadOnlyOrderDetailSheet(
            scopedWorkerDetail: workerHydrated,
            baseMetraj: metrics?.base,
            orderKg: metrics?.kg,
            detailPending: detailPending,
            detailError: detailError,
            onRetryDetail: onRetryDetail,
            order: detailOrder,
            apparatus: apparatus,
            apparatusCatalog: _apparatus,
            busyOrderTitleLookup: (orderId) {
              for (final candidate in _orders) {
                if (candidate.map.id.trim() == orderId.trim()) {
                  return _busyOrderDisplayLabel(candidate, context.l10n);
                }
              }
              return null;
            },
            workerMode: widget.workerMode,
            initialControlConfirmed: initialControlConfirmed || workerHydrated,
            stageFreezeSupported:
                detail?.stageFreezeSupported ??
                _canonicalQueueSnapshot?.stageFreezeSupported ??
                false,
            currentQueueSnapshot: (initialControlConfirmed || workerHydrated) &&
                    (!widget.workerMode || workerHydrated)
                ? () => authority.value
                : () => _canonicalQueueSnapshot,
            queueSnapshotListenable: authority,
            queueActionsInFlight: _sheetQueueActionsInFlight,
            beginPrintPreflight: () =>
                _beginQueueAction('${apparatus.id.trim()}|$mapId'),
            endPrintPreflight: () =>
                _endQueueAction('${apparatus.id.trim()}|$mapId'),
            customerName: detailPending
                ? initialPreview?.customerName
                : (initialControlConfirmed && detail != null
                    ? detail.orderCustomers[mapId] ?? detailOrder.map.customerName
                    : _customerByMapId[mapId] ?? detailOrder.map.customerName),
            canManageQueue:
                widget.workerMode &&
                _isAssignedWatchApparatus(
                  apparatus,
                  assignedApparatus:
                      AppSession.instance.profile?.assignedApparatus ??
                      const <String>[],
                ),
            initialQueueStates: _queueStatesForApparatus(
              apparatus,
              queueStatesByApparatus: states,
            ),
            queueStatesByApparatus: states,
            stageStatesByOrderId: detailPending
                ? const {}
                : detail?.stageStates ?? _stageStatesByOrderId,
            queueActionControl: controls[apparatus.id.trim()]?[mapId],
            queueActionControlsByApparatus: controls,
            queuePolicy: _queuePolicyForApparatus(
              apparatus,
              queuePoliciesByApparatus:
                  detail?.queuePolicies ?? _queuePoliciesByApparatus,
            ),
            sequenceOrderIds: _sequenceOrderIdsForApparatus(
              apparatus,
              sequenceByApparatus:
                  detail?.sequences ?? _displaySequenceByApparatus,
            ),
            visibleOrderIds:
                detail?.visibleOrderIds[apparatus.id.trim()] ??
                _ordersForApparatus(apparatus)
                    .map((item) => item.map.id)
                    .toList(growable: false),
            onQueueAction: detailPending ? null : _handleQueueAction,
            progressDriverUrlPicker: widget.progressDriverUrlPicker,
            initialOrderControls: detailPending
                ? const {}
                : detail?.orderControls ?? _orderControlsByOrderId,
            initialOrderSwitchBatch: initialOrderSwitchBatch,
            initialScanQrPayload: initialScanQrPayload,
            initialFabPreparedScan: initialFabPreparedScan,
            startWorkerHandoffOnOpen: startWorkerHandoffOnOpen,
            startAstatkaOnOpen: startAstatkaOnOpen,
            expectedReportSessionId: expectedReportSessionId,
            startBosmaFinishOnOpen: startBosmaFinishOnOpen,
            startRollRemovalOnOpen: startRollRemovalOnOpen,
            startResumeOnOpen: startResumeOnOpen,
          );
          if (workerHydrated) {
            return FutureBuilder<({double? base, double? kg})>(
                future: detail == null ? null : _workerScopedDetailMetrics(detail, detailOrder),
                builder: (_, result) => buildSheet(result.data));
          }
          return buildSheet(null);
        }

        bool detailIsCurrent() => mounted &&
            detailAccount == _adminPageAccount &&
            detailSearch == _adminPageSearch &&
            (widget.workerMode || _selectedApparatus?.id == apparatus.id) &&
            readScope == currentSessionReadScope();
        ({String epoch, int revision})? detailCursor() {
          if (workerHydrated) {
            final baseline = _canonicalQueueSnapshot;
            return baseline?.revision == null ? null :
                (epoch: baseline!.epoch, revision: baseline.revision!);
          }
          final window = _adminWindow('sequence', apparatus: apparatus.id);
          if (!window.sequenceRows.containsKey(mapId) || window.pages.isEmpty) {
            return null;
          }
          final page = window.pages.first;
          return (epoch: page.epoch, revision: page.revision!);
        }
        Widget hydratedDetail(AdminApparatusQueueSnapshot? snapshot,
                {String? error, VoidCallback? onRetry}) =>
            _AdminHydratedDetailHost(
              initialSnapshot: snapshot,
              isCurrent: detailIsCurrent,
              currentCursor: detailCursor,
              load: () => workerHydrated
                  ? _readWorkerListDetail(apparatus, mapId)
                  : _readAdminSequenceDetail(apparatus, mapId),
              builder: (detail, authority) => detailBuilder(detail, authority,
                  detailPending: detail == null,
                  detailError: error,
                  onRetryDetail: onRetry),
            );
        if (initialPreview != null || workerPreview) {
          return _AdminInitialDetailHost(
            isCurrent: detailIsCurrent,
            load: () => workerPreview
                ? _readWorkerListDetail(apparatus, mapId)
                : _readAdminSequenceDetail(apparatus, mapId),
            onReady: workerPreview
                ? (_) {} : _installAdminDetailAuthority,
            builder: (snapshot, error, onRetry) =>
                hydratedDetail(snapshot, error: error, onRetry: onRetry),
          );
        }
        if ((initialControlConfirmed || workerHydrated) &&
            (!widget.workerMode || workerHydrated) &&
            initialQueueSnapshot != null) {
          return hydratedDetail(initialQueueSnapshot);
        }
        return detailBuilder(initialQueueSnapshot, _sheetQueueSnapshot);
      },
    );
    unawaited(
      sheetFuture.then((result) async {
        if (initialPreview != null || workerPreview) _adminDetailOpening = false;
        if (!mounted || readScope != currentSessionReadScope()) return;
        if (result == true && initialOrderSwitchBatch != null) {
          // Revalidate the scanned order even when it is outside the list window.
          await _handleWorkerFabQr(initialOrderSwitchBatch.qrPayload);
          return;
        }
        if (mounted && result == true) unawaited(_refreshLive());
        if (mounted) unawaited(_showPendingStageAstatkaPrompt());
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
    if (_workerQrScanInFlight || _workerQrGuidanceOpen) return;
    _workerQrScanInFlight = true;
    final scope = currentSessionReadScope();
    try {
      final result = await Navigator.of(context).pushNamed(
        AppRoutes.adminProgressQrScan,
        arguments: const AdminProgressQrScanArgs(scanOnly: true),
      );
      if (!mounted || scope != currentSessionReadScope() ||
          result is! String || result.trim().isEmpty) {
        return;
      }
      await _handleWorkerFabQr(result.trim());
    } finally {
      _workerQrScanInFlight = false;
    }
  }

  Future<void> _handleWorkerFabQr(String qrPayload) async {
    var orderTitle = '';
    final scope = currentSessionReadScope();
    try {
      final wip = await _identifyWorkerWip(qrPayload);
      if (wip == null) {
        throw const MobileApiException(
          code: 'progress_batch_not_found',
          message: '',
        );
      }
      final batch = wip.progress;
      if (!mounted || scope != currentSessionReadScope()) return;
      final targetOrderId = wip.orderId;
      final stationId =
          batch?.nextApparatus.trim() ??
          wip.openingRecord!.intake.resumeApparatus.trim();
      if (targetOrderId.isEmpty) {
        throw const MobileApiException(
          code: 'progress_qr_invalid_response',
          message: '',
        );
      }
      final providedSnapshot = widget.queueSnapshotLoader == null
          ? null
          : await widget.queueSnapshotLoader!();
      if (!mounted || scope != currentSessionReadScope()) return;
      final targetMaps = _orders.where(
        (order) => order.map.id.trim() == targetOrderId,
      );
      ProductionMapSaved? targetOrder = targetMaps.firstOrNull;
      if (targetOrder != null && isWorkerListPresentationOrder(targetOrder)) {
        targetOrder = null;
      }
      orderTitle = targetOrder?.map.title.trim() ?? '';
      final providedControl = providedSnapshot?.orderControlFor(targetOrderId);
      if (providedControl != null &&
          providedControl != AdminOrderControlState.active) {
        throw MobileApiException(
          code: providedControl == AdminOrderControlState.frozen
              ? 'order_frozen'
              : 'order_freeze_requested',
          message: '',
          orderTitle: orderTitle,
        );
      }
      final usageError = switch (wip.status) {
        'in_use' => 'progress_batch_in_use',
        'processed' || 'void' => 'progress_batch_already_used',
        _ => '',
      };
      if (usageError.isNotEmpty) {
        await _showWorkerQrGuidance(
          context,
          usageError == 'progress_batch_in_use'
              ? _workerQrLoadedRollText(
                  wip,
                  targetOrder,
                  snapshot: providedSnapshot,
                )
              : context.l10n.productionText(
                  wip.status == 'void'
                      ? 'worker.qr.roll_void'
                      : 'worker.error.wip_used',
                ),
          icon: Icons.warning_amber_rounded,
          tone: AdminTopNoticeTone.error,
        );
        return;
      }
      if ((batch?.inputRouteError ?? '').isNotEmpty) {
        throw MobileApiException(code: batch!.inputRouteError, message: '');
      }
      if (!_workerCatalogReady) {
        throw const MobileApiException(code: 'worker_qr_sync', message: '');
      }
      // Modern QR route metadata selects the station without a separate map
      // GET. Opening/training/older payloads retain their map-based resolver.
      if (targetOrder == null && batch?.hasInputRouteMetadata != true) {
        targetOrder = await MobileApi.instance
            .adminProductionMap(targetOrderId)
            .timeout(_queueActionControlRefreshTimeout);
        if (!mounted || scope != currentSessionReadScope()) return;
        if (targetOrder.map.id.trim() != targetOrderId) {
          throw const MobileApiException(
            code: 'progress_qr_invalid_response',
            message: '',
          );
        }
      }
      final candidates = _workerWipConsumerIds(wip, targetOrder?.map);
      final assigned =
          AppSession.instance.profile?.assignedApparatus ?? const <String>[];
      if (candidates.isEmpty) {
        throw const MobileApiException(
          code: 'wip_route_destination_unresolved',
          message: '',
        );
      }
      if (assigned.isEmpty) {
        throw const MobileApiException(
          code: 'worker_qr_no_assignment',
          message: '',
        );
      }
      AdminApparatus? station;
      for (final candidate in _apparatus) {
        if (candidates.contains(candidate.id.trim()) &&
            _isAssignedWatchApparatus(candidate, assignedApparatus: assigned)) {
          station = candidate;
          if (candidate.id.trim() == stationId) break;
        }
      }
      if (station == null ||
          !_isAssignedWatchApparatus(station, assignedApparatus: assigned)) {
        if (candidates.any(
          (id) => !_apparatus.any((apparatus) => apparatus.id.trim() == id),
        )) {
          throw const MobileApiException(
            code: 'worker_qr_catalog_missing',
            message: '',
          );
        }
        // Route guidance needs the later stages to distinguish an unassigned
        // destination from a job that has not reached this worker yet.
        targetOrder ??= await MobileApi.instance
            .adminProductionMap(targetOrderId)
            .timeout(_queueActionControlRefreshTimeout);
        if (!mounted || scope != currentSessionReadScope()) return;
        if (targetOrder.map.id.trim() != targetOrderId) {
          throw const MobileApiException(
            code: 'progress_qr_invalid_response',
            message: '',
          );
        }
        await _showWorkerQrGuidance(
          context,
          _workerWipRouteGuidance(
            l10n: context.l10n,
            wip: wip,
            map: targetOrder.map,
            apparatus: _apparatus,
            consumers: candidates,
            assignedApparatus: assigned,
          ),
          icon: Icons.warning_amber_rounded,
          tone: AdminTopNoticeTone.error,
        );
        return;
      }
      final bootstrap = widget.queueSnapshotLoader == null
          ? await _loadWorkerFabBootstrap(
              apparatus: station.id,
              orderId: targetOrderId,
              qrPayload: batch == null ? '' : qrPayload,
              isCurrent: () => mounted && scope == currentSessionReadScope(),
              currentSnapshot: () => _canonicalQueueSnapshot,
            )
          : null;
      if (!mounted || scope != currentSessionReadScope()) return;
      var targetSnapshot = bootstrap?.queueContext;
      // Old servers ignore the additive context/proof fields. Keep their
      // scoped reads and exact QR validation, without refreshing the whole page.
      targetSnapshot ??= providedSnapshot ?? await _loadWorkerQrSnapshot(
              apparatus: station.id,
              orderId: targetOrderId,
              isCurrent: () => mounted && scope == currentSessionReadScope(),
              currentSnapshot: () => _canonicalQueueSnapshot,
            );
      if (!mounted ||
          scope != currentSessionReadScope() ||
          targetSnapshot == null) {
        return;
      }
      targetOrder =
          targetSnapshot.maps
              .where((order) => order.map.id.trim() == targetOrderId)
              .firstOrNull ??
          targetOrder;
      targetOrder ??= await MobileApi.instance
          .adminProductionMap(targetOrderId)
          .timeout(_queueActionControlRefreshTimeout);
      if (!mounted || scope != currentSessionReadScope()) return;
      if (targetOrder.map.id.trim() != targetOrderId) {
        throw const MobileApiException(
          code: 'progress_qr_invalid_response',
          message: '',
        );
      }
      orderTitle = targetOrder.map.title.trim();
      final verified = bootstrap?.validatedProgress;
      if (batch != null) {
        if (verified == null) {
          await MobileApi.instance.adminProgressQrLookup(
            qrPayload,
            apparatus: station.id,
            orderId: targetOrderId,
            requireActiveOrder: true,
          );
        } else if (verified.batchId != batch.batchId) {
          throw const MobileApiException(
            code: 'progress_qr_invalid_response',
            message: '',
          );
        }
      } else {
        await MobileApi.instance.adminLookupOpeningWip(
          apparatus: station.id,
          orderId: targetOrderId,
          qrPayload: qrPayload,
        );
      }
      if (!mounted || scope != currentSessionReadScope()) return;
      final targetControl =
          targetSnapshot.queueActionControls[station.id.trim()]?[targetOrderId];
      final targetOrderControl = targetSnapshot.orderControlFor(targetOrderId);
      if (targetOrderControl != AdminOrderControlState.active) {
        throw MobileApiException(
            code: targetOrderControl == AdminOrderControlState.frozen
                ? 'order_frozen' : 'order_freeze_requested',
            message: '', orderTitle: targetOrder.map.title);
      }
      final targetQueueState =
          targetSnapshot.queueStates[station.id.trim()]?[targetOrderId];
      if (targetControl?.isConsistentWith(
            targetOrderControl,
            queueState: targetQueueState,
          ) !=
          true) {
        final busyOrder = _workerCurrentOrderForApparatus(apparatus: station);
        final busyIsOther =
            busyOrder != null && busyOrder.map.id.trim() != targetOrderId;
        await _showWorkerQrGuidance(
          context,
          _queueActionUnavailableText(
            l10n: context.l10n,
            control: targetControl,
            orderControlState: targetOrderControl,
            queueState: targetQueueState,
            busyApparatusLabel: canonicalApparatusDisplayLabel(
              station.id,
              _apparatus,
            ),
            busyOrderLabel: busyIsOther
                ? _busyOrderDisplayLabel(busyOrder, context.l10n)
                : '',
          ),
          icon: Icons.warning_amber_rounded,
          tone: AdminTopNoticeTone.error,
        );
        return;
      }
      var currentOrder = _workerCurrentOrderForApparatus(apparatus: station);
      AdminApparatusQueueSnapshot? currentSnapshot;
      final activeId = targetSnapshot.queueStates[station.id.trim()]?.entries
          .where(
            (entry) =>
                const {'in_progress', 'print_preflight'}.contains(entry.value),
          )
          .firstOrNull
          ?.key;
      if (activeId == null &&
          currentOrder != null &&
          _canonicalQueueSnapshot?.workerPendingReportIds[station.id]
                  ?.contains(currentOrder.map.id) != true &&
          _canonicalQueueSnapshot?.workerReportPrompts[station.id]
                  ?[currentOrder.map.id] == null &&
          _queueActionControlForApparatus(
                apparatus: station,
                orderId: currentOrder.map.id,
              )?.stageWork?.astatkaRequired !=
              true) {
        // Scoped occupancy supersedes an older visible in-progress row.
        currentOrder = null;
      }
      if (activeId != null) {
        if (activeId == targetOrderId) {
          currentOrder = targetOrder;
          currentSnapshot = targetSnapshot;
        } else {
          if (_canonicalQueueSnapshot?.isWorkerList == true) {
            currentSnapshot = await _readWorkerListDetail(station, activeId);
            if (!mounted || scope != currentSessionReadScope() ||
                currentSnapshot == null) {
              return;
            }
            currentOrder = currentSnapshot.maps.single;
          } else {
          currentOrder =
              targetSnapshot.maps
                  .where((order) => order.map.id.trim() == activeId)
                  .firstOrNull ??
              _orders
                  .where((order) => order.map.id.trim() == activeId)
                  .firstOrNull ??
              await MobileApi.instance
                  .adminProductionMap(activeId)
                  .timeout(_queueActionControlRefreshTimeout);
          if (!mounted || scope != currentSessionReadScope()) return;
          if (currentOrder.map.id.trim() != activeId) {
            throw const MobileApiException(code: 'worker_qr_sync', message: '');
          }
          currentSnapshot =
              targetSnapshot.queueActionControls[station.id
                      .trim()]?[activeId] !=
                  null
              ? targetSnapshot
              : await _loadWorkerQrSnapshot(
                  apparatus: station.id,
                  orderId: activeId,
                  isCurrent: () =>
                      mounted && scope == currentSessionReadScope(),
                  currentSnapshot: () => _canonicalQueueSnapshot,
                );
          if (!mounted ||
              scope != currentSessionReadScope() ||
              currentSnapshot == null) {
            return;
          }
          }
        }
      }
      if (currentOrder != null && isWorkerListPresentationOrder(currentOrder)) {
        currentSnapshot = await _readWorkerListDetail(station, currentOrder.map.id);
        if (!mounted || scope != currentSessionReadScope() ||
            currentSnapshot == null) {
          return;
        }
        currentOrder = currentSnapshot.maps.single;
      }
      // Only an actual handoff may temporarily tolerate the busy-machine gate.
      final currentControl = currentSnapshot?.queueActionControls[station.id.trim()]
              ?[currentOrder?.map.id.trim()] ??
          (currentOrder == null ? null : _queueActionControlForApparatus(
              apparatus: station, orderId: currentOrder.map.id));
      final canFinishCurrent = currentOrder != null &&
          currentOrder.map.id.trim() != targetOrderId &&
          currentControl?.allows('complete') == true;
      final canPrepareSwitch = canFinishCurrent &&
          targetControl?.interaction?.mode ==
              AdminQueueInteractionMode.freshStartBlocked &&
          targetControl?.interaction?.blockingReasonCode == 'apparatus_busy';
      final canResumeWithInput = targetControl?.allows('resume') == true &&
          targetControl?.interaction?.resumeInputRequired == true;
      if (targetControl?.allows('start') != true &&
          !canResumeWithInput &&
          !canPrepareSwitch) {
        final busyIsOther =
            currentOrder != null && currentOrder.map.id.trim() != targetOrderId;
        await _showWorkerQrGuidance(
          context,
          _workerQrExistingOrderText(
            l10n: context.l10n,
            control: targetControl,
            orderControlState: targetOrderControl,
            queueState: targetQueueState,
            apparatusLabel: canonicalApparatusDisplayLabel(
              station.id,
              _apparatus,
            ),
            orderLabel: _busyOrderDisplayLabel(targetOrder, context.l10n),
            usesRollJoining:
                station.usesLaminationWorkflow || station.operation == 'cut',
            busyOrderLabel: busyIsOther
                ? _busyOrderDisplayLabel(currentOrder, context.l10n)
                : '',
          ),
          icon: Icons.info_outline,
          tone: targetControl?.interaction?.blockingReasonCode.trim().isEmpty ==
                  true
              ? AdminTopNoticeTone.success
              : AdminTopNoticeTone.error,
        );
        return;
      }
      if (currentOrder == null || currentOrder.map.id.trim() == targetOrderId) {
        _showWatchOrderDetail(
          apparatus: station,
          order: targetOrder,
          initialQueueSnapshot: targetSnapshot,
          initialScanQrPayload: qrPayload,
          initialFabPreparedScan: bootstrap?.queueContext == null
              ? null
              : _WorkerFabPreparedScan(bootstrap!, qrPayload, scope),
        );
        return;
      }
      _showWatchOrderDetail(
        apparatus: station,
        order: currentOrder,
        initialQueueSnapshot: currentSnapshot,
        initialOrderSwitchBatch: wip,
      );
    } catch (error) {
      if (!mounted || scope != currentSessionReadScope()) return;
      if (error is MobileApiException && error.code == 'order_frozen' &&
          error.orderTitle.trim().isEmpty && orderTitle.isEmpty) {
        // Older servers reject the QR without its title. This history read
        // identifies the order for the notice; it never authorizes a Start.
        try {
          final batch = await MobileApi.instance.adminProgressQrLookup(qrPayload);
          orderTitle = _orders
              .where((order) => order.map.id.trim() == batch.orderId.trim())
              .firstOrNull?.map.title.trim() ?? '';
          if (orderTitle.isEmpty) {
            orderTitle = batch.labelItemName
                .split(RegExp(r',?\s*apparat:', caseSensitive: false))
                .first.trim();
          }
        } catch (_) {}
        if (!mounted || scope != currentSessionReadScope()) return;
      }
      await _showWorkerQrGuidance(
        context,
        _workerQrErrorText(error, orderTitle: orderTitle),
        icon: Icons.warning_amber_rounded,
        tone: AdminTopNoticeTone.error,
      );
    }
  }

  Future<void> _showWorkerQrGuidance(BuildContext dialogContext, String message,
      {IconData? icon, AdminTopNoticeTone tone = AdminTopNoticeTone.error}) async {
    if (!mounted || _workerQrGuidanceOpen) return;
    _workerQrGuidanceOpen = true;
    final l10n = dialogContext.l10n;
    unawaited(showDialog<void>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        key: const ValueKey('production-wip-guidance-dialog'),
        scrollable: true,
        title: Text(l10n.productionText('worker.qr.guidance.title')),
        content: Text(message),
        actions: [TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.productionText('worker.action.close')),
        )],
      ),
    ).whenComplete(() => _workerQrGuidanceOpen = false));
  }

  String _workerQrLoadedRollText(
    _ScannedWorkerWip batch,
    ProductionMapSaved? order, {
    AdminApparatusQueueSnapshot? snapshot,
  }) {
    final l10n = context.l10n;
    final apparatusId = batch.usedBy;
    final station = _apparatus
        .where((apparatus) => apparatus.id.trim() == apparatusId)
        .firstOrNull;
    if (station == null || order == null || !_workerCatalogReady) {
      return l10n.productionText('worker.error.wip_in_use');
    }
    final text = l10n.productionText(
      'worker.qr.roll_in_use',
      values: {
        'apparatus': canonicalApparatusDisplayLabel(station.id, _apparatus),
        'order': _busyOrderDisplayLabel(order, l10n),
      },
    );
    final control = snapshot == null
        ? _queueActionControlForApparatus(
            apparatus: station,
            orderId: batch.orderId,
          )
        : snapshot.queueActionControls[station.id.trim()]?[batch.orderId];
    final orderControl =
        snapshot?.orderControlFor(batch.orderId) ??
        adminProductionMapOrderControlFor(
          _orderControlsByOrderId,
          batch.orderId,
        );
    final queueState =
        (snapshot?.queueStates[station.id.trim()] ??
        _queueStatesForApparatus(
          station,
          queueStatesByApparatus: _queueStatesByApparatus,
        ))[batch.orderId];
    final assigned =
        AppSession.instance.profile?.assignedApparatus ?? const <String>[];
    if ((snapshot == null &&
            (_loadError != null || _queueSnapshotContractError)) ||
        !_isAssignedWatchApparatus(station, assignedApparatus: assigned) ||
        control?.isConsistentWith(orderControl, queueState: queueState) !=
            true) {
      return text;
    }
    if (control?.interaction?.mode == AdminQueueInteractionMode.inProgress) {
      return '$text ${l10n.productionText('worker.qr.loaded_active')}';
    }
    if (control?.interaction?.mode == AdminQueueInteractionMode.paused &&
        control?.allows('resume') == true) {
      return '$text ${l10n.productionText('worker.qr.resume_loaded_roll', values: {'action': l10n.productionText('worker.action.resume')})}';
    }
    final busy = _workerCurrentOrderForApparatus(apparatus: station);
    return '$text ${_workerQrExistingOrderText(l10n: l10n, control: control, orderControlState: orderControl, queueState: queueState, apparatusLabel: canonicalApparatusDisplayLabel(station.id, _apparatus), orderLabel: _busyOrderDisplayLabel(order, l10n), usesRollJoining: false, busyOrderLabel: busy != null && busy.map.id.trim() != batch.orderId.trim() ? _busyOrderDisplayLabel(busy, l10n) : '')}';
  }

  String _workerQrErrorText(Object error, {String orderTitle = ''}) {
    final l10n = context.l10n;
    if (error is TimeoutException) {
      return l10n.productionText('worker.error.network_timeout');
    }
    if (error is http.ClientException) {
      return l10n.productionText('worker.qr.connection');
    }
    if (error is FormatException || error is TypeError) {
      return l10n.productionText('worker.qr.invalid_response');
    }
    if (error is MobileApiException) {
      if (error.code.trim().toLowerCase() == 'order_frozen') {
        return _workerFrozenOrderMessage(l10n,
            error.orderTitle.trim().isEmpty ? orderTitle : error.orderTitle);
      }
      final key = switch (error.code.trim().toLowerCase()) {
        'order_freeze_requested' => 'worker.qr.freeze_requested',
        'progress_batch_not_found' || 'progress_qr_not_found' =>
          'worker.qr.not_found',
        'progress_batch_not_accepted' => 'worker.qr.not_accepted',
        'progress_qr_invalid_response' || 'progress_qr_validation_missing' ||
          'progress_input_invalid' =>
          'worker.qr.invalid_response',
        'worker_qr_no_assignment' => 'worker.qr.no_assignment',
        'worker_qr_catalog_missing' => 'worker.qr.catalog_missing',
        'worker_qr_sync' || 'production_map_snapshot_contract_invalid' =>
          'worker.error.sync',
        'order_not_found' || 'map_not_found' => 'worker.qr.order_unavailable',
        'unauthorized' => 'worker.qr.session_expired',
        'forbidden' => 'worker.qr.forbidden',
        _ => '',
      };
      if (key.isNotEmpty) return l10n.productionText(key);
      if (error.statusCode == 401) {
        return l10n.productionText('worker.qr.session_expired');
      }
      if (error.statusCode == 403) {
        return l10n.productionText('worker.qr.forbidden');
      }
      if ((error.statusCode ?? 0) >= 500) {
        return l10n.productionText('worker.qr.server');
      }
      if (error.code == 'progress_batch_in_use' ||
          error.code == 'progress_batch_already_used') {
        return error.message;
      }
      final specific = l10n.productionErrorMessage(error.code);
      if (specific.isNotEmpty) return specific;
    }
    return l10n.productionText('worker.qr.lookup_failed');
  }

  ProductionMapSaved? _workerCurrentOrderForApparatus({
    required AdminApparatus apparatus,
  }) {
    final compact = _canonicalQueueSnapshot;
    if (compact?.isWorkerList == true) {
      final states = compact!.queueStates[apparatus.id] ?? const {};
      for (final entry in states.entries) {
        if (const {'in_progress', 'print_preflight'}.contains(entry.value) &&
            !_isWorkerOrderFrozen(entry.key)) {
          return compact.workerListRows[entry.key]?.toPresentationOrder();
        }
      }
      final reportIds = compact.workerPendingReportIds[apparatus.id] ??
          compact.workerReportPrompts[apparatus.id]?.keys.toList() ??
          const <String>[];
      for (final id in reportIds) {
        if (!_isWorkerOrderFrozen(id)) {
          return compact.workerListRows[id]?.toPresentationOrder();
        }
      }
      return null;
    }
    AdminQueueInteractionMode? modeFor(ProductionMapSaved order) {
      if (_isWorkerOrderFrozen(order.map.id)) return null;
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
      final needsReport = _queueActionControlForApparatus(
            apparatus: apparatus,
            orderId: order.map.id,
          )?.stageWork?.astatkaRequired ==
          true;
      if (needsReport &&
          (mode == AdminQueueInteractionMode.paused ||
              mode == AdminQueueInteractionMode.completed)) {
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
          icon: Icons.warning_amber_rounded,
          tone: AdminTopNoticeTone.error,
        );
      }
    }
    return null;
  }

  Future<void> _showWatchOrderLongPress({
    required AdminApparatus apparatus,
    required ProductionMapSaved order,
  }) async {
    if (widget.workerMode && isWorkerListPresentationOrder(order)) {
      await _hydrateWorkerActions(apparatus, order);
      return;
    }
    final operation = apparatus.operation.trim().toLowerCase();
    final isLaminatsiya = apparatus.usesLaminationWorkflow;
    final isBosma = operation == 'print';
    final supportsAstatka = isLaminatsiya || operation == 'cut' || isBosma;
    if (!widget.workerMode ||
        !_isAssignedWatchApparatus(
          apparatus,
          assignedApparatus: AppSession.instance.profile?.assignedApparatus ??
              const <String>[],
        ) ||
        !supportsAstatka) {
      return;
    }
    if (_isWorkerOrderFrozen(order.map.id)) {
      return;
    }
    final queueStates = _queueStatesForApparatus(
      apparatus,
      queueStatesByApparatus: _queueStatesByApparatus,
    );
    final state = apparatusQueueOrderStateFromRaw(
      queueStates[order.map.id.trim()],
    );
    final control = _queueActionControlForApparatus(
        apparatus: apparatus, orderId: order.map.id.trim());
    if (isBosma && _reopenablePrintPreflight(apparatus, order) != null) {
      await _showPrintPreflightReopenActions(apparatus, order);
      return;
    }
    final stageWork = control?.stageWork;
    final rePause = _workerRePauseControl(apparatus, order, control);
    final reclose = _workerRecloseControl(apparatus, order, control);
    if (stageWork?.astatkaAvailable == true && operation != 'laminate' && rePause == null && reclose == null) {
      _showWatchOrderDetail(
          apparatus: apparatus, order: order, startAstatkaOnOpen: true);
      return;
    }
    if (isBosma) {
      final control = _queueActionControlForApparatus(
          apparatus: apparatus, orderId: order.map.id.trim());
      if (control?.isConsistentWith(
                  _orderControlsByOrderId[order.map.id.trim()] ??
                      AdminOrderControlState.active,
                  queueState: queueStates[order.map.id.trim()]) !=
              true ||
          !const {
            ApparatusQueueOrderState.inProgress,
            ApparatusQueueOrderState.paused,
            ApparatusQueueOrderState.completed
          }.contains(state)) {
        return;
      }
      final choice = await showModalBottomSheet<_BosmaWorkerLongPressChoice>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _BosmaWorkerFinishSheet(
            canFinish: control?.allows('complete') == true,
            canRePause: rePause != null, canReclose: reclose != null),
      );
      if (!mounted || choice == null) return;
      if (choice == _BosmaWorkerLongPressChoice.reclose) {
        if (reclose != null) await _runWorkerReclose(apparatus, order, reclose);
        return;
      }
      if (choice == _BosmaWorkerLongPressChoice.rePause) {
        if (rePause != null) await _runWorkerRePause(apparatus, order, rePause);
        return;
      }
      _showWatchOrderDetail(
          apparatus: apparatus,
          order: order,
          startBosmaFinishOnOpen:
              choice == _BosmaWorkerLongPressChoice.finishWork,
          startAstatkaOnOpen:
              choice == _BosmaWorkerLongPressChoice.astatkaReport);
      return;
    }
    if (isLaminatsiya && state == ApparatusQueueOrderState.paused && reclose == null) {
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
          builder: (_) => _LaminatsiyaWorkerHandoffSheet(
              showAstatka: operation == 'laminate'),
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
            _showWatchOrderDetail(
              apparatus: apparatus,
              order: order,
              startAstatkaOnOpen: true,
            );
          case _LaminatsiyaWorkerLongPressChoice.rePause:
          case _LaminatsiyaWorkerLongPressChoice.reclose:
          case null:
            break;
        }
        return;
      }
    }
    if (stageWork?.astatkaAvailable == true ||
        state == ApparatusQueueOrderState.inProgress ||
        state == ApparatusQueueOrderState.paused ||
        state == ApparatusQueueOrderState.completed) {
      final choice =
          await showModalBottomSheet<_LaminatsiyaWorkerLongPressChoice>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _LaminatsiyaWorkerFinishSheet(
          isRezka: operation == 'cut',
          isLamination: operation == 'laminate',
          canRePause: rePause != null,
          canReclose: reclose != null,
        ),
      );
      if (!mounted || choice == null) return;
      if (choice == _LaminatsiyaWorkerLongPressChoice.rePause) {
        if (rePause != null) await _runWorkerRePause(apparatus, order, rePause);
        return;
      }
      if (choice == _LaminatsiyaWorkerLongPressChoice.reclose) {
        if (reclose != null) await _runWorkerReclose(apparatus, order, reclose);
        return;
      }
      if (choice != _LaminatsiyaWorkerLongPressChoice.finishWork) return;
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
            printValSizeMm: map.printValSizeMm,
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
          icon: Icons.warning_amber_rounded,
          tone: AdminTopNoticeTone.error,
        );
      }
    }
  }

  Future<void> _showOrderActions(ProductionMapSaved order,
      {AdminApparatus? apparatus, bool hydrated = false}) async {
    final orderId = order.map.id.trim();
    if (!hydrated && _adminOrdersRows.containsKey(orderId)) {
      await _openOrdersListActions(order);
      return;
    }
    if (!hydrated && _adminPaging && _adminSequenceRows.containsKey(orderId)) {
      if (apparatus != null) {
        await _openAdminSequenceActions(apparatus, order);
      }
      return;
    }
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
        icon: Icons.warning_amber_rounded,
        tone: AdminTopNoticeTone.error,
      );
      return;
    }
    final scoped = apparatus != null;
    final apparatusId = apparatus?.id.trim() ?? '';
    final stageNodeId = scoped
        ? (_queueActionControlsByApparatus[apparatusId]?[orderId]
                ?.stageNodeId ??
            '')
        : '';
    final globalControl =
        adminProductionMapOrderControlFor(_orderControlsByOrderId, orderId);
    final localControl = _stageOrderControls.where((item) =>
        item.orderId == orderId &&
        item.stageNodeId == stageNodeId &&
        item.apparatus == apparatusId);
    final control = scoped
        ? (localControl.isEmpty
            ? AdminOrderControlState.active
            : localControl.first.state)
        : globalControl;
    final stageActionsBlocked = scoped &&
        (stageNodeId.isEmpty ||
            globalControl != AdminOrderControlState.active ||
            _canonicalQueueSnapshot?.stageFreezeSupported != true);
    final closingEarly = _earlyClosingOrderIds.contains(orderId);
    final reopenApparatus = _printPreflightReopenApparatus(order);
    final action = await showModalBottomSheet<_OrderLongPressAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reopenApparatus != null)
              _PrintPreflightReopenTile(
                onTap: () => Navigator.pop(
                    context, _OrderLongPressAction.reopenPrintPreflight),
              ),
            ListTile(
              title: UrduAwareText(scoped
                  ? 'Shu bosqich: ${canonicalApparatusDisplayLabel(apparatusId, _apparatus)}'
                  : 'Butun buyurtma'),
              subtitle: UrduAwareText(scoped
                  ? (_canonicalQueueSnapshot?.stageFreezeSupported != true
                      ? 'Server bosqich bo‘yicha muzlatishni qo‘llamaydi. Serverni yangilang.'
                      : stageActionsBlocked
                      ? 'Butun buyurtma muzlatilgan yoki bosqich yangilanishi kutilmoqda'
                      : 'Boshqa bosqichlardagi tayyor rulonlar davom etadi')
                  : 'Muzlatish barcha bosqichlarni to‘xtatadi'),
            ),
            if (control == AdminOrderControlState.active &&
                !closingEarly &&
                !stageActionsBlocked)
              ListTile(
                leading: const Icon(Icons.ac_unit_rounded),
                title: UrduAwareText(scoped
                    ? 'Shu bosqichda muzlatish'
                    : 'Butun buyurtmani muzlatish'),
                onTap: () => Navigator.pop(
                  context,
                  _OrderLongPressAction.freeze,
                ),
              ),
            if (globalControl == AdminOrderControlState.active && !closingEarly)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: UrduAwareText(
                  scoped ? 'Butun buyurtmani o‘chirish' : 'O‘chirish',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () => Navigator.pop(
                  context,
                  _OrderLongPressAction.delete,
                ),
              ),
            if (control == AdminOrderControlState.freezeRequested &&
                !closingEarly &&
                !stageActionsBlocked)
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
            if (control == AdminOrderControlState.frozen &&
                !closingEarly &&
                !stageActionsBlocked)
              ListTile(
                leading: const Icon(Icons.play_circle_outline_rounded),
                title: UrduAwareText(scoped
                    ? 'Shu bosqichni muzdan ochish'
                    : 'Butun buyurtmani muzdan ochish'),
                onTap: () => Navigator.pop(
                  context,
                  _OrderLongPressAction.unfreeze,
                ),
              ),
            if (closingEarly)
              const ListTile(
                  enabled: false,
                  leading: Icon(Icons.hourglass_bottom_rounded),
                  title: UrduAwareText('Erta yopish so‘rovi yuborilgan'),
                  subtitle: UrduAwareText(
                      'Ishchining oxirgi rulonni yechishi kutilmoqda'))
            else
              ListTile(
                leading: Icon(Icons.stop_circle_outlined,
                    color: Theme.of(context).colorScheme.error),
                title: const UrduAwareText('Orderni muammo bilan erta yopish'),
                onTap: () =>
                    Navigator.pop(context, _OrderLongPressAction.closeEarly),
              ),
            if (!closingEarly)
              ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: Text(context.l10n.adminText('production.edit_map')),
                onTap: () => Navigator.pop(
                  context,
                  _OrderLongPressAction.editMap,
                ),
              ),
            if (!closingEarly)
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const UrduAwareText('Buyurtmani tahrirlash'),
                onTap: () =>
                    Navigator.pop(context, _OrderLongPressAction.editOrder),
              ),
          ],
        )),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _OrderLongPressAction.reopenPrintPreflight) {
      if (reopenApparatus != null) {
        await _confirmPrintPreflightReopen(reopenApparatus, order);
      }
      return;
    }
    if (action == _OrderLongPressAction.closeEarly) {
      final comment = await showProductionMapEarlyCloseDialog(context);
      if (!mounted ||
          comment == null ||
          !_orderControlActionsInFlight.add(orderId)) return;
      setState(() {});
      try {
        final AdminOrderControlState next;
        try {
          next = await MobileApi.instance.adminEarlyCloseProductionOrder(
              orderId: orderId, comment: comment);
        } catch (error) {
          if (mounted)
            showAdminTopNotice(
                context,
                error is MobileApiException
                    ? error.message
                    : 'Buyurtma yopilmadi',
                icon: Icons.warning_amber_rounded, tone: AdminTopNoticeTone.error);
          return;
        }
        if (!mounted) return;
        setState(() {
          _earlyClosingOrderIds.add(orderId);
          _orderControlsByOrderId[orderId] = next;
          if (next == AdminOrderControlState.frozen) {
            _orders = [
              for (final item in _orders)
                if (item.map.id.trim() != orderId) item
            ];
            // API snapshots own immutable lists. Replace our local values;
            // never mutate a snapshot after the server has accepted closure.
            _sequenceByApparatus.updateAll((_, sequence) => [
                  for (final id in sequence)
                    if (id.trim() != orderId) id,
                ]);
          }
        });
        showAdminTopNotice(
            context,
            next == AdminOrderControlState.frozen
                ? 'Buyurtma erta yopildi. Tarix Yopilganlar bo‘limida saqlandi.'
                : 'Yopish so‘rovi yuborildi. Oxirgi rulon yechilishi kutilmoqda.', tone: AdminTopNoticeTone.success);
        // Refresh helpers report their own read errors. They must not turn
        // an already accepted close into a "Buyurtma yopilmadi" notice.
        await _refreshLive();
      } finally {
        _orderControlActionsInFlight.remove(orderId);
        if (mounted) setState(() {});
      }
      return;
    }
    if (action == _OrderLongPressAction.editOrder) {
      _orderControlActionsInFlight.add(orderId);
      try {
        final source =
            await MobileApi.instance.adminOpenedOrderEditSource(orderId);
        if (!mounted) return;
        final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => AdminCalculateScreen(openedOrder: source),
        ));
        if (mounted && saved == true) {
          showAdminTopNotice(context, 'Buyurtma o‘zgarishlari saqlandi', tone: AdminTopNoticeTone.success);
          await _refreshLive();
        }
      } catch (error) {
        if (mounted) {
          await showOpenedOrderEditErrorDialog(
            context,
            error: error,
            orderNumber: order.map.orderNumber,
          );
        }
      } finally {
        _orderControlActionsInFlight.remove(orderId);
      }
      return;
    }
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
      _OrderLongPressAction.editMap ||
      _OrderLongPressAction.editOrder ||
      _OrderLongPressAction.reopenPrintPreflight ||
      _OrderLongPressAction.closeEarly =>
        null,
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
    final stageAction =
        scoped && controlAction != AdminOrderControlAction.delete;
    await _runOrderControlAction(order, controlAction,
        apparatus: stageAction ? apparatusId : '',
        stageNodeId: stageAction ? stageNodeId : '');
  }

  Future<void> _runOrderControlAction(
    ProductionMapSaved order,
    AdminOrderControlAction action, {
    String apparatus = '',
    String stageNodeId = '',
  }) async {
    final orderId = order.map.id.trim();
    if (_queueSnapshotContractError) {
      showAdminTopNotice(
        context,
        context.l10n.productionText('worker.error.sync'),
        icon: Icons.warning_amber_rounded,
        tone: AdminTopNoticeTone.error,
      );
      return;
    }
    if (!_orderControlActionsInFlight.add(orderId)) {
      return;
    }
    setState(() {});
    try {
      final snapshotGeneration = _queueSnapshotGeneration;
      final next = await MobileApi.instance.adminProductionMapOrderControl(
        orderId: orderId,
        action: action,
        apparatus: apparatus,
        stageNodeId: stageNodeId,
        stageFreezeSupported:
            _canonicalQueueSnapshot?.stageFreezeSupported == true,
      );
      if (!mounted) return;
      setState(() {
        final applyState = snapshotGeneration == _queueSnapshotGeneration;
        // Discard reads started before this mutation and force a fresh full
        // snapshot even if its global revision was already seen over live.
        _queueSnapshotGeneration++;
        _queueSnapshotNeedsReconcile = true;
        if (!applyState) return;
        if (action == AdminOrderControlAction.delete) {
          _orders = [
            for (final item in _orders)
              if (item.map.id.trim() != orderId) item,
          ];
          _orderControlsByOrderId.remove(orderId);
          // Snapshot lists are immutable and may still be shared with readers.
          _sequenceByApparatus.updateAll((_, sequence) => [
                for (final id in sequence)
                  if (id.trim() != orderId) id,
              ]);
        } else if (next != null && apparatus.isEmpty) {
          _orderControlsByOrderId[orderId] = next;
        }
      });
      showAdminTopNotice(
        context,
        switch (action) {
          AdminOrderControlAction.freeze =>
            next == AdminOrderControlState.frozen
                ? (apparatus.isEmpty
                    ? 'Butun buyurtma muzlatildi'
                    : 'Shu bosqich muzlatildi')
                : 'Worker pauzasi kutilmoqda',
          AdminOrderControlAction.cancelFreeze =>
            'Muzlatish so‘rovi bekor qilindi',
          AdminOrderControlAction.unfreeze => apparatus.isEmpty
              ? 'Butun buyurtma muzdan ochildi'
              : 'Shu bosqich muzdan ochildi',
          AdminOrderControlAction.delete => 'Buyurtma o‘chirildi',
        },
        tone: AdminTopNoticeTone.success,
      );
      unawaited(_refreshLive());
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
          context,
          error is MobileApiException
              ? error.message
              : 'Buyurtma amali bajarilmadi',
          icon: Icons.warning_amber_rounded,
          tone: AdminTopNoticeTone.error,
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
    if (isWorkerListPresentationOrder(entry.order)) {
      unawaited(_hydrateWorkerHistory(entry));
      return;
    }
    if (entry.isFrozen || _isWorkerOrderFrozen(entry.order.map.id)) return;
    if (entry.hasFreezeIssue) {
      _showWorkerFrozenOrderDetails(entry);
      return;
    }
    _showWorkerWipHistory(entry);
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
        workerMode: true,
        ownWorkerOutputOnly: true,
        sourceApparatusId: entry.apparatusId,
        progressDriverUrlPicker: widget.progressDriverUrlPicker,
        allowReactivation: entry.apparatus?.usesLaminationWorkflow == true ||
            entry.apparatus?.operation.trim() == 'cut',
        onReactivationAttempted: _reconcileReactivatedWork,
      ),
    );
  }

  void _setModule(_OpenedOrderModule module) {
    if (_module != module) {
      _updateScreenState(() {
        _module = module;
        if (_adminPaging) _rebuildAdminPageState();
      });
      if (!_adminPaging && module == _OpenedOrderModule.closed) {
        unawaited(_refreshClosedOrders());
      }
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
    if (_adminPaging) {
      unawaited(_ensureAdminModule(module));
    } else if (module == _OpenedOrderModule.audit) {
      unawaited(_refreshWorkflowAudit());
    }
  }

  void _syncModuleFromTab() {
    final module = _modules[_tabController.index];
    if (_module != module) {
      _updateScreenState(() {
        _module = module;
        if (_adminPaging) _rebuildAdminPageState();
      });
      if (_adminPaging) {
        unawaited(_ensureAdminModule(module));
      }
      if (!_adminPaging && module == _OpenedOrderModule.closed) {
        unawaited(_refreshClosedOrders());
      }
    }
    if (!_adminPaging && module == _OpenedOrderModule.audit) {
      unawaited(_refreshWorkflowAudit());
    }
  }

  List<ProductionMapSaved> _ordersForApparatus(AdminApparatus apparatus) {
    if (_adminPaging) return _adminSequenceOrders(apparatus);
    return _productionMapOrdersForApparatus(
      orders: _supplyFilteredOrders,
      apparatus: apparatus,
      visibleOrderIdsByApparatus: _visibleOrderIdsByApparatus,
      sequenceByApparatus: _displaySequenceByApparatus,
      queuePoliciesByApparatus: _queuePoliciesByApparatus,
      queueStatesByApparatus: _queueStatesByApparatus,
      stageStatesByOrderId: _stageStatesByOrderId,
      queueActionControlsByApparatus: _queueActionControlsByApparatus,
      orderStatusesByOrderId: _orderStatusesByOrderId,
      workerMode: widget.workerMode,
      orderControlsByOrderId: _orderControlsByOrderId,
      excludeFrozen: widget.workerMode,
      query: _searchQuery,
    );
  }

  bool _isWorkerOrderFrozen(String orderId) => _workerOrderIsFrozen(
    orderId: orderId,
    orderControlsByOrderId: _orderControlsByOrderId,
    queueStatesByApparatus: _queueStatesByApparatus,
    queueActionControlsByApparatus: _queueActionControlsByApparatus,
    orderStatusesByOrderId: _orderStatusesByOrderId,
  );
}
