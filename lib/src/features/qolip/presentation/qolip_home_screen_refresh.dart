part of 'qolip_home_screen.dart';

extension _QolipHomeRefresh on _QolipHomeScreenState {
  void _startQuietRefreshCooldown() {
    _quietRefreshCooldown?.cancel();
    _quietRefreshCooldown =
        Timer(_QolipHomeScreenState._quietRefreshInterval, () {
      _quietRefreshCooldown = null;
    });
  }

  void _handleHomeSessionChange() {
    if (!mounted) return;
    final scope = currentSessionReadScope();
    final valid = AppSession.instance.isLoggedIn &&
        AppSession.instance.profile?.role == UserRole.qolipchi;
    if (scope == _homeScope && valid == !_homeSessionInvalid) return;

    _quietRefreshGeneration++;
    _quietRefreshQueued = false;
    _quietRefreshCooldown?.cancel();
    _quietRefreshCooldown = null;
    _searchGeneration++;
    _searchDebounce?.cancel();
    _searchFocusNode.unfocus();
    setState(() {
      _homeScope = scope;
      _homeSessionInvalid = !valid;
      _homeDataReady = false;
      _homeBlocksSnapshot = null;
      _locations.clear();
      _resolvedLocations.clear();
      _locationGenerations.clear();
      _orderedBlocks = const [];
      _pendingTabIndex = 0;
      if (_blockTabController != null) _blockTabController!.index = 0;
      _searchController.clear();
      _searchQuery = '';
      _clearSearchCounts();
      if (valid) _blocksFuture = _loadBlocks();
    });
  }

  void _requestQuietRefresh({bool force = false}) {
    if (!_preserveHome || !mounted || _homeSessionInvalid) return;
    if (_homeScope != currentSessionReadScope() ||
        !AppSession.instance.isLoggedIn) {
      _handleHomeSessionChange();
      return;
    }
    if (!_homeDataReady) return;
    if (_quietRefreshInFlight) {
      if (force) _quietRefreshQueued = true;
      return;
    }
    if (!force && _quietRefreshCooldown != null) return;
    _quietRefreshInFlight = true;
    _quietRefreshQueued = false;
    _startQuietRefreshCooldown();
    unawaited(_refreshHomeQuietly(_homeScope, _quietRefreshGeneration));
  }

  bool _quietRefreshIsCurrent(String scope, int generation) =>
      mounted &&
      !_homeSessionInvalid &&
      AppSession.instance.isLoggedIn &&
      scope == _homeScope &&
      scope == currentSessionReadScope() &&
      generation == _quietRefreshGeneration;

  Future<void> _refreshHomeQuietly(String scope, int generation) async {
    try {
      final latest = await MobileApi.instance.qolipBlocksData();
      if (!_quietRefreshIsCurrent(scope, generation)) return;

      final blocksByKey = <String, QolipBlock>{};
      for (final block in latest.blocks) {
        if (block.name.trim().isNotEmpty) {
          blocksByKey.putIfAbsent(_blockKey(block), () => block);
        }
      }
      final locations = await Future.wait(
        blocksByKey.values.map(_readQuietBlockLocations),
      );
      if (!_quietRefreshIsCurrent(scope, generation)) return;
      if (locations.any((entry) => entry.locations == null)) {
        _quietRefreshCooldown?.cancel();
        _quietRefreshCooldown = null;
      }

      final remaining = Map<String, QolipBlock>.of(blocksByKey);
      final ordered = <QolipBlock>[
        for (final old in _orderedBlocks)
          if (remaining.containsKey(_blockKey(old)))
            remaining.remove(_blockKey(old))!,
        ...remaining.values,
      ];
      final snapshot = QolipBlocksResult(
        warehouses: latest.warehouses
            .where((warehouse) => warehouse.trim().isNotEmpty)
            .toList(growable: false),
        blocks: ordered,
        supportsCrossBlockMove: latest.supportsCrossBlockMove,
      );
      final changedBlocks = !_sameHomeBlocks(_homeBlocksSnapshot, snapshot);
      final changedLocations = locations
          .where((entry) =>
              entry.locations != null &&
              _locationGenerations[entry.key] == entry.generation &&
              !_sameHomeLocations(
                  _resolvedLocations[entry.key], entry.locations!))
          .toList();
      if (!changedBlocks && changedLocations.isEmpty) return;

      final controller = _blockTabController;
      final oldIndex = controller?.index ?? 0;
      final selectedKey = oldIndex < _orderedBlocks.length
          ? _blockKey(_orderedBlocks[oldIndex])
          : null;
      final selectedIndex = selectedKey == null
          ? 0
          : ordered.indexWhere((block) => _blockKey(block) == selectedKey);
      final nextIndex = selectedIndex < 0 ? 0 : selectedIndex;
      setState(() {
        if (changedBlocks) {
          _orderedBlocks = ordered;
          _homeBlocksSnapshot = snapshot;
          _supportsCrossBlockMove = snapshot.supportsCrossBlockMove;
          _blocksFuture = Future.value(snapshot);
          _locations.removeWhere((key, _) => !blocksByKey.containsKey(key));
          _resolvedLocations
              .removeWhere((key, _) => !blocksByKey.containsKey(key));
          _locationGenerations
              .removeWhere((key, _) => !blocksByKey.containsKey(key));
          if (controller != null && controller.length == ordered.length + 1) {
            if (controller.index != nextIndex) controller.index = nextIndex;
          } else {
            _pendingTabIndex = nextIndex;
          }
        }
        for (final entry in changedLocations) {
          final data = entry.locations!;
          _resolvedLocations[entry.key] = data;
          _locations[entry.key] = Future.value(data);
        }
      });
      _refreshSearchMatches();
    } catch (_) {
      // Keep the visible snapshot and try again on a later return.
      if (_quietRefreshIsCurrent(scope, generation)) {
        _quietRefreshCooldown?.cancel();
        _quietRefreshCooldown = null;
      }
    } finally {
      _quietRefreshInFlight = false;
      if (_quietRefreshQueued && mounted) {
        _quietRefreshQueued = false;
        _requestQuietRefresh(force: true);
      }
    }
  }

  Future<({String key, int generation, List<QolipLocationEntry>? locations})>
      _readQuietBlockLocations(QolipBlock block) async {
    final key = _blockKey(block);
    final generation = (_locationGenerations[key] ?? 0) + 1;
    _locationGenerations[key] = generation;
    try {
      final locations = await MobileApi.instance.qolipLocations(block.name);
      return (
        key: key,
        generation: generation,
        locations: List<QolipLocationEntry>.unmodifiable(locations)
      );
    } catch (_) {
      return (key: key, generation: generation, locations: null);
    }
  }
}

bool _sameHomeBlocks(QolipBlocksResult? a, QolipBlocksResult b) {
  if (a == null ||
      a.supportsCrossBlockMove != b.supportsCrossBlockMove ||
      a.warehouses.length != b.warehouses.length ||
      a.blocks.length != b.blocks.length) return false;
  for (var i = 0; i < a.warehouses.length; i++) {
    if (a.warehouses[i] != b.warehouses[i]) return false;
  }
  for (var i = 0; i < a.blocks.length; i++) {
    if (a.blocks[i].name != b.blocks[i].name ||
        a.blocks[i].warehouse != b.blocks[i].warehouse) return false;
  }
  return true;
}

bool _sameHomeLocations(
    List<QolipLocationEntry>? a, List<QolipLocationEntry> b) {
  if (a == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    final x = a[i], y = b[i];
    if (x.id != y.id ||
        x.block != y.block ||
        x.warehouse != y.warehouse ||
        x.itemCode != y.itemCode ||
        x.itemName != y.itemName ||
        x.qolipCode != y.qolipCode ||
        x.size != y.size ||
        x.quantity != y.quantity ||
        x.rowLetter != y.rowLetter ||
        x.columnNumber != y.columnNumber ||
        x.locationLabel != y.locationLabel) {
      return false;
    }
  }
  return true;
}
