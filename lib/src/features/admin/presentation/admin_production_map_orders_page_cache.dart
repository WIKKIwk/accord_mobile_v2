part of 'admin_production_map_orders_screen.dart';

extension _AdminOrdersPageCache on _AdminProductionMapOrdersScreenState {
  String get _adminPageCacheScope => jsonEncode([
        _adminPageAccount,
        currentSessionReadScope(),
        AppSession.instance.revision.value,
      ]);

  void _restoreAdminPageCache() {
    if (!_adminPaging || !AppSession.instance.isLoggedIn) return;
    _adminCacheScope = _adminPageCacheScope;
    final visit = AdminOrderPageCache.instance.open(_adminCacheScope!);
    _adminCacheVisit = visit;
    final snapshot = visit.snapshot;
    if (snapshot != null) _applyRestoredAdminPageCache(snapshot);
  }

  Future<void> _restoreAdminPageCacheFromDisk() async {
    if (!_adminPaging ||
        _adminCacheRestored ||
        !AppSession.instance.isLoggedIn) {
      return;
    }
    final visit = _adminCacheVisit;
    final runtimeScope = _adminCacheScope;
    final persistentScope = currentSessionReadScope();
    if (visit == null || runtimeScope != _adminPageCacheScope) return;
    final snapshot = await AdminOrderPageCache.instance
        .restore(visit: visit, persistentScope: persistentScope);
    if (!mounted ||
        runtimeScope != _adminPageCacheScope ||
        persistentScope != currentSessionReadScope() ||
        snapshot == null ||
        _adminWindows.values.any((window) => window.loaded)) {
      return;
    }
    _updateScreenState(() => _applyRestoredAdminPageCache(snapshot));
  }

  void _applyRestoredAdminPageCache(AdminOrderPageCacheSnapshot snapshot) {
    if (snapshot.apparatus.isEmpty) return;
    _apparatus = snapshot.apparatus;
    _workerCatalogReady = true;
    _selectedApparatus = snapshot.apparatus
        .where((a) => a.id == snapshot.selectedApparatusId)
        .firstOrNull;
    _syncSelectedSequenceApparatus(_apparatus);
    _syncMoveApparatusDefaults(_apparatus);
    for (final cached in snapshot.windows) {
      final request = cached.request;
      if (request.search.isNotEmpty) continue;
      final window = _adminWindow(request.view,
          apparatus: request.apparatus, target: request.target);
      window.pages = List.of(cached.pages);
      window.cacheNeedsValidation = true;
      window.awaitingLive = true;
    }
    _rebuildAdminPageState();
    _adminCacheRestored = true;
    _loading = !_adminModuleWindows(_module).every((window) => window.loaded);
  }

  void _saveAdminPageCache({bool flush = false}) {
    final visit = _adminCacheVisit;
    if (!_adminPaging ||
        visit == null ||
        !AppSession.instance.isLoggedIn ||
        _adminCacheScope != _adminPageCacheScope ||
        _queueSnapshotContractError) {
      return;
    }
    final active = _adminModuleWindows(_module);
    final windows = {...active, ..._adminWindows.values}
        .where((window) =>
            window.account == _adminPageAccount &&
            window.loaded &&
            !window.dirty &&
            window.inFlight == null &&
            window.error == null &&
            window.sequencePendingPages == null &&
            window.request.search.isEmpty &&
            !_pendingSequenceMoves.containsKey(window.request.apparatus) &&
            !_sequenceNeedsSnapshot.contains(window.request.apparatus) &&
            !_adminSequenceAcks.containsKey(window.request.apparatus))
        .toList();
    AdminOrderPageCache.instance.save(
      visit: visit,
      apparatus: _apparatus,
      selectedApparatusId: _selectedApparatus?.id,
      refreshAge: windows.any((window) => !window.cacheNeedsValidation),
      persistentScope: currentSessionReadScope(),
      persistentWindows: [
        for (final window in windows)
          if (!window.cacheNeedsValidation)
            AdminOrderPageCacheWindow(window.request, window.pages),
      ],
      windows: [
        for (final window in windows)
          AdminOrderPageCacheWindow(window.request, window.pages),
      ],
    );
    if (flush) unawaited(AdminOrderPageCache.instance.flush());
  }

  Future<void> _refreshCachedAdminApparatus() async {
    final scope = _adminCacheScope;
    try {
      final apparatus = await _readOrdersApparatus();
      if (!mounted || scope != _adminPageCacheScope) return;
      _updateScreenState(() {
        _apparatus = apparatus;
        _syncSelectedSequenceApparatus(apparatus);
        _syncMoveApparatusDefaults(apparatus);
        _rebuildAdminPageState();
      });
      await _ensureAdminModule(_module);
    } catch (_) {
      // Cached catalog is display-only until the page's existing authority
      // barrier is released by a matching stream or an HTTP reconciliation.
    }
  }
}
