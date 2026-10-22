part of 'admin_production_map_orders_screen.dart';

extension _ProductionOrdersSnapshotCache
    on _AdminProductionMapOrdersScreenState {
  String get _canonicalCacheKey => jsonEncode([
        'canonical-queue-v1',
        widget.workerMode,
        widget.supplyViewerMode,
        widget.readOnly,
        if (widget.workerMode) _workerQueueLimit,
        if (widget.workerMode) _workerServerSearch,
      ]);

  String get _canonicalCacheRuntimeScope => jsonEncode([
        currentSessionReadScope(),
        AppSession.instance.revision.value,
        ProductionSnapshotStore.instance.generation,
      ]);

  bool get _canonicalCacheEnabled =>
      !_adminPaging &&
      AppSession.instance.isLoggedIn &&
      !AppSession.instance.isTestModeSession &&
      !_canonicalCacheDemoMode &&
      _canonicalCacheOwner == _canonicalCacheRuntimeScope;

  Future<bool> _restoreCanonicalQueueCache() {
    final generation = ++_canonicalCacheRestoreGeneration;
    return _restoreCanonicalQueueCacheOnce(generation).timeout(
      const Duration(milliseconds: 500),
      onTimeout: () {
        if (_canonicalCacheRestoreGeneration == generation) {
          _canonicalCacheRestoreGeneration++;
        }
        return false;
      },
    );
  }

  Future<bool> _restoreCanonicalQueueCacheOnce(int generation) async {
    if (!_canonicalCacheEnabled || _canonicalQueueSnapshot != null) {
      return false;
    }
    final scope = currentSessionReadScope();
    final owner = _canonicalCacheOwner;
    final key = _canonicalCacheKey;
    final window = _workerQueueWindowGeneration;
    try {
      _canonicalCacheDemoMode = await TestModeController.instance.isEnabled();
      if (_canonicalCacheDemoMode ||
          !mounted ||
          owner != _canonicalCacheRuntimeScope ||
          generation != _canonicalCacheRestoreGeneration) {
        return false;
      }
      final value =
          await ProductionSnapshotStore.instance.read(scope: scope, key: key);
      if (value == null ||
          !mounted ||
          owner != _canonicalCacheRuntimeScope ||
          key != _canonicalCacheKey ||
          window != _workerQueueWindowGeneration ||
          generation != _canonicalCacheRestoreGeneration ||
          _canonicalQueueSnapshot != null) {
        return false;
      }
      final rawSnapshot = value['snapshot'];
      final rawApparatus = value['apparatus'];
      if (value['schema'] != 1 ||
          rawSnapshot is! Map ||
          rawApparatus is! List ||
          rawApparatus.isEmpty ||
          rawApparatus.length > 200) {
        throw const FormatException('Invalid production cache');
      }
      final maps = rawSnapshot['maps'];
      final controls = rawSnapshot['queue_action_controls'];
      final completed = rawSnapshot['completed_orders'];
      final large = (maps is List && maps.length > 20) ||
          rawApparatus.length >= 50 ||
          (completed is List && completed.length > 100) ||
          (controls is Map &&
              controls.values.fold<int>(
                      0, (n, value) => n + (value is Map ? value.length : 0)) >
                  100);
      final decoded = !kIsWeb && large
          ? await compute(_decodeCanonicalSnapshotCache, value,
              debugLabel: 'production-cache-restore')
          : _decodeCanonicalSnapshotCache(value);
      final snapshot = decoded.snapshot;
      final apparatus = decoded.apparatus;
      if (snapshot.revision == null ||
          snapshot.epoch.isEmpty ||
          (widget.workerMode && snapshot.scope.isEmpty) ||
          maps is! List ||
          snapshot.maps.length != maps.length ||
          snapshot.maps.map((saved) => saved.map.id).toSet().length !=
              snapshot.maps.length ||
          apparatus.map((value) => value.id).toSet().length !=
              apparatus.length) {
        throw const FormatException('Unversioned production cache');
      }
      if (!mounted ||
          owner != _canonicalCacheRuntimeScope ||
          key != _canonicalCacheKey ||
          window != _workerQueueWindowGeneration ||
          generation != _canonicalCacheRestoreGeneration ||
          _canonicalQueueSnapshot != null) {
        return false;
      }
      _canonicalCacheAwaitingValidation = true;
      _rememberSnapshotVersion(snapshot);
      _updateScreenState(() {
        _apparatus = apparatus;
        _workerCatalogReady = true;
        _orders = _productionMapZakazOrders(snapshot.maps);
        _replaceQueueSnapshotMaps(snapshot);
        if (snapshot is AdminProductionMapLiveSnapshot) {
          _replaceLiveSnapshotExtras(snapshot);
        }
        _loading = false;
        _loadError = null;
        _queueSnapshotNeedsReconcile = true;
        if (!widget.workerMode) {
          _syncSelectedSequenceApparatus(apparatus);
          _syncMoveApparatusDefaults(apparatus);
        }
      });
      // Cached apparatus is useful for the first frame. Its live metadata is
      // refreshed independently, without downloading the order list again.
      unawaited(_refreshApparatusCatalog());
      return true;
    } catch (_) {
      // A bad local record must behave exactly like a fresh installation.
      if (owner == _canonicalCacheRuntimeScope &&
          generation == _canonicalCacheRestoreGeneration) {
        unawaited(
            ProductionSnapshotStore.instance.remove(scope: scope, key: key));
      }
      return false;
    }
  }

  void _scheduleCanonicalCacheSave() {
    if (!_canonicalCacheEnabled ||
        _canonicalCacheAwaitingValidation ||
        !_canonicalCacheHasLiveExtras ||
        _queueSnapshotNeedsReconcile ||
        _queueSnapshotContractError ||
        _canonicalQueueSnapshot?.revision == null ||
        _apparatus.isEmpty ||
        _canonicalCacheIdentity == _canonicalCacheLastSavedIdentity) {
      return;
    }
    _canonicalCacheSaveTimer?.cancel();
    _canonicalCacheSaveTimer = Timer(const Duration(milliseconds: 400), () {
      _canonicalCacheSaveTimer = null;
      _flushCanonicalCache();
    });
  }

  void _flushCanonicalCache() {
    _canonicalCacheSaveTimer?.cancel();
    _canonicalCacheSaveTimer = null;
    final snapshot = _canonicalQueueSnapshot;
    if (!_canonicalCacheEnabled ||
        _canonicalCacheAwaitingValidation ||
        !_canonicalCacheHasLiveExtras ||
        _queueSnapshotNeedsReconcile ||
        _queueSnapshotContractError ||
        snapshot == null ||
        snapshot.revision == null ||
        snapshot.epoch.isEmpty ||
        (widget.workerMode && snapshot.scope.isEmpty) ||
        _apparatus.isEmpty ||
        _pendingSequenceMoves.isNotEmpty ||
        _sequenceNeedsSnapshot.isNotEmpty ||
        _pendingQueueActionRevision != null ||
        _canonicalCacheIdentity == _canonicalCacheLastSavedIdentity) {
      return;
    }
    if (_canonicalCacheWriteInFlight) {
      _canonicalCacheWriteQueued = true;
      return;
    }
    final input = _CanonicalSnapshotCacheInput(
        snapshot,
        List.of(_apparatus),
        List.of(_completedWorkerOrders),
        List.of(_completionRequests),
        List.of(_canonicalCompletionDecisions));
    _canonicalCacheWriteInFlight = true;
    unawaited(_writeCanonicalQueueCache(
        input,
        _canonicalCacheIdentity,
        currentSessionReadScope(),
        _canonicalCacheKey,
        _canonicalCacheOwner!,
        ProductionSnapshotStore.instance.generation));
  }

  Object get _canonicalCacheIdentity => (
        _canonicalQueueSnapshot,
        _apparatus,
        _completedWorkerOrders,
        _completionRequests,
        _canonicalCompletionDecisions,
        _canonicalCacheKey,
      );

  Future<void> _writeCanonicalQueueCache(
      _CanonicalSnapshotCacheInput input,
      Object identity,
      String scope,
      String key,
      String owner,
      int generation) async {
    try {
      final valueJson = !kIsWeb && input.large
          ? await compute(_encodeCanonicalSnapshotCache, input,
              debugLabel: 'production-cache-encode')
          : _encodeCanonicalSnapshotCache(input);
      if (!mounted ||
          owner != _canonicalCacheRuntimeScope ||
          _queueSnapshotNeedsReconcile ||
          _queueSnapshotContractError) {
        return;
      }
      if (_canonicalCacheIdentity != identity) {
        _canonicalCacheWriteQueued = true;
        return;
      }
      await ProductionSnapshotStore.instance.writeEncoded(
          scope: scope,
          key: key,
          valueJson: valueJson,
          expectedGeneration: generation);
      if (owner == _canonicalCacheRuntimeScope) {
        _canonicalCacheLastSavedIdentity = identity;
      }
    } catch (_) {
      // A cache failure never prevents the normal canonical network path.
    } finally {
      _canonicalCacheWriteInFlight = false;
      if (_canonicalCacheWriteQueued && mounted) {
        _canonicalCacheWriteQueued = false;
        _flushCanonicalCache();
      }
    }
  }

  void _discardCanonicalCacheOnError(Object error) {
    if (error is! MobileApiException ||
        !(error.statusCode == 401 ||
            error.statusCode == 403 ||
            const {
              'unauthorized',
              'forbidden',
              'permission_denied',
              'production_map_snapshot_contract_invalid'
            }.contains(error.code))) {
      return;
    }
    _canonicalCacheSaveTimer?.cancel();
    if (_canonicalCacheOwner == _canonicalCacheRuntimeScope) {
      unawaited(ProductionSnapshotStore.instance
          .remove(scope: currentSessionReadScope(), key: _canonicalCacheKey));
    }
    if (_canonicalCacheAwaitingValidation && mounted) {
      _updateScreenState(() {
        _canonicalCacheAwaitingValidation = false;
        _canonicalQueueSnapshot = null;
        _orders = const [];
        _workerCatalogReady = false;
        _queueSnapshotNeedsReconcile = true;
      });
    }
  }
}

class _CanonicalSnapshotCacheDecoded {
  const _CanonicalSnapshotCacheDecoded(this.snapshot, this.apparatus);
  final AdminApparatusQueueSnapshot snapshot;
  final List<AdminApparatus> apparatus;
}

_CanonicalSnapshotCacheDecoded _decodeCanonicalSnapshotCache(
        Map<String, dynamic> value) =>
    _CanonicalSnapshotCacheDecoded(
      decodeCachedProductionMapQueueSnapshot(
          (value['snapshot'] as Map).cast<String, dynamic>()),
      [
        for (final raw in value['apparatus'] as List)
          decodeCachedApparatus((raw as Map).cast<String, dynamic>())
      ],
    );

class _CanonicalSnapshotCacheInput {
  const _CanonicalSnapshotCacheInput(this.snapshot, this.apparatus,
      this.completed, this.requests, this.decisions);
  final AdminApparatusQueueSnapshot snapshot;
  final List<AdminApparatus> apparatus;
  final List<AdminCompletedQueueOrder> completed;
  final List<AdminCompletionRequestNotification> requests;
  final List<AdminCompletionRequestDecisionNotification> decisions;

  bool get large =>
      snapshot.maps.length > 20 ||
      snapshot.maps.fold<int>(
              0,
              (count, saved) =>
                  count +
                  saved.map.nodes.length +
                  saved.program.operations.length) >
          100 ||
      snapshot.queueActionControls.values.fold<int>(
              0,
              (count, orders) =>
                  count +
                  orders.values.fold<int>(
                      0,
                      (sum, control) =>
                          sum + control.serverContractSignature.length)) >
          32768;
}

String _encodeCanonicalSnapshotCache(_CanonicalSnapshotCacheInput input) =>
    jsonEncode({
      'schema': 1,
      'snapshot': encodeProductionMapQueueSnapshot(input.snapshot,
          completedOrders: input.completed,
          completionRequests: input.requests,
          completionRequestDecisions: input.decisions),
      'apparatus': [
        for (final value in input.apparatus) encodeCachedApparatus(value)
      ],
    });
