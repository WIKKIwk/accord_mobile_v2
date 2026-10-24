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
  }

  void _syncAdminWarmSession() {
    if (!mounted || _adminWarmReadScope == null) return;
    if (!AppSession.instance.isLoggedIn ||
        _adminWarmReadScope != currentSessionReadScope()) {
      _adminWarmLease?.release();
      _adminWarmLease = null;
      _adminWarmScope = null;
      return;
    }
    if (!_adminForeground) return;
    final scope = currentAdminSequenceWarmScope();
    if (scope == _adminWarmScope) return;
    final previous = _adminWarmLease;
    _adminWarmScope = scope;
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
    _loading = false;
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
  }

  String? _adminOrdersWarmScope(_AdminOrderWindow window) {
    final scope = _adminWarmScope;
    if (scope == null ||
        scope != currentAdminSequenceWarmScope() ||
        window.account != _adminPageAccount ||
        window.request.view != 'orders' ||
        window.request.search.isNotEmpty ||
        window.request.apparatus.isNotEmpty ||
        window.request.target.isNotEmpty) {
      return null;
    }
    return scope;
  }

  bool _adoptAdminWarmOrders(
      _AdminOrderWindow window, AdminProductionOrderPage page) {
    if (_adminOrdersWarmScope(window) == null ||
        window.loaded ||
        window.dirty ||
        !page.isOrdersList ||
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
      window.pages = [page];
      // A prefetched list can render immediately; the visible window's socket
      // still proves continuity before the existing action guards are released.
      window.cacheNeedsValidation = true;
      window.awaitingLive = true;
      window.error = null;
      _rebuildAdminPageState();
      _loading = false;
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
      final orders = _adminWindows.values.where((window) =>
          _adminOrdersWarmScope(window) == scope &&
          window.loaded &&
          !window.dirty &&
          !window.cacheNeedsValidation &&
          !window.awaitingLive &&
          window.inFlight == null &&
          window.error == null).firstOrNull;
      if (orders != null) {
        ordersPage = orders.pages.first;
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
