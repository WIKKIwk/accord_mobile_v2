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
        // Keep the last good state on screen. Fall back to the canonical
        // REST snapshot (revision-guarded) instead of clearing the list.
        if (wasLoading) {
          await _refreshLive(initial: true);
        } else {
          await _refreshQueueSnapshot();
        }
      }
      if (!mounted || generation != _liveStreamGeneration) {
        return;
      }
      // Bounded exponential backoff: 1s -> 2s -> 4s -> 8s -> max 30s.
      // Reset to 1s on the next successful snapshot (see listener below).
      final delay = productionMapLiveReconnectDelay(_liveReconnectAttempt);
      _liveReconnectAttempt++;
      await Future.delayed(delay);
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
        // A fresh snapshot means the stream is healthy: reset backoff.
        _liveReconnectAttempt = 0;
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
    _applyCanonicalLiveSnapshot(snapshot);
  }

  void _applyCanonicalLiveSnapshot(AdminProductionMapLiveSnapshot snapshot) {
    final decision = canonicalSnapshotDecision(
      incomingRevision: snapshot.revision,
      lastAppliedRevision: _lastAppliedSnapshotRevision,
    );
    if (decision == _CanonicalSnapshotDecision.ignoreStale ||
        decision == _CanonicalSnapshotDecision.ignoreDuplicate) {
      if (_queueSnapshotContractError) {
        _updateScreenState(() {
          _queueSnapshotContractError = false;
          _queueSnapshotErrorMessage = null;
          _loadError = null;
        });
      }
      return;
    }
    final orders = _productionMapZakazOrders(snapshot.maps);
    if (decision == _CanonicalSnapshotDecision.applyLegacy) {
      // Legacy live payload without `rev`: only rebuild when content
      // actually changed to avoid duplicate rebuilds.
      if (_ordersRevision(orders) == _ordersRevision(_orders) &&
          !_queueSnapshotChanged(snapshot)) {
        return;
      }
    }
    _queueSnapshotGeneration++;
    if (decision != _CanonicalSnapshotDecision.applyLegacy) {
      _lastAppliedSnapshotRevision = snapshot.revision;
      _liveReconnectAttempt = 0;
    }
    _updateScreenState(() {
      _orders = orders;
      _replaceQueueSnapshotMaps(snapshot);
      _completedWorkerOrders = snapshot.completedOrders;
      _workerCompletedHistoryError = false;
      _workerCompletedHistoryErrorMessage = null;
      _completionRequests = snapshot.completionRequests;
      _completionRequestsErrorMessage = null;
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
    if (initial) {
      // Canonical cold load: one atomic snapshot+apparatus apply, no partial UI.
      await _refreshCanonicalInitial();
      await _refreshWorkerCompletedOrders();
      await _refreshWorkerCompletionRequestDecisions();
      return;
    }
    // Background refresh: orders only via the revisioned snapshot authority
    // (avoids REST/live race). Apparatus catalog refreshes separately.
    // Legacy backends without `rev` still need the old maps endpoint.
    await Future.wait([
      _refreshQueueSnapshot(),
      _refreshApparatusCatalog(),
    ]);
    if (_lastAppliedSnapshotRevision == null) {
      await _refreshMapsAndApparatus();
    }
    await _refreshWorkerCompletedOrders();
    await _refreshWorkerCompletionRequestDecisions();
  }

  Future<void> _refreshAdminLiveBatch({required bool initial}) async {
    if (widget.supplyViewerMode) {
      if (initial) {
        await _refreshCanonicalInitial();
        return;
      }
      await Future.wait([
        _refreshQueueSnapshot(),
        _refreshApparatusCatalog(),
      ]);
      if (_lastAppliedSnapshotRevision == null) {
        await _refreshMapsAndApparatus();
      }
      return;
    }
    if (initial) {
      await _refreshCanonicalInitial();
      await Future.wait([
        _refreshCompletionRequests(),
        _refreshClosedOrders(),
        _refreshWorkflowAudit(force: true),
      ]);
      return;
    }
    await Future.wait([
      _refreshQueueSnapshot(),
      _refreshApparatusCatalog(),
      _refreshCompletionRequests(),
      _refreshClosedOrders(),
    ]);
    if (_lastAppliedSnapshotRevision == null) {
      await _refreshMapsAndApparatus();
    }
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
      // Revision guard: stale/duplicate REST snapshots must not rewrite UI.
      final decision = canonicalSnapshotDecision(
        incomingRevision: queueSnapshot.revision,
        lastAppliedRevision: _lastAppliedSnapshotRevision,
      );
      if (decision == _CanonicalSnapshotDecision.ignoreStale ||
          decision == _CanonicalSnapshotDecision.ignoreDuplicate) {
        // Successful fetch still clears a previous transient warning.
        if (_queueSnapshotContractError) {
          _updateScreenState(() {
            _queueSnapshotContractError = false;
            _queueSnapshotErrorMessage = null;
          });
        }
        return;
      }
      if (decision == _CanonicalSnapshotDecision.apply) {
        // New canonical revision: apply atomically, including orders when
        // the snapshot bundles maps (new backend).
        _lastAppliedSnapshotRevision = queueSnapshot.revision;
        _liveReconnectAttempt = 0;
        final hasMaps = queueSnapshot.maps.isNotEmpty;
        final nextOrders =
            hasMaps ? _productionMapZakazOrders(queueSnapshot.maps) : null;
        _updateScreenState(() {
          if (nextOrders != null) {
            _orders = nextOrders;
          }
          _replaceQueueSnapshotMaps(queueSnapshot);
          if (_queueSnapshotContractError) {
            _queueSnapshotContractError = false;
            _queueSnapshotErrorMessage = null;
          }
        });
        return;
      }
      // Legacy (no rev): fall back to content comparison to avoid rebuilds.
      if (!_queueSnapshotChanged(queueSnapshot)) {
        if (_queueSnapshotContractError) {
          _updateScreenState(() {
            _queueSnapshotContractError = false;
            _queueSnapshotErrorMessage = null;
          });
        }
        return;
      }
      _updateScreenState(() {
        _replaceQueueSnapshotMaps(queueSnapshot);
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
    // Keep the last good state on screen (no list wipe, no loading spinner).
    // Only surface the warning; a newer canonical snapshot will recover.
    _updateScreenState(() {
      _queueSnapshotContractError = true;
      _queueSnapshotErrorMessage ??= message;
      _loading = false;
    });
  }

  bool _queueSnapshotChanged(AdminApparatusQueueSnapshot snapshot) {
    if (_sequenceByApparatus.length != snapshot.sequences.length ||
        _visibleOrderIdsByApparatus.length != snapshot.visibleOrderIds.length ||
        _queueStatesByApparatus.length != snapshot.queueStates.length ||
        _stageStatesByOrderId.length != snapshot.stageStates.length ||
        _queuePoliciesByApparatus.length != snapshot.queuePolicies.length ||
        _queueActionControlsByApparatus.length !=
            snapshot.queueActionControls.length ||
        _orderControlsByOrderId.length != snapshot.orderControls.length ||
        _customerByMapId.length != snapshot.orderCustomers.length ||
        _orderStatusesByOrderId.length != snapshot.orderStatuses.length ||
        _frozenOrdersByApparatus.length !=
            snapshot.frozenOrdersByApparatus.length) {
      return true;
    }
    for (final entry in snapshot.sequences.entries) {
      final current = _sequenceByApparatus[entry.key];
      if (current == null ||
          current.length != entry.value.length ||
          !_stringListsEqual(current, entry.value)) {
        return true;
      }
    }
    for (final entry in snapshot.visibleOrderIds.entries) {
      final current = _visibleOrderIdsByApparatus[entry.key];
      if (current == null ||
          current.length != entry.value.length ||
          !_stringListsEqual(current, entry.value)) {
        return true;
      }
    }
    for (final entry in snapshot.queueStates.entries) {
      final current = _queueStatesByApparatus[entry.key];
      if (current == null || !_stringMapsEqual(current, entry.value)) {
        return true;
      }
    }
    for (final entry in snapshot.stageStates.entries) {
      final current = _stageStatesByOrderId[entry.key];
      if (current == null || !_stringMapsEqual(current, entry.value)) {
        return true;
      }
    }
    for (final entry in snapshot.queuePolicies.entries) {
      final current = _queuePoliciesByApparatus[entry.key];
      if (current == null ||
          current.policy != entry.value.policy ||
          current.locked != entry.value.locked) {
        return true;
      }
    }
    for (final entry in snapshot.queueActionControls.entries) {
      final current = _queueActionControlsByApparatus[entry.key];
      if (current == null || !_queueActionControlsEqual(current, entry.value)) {
        return true;
      }
    }
    for (final entry in snapshot.orderControls.entries) {
      if (_orderControlsByOrderId[entry.key] != entry.value) {
        return true;
      }
    }
    for (final entry in snapshot.orderCustomers.entries) {
      if (_customerByMapId[entry.key] != entry.value) {
        return true;
      }
    }
    for (final entry in snapshot.orderStatuses.entries) {
      final current = _orderStatusesByOrderId[entry.key];
      if (current == null ||
          current.orderStatus != entry.value.orderStatus ||
          current.completedWithIssueCount !=
              entry.value.completedWithIssueCount) {
        return true;
      }
    }
    for (final entry in snapshot.frozenOrdersByApparatus.entries) {
      final current = _frozenOrdersByApparatus[entry.key];
      if (current == null || !_frozenOrdersEqual(current, entry.value)) {
        return true;
      }
    }
    return false;
  }

  void _replaceQueueSnapshotMaps(AdminApparatusQueueSnapshot snapshot) {
    _sequenceByApparatus
      ..clear()
      ..addAll(snapshot.sequences);
    _visibleOrderIdsByApparatus
      ..clear()
      ..addAll(snapshot.visibleOrderIds);
    _queueStatesByApparatus
      ..clear()
      ..addAll(snapshot.queueStates);
    _stageStatesByOrderId
      ..clear()
      ..addAll(snapshot.stageStates);
    _queuePoliciesByApparatus
      ..clear()
      ..addAll(snapshot.queuePolicies);
    _queueActionControlsByApparatus
      ..clear()
      ..addAll(snapshot.queueActionControls);
    _frozenOrdersByApparatus
      ..clear()
      ..addAll(snapshot.frozenOrdersByApparatus);
    _orderControlsByOrderId
      ..clear()
      ..addAll(snapshot.orderControls);
    _customerByMapId = {...snapshot.orderCustomers};
    _orderStatusesByOrderId
      ..clear()
      ..addAll(snapshot.orderStatuses);
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
      final loader =
          widget.closedOrdersLoader ?? _loadClosedProductionMapOrders;
      final closed = await loader();
      if (!mounted) {
        return;
      }
      _updateScreenState(() {
        _closedOrders = closed;
        _closedOrdersErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _updateScreenState(() {
        _closedOrdersErrorMessage =
            error is MobileApiException && error.message.trim().isNotEmpty
                ? error.message
                : 'Yopilgan orderlar yuklanmadi';
      });
    }
  }

  Future<void> _refreshCompletionRequests() async {
    if (!_shouldRefreshAdminOnlyData(widget.workerMode)) {
      return;
    }
    try {
      final loader = widget.completionRequestsLoader ??
          _loadProductionMapCompletionRequests;
      final requests = await loader();
      if (!mounted) {
        return;
      }
      _updateScreenState(() {
        _completionRequests = requests;
        _completionRequestsErrorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      _updateScreenState(() {
        _completionRequestsErrorMessage =
            error is MobileApiException && error.message.trim().isNotEmpty
                ? error.message
                : 'Tugatish so‘rovlari yuklanmadi';
      });
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
    // Legacy path kept for compatibility. Initial loads must use
    // [_refreshCanonicalInitial] (parallel snapshot + apparatus, single
    // atomic apply) to avoid title/subtitle flicker.
    if (initial) {
      await _refreshCanonicalInitial();
      return;
    }
    if (_mapsRefreshInFlight) {
      return;
    }
    _mapsRefreshInFlight = true;
    try {
      final loaded = await _loadProductionMapOrdersAndApparatus();
      if (!mounted) {
        return;
      }
      final orders = loaded.orders;
      final apparatus = loaded.apparatus;
      if (!_productionMapOrdersOrApparatusChanged(
        currentOrders: _orders,
        nextOrders: orders,
        currentApparatus: _apparatus,
        nextApparatus: apparatus,
      )) {
        return;
      }
      if (widget.workerMode &&
          _workerWatchTabCount(apparatus) != _tabController.length) {
        _recreateWorkerTabController(apparatus);
      }
      _applyLoadedProductionMapOrdersAndApparatus(
        orders: orders,
        apparatus: apparatus,
        initial: false,
      );
      if (!widget.supplyViewerMode) {
        unawaited(_refreshOrderBaseMetraj(orders));
      }
    } catch (_) {
      // Background refreshes keep the last good state on screen.
    } finally {
      _mapsRefreshInFlight = false;
    }
  }

  /// Canonical cold-load: parallel snapshot + apparatus, one atomic apply.
  ///
  /// First non-loading frame already carries the final title/subtitle.
  /// Legacy backends without `maps` fall back to a single
  /// `adminProductionMaps()` fetch, still applied in one transaction.
  Future<void> _refreshCanonicalInitial() async {
    try {
      final results = await Future.wait<Object>([
        _loadQueueSnapshot(),
        _loadProductionMapApparatus(),
      ]);
      final queueSnapshot = results[0] as AdminApparatusQueueSnapshot;
      final apparatus = results[1] as List<AdminApparatus>;
      List<ProductionMapSaved> orders;
      if (queueSnapshot.maps.isNotEmpty) {
        orders = _productionMapZakazOrders(queueSnapshot.maps);
      } else {
        final legacyMaps = await MobileApi.instance.adminProductionMaps();
        if (!mounted) return;
        orders = _productionMapZakazOrders(legacyMaps);
      }
      if (!mounted) {
        return;
      }
      // If a live snapshot already applied a newer revision, do not let an
      // older REST response overwrite it.
      final decision = canonicalSnapshotDecision(
        incomingRevision: queueSnapshot.revision,
        lastAppliedRevision: _lastAppliedSnapshotRevision,
      );
      if ((decision == _CanonicalSnapshotDecision.ignoreStale ||
              decision == _CanonicalSnapshotDecision.ignoreDuplicate) &&
          _orders.isNotEmpty) {
        return;
      }
      if (queueSnapshot.revision != null) {
        _lastAppliedSnapshotRevision = queueSnapshot.revision;
      }
      _liveReconnectAttempt = 0;
      if (widget.workerMode &&
          _workerWatchTabCount(apparatus) != _tabController.length) {
        _recreateWorkerTabController(apparatus);
      }
      _updateScreenState(() {
        _loadError = null;
        _orders = orders;
        _apparatus = apparatus;
        _replaceQueueSnapshotMaps(queueSnapshot);
        if (!widget.workerMode) {
          _syncSelectedSequenceApparatus(apparatus);
          _syncMoveApparatusDefaults(apparatus);
        }
        _loading = false;
        _loadError = null;
        if (_queueSnapshotContractError) {
          _queueSnapshotContractError = false;
          _queueSnapshotErrorMessage = null;
        }
      });
      if (!widget.supplyViewerMode) {
        unawaited(_refreshOrderBaseMetraj(orders));
      }
    } catch (_) {
      if (mounted) {
        _applyInitialProductionMapLoadError();
      }
    }
  }

  /// Background apparatus refresh without touching `_orders`.
  /// Orders arrive only via the revisioned queue/live snapshot authority.
  Future<void> _refreshApparatusCatalog() async {
    try {
      final apparatus = await _loadProductionMapApparatus();
      if (!mounted) return;
      if (_apparatusListsHaveSameCanonicalRevisions(_apparatus, apparatus)) {
        return;
      }
      if (widget.workerMode &&
          _workerWatchTabCount(apparatus) != _tabController.length) {
        _recreateWorkerTabController(apparatus);
      }
      _updateScreenState(() {
        _apparatus = apparatus;
        if (!widget.workerMode) {
          _syncSelectedSequenceApparatus(apparatus);
          _syncMoveApparatusDefaults(apparatus);
        }
      });
    } catch (_) {
      // Keep last good catalog on failure.
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
        _syncSelectedSequenceApparatus(apparatus);
        _syncMoveApparatusDefaults(apparatus);
      }
      if (initial) {
        _loading = false;
      }
    });
  }

  Future<void> _restoreSavedSequenceApparatusPreference() async {
    await AdminSequenceApparatusStore.instance.loadSavedApparatusId();
    if (!mounted || widget.workerMode || _userChangedSequenceApparatus) {
      return;
    }
    if (_apparatus.isNotEmpty) {
      _updateScreenState(() {
        _syncSelectedSequenceApparatus(_apparatus, forceRemembered: true);
      });
    }
  }

  void _syncSelectedSequenceApparatus(
    List<AdminApparatus> apparatus, {
    bool forceRemembered = false,
  }) {
    if (apparatus.isEmpty) {
      _selectedApparatus = null;
      return;
    }

    final current = _selectedApparatus;
    final currentInList = current == null
        ? null
        : AdminSequenceApparatusStore.instance.resolveApparatus(
            apparatus,
            id: current.id,
            name: current.name,
          );

    final remembered = AdminSequenceApparatusStore.instance.resolveApparatus(
      apparatus,
    );

    if (_userChangedSequenceApparatus && currentInList != null) {
      _selectedApparatus = currentInList;
      return;
    }

    if (forceRemembered && remembered != null) {
      _selectedApparatus = remembered;
      return;
    }

    if (currentInList != null) {
      _selectedApparatus = currentInList;
    } else if (remembered != null) {
      _selectedApparatus = remembered;
    } else {
      _selectedApparatus = apparatus.first;
    }
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
    // Canonical customer authority is snapshot.orderCustomers with
    // map.customerName fallback. Template-derived customers must never
    // rewrite the card subtitle (would cause a delayed label flicker), so
    // only metraj/kg are applied here.
    _updateScreenState(() {
      _baseMetrajByMapId = metrics.baseMetrajByMapId;
      _orderKgByMapId = metrics.orderKgByMapId;
    });
  }

  Future<void> _load() => _refreshLive(initial: true);
}
