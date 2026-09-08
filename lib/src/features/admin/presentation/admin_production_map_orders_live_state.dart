part of 'admin_production_map_orders_screen.dart';

extension _AdminProductionMapOrdersLiveState
    on _AdminProductionMapOrdersScreenState {
  void _scheduleWorkerRecovery() {
    if (!_workerRetryAllowed) {
      _workerRecoveryTimer?.cancel();
      _workerRecoveryTimer = null;
      return;
    }
    if (!widget.workerMode || !mounted || !_workerForeground ||
        !_workerRetryAllowed || _workerRecoveryTimer != null) {
      return;
    }
    _workerRecoveryTimer = Timer(const Duration(seconds: 2), () {
      _workerRecoveryTimer = null;
      unawaited(_recoverWorkerOrders());
    });
  }

  Future<void> _recoverWorkerOrders() async {
    if (!mounted || !_workerForeground || !_workerRetryAllowed) return;
    // Initial/catalog failures need both reads, not a queue-only fallback.
    // This is read-only; queue actions are never replayed by recovery.
    await _refreshCanonicalInitial();
    if (!mounted || !_workerForeground) return;
    if (_loadError != null || _queueSnapshotContractError ||
        !_workerCatalogReady) {
      _scheduleWorkerRecovery();
    } else {
      await _restartWorkerLiveStream();
    }
  }

  void _clearOrdersLoadError() {
    if (widget.workerMode && !_workerCatalogReady) return;
    _workerRecoveryTimer?.cancel();
    _workerRecoveryTimer = null;
    _workerRetryAllowed = true;
    _loading = false;
    _loadError = null;
    _queueSnapshotContractError = false;
    _queueSnapshotErrorMessage = null;
  }

  bool _canRetryWorkerRead(Object error) => error is! MobileApiException ||
      (error.statusCode != 401 && error.statusCode != 403 &&
          error.code != 'unauthorized' && error.code != 'forbidden' &&
          error.code != 'production_map_snapshot_contract_invalid');

  String _workerReadErrorText(Object error) => _canRetryWorkerRead(error)
      ? context.l10n.productionText('worker.connection.reconnecting')
      : error is MobileApiException
          ? error.message
          : context.l10n.productionText('worker.error.sync');

  Future<AdminApparatusQueueSnapshot> _readOrdersSnapshot({bool fresh = false}) {
    return widget.queueSnapshotLoader?.call() ??
        MobileApi.instance.adminProductionMapQueueSnapshot(fresh: fresh);
  }

  Future<List<AdminApparatus>> _readOrdersApparatus() =>
      widget.apparatusLoader?.call() ?? MobileApi.instance.adminApparatus(limit: 200);

  Future<void> _restartWorkerLiveStream() async {
    if (!_workerRetryAllowed) return;
    final generation = _liveStreamGeneration;
    if (widget.liveEventsLoader == null &&
        await TestModeController.instance.isEnabled()) {
      return;
    }
    if (!mounted || !_workerForeground || generation != _liveStreamGeneration) return;
    _stopWorkerLiveStream();
    unawaited(_runWorkerLiveStream(_liveStreamGeneration));
  }

  void _rememberSnapshotVersion(AdminApparatusQueueSnapshot snapshot) {
    if (snapshot.epoch.isNotEmpty && snapshot.epoch != _lastAppliedSnapshotEpoch) {
      if (_lastAppliedSnapshotEpoch.isNotEmpty) {
        _retiredSnapshotEpochs.add(_lastAppliedSnapshotEpoch);
      }
      _lastAppliedSnapshotEpoch = snapshot.epoch;
    }
    _lastAppliedSnapshotRevision = snapshot.revision;
  }

  Future<void> _startWorkerLive() async {
    // Drop the previous provider's stream before awaiting any REST request.
    _stopWorkerLiveStream();
    final generation = _liveStreamGeneration;
    // REST has bounded requests and a visible error state. Never leave the
    // first frame dependent on an unbounded/silent WebSocket handshake.
    await _refreshCanonicalInitial();
    if (!mounted || !_workerForeground || generation != _liveStreamGeneration) {
      return;
    }
    unawaited(_refreshWorkerCompletedOrders());
    unawaited(_refreshWorkerCompletionRequestDecisions());
    await _restartWorkerLiveStream();
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
    _liveReconnectTimer?.cancel();
    final reconnect = _liveReconnectFinished;
    if (reconnect != null && !reconnect.isCompleted) reconnect.complete();
    final finished = _liveStreamFinished;
    if (finished != null && !finished.isCompleted) finished.complete();
    final subscription = _liveStreamSubscription;
    _liveStreamSubscription = null;
    unawaited(subscription?.cancel());
  }

  Future<void> _runWorkerLiveStream(int generation) async {
    while (mounted && generation == _liveStreamGeneration) {
      Object? streamError;
      try {
        await _connectWorkerLiveStreamOnce(generation);
      } catch (error) {
        streamError = error;
        if (!mounted || generation != _liveStreamGeneration) {
          return;
        }
        final wasLoading = _loading;
        // Keep the last good state on screen. Fall back to the canonical
        // REST snapshot (revision-guarded) instead of clearing the list.
        if (!widget.workerMode && wasLoading) {
          await _refreshLive(initial: true);
        } else if (!widget.workerMode) {
          await _refreshQueueSnapshot();
        }
      }
      if (!mounted || generation != _liveStreamGeneration) {
        return;
      }
      if (widget.workerMode) {
        final error = streamError ?? const MobileApiException(
          code: 'live_closed', message: 'Live connection closed');
        _workerRetryAllowed = _canRetryWorkerRead(error);
        _invalidateQueueSnapshotContract(_workerReadErrorText(error));
        if (!_workerRetryAllowed) return;
      }
      // Workers retry at 1s -> 2s -> max 4s; admin keeps its 30s cap.
      // Reset to 1s on the next successful snapshot (see listener below).
      final delay = productionMapLiveReconnectDelay(
        widget.workerMode && _liveReconnectAttempt > 2 ? 2 : _liveReconnectAttempt);
      _liveReconnectAttempt++;
      final reconnect = Completer<void>();
      _liveReconnectFinished = reconnect;
      _liveReconnectTimer = Timer(delay, reconnect.complete);
      await reconnect.future;
    }
  }

  Future<void> _connectWorkerLiveStreamOnce(int generation) async {
    // Cancellation may wait for a dead native/socket handshake. It must not
    // prevent opening a connection on the newly available network.
    unawaited(_liveStreamSubscription?.cancel());
    if (!mounted || generation != _liveStreamGeneration) return;
    final completer = Completer<void>();
    _liveStreamFinished = completer;
    final firstSnapshotTimer = Timer(const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.completeError(TimeoutException('First production snapshot'));
      }
    });
    final subscription =
        (widget.liveEventsLoader?.call() ??
            MobileApi.instance.adminProductionMapLiveEvents()).listen(
      (snapshot) {
        if (!mounted || generation != _liveStreamGeneration) {
          return;
        }
        // A fresh snapshot means the stream is healthy: reset backoff.
        firstSnapshotTimer.cancel();
        _liveReconnectAttempt = 0;
        _applyCanonicalLiveSnapshot(snapshot);
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
      // Auto-cancel can await a dead native handshake before delivering the
      // error. Deliver it now, and cancel without awaiting cleanup below.
      cancelOnError: false,
    );
    _liveStreamSubscription = subscription;
    try {
      await completer.future;
    } finally {
      firstSnapshotTimer.cancel();
      if (identical(_liveStreamSubscription, subscription)) {
        _liveStreamSubscription = null;
      }
      unawaited(subscription.cancel());
      if (identical(_liveStreamFinished, completer)) _liveStreamFinished = null;
    }
  }

  void _applyCanonicalLiveSnapshot(AdminProductionMapLiveSnapshot snapshot) {
    final decision = canonicalSnapshotDecision(
      incomingRevision: snapshot.revision,
      lastAppliedRevision: _lastAppliedSnapshotRevision,
      incomingEpoch: snapshot.epoch,
      lastAppliedEpoch: _lastAppliedSnapshotEpoch,
      retiredEpochs: _retiredSnapshotEpochs,
    );
    if (decision == CanonicalSnapshotDecision.ignoreStale) return;
    if (decision == CanonicalSnapshotDecision.ignoreDuplicate &&
        !_queueSnapshotNeedsReconcile) {
      if (_queueSnapshotContractError || _loadError != null || _loading) {
        _updateScreenState(_clearOrdersLoadError);
      }
      return;
    }
    final orders = _productionMapZakazOrders(snapshot.maps);
    if (decision == CanonicalSnapshotDecision.applyLegacy) {
      // Legacy live payload without `rev`: only rebuild when content
      // actually changed to avoid duplicate rebuilds.
      if (_ordersRevision(orders) == _ordersRevision(_orders) &&
          !_queueSnapshotChanged(snapshot)) {
        if (_queueSnapshotContractError || _loadError != null || _loading) {
          _updateScreenState(_clearOrdersLoadError);
        }
        return;
      }
    }
    _queueSnapshotGeneration++;
    _queueSnapshotNeedsReconcile = false;
    if (decision != CanonicalSnapshotDecision.applyLegacy) {
      _rememberSnapshotVersion(snapshot);
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
      _clearOrdersLoadError();
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
      final queueSnapshot = await _readOrdersSnapshot();
      if (!mounted || requestGeneration != _queueSnapshotGeneration) {
        return;
      }
      // Revision guard: stale/duplicate REST snapshots must not rewrite UI.
      final decision = canonicalSnapshotDecision(
        incomingRevision: queueSnapshot.revision,
        lastAppliedRevision: _lastAppliedSnapshotRevision,
        incomingEpoch: queueSnapshot.epoch,
        lastAppliedEpoch: _lastAppliedSnapshotEpoch,
        retiredEpochs: _retiredSnapshotEpochs,
      );
      if (decision == CanonicalSnapshotDecision.ignoreStale) return;
      if (decision == CanonicalSnapshotDecision.ignoreDuplicate &&
          !_queueSnapshotNeedsReconcile) {
        // Successful fetch still clears a previous transient warning.
        if (_queueSnapshotContractError || _loadError != null || _loading) {
          _updateScreenState(_clearOrdersLoadError);
        }
        return;
      }
      if (decision == CanonicalSnapshotDecision.apply ||
          decision == CanonicalSnapshotDecision.ignoreDuplicate) {
        _queueSnapshotNeedsReconcile = false;
        // New canonical revision: apply atomically, including orders when
        // the snapshot bundles maps (new backend).
        _rememberSnapshotVersion(queueSnapshot);
        _liveReconnectAttempt = 0;
        final hasMaps = queueSnapshot.maps.isNotEmpty || queueSnapshot.epoch.isNotEmpty;
        final nextOrders =
            hasMaps ? _productionMapZakazOrders(queueSnapshot.maps) : null;
        _updateScreenState(() {
          if (nextOrders != null) {
            _orders = nextOrders;
          }
          _replaceQueueSnapshotMaps(queueSnapshot);
          _clearOrdersLoadError();
        });
        return;
      }
      // Legacy (no rev): fall back to content comparison to avoid rebuilds.
      if (!_queueSnapshotChanged(queueSnapshot)) {
        if (_queueSnapshotContractError || _loadError != null || _loading) {
          _updateScreenState(_clearOrdersLoadError);
        }
        return;
      }
      _updateScreenState(() {
        _replaceQueueSnapshotMaps(queueSnapshot);
        _clearOrdersLoadError();
      });
    } catch (error) {
      if (mounted && requestGeneration == _queueSnapshotGeneration) {
        if (widget.workerMode) _workerRetryAllowed = _canRetryWorkerRead(error);
        _invalidateQueueSnapshotContract(
          widget.workerMode ? _workerReadErrorText(error) : error is MobileApiException
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
    if (_queueSnapshotContractError && !_loading &&
        _queueSnapshotErrorMessage == message) {
      _scheduleWorkerRecovery();
      return;
    }
    // Keep the last good state on screen (no list wipe, no loading spinner).
    // Only surface the warning; a newer canonical snapshot will recover.
    _updateScreenState(() {
      _queueSnapshotContractError = true;
      _queueSnapshotErrorMessage = message;
      _loading = false;
    });
    _scheduleWorkerRecovery();
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
      if (!listEquals(current, entry.value)) {
        return true;
      }
    }
    for (final entry in snapshot.visibleOrderIds.entries) {
      final current = _visibleOrderIdsByApparatus[entry.key];
      if (!listEquals(current, entry.value)) {
        return true;
      }
    }
    for (final entry in snapshot.queueStates.entries) {
      final current = _queueStatesByApparatus[entry.key];
      if (!mapEquals(current, entry.value)) {
        return true;
      }
    }
    for (final entry in snapshot.stageStates.entries) {
      final current = _stageStatesByOrderId[entry.key];
      if (!mapEquals(current, entry.value)) {
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
    _workActivityByApparatus
      ..clear()
      ..addAll({
        for (final apparatus in snapshot.queueActionControls.entries)
          apparatus.key: {
            for (final order in apparatus.value.entries)
              if (order.value.workActivity != null)
                order.key: order.value.workActivity!,
          },
      });
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
    if (!widget.workerMode) {
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
    if (!widget.workerMode) {
      return;
    }
    try {
      final decisions = await MobileApi.instance
          .adminProductionMapCompletionRequestDecisions();
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
    if (widget.workerMode) {
      return;
    }
    try {
      final loader = widget.closedOrdersLoader ??
          MobileApi.instance.adminClosedProductionMapOrders;
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
    if (widget.workerMode) {
      return;
    }
    try {
      final loader = widget.completionRequestsLoader ??
          MobileApi.instance.adminProductionMapCompletionRequests;
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
  Future<void> _refreshCanonicalInitial() {
    return _initialRefresh ??= _refreshCanonicalInitialOnce().whenComplete(() {
      _initialRefresh = null;
    });
  }

  Future<void> _refreshCanonicalInitialOnce() async {
    try {
      final pending = Future.wait<Object>([
        _readOrdersSnapshot(fresh: widget.workerMode),
        _readOrdersApparatus(),
      ], eagerError: true);
      // Keep the API's existing download budget on weak factory networks.
      // Eager errors still recover immediately instead of waiting for siblings.
      final results = await (widget.workerMode
          ? pending.timeout(const Duration(seconds: 10)) : pending);
      final queueSnapshot = results[0] as AdminApparatusQueueSnapshot;
      final apparatus = results[1] as List<AdminApparatus>;
      List<ProductionMapSaved> orders;
      if (queueSnapshot.maps.isNotEmpty || queueSnapshot.epoch.isNotEmpty) {
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
        incomingEpoch: queueSnapshot.epoch,
        lastAppliedEpoch: _lastAppliedSnapshotEpoch,
        retiredEpochs: _retiredSnapshotEpochs,
      );
      if (decision == CanonicalSnapshotDecision.ignoreStale) {
        _scheduleWorkerRecovery();
        return;
      }
      if (decision == CanonicalSnapshotDecision.ignoreDuplicate &&
          !_queueSnapshotNeedsReconcile) {
        // A same-revision reply still proves recovery. Do not leave a resume
        // error covering valid rows, including a genuinely empty queue.
        if (widget.workerMode &&
            _workerWatchTabCount(apparatus) != _tabController.length) {
          _recreateWorkerTabController(apparatus);
        }
        _updateScreenState(() {
          _apparatus = apparatus;
          _workerCatalogReady = true;
          _clearOrdersLoadError();
        });
        return;
      }
      if (queueSnapshot.revision != null) {
        _rememberSnapshotVersion(queueSnapshot);
      }
      _liveReconnectAttempt = 0;
      if (widget.workerMode &&
          _workerWatchTabCount(apparatus) != _tabController.length) {
        _recreateWorkerTabController(apparatus);
      }
      _updateScreenState(() {
        _workerCatalogReady = true;
        _queueSnapshotNeedsReconcile = false;
        _loadError = null;
        _orders = orders;
        _apparatus = apparatus;
        _replaceQueueSnapshotMaps(queueSnapshot);
        if (!widget.workerMode) {
          _syncSelectedSequenceApparatus(apparatus);
          _syncMoveApparatusDefaults(apparatus);
        }
        _clearOrdersLoadError();
      });
      if (!widget.supplyViewerMode) {
        unawaited(_refreshOrderBaseMetraj(orders));
      }
    } catch (error) {
      if (mounted) {
        _applyInitialProductionMapLoadError(error);
      }
    }
  }

  /// Background apparatus refresh without touching `_orders`.
  /// Orders arrive only via the revisioned queue/live snapshot authority.
  Future<void> _refreshApparatusCatalog() async {
    try {
      final apparatus = await _readOrdersApparatus();
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

  void _applyInitialProductionMapLoadError(Object error) {
    if (widget.workerMode) {
      _workerRetryAllowed = _canRetryWorkerRead(error);
      if (_workerCatalogReady) {
        _invalidateQueueSnapshotContract(_workerReadErrorText(error));
        return;
      }
    }
    _updateScreenState(() {
      _loading = false;
      _loadError = widget.workerMode
          ? _workerReadErrorText(error) : 'Reja menu yuklanmadi';
    });
    _scheduleWorkerRecovery();
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

  Future<void> _load() {
    _workerRetryAllowed = true;
    return _refreshLive(initial: true);
  }
}
