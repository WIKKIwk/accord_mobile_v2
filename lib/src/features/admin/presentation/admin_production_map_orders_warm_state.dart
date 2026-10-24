part of 'admin_production_map_orders_screen.dart';

extension _AdminOrdersWarmState on _AdminProductionMapOrdersScreenState {
  AdminSequenceWarmStore get _sequenceWarmStore =>
      widget.sequenceWarmStore ?? AdminSequenceWarmStore.instance;

  void _claimAdminWarmSequence() {
    if (!_adminPaging ||
        !AppSession.instance.isLoggedIn ||
        (widget.sequenceWarmStore == null &&
            (AppSession.instance.isTestModeSession ||
                widget.orderPageLoader != null ||
                widget.apparatusLoader != null ||
                widget.liveEventsLoader != null))) return;
    final scope = currentAdminSequenceWarmScope();
    _adminWarmReadScope = currentSessionReadScope();
    _adminWarmScope = scope;
    _sequenceWarmStore.configure(
      scope: scope,
      profileRef: AppSession.instance.profile?.ref,
      foreground: _adminForeground,
    );
    final ready = _sequenceWarmStore.peek(scope);
    _adminWarmLease = _sequenceWarmStore.acquire(scope);
    if (ready != null) _adoptAdminWarmSequence(ready);
    _sequenceWarmStore.pagesChanges.addListener(_adoptPreparedAdminPages);
    _adoptPreparedAdminPages();
  }

  void _adoptPreparedAdminPages() {
    if (!mounted || !_adminPaging || !_adminForeground) return;
    final scope = _adminWarmScope;
    if (scope == null || scope != currentAdminSequenceWarmScope()) return;
    final catalog = _sequenceWarmStore.peekApparatus(scope);
    if (_apparatus.isEmpty && catalog != null && catalog.isNotEmpty) {
      _updateScreenState(() {
        _apparatus = catalog;
        _workerCatalogReady = true;
        _syncSelectedSequenceApparatus(catalog);
        _syncMoveApparatusDefaults(catalog);
      });
    }
    for (final module in const [
      _OpenedOrderModule.orders,
      _OpenedOrderModule.move,
      _OpenedOrderModule.closed,
      _OpenedOrderModule.audit,
    ]) {
      for (final window in _adminModuleWindows(module)) {
        final scope = _adminPageWarmScope(window);
        if (scope == null || window.loaded || window.dirty ||
            window.inFlight != null) continue;
        final page = _sequenceWarmStore.peekPage(scope, window.request);
        if (page != null) _adoptAdminWarmPage(window, page);
      }
    }
  }

  void _configureAdminWarmMovePages() {
    final scope = _adminWarmScope;
    if (scope == null || scope != currentAdminSequenceWarmScope()) return;
    _sequenceWarmStore.configureMoveRequests(scope, [
      for (final window in _adminModuleWindows(_OpenedOrderModule.move))
        window.request,
    ]);
  }

  void _syncAdminWarmSession() {
    if (!mounted || _adminWarmReadScope == null) return;
    if (!AppSession.instance.isLoggedIn ||
        _adminWarmReadScope != currentSessionReadScope()) {
      _adminWarmLease?.release();
      _adminWarmLease = null;
      _adminWarmScope = null;
      _adminEarlyTabEpoch = null;
      _updateScreenState(() {
        _adminWindows.clear();
        _rebuildAdminPageState();
      });
      return;
    }
    if (!_adminForeground) return;
    final scope = currentAdminSequenceWarmScope();
    if (scope == _adminWarmScope) return;
    final previous = _adminWarmLease;
    _adminWarmScope = scope;
    _adminEarlyTabEpoch = null;
    _sequenceWarmStore.configure(
      scope: scope,
      profileRef: AppSession.instance.profile?.ref,
      foreground: _adminForeground,
    );
    // Configure retires the old generation before releasing its lease, so it
    // cannot restart an old background socket while this screen is active.
    previous?.release();
    _adminWarmLease = _sequenceWarmStore.acquire(scope);
    scheduleMicrotask(() {
      if (mounted &&
          _adminForeground &&
          _adminWarmScope == scope &&
          _adminWarmReadScope == currentSessionReadScope()) {
        unawaited(_ensureAdminModule(_module));
      }
    });
  }

  bool _adoptAdminWarmSequence(AdminSequenceWarmSnapshot ready) {
    if (_adminWarmScope != currentAdminSequenceWarmScope() ||
        _adminPageSearch.isNotEmpty ||
        (_userChangedSequenceApparatus &&
            _selectedApparatus?.id != ready.selectedApparatusId) ||
        ready.scope != _adminWarmScope ||
        ready.apparatus.isEmpty ||
        (!_adminWarmAdopted &&
            _adminEarlyTabEpoch != null &&
            _adminEarlyTabEpoch != ready.page.epoch) ||
        _retiredSnapshotEpochs.contains(ready.page.epoch)) return false;
    final selected = ready.apparatus
        .where((item) => item.id == ready.selectedApparatusId)
        .firstOrNull;
    if (selected == null) return false;
    final page = ready.page;
    if (_lastAppliedSnapshotEpoch.isNotEmpty &&
        _lastAppliedSnapshotEpoch != page.epoch) {
      _retiredSnapshotEpochs.add(_lastAppliedSnapshotEpoch);
      _adminWindows.clear();
      _sequenceRevisions.clear();
      _sequenceVersions.clear();
      _adminSequenceAcks.clear();
      _adminSequenceAckWindows.clear();
      _cancelAdminSequenceSyncTimers();
      _lastAppliedSnapshotEpoch = page.epoch;
      _lastAppliedSnapshotRevision = null;
      if (_retiredSnapshotEpochs.contains(_adminLiveEpoch)) {
        _adminLiveEpoch = page.epoch;
        _adminLiveRevision = page.revision ?? -1;
      }
    }
    final window = _adminWindow('sequence', apparatus: selected.id);
    final current = window.pages.firstOrNull;
    if (current != null &&
        current.epoch == page.epoch &&
        (current.revision ?? -1) > (page.revision ?? -1)) return false;
    _apparatus = ready.apparatus;
    _selectedApparatus = selected;
    _workerCatalogReady = true;
    _syncMoveApparatusDefaults(_apparatus);
    window.pages = [page];
    // A new screen must prove its socket's continuity before allowing writes.
    window.cacheNeedsValidation = true;
    window.awaitingLive = true;
    window.error = null;
    _rebuildAdminPageState();
    _adminCacheRestored = true;
    _adminWarmAdopted = true;
    if (_module == _OpenedOrderModule.sequence) _loading = false;
    final account = _adminPageAccount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && account == _adminPageAccount) {
        unawaited(_loadAdminPageMetrics(page, account));
      }
    });
    return true;
  }

  Future<void> _joinAdminWarmSequence() async {
    final lease = _adminWarmLease;
    if (lease == null || _adminWarmAdopted) return;
    final ready = await lease.ready;
    if (!mounted ||
        ready == null ||
        _adminWarmScope != currentAdminSequenceWarmScope()) return;
    _updateScreenState(() => _adoptAdminWarmSequence(ready));
    _adoptPreparedAdminPages();
  }

  String? _adminPageWarmScope(_AdminOrderWindow window) {
    final scope = _adminWarmScope;
    if (scope == null ||
        scope != currentAdminSequenceWarmScope() ||
        window.account != _adminPageAccount ||
        !const {'orders', 'move', 'closed', 'audit'}
            .contains(window.request.view) ||
        window.request.search.isNotEmpty ||
        (window.request.view != 'move' &&
            (window.request.apparatus.isNotEmpty ||
                window.request.target.isNotEmpty))) {
      return null;
    }
    return scope;
  }

  bool _adoptAdminWarmPage(
      _AdminOrderWindow window, AdminProductionOrderPage page,
      {bool prioritized = false}) {
    if (_adminPageWarmScope(window) == null ||
        window.loaded ||
        window.dirty ||
        (window.request.view == 'orders' && !page.isOrdersList) ||
        page.offset != 0 ||
        page.length > 20 ||
        page.version.isEmpty ||
        page.epoch.isEmpty ||
        page.revision == null ||
        page.revision! < 0 ||
        page.wireValue == null ||
        _retiredSnapshotEpochs.contains(page.epoch) ||
        (_lastAppliedSnapshotEpoch.isNotEmpty &&
            _lastAppliedSnapshotEpoch != page.epoch)) {
      return false;
    }
    _updateScreenState(() {
      if (prioritized && !_adminWarmAdopted) {
        _adminEarlyTabEpoch = page.epoch;
      }
      window.pages = [page];
      if (_lastAppliedSnapshotEpoch.isEmpty) {
        _lastAppliedSnapshotEpoch = page.epoch;
      }
      // A prefetched list can render immediately; the visible window's socket
      // still proves continuity before the existing action guards are released.
      window.cacheNeedsValidation = true;
      window.awaitingLive = true;
      window.error = null;
      _rebuildAdminPageState();
      if (_adminModuleWindows(_module).contains(window)) _loading = false;
    });
    return true;
  }

  void _releaseAdminWarmSequence() {
    final lease = _adminWarmLease;
    _adminWarmLease = null;
    if (lease == null) return;
    final scope = _adminWarmScope;
    AdminProductionOrderPage? ordersPage;
    if (scope != null && !_queueSnapshotContractError) {
      for (final window in _adminWindows.values.where((window) =>
          _adminPageWarmScope(window) == scope &&
          window.loaded &&
          !window.dirty &&
          !window.cacheNeedsValidation &&
          !window.awaitingLive &&
          window.inFlight == null &&
          window.error == null)) {
        _sequenceWarmStore.rememberPage(scope, window.request, window.pages.first);
        if (window.request.view == 'orders') ordersPage = window.pages.first;
      }
    }
    final selected = _selectedApparatus;
    final windows = _adminWindows.values.where((window) =>
        window.account == _adminPageAccount &&
        window.request.view == 'sequence' &&
        window.request.apparatus == selected?.id &&
        window.request.search.isEmpty &&
        window.loaded &&
        !window.dirty &&
        window.error == null &&
        window.inFlight == null &&
        window.sequencePendingPages == null &&
        !_pendingSequenceMoves.containsKey(window.request.apparatus) &&
        !_sequenceNeedsSnapshot.contains(window.request.apparatus) &&
        !_adminSequenceAcks.containsKey(window.request.apparatus));
    final window = windows.firstOrNull;
    lease.release(
      apparatus: _apparatus,
      selectedApparatusId: selected?.id,
      page: window?.pages.firstOrNull,
      ordersPage: ordersPage,
      confirmed: window != null &&
          !window.cacheNeedsValidation &&
          !window.awaitingLive &&
          !_queueSnapshotContractError,
    );
  }
}
