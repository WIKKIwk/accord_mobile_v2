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
        final wasLoading = _loading;
        // A transient live-stream disconnect does not invalidate the last
        // successfully loaded queue snapshot. The REST refresh below is the
        // fallback authority and will surface a warning only if that snapshot
        // request also fails or violates its contract.
        await _refreshLive(initial: wasLoading);
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
    _queueSnapshotGeneration++;
    final orders = _productionMapZakazOrders(snapshot.maps);
    _updateScreenState(() {
      _orders = orders;
      _replaceQueueSnapshotMaps(
        sequences: snapshot.sequences,
        visibleOrderIds: snapshot.visibleOrderIds,
        queueStates: snapshot.queueStates,
        queuePolicies: snapshot.queuePolicies,
        queueActionControls: snapshot.queueActionControls,
        orderControls: snapshot.orderControls,
        orderCustomers: snapshot.orderCustomers,
        orderStatuses: snapshot.orderStatuses,
        frozenOrdersByApparatus: snapshot.frozenOrdersByApparatus,
      );
      _completedWorkerOrders = snapshot.completedOrders;
      _workerCompletedHistoryError = false;
      _workerCompletedHistoryErrorMessage = null;
      _completionRequests = snapshot.completionRequests;
      _loading = false;
      if (_queueSnapshotContractError) {
        _queueSnapshotContractError = false;
        _queueSnapshotErrorMessage = null;
        _loadError = null;
      }
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
      _queueSnapshotRefreshQueued = true;
      return;
    }
    _queueSnapshotRefreshInFlight = true;
    final requestGeneration = ++_queueSnapshotGeneration;
    try {
      final queueSnapshot = await _loadQueueSnapshot();
      if (!mounted || requestGeneration != _queueSnapshotGeneration) {
        return;
      }
      if (!_queueSnapshotChanged(
        snapshot: queueSnapshot,
        sequenceByApparatus: _sequenceByApparatus,
        visibleOrderIdsByApparatus: _visibleOrderIdsByApparatus,
        queueStatesByApparatus: _queueStatesByApparatus,
        queuePoliciesByApparatus: _queuePoliciesByApparatus,
        queueActionControlsByApparatus: _queueActionControlsByApparatus,
        orderControlsByOrderId: _orderControlsByOrderId,
        orderCustomersByOrderId: _customerByMapId,
        orderStatusesByOrderId: _orderStatusesByOrderId,
        qolipOrderNotesByOrderId: _qolipOrderNotesByOrderId,
        frozenOrdersByApparatus: _frozenOrdersByApparatus,
      )) {
        if (_queueSnapshotContractError) {
          _updateScreenState(() {
            _queueSnapshotContractError = false;
            _queueSnapshotErrorMessage = null;
          });
        }
        return;
      }
      _updateScreenState(() {
        _replaceQueueSnapshotMaps(
          sequences: queueSnapshot.sequences,
          visibleOrderIds: queueSnapshot.visibleOrderIds,
          queueStates: queueSnapshot.queueStates,
          queuePolicies: queueSnapshot.queuePolicies,
          queueActionControls: queueSnapshot.queueActionControls,
          orderControls: queueSnapshot.orderControls,
          orderCustomers: queueSnapshot.orderCustomers,
          orderStatuses: queueSnapshot.orderStatuses,
          qolipOrderNotes: queueSnapshot.qolipOrderNotes,
          frozenOrdersByApparatus: queueSnapshot.frozenOrdersByApparatus,
        );
        if (_queueSnapshotContractError) {
          _queueSnapshotContractError = false;
          _queueSnapshotErrorMessage = null;
        }
      });
    } catch (error) {
      if (mounted && requestGeneration == _queueSnapshotGeneration) {
        _invalidateQueueSnapshotContract(
          error is MobileApiException
              ? error.message
              : context.l10n.productionText('worker.error.sync'),
        );
      }
      return;
    } finally {
      _queueSnapshotRefreshInFlight = false;
      if (_queueSnapshotRefreshQueued && mounted) {
        _queueSnapshotRefreshQueued = false;
        unawaited(_refreshQueueSnapshot());
      }
    }
  }

  void _invalidateQueueSnapshotContract(String message) {
    _queueSnapshotGeneration++;
    if (!mounted) {
      return;
    }
    _updateScreenState(() {
      _replaceQueueSnapshotMaps(
        sequences: const {},
        visibleOrderIds: const {},
        queueStates: const {},
        queuePolicies: const {},
        queueActionControls: const {},
        orderControls: const {},
        orderCustomers: const {},
        orderStatuses: const {},
        qolipOrderNotes: const {},
        frozenOrdersByApparatus: const {},
      );
      _queueSnapshotContractError = true;
      _queueSnapshotErrorMessage ??= message;
      _loading = false;
    });
  }

  void _replaceQueueSnapshotMaps({
    required Map<String, List<String>> sequences,
    required Map<String, List<String>> visibleOrderIds,
    required Map<String, Map<String, String>> queueStates,
    required Map<String, AdminApparatusQueuePolicy> queuePolicies,
    required Map<String, Map<String, AdminApparatusQueueOrderActionControl>>
        queueActionControls,
    required Map<String, AdminOrderControlState> orderControls,
    required Map<String, String> orderCustomers,
    required Map<String, AdminProductionOrderStatusDetail> orderStatuses,
    required Map<String, List<AdminFrozenQueueOrder>> frozenOrdersByApparatus,
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
    _queueActionControlsByApparatus
      ..clear()
      ..addAll(queueActionControls);
    _frozenOrdersByApparatus
      ..clear()
      ..addAll(frozenOrdersByApparatus);
    _orderControlsByOrderId
      ..clear()
      ..addAll(orderControls);
    _customerByMapId = {...orderCustomers};
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
        _workerCompletedHistoryError = false;
        _workerCompletedHistoryErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _updateScreenState(() {
        _workerCompletedHistoryError = true;
        _workerCompletedHistoryErrorMessage = error is MobileApiException
            ? error.message
            : context.l10n.productionText('worker.error.sync');
      });
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
