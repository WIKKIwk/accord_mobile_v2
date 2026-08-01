part of 'admin_production_map_orders_screen.dart';

extension _AdminProductionMapOrdersLiveState
    on _AdminProductionMapOrdersScreenState {
  Future<void> _startWorkerLive() async {
    await _loadWorkerApparatus();
    if (!mounted) {
      return;
    }
    if (await TestModeController.instance.isEnabled()) {
      await _refreshLive(initial: true);
      return;
    }
    _stopWorkerLiveStream();
    _liveStreamGeneration++;
    unawaited(_runWorkerLiveStream(_liveStreamGeneration));
  }

  Future<void> _startAdminLive() async {
    await _refreshLive(initial: true);
    if (!mounted) {
      return;
    }
    _startQueueSnapshotPolling();
    if (await TestModeController.instance.isEnabled()) {
      return;
    }
    _stopWorkerLiveStream();
    _liveStreamGeneration++;
    unawaited(_runWorkerLiveStream(_liveStreamGeneration));
  }

  void _startQueueSnapshotPolling() {
    _queueSnapshotPollTimer?.cancel();
    _queueSnapshotPollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) {
        if (!mounted || _queueSnapshotRefreshInFlight) {
          return;
        }
        unawaited(_refreshQueueSnapshot());
      },
    );
  }

  void _stopWorkerLiveStream() {
    _liveStreamGeneration++;
    final subscription = _liveStreamSubscription;
    _liveStreamSubscription = null;
    unawaited(subscription?.cancel());
  }

  Future<void> _runWorkerLiveStream(int generation) async {
    while (mounted && generation == _liveStreamGeneration) {
      try {
        await _connectWorkerLiveStreamOnce(generation);
      } catch (_) {
        if (!mounted || generation != _liveStreamGeneration) {
          return;
        }
        await _refreshLive(initial: _loading);
      }
      if (!mounted || generation != _liveStreamGeneration) {
        return;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _connectWorkerLiveStreamOnce(int generation) async {
    final completer = Completer<void>();
    await _liveStreamSubscription?.cancel();
    _liveStreamSubscription =
        MobileApi.instance.adminProductionMapLiveEvents().listen(
      (snapshot) {
        if (!mounted || generation != _liveStreamGeneration) {
          return;
        }
        _applyWorkerLiveSnapshot(snapshot);
      },
      onError: (error, _) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      cancelOnError: true,
    );
    await completer.future;
  }

  Future<void> _loadWorkerApparatus() async {
    final apparatus = await _loadProductionMapApparatus();
    if (!mounted) {
      return;
    }
    if (widget.workerMode &&
        _workerWatchTabCount(apparatus) != _tabController.length) {
      _recreateWorkerTabController(apparatus);
    }
    _updateScreenState(() {
      _apparatus = apparatus;
    });
  }

  void _applyWorkerLiveSnapshot(AdminProductionMapLiveSnapshot snapshot) {
    final orders = _productionMapZakazOrders(snapshot.maps);
    _updateScreenState(() {
      _orders = orders;
      _replaceQueueSnapshotMaps(
        sequences: snapshot.sequences,
        visibleOrderIds: snapshot.visibleOrderIds,
        queueStates: snapshot.queueStates,
        queuePolicies: snapshot.queuePolicies,
        orderControls: snapshot.orderControls,
        orderCustomers: snapshot.orderCustomers,
        orderStatuses: snapshot.orderStatuses,
      );
      _completedWorkerOrders = snapshot.completedOrders;
      _completionRequests = snapshot.completionRequests;
      _loading = false;
    });
    _showNewRejectedCompletionDecisionNotices(
      snapshot.completionRequestDecisions,
    );
  }

  Future<void> _refreshLive({bool initial = false}) async {
    if (_liveRefreshInFlight) {
      _liveRefreshQueued = true;
      return;
    }
    _liveRefreshInFlight = true;
    var runInitial = initial;
    try {
      while (mounted) {
        _liveRefreshQueued = false;
        await _refreshLiveBatch(initial: runInitial);
        if (!_liveRefreshQueued) {
          return;
        }
        runInitial = false;
      }
    } finally {
      _liveRefreshInFlight = false;
    }
  }

  Future<void> _refreshLiveBatch({required bool initial}) {
    return widget.workerMode
        ? _refreshWorkerLiveBatch(initial: initial)
        : _refreshAdminLiveBatch(initial: initial);
  }

  Future<void> _refreshWorkerLiveBatch({required bool initial}) async {
    await _refreshMapsAndApparatus(initial: initial);
    await _refreshQueueSnapshot();
    await _refreshWorkerCompletedOrders();
    await _refreshWorkerCompletionRequestDecisions();
  }

  Future<void> _refreshAdminLiveBatch({required bool initial}) async {
    if (widget.supplyViewerMode) {
      if (initial) {
        await _refreshMapsAndApparatus(initial: true);
        await _refreshQueueSnapshot();
        return;
      }
      await Future.wait([
        _refreshMapsAndApparatus(),
        _refreshQueueSnapshot(),
      ]);
      return;
    }
    if (initial) {
      await _refreshMapsAndApparatus(initial: initial);
      await _refreshQueueSnapshot();
      await Future.wait([
        _refreshCompletionRequests(),
        _refreshClosedOrders(),
        _refreshWorkflowAudit(force: true),
      ]);
      return;
    }
    await Future.wait([
      _refreshMapsAndApparatus(initial: initial),
      _refreshQueueSnapshot(),
      _refreshCompletionRequests(),
      _refreshClosedOrders(),
    ]);
  }

  Future<void> _refreshQueueSnapshot() async {
    if (_queueSnapshotRefreshInFlight) {
      return;
    }
    _queueSnapshotRefreshInFlight = true;
    try {
      final queueSnapshot = await _loadQueueSnapshot();
      if (!mounted) {
        return;
      }
      if (!_queueSnapshotChanged(
        snapshot: queueSnapshot,
        sequenceByApparatus: _sequenceByApparatus,
        visibleOrderIdsByApparatus: _visibleOrderIdsByApparatus,
        queueStatesByApparatus: _queueStatesByApparatus,
        queuePoliciesByApparatus: _queuePoliciesByApparatus,
        orderControlsByOrderId: _orderControlsByOrderId,
        orderCustomersByOrderId: _customerByMapId,
        orderStatusesByOrderId: _orderStatusesByOrderId,
        qolipOrderNotesByOrderId: _qolipOrderNotesByOrderId,
      )) {
        return;
      }
      _updateScreenState(() {
        _replaceQueueSnapshotMaps(
          sequences: queueSnapshot.sequences,
          visibleOrderIds: queueSnapshot.visibleOrderIds,
          queueStates: queueSnapshot.queueStates,
          queuePolicies: queueSnapshot.queuePolicies,
          orderControls: queueSnapshot.orderControls,
          orderCustomers: queueSnapshot.orderCustomers,
          orderStatuses: queueSnapshot.orderStatuses,
          qolipOrderNotes: queueSnapshot.qolipOrderNotes,
        );
      });
    } catch (error) {
      if (error is MobileApiException &&
          error.code == 'production_map_visible_order_ids_missing' &&
          mounted) {
        _updateScreenState(() {
          _loading = false;
          _loadError = error.message;
        });
      }
      return;
    } finally {
      _queueSnapshotRefreshInFlight = false;
    }
  }

  void _replaceQueueSnapshotMaps({
    required Map<String, List<String>> sequences,
    required Map<String, List<String>> visibleOrderIds,
    required Map<String, Map<String, String>> queueStates,
    required Map<String, AdminApparatusQueuePolicy> queuePolicies,
    required Map<String, AdminOrderControlState> orderControls,
    required Map<String, String> orderCustomers,
    required Map<String, AdminProductionOrderStatusDetail> orderStatuses,
    Map<String, AdminQolipOrderNote>? qolipOrderNotes,
  }) {
    _sequenceByApparatus
      ..clear()
      ..addAll(sequences);
    _visibleOrderIdsByApparatus
      ..clear()
      ..addAll(visibleOrderIds);
    _queueStatesByApparatus
      ..clear()
      ..addAll(queueStates);
    _queuePoliciesByApparatus
      ..clear()
      ..addAll(queuePolicies);
    _orderControlsByOrderId
      ..clear()
      ..addAll(orderControls);
    _customerByMapId = {
      ..._customerByMapId,
      ...orderCustomers,
    };
    _orderStatusesByOrderId
      ..clear()
      ..addAll(orderStatuses);
    if (qolipOrderNotes != null) {
      _qolipOrderNotesByOrderId
        ..clear()
        ..addAll(qolipOrderNotes);
    }
  }

  Future<void> _refreshWorkerCompletedOrders() async {
    if (!_shouldRefreshWorkerOnlyData(widget.workerMode)) {
      return;
    }
    try {
      final completed = await _loadCompletedProductionMapOrders();
      if (!mounted) {
        return;
      }
      _updateScreenState(() {
        _completedWorkerOrders = completed;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshWorkerCompletionRequestDecisions() async {
    if (!_shouldRefreshWorkerOnlyData(widget.workerMode)) {
      return;
    }
    try {
      final decisions = await _loadProductionMapCompletionRequestDecisions();
      if (!mounted) {
        return;
      }
      _showNewRejectedCompletionDecisionNotices(decisions);
    } catch (_) {
      return;
    }
  }

  void _showNewRejectedCompletionDecisionNotices(
    List<AdminCompletionRequestDecisionNotification> decisions,
  ) {
    if (!widget.workerMode) {
      return;
    }
    final newRejectedDecisions = _newRejectedCompletionRequestDecisions(
      decisions: decisions,
      shownDecisionIds: _shownCompletionDecisionIds,
    );
    for (final decision in newRejectedDecisions) {
      _shownCompletionDecisionIds.add(decision.eventId.trim());
      showAdminTopNotice(
        context,
        _completionRejectedNoticeText(decision),
      );
    }
  }

  Future<void> _refreshClosedOrders() async {
    if (!_shouldRefreshAdminOnlyData(widget.workerMode)) {
      return;
    }
    try {
      final closed = await _loadClosedProductionMapOrders();
      if (!mounted) {
        return;
      }
      _updateScreenState(() {
        _closedOrders = closed;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshCompletionRequests() async {
    if (!_shouldRefreshAdminOnlyData(widget.workerMode)) {
      return;
    }
    try {
      final requests = await _loadProductionMapCompletionRequests();
      if (!mounted) {
        return;
      }
      _updateScreenState(() {
        _completionRequests = requests;
      });
    } catch (_) {
      return;
    }
  }

  Future<void> _refreshWorkflowAudit({bool force = false}) async {
    if (_workflowAuditLoading ||
        (!force && _workflowAudit != null && _workflowAuditError == null)) {
      return;
    }
    _workflowAuditLoading = true;
    if (mounted) {
      _updateScreenState(() {
        _workflowAuditError = null;
      });
    }
    try {
      final report = await MobileApi.instance.adminProductionMapAudit();
      if (!mounted) {
        return;
      }
      _updateScreenState(() {
        _workflowAudit = report;
        _workflowAuditError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _updateScreenState(() {
        _workflowAuditError = error is MobileApiException
            ? error.message
            : 'Ish jarayoni tekshiruvi yuklanmadi';
      });
    } finally {
      _workflowAuditLoading = false;
      if (mounted) {
        _updateScreenState(() {});
      }
    }
  }

  Future<void> _refreshMapsAndApparatus({bool initial = false}) async {
    if (!initial && _mapsRefreshInFlight) {
      return;
    }
    if (!initial) {
      _mapsRefreshInFlight = true;
    }
    try {
      final loaded = await _loadProductionMapOrdersAndApparatus();
      if (!mounted) {
        return;
      }
      final orders = loaded.orders;
      final apparatus = loaded.apparatus;
      if (!initial &&
          !_productionMapOrdersOrApparatusChanged(
            currentOrders: _orders,
            nextOrders: orders,
            currentApparatus: _apparatus,
            nextApparatus: apparatus,
          )) {
        return;
      }
      if (widget.workerMode &&
          (initial ||
              _workerWatchTabCount(apparatus) != _tabController.length)) {
        _recreateWorkerTabController(apparatus);
      }
      _applyLoadedProductionMapOrdersAndApparatus(
        orders: orders,
        apparatus: apparatus,
        initial: initial,
      );
      if (!widget.supplyViewerMode) {
        unawaited(_refreshOrderBaseMetraj(orders));
      }
    } catch (_) {
      if (mounted && initial) {
        _applyInitialProductionMapLoadError();
      }
    } finally {
      _mapsRefreshInFlight = false;
    }
  }

  void _applyLoadedProductionMapOrdersAndApparatus({
    required List<ProductionMapSaved> orders,
    required List<AdminApparatus> apparatus,
    required bool initial,
  }) {
    _updateScreenState(() {
      _loadError = null;
      _orders = orders;
      _apparatus = apparatus;
      if (!widget.workerMode) {
        _selectedApparatus ??= apparatus.isEmpty ? null : apparatus.first;
        _syncMoveApparatusDefaults(apparatus);
      }
      if (initial) {
        _loading = false;
      }
    });
  }

  void _applyInitialProductionMapLoadError() {
    _updateScreenState(() {
      _loading = false;
      _loadError = 'Reja menu yuklanmadi';
    });
  }

  Future<void> _refreshOrderBaseMetraj(List<ProductionMapSaved> orders) async {
    try {
      await CalculateOrderTemplateStore.instance.load(force: true);
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }
    final templates = CalculateOrderTemplateStore.instance.templates;
    final metrics = await _productionMapOrderMetrics(orders, templates);
    if (!mounted) {
      return;
    }
    _updateScreenState(() {
      _baseMetrajByMapId = metrics.baseMetrajByMapId;
      _orderKgByMapId = metrics.orderKgByMapId;
      _customerByMapId = {
        ...metrics.customerByMapId,
        ..._customerByMapId,
      };
    });
  }

  Future<void> _load() => _refreshLive(initial: true);
}
