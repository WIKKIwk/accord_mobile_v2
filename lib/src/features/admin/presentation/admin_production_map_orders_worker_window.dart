part of 'admin_production_map_orders_screen.dart';

extension _WorkerQueueWindowState on _AdminProductionMapOrdersScreenState {
  String get _workerQueuePreferenceAccount {
    final profile = AppSession.instance.profile;
    return jsonEncode([MobileApi.baseUrl, profile?.role.name, profile?.ref]);
  }

  Future<void> _loadWorkerQueueLimit() async {
    try {
      final value =
          await WorkerQueueLimitStore.load(_workerQueuePreferenceAccount);
      if (mounted) _workerQueueLimit = value;
    } catch (_) {
      // An unavailable device preference must not block production reads.
    }
  }

  void _onOrdersSearchChanged(String value) {
    setState(() => _searchQuery = value);
    if (!widget.workerMode) return;
    _workerQueueSearchDebounce?.cancel();
    _workerQueueSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final query = String.fromCharCodes(value.trim().runes.take(120));
      if (query == _workerServerSearch) return;
      unawaited(_changeWorkerQueueWindow(search: query));
    });
  }

  Future<void> _changeWorkerQueueWindow({int? limit, String? search}) async {
    if (!widget.workerMode || !mounted) return;
    if (limit != null && !WorkerQueueLimitStore.choices.contains(limit)) return;
    final nextLimit = limit ?? _workerQueueLimit;
    final nextSearch = search ?? _workerServerSearch;
    if (nextLimit == _workerQueueLimit && nextSearch == _workerServerSearch)
      return;
    final pendingInitial = _initialRefresh;
    final generation = ++_workerQueueWindowGeneration;
    _stopWorkerLiveStream();
    _queueSnapshotGeneration++;
    _updateScreenState(() {
      _workerQueueLimit = nextLimit;
      _workerServerSearch = nextSearch;
      _canonicalQueueSnapshot = null;
      _sheetQueueSnapshot.value = null;
      _lastAppliedSnapshotRevision = null;
      _queueSnapshotNeedsReconcile = true;
      _queueSnapshotContractError = true;
      _loading = true;
      _loadError = null;
    });
    if (limit != null) {
      unawaited(WorkerQueueLimitStore.save(_workerQueuePreferenceAccount, limit)
          .catchError((Object _) {}));
    }
    // An older initial read must finish and be discarded before a new one can
    // join the shared initial-read future. Socket generations reject old deltas.
    await pendingInitial;
    if (!mounted ||
        !_workerForeground ||
        generation != _workerQueueWindowGeneration) return;
    await _startWorkerLive();
  }
}
