part of 'admin_production_map_orders_screen.dart';

class _AdminOrderWindow {
  _AdminOrderWindow(this.request, this.account);
  final AdminProductionOrderPageRequest request;
  final String account;
  final storage = PageStorageBucket();
  List<AdminProductionOrderPage> pages = [];
  Future<void>? inFlight;
  String? error;
  int invalidation = 0;
  int validated = 0;
  bool get dirty => validated < invalidation;
  bool get loaded => pages.isNotEmpty;
  String? get cursor => pages.lastOrNull?.nextCursor;
  int get total => pages.firstOrNull?.total ?? 0;
  int get length => pages.fold(0, (sum, page) => sum + page.length);
  List<ProductionMapSaved> get orders => [
        for (final page in pages)
          for (final id in page.orderIds)
            ...?page.snapshot?.maps.where((saved) => saved.map.id == id),
      ];
}

extension _AdminOrdersPaging on _AdminProductionMapOrdersScreenState {
  bool get _adminPagingCandidate =>
      !widget.workerMode &&
      !widget.supplyViewerMode &&
      !widget.readOnly &&
      !widget.qolipTasksMode &&
      !widget.materialTasksMode &&
      (widget.queueSnapshotLoader == null || widget.orderPageLoader != null);

  String get _adminPageAccount => jsonEncode([
        MobileApi.baseUrl,
        AppSession.instance.token,
        _sequenceWriteScope,
      ]);

  String _pageApparatus(AdminApparatus? apparatus) =>
      _isMoveUnassignedApparatus(apparatus)
          ? 'unassigned'
          : apparatus?.id.trim() ?? '';

  _AdminOrderWindow _adminWindow(String view,
      {String apparatus = '', String target = ''}) {
    final account = _adminPageAccount;
    final key =
        jsonEncode([account, view, apparatus, target, _adminPageSearch]);
    return _adminWindows.putIfAbsent(
        key,
        () => _AdminOrderWindow(
            AdminProductionOrderPageRequest(
                view: view,
                apparatus: apparatus,
                target: target,
                search: _adminPageSearch),
            account));
  }

  List<_AdminOrderWindow> _adminModuleWindows(_OpenedOrderModule module) =>
      switch (module) {
        _OpenedOrderModule.sequence => [
            if (_selectedApparatus != null)
              _adminWindow('sequence', apparatus: _selectedApparatus!.id),
          ],
        _OpenedOrderModule.orders => [_adminWindow('orders')],
        _OpenedOrderModule.closed => [_adminWindow('closed')],
        _OpenedOrderModule.move => [
            if (_moveTopApparatus != null && _moveBottomApparatus != null) ...[
              _adminWindow('move',
                  apparatus: _pageApparatus(_moveTopApparatus),
                  target: _pageApparatus(_moveBottomApparatus)),
              _adminWindow('move',
                  apparatus: _pageApparatus(_moveBottomApparatus),
                  target: _pageApparatus(_moveTopApparatus)),
            ],
          ],
        _OpenedOrderModule.audit => [_adminWindow('audit')],
      };

  Future<void> _startAdminPaging() async {
    try {
      await AdminSequenceApparatusStore.instance.loadSavedApparatusId();
      final apparatus = await _readOrdersApparatus();
      if (!mounted) return;
      _updateScreenState(() {
        _apparatus = apparatus;
        _workerCatalogReady = true;
        _syncSelectedSequenceApparatus(apparatus);
        _syncMoveApparatusDefaults(apparatus);
      });
      await _ensureAdminModule(_OpenedOrderModule.sequence);
      if (!mounted) return;
      _updateScreenState(() => _loading = false);
      // Completion notifications are small and must not gate the first queue.
      unawaited(_refreshCompletionRequests());
      unawaited(_prefetchAdminFirstPages());
    } catch (error) {
      if (mounted) _applyInitialProductionMapLoadError(error);
    }
  }

  Future<void> _prefetchAdminFirstPages() async {
    for (final module in [
      _OpenedOrderModule.orders,
      _OpenedOrderModule.move,
      _OpenedOrderModule.closed,
      _OpenedOrderModule.audit
    ]) {
      if (!mounted || !_adminPaging || !_adminForeground) return;
      // A selected tab takes priority over the next background page.
      await _ensureAdminModule(_module);
      if (!mounted || !_adminForeground) return;
      for (final window in _adminModuleWindows(module)) {
        if (!mounted || !_adminForeground) return;
        if (!window.loaded) await _loadAdminWindow(window);
      }
    }
  }

  Future<void> _ensureAdminModule(_OpenedOrderModule module,
      {bool refresh = false}) async {
    if (!_adminPaging || !mounted) return;
    _adminWindows
        .removeWhere((_, window) => window.account != _adminPageAccount);
    for (final window in _adminModuleWindows(module)) {
      if (!mounted) return;
      if (!window.loaded || refresh || window.dirty) await _loadAdminWindow(window);
    }
  }

  Future<void> _refreshAdminPagedView() async {
    if (!_workerCatalogReady) return _startAdminPaging();
    for (final window in _adminModuleWindows(_module)) {
      await _loadAdminWindow(window, force: _queueSnapshotNeedsReconcile);
    }
    // A reorder may finish after its apparatus/tab was changed.
    for (final apparatus in _sequenceNeedsSnapshot.toList()) {
      await _loadAdminWindow(_adminWindow('sequence', apparatus: apparatus),
          force: true);
    }
  }

  Future<void> _loadAdminWindow(_AdminOrderWindow window,
      {bool append = false, bool force = false}) {
    if (!mounted || window.account != _adminPageAccount) return Future.value();
    if (window.inFlight != null) {
      // A mutation's reconciliation must read after an older request.
      // Otherwise a 304 from before the write could leave queued moves waiting.
      return force
          ? window.inFlight!.then((_) => _loadAdminWindow(window, force: true))
          : window.inFlight!;
    }
    if (append && (!window.loaded || window.cursor == null)) {
      return Future.value();
    }
    final future = _readAdminWindow(window, append: append, force: force);
    window.inFlight = future;
    if (mounted) _updateScreenState(() {});
    return future.whenComplete(() {
      window.inFlight = null;
      if (mounted) _updateScreenState(() {});
    });
  }

  Future<void> _readAdminWindow(_AdminOrderWindow window,
      {required bool append, required bool force}) async {
    final loader =
        widget.orderPageLoader ?? MobileApi.instance.adminProductionOrderPage;
    var appendRead = append;
    final wanted = window.length + (append ? 20 : 0);
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final invalidation = window.invalidation;
        var cursor = appendRead ? window.cursor : null;
        final staged =
            appendRead ? [...window.pages] : <AdminProductionOrderPage>[];
        do {
          final page = await loader(AdminProductionOrderPageRequest(
            view: window.request.view,
            apparatus: window.request.apparatus,
            target: window.request.target,
            search: window.request.search,
            cursor: cursor,
            ifVersion: !appendRead &&
                    cursor == null &&
                    attempt == 0 &&
                    !force &&
                    !window.dirty &&
                    window.loaded
                ? window.pages.first.version
                : null,
          ));
          if (!mounted || window.account != _adminPageAccount) return;
          if (page == null) {
            if (window.invalidation != invalidation) {
              throw const MobileApiException(
                  code: 'order_page_changed', message: 'Navbat yangilandi');
            }
            window.error = null;
            return;
          }
          final snapshot = page.snapshot;
          if (_retiredSnapshotEpochs.contains(page.epoch) ||
              (_adminLiveEpoch == page.epoch &&
                  (page.revision ?? -1) < _adminLiveRevision) ||
              (_adminLiveEpoch.isNotEmpty &&
                  _adminLiveEpoch != _lastAppliedSnapshotEpoch &&
                  page.epoch == _lastAppliedSnapshotEpoch) ||
              (snapshot != null && _snapshotBehindSequenceMoves(snapshot))) {
            throw const MobileApiException(
                code: 'order_page_changed', message: 'Navbat yangilandi');
          }
          final expectedOffset = staged.fold<int>(0, (n, p) => n + p.length);
          if (page.offset != expectedOffset ||
              (staged.isNotEmpty && staged.first.version != page.version)) {
            throw const MobileApiException(
                code: 'order_page_changed', message: 'Navbat yangilandi');
          }
          final previousIds = {
            for (final p in staged) ...[
              ...p.orderIds,
              ...p.pendingOrders.map((o) => o.id),
              ...p.closedOrders.map((o) => o.orderId),
            ],
          };
          if ([
            ...page.orderIds,
            ...page.pendingOrders.map((o) => o.id),
            ...page.closedOrders.map((o) => o.orderId)
          ].any(previousIds.contains)) {
            throw const MobileApiException(
                code: 'order_page_changed', message: 'Navbat yangilandi');
          }
          staged.add(page);
          cursor = page.nextCursor;
          // Appending consumes exactly one page. A revision change refreshes
          // only the previously requested range, atomically, before displaying it.
          if (appendRead) break;
        } while (cursor != null &&
            staged.fold<int>(0, (n, p) => n + p.length) < wanted);
        _updateScreenState(() {
          final epoch = staged.first.epoch;
          if (epoch.isNotEmpty &&
              _lastAppliedSnapshotEpoch.isNotEmpty &&
              epoch != _lastAppliedSnapshotEpoch) {
            _retiredSnapshotEpochs.add(_lastAppliedSnapshotEpoch);
            for (final cached in _adminWindows.values) {
              if (cached != window) cached.pages = [];
            }
            _sequenceRevisions.clear();
            _sequenceVersions.clear();
            _adminSequenceAcks.clear();
            _lastAppliedSnapshotEpoch = epoch;
            if (_retiredSnapshotEpochs.contains(_adminLiveEpoch)) {
              _adminLiveEpoch = epoch;
              _adminLiveRevision = staged.first.revision ?? -1;
            }
          }
          window.pages = staged;
          window.validated = window.invalidation;
          window.error = null;
          if (window.request.view == 'sequence') {
            _sequenceNeedsSnapshot.remove(window.request.apparatus);
          }
          // Retain active tabs and pending writes; bound inactive apparatus/
          // search caches so browsing many scopes cannot accumulate every order.
          final pinned = {
            for (final module in _OpenedOrderModule.values)
              ..._adminModuleWindows(module),
          };
          if (_adminWindows.length > 16) {
            for (final entry in _adminWindows.entries.toList()) {
              if (_adminWindows.length <= 16) break;
              if (entry.value != window &&
                  !pinned.contains(entry.value) &&
                  entry.value.inFlight == null &&
                  !_pendingSequenceMoves
                      .containsKey(entry.value.request.apparatus)) {
                _adminWindows.remove(entry.key);
              }
            }
          }
          _rebuildAdminPageState();
          _loadError = null;
          _loading = false;
          _queueSnapshotContractError = false;
        });
        for (final page in staged) {
          unawaited(_loadAdminPageMetrics(page, window.account));
        }
        return;
      } catch (error) {
        if (!mounted || window.account != _adminPageAccount) return;
        if (error is MobileApiException &&
            error.code == 'order_page_changed' &&
            attempt < 2) {
          appendRead = false;
          continue;
        }
        _updateScreenState(() {
          window.error = error is MobileApiException
              ? error.message
              : 'Buyurtmalar yuklanmadi';
          _loading = false;
        });
        return;
      }
    }
  }

  void _rebuildAdminPageState() {
    // Windows keep their own ordered membership. The shared dictionaries only
    // cache card/detail data, with newer revisions winning for the same order.
    final windows = _adminWindows.values
        .where((w) => w.account == _adminPageAccount)
        .toList();
    final snapshots = [
      for (final w in windows)
        for (final p in w.pages)
          if (p.snapshot != null) p.snapshot!
    ]..sort((a, b) => (a.revision ?? 0).compareTo(b.revision ?? 0));
    final maps = <String, ProductionMapSaved>{};
    final mapRevisions = <String, int>{};
    final acknowledgedRevisions = Map.of(_sequenceRevisions);
    final acknowledgedVersions = Map.of(_sequenceVersions);
    _sequenceVersions.clear();
    _sequenceRevisions.clear();
    _queueStatesByApparatus.clear();
    _queueActionControlsByApparatus.clear();
    _stageStatesByOrderId.clear();
    _orderStatusesByOrderId.clear();
    _orderControlsByOrderId.clear();
    _earlyClosingOrderIds.clear();
    _frozenOrdersByApparatus.clear();
    _visibleOrderIdsByApparatus.clear();
    _customerByMapId = {};
    _sequenceByApparatus.clear();
    for (final snapshot in snapshots) {
      for (final map in snapshot.maps) {
        final id = map.map.id;
        maps[id] = map;
        if ((snapshot.revision ?? 0) > (mapRevisions[id] ?? -1)) {
          for (final states in _queueStatesByApparatus.values) {
            states.remove(id);
          }
          for (final controls in _queueActionControlsByApparatus.values) {
            controls.remove(id);
          }
          for (final ids in _visibleOrderIdsByApparatus.values) {
            ids.remove(id);
          }
          for (final orders in _frozenOrdersByApparatus.values) {
            orders.removeWhere((o) => o.orderId == id);
          }
          mapRevisions[id] = snapshot.revision ?? 0;
        }
        // Omitted overrides mean active, including after an unfreeze.
        _orderControlsByOrderId.remove(id);
        _earlyClosingOrderIds.remove(id);
      }
      _sequenceVersions.addAll(snapshot.sequenceVersions);
      _sequenceRevisions.addAll(snapshot.sequenceRevisions);
      _queuePoliciesByApparatus.addAll(snapshot.queuePolicies);
      _orderStatusesByOrderId.addAll(snapshot.orderStatuses);
      _orderControlsByOrderId.addAll(snapshot.orderControls);
      _earlyClosingOrderIds.addAll(snapshot.earlyClosingOrderIds);
      _stageStatesByOrderId.addAll(snapshot.stageStates);
      _customerByMapId.addAll(snapshot.orderCustomers);
      for (final entry in snapshot.queueStates.entries) {
        _queueStatesByApparatus
            .putIfAbsent(entry.key, () => {})
            .addAll(entry.value);
      }
      for (final entry in snapshot.queueActionControls.entries) {
        _queueActionControlsByApparatus
            .putIfAbsent(entry.key, () => {})
            .addAll(entry.value);
      }
      for (final entry in snapshot.frozenOrdersByApparatus.entries) {
        final values =
            _frozenOrdersByApparatus.putIfAbsent(entry.key, () => []);
        values.removeWhere(
            (old) => entry.value.any((next) => next.orderId == old.orderId));
        values.addAll(entry.value);
      }
      for (final entry in snapshot.visibleOrderIds.entries) {
        final values =
            _visibleOrderIdsByApparatus.putIfAbsent(entry.key, () => []);
        values.addAll(entry.value.where((id) => !values.contains(id)));
      }
    }
    for (final window in windows.where((w) =>
        w.request.view == 'sequence' &&
        w.request.search == _adminPageSearch &&
        w.loaded)) {
      _sequenceByApparatus[window.request.apparatus] = [
        for (final p in window.pages)
          ...?p.snapshot?.sequences[window.request.apparatus],
      ];
      final apparatus = window.request.apparatus;
      final ack = _adminSequenceAcks[apparatus];
      if (ack != null) {
        final snapshot = window.pages.first.snapshot;
        final revision = snapshot?.sequenceRevisions[apparatus];
        if (snapshot?.sequenceVersions[apparatus] == ack.version ||
            (revision != null &&
                ack.revision != null &&
                revision >= ack.revision!)) {
          _adminSequenceAcks.remove(apparatus);
        } else {
          // Background pages must not undo a confirmed move while this
          // apparatus's visible window is still waiting for reconciliation.
          _sequenceByApparatus[apparatus] = ack.orderIds;
        }
      }
    }
    for (final entry in acknowledgedRevisions.entries) {
      if (entry.value > (_sequenceRevisions[entry.key] ?? -1)) {
        _sequenceRevisions[entry.key] = entry.value;
        if (acknowledgedVersions[entry.key] != null) {
          _sequenceVersions[entry.key] = acknowledgedVersions[entry.key]!;
        }
      }
    }
    _orders = maps.values.toList();
    final ordersWindow = _adminWindow('orders');
    _pendingOrders = [for (final p in ordersWindow.pages) ...p.pendingOrders];
    _closedOrders = [
      for (final p in _adminWindow('closed').pages) ...p.closedOrders
    ];
    final auditPages = _adminWindow('audit').pages;
    final report = auditPages.firstOrNull?.workflowAudit;
    _workflowAudit = report == null
        ? null
        : AdminProductionWorkflowAuditReport(
            ok: report.ok,
            checkedOrderCount: report.checkedOrderCount,
            checkedBatchCount: report.checkedBatchCount,
            checkedSessionCount: report.checkedSessionCount,
            totalViolations: report.totalViolations,
            violations: [
              for (final page in auditPages) ...?page.workflowAudit?.violations
            ],
          );
    _baseMetrajByMapId = {
      for (final o in _orders)
        if ((o.map.baseLength ?? 0) > 0 || _baseMetrajByMapId[o.map.id] != null)
          o.map.id: (o.map.baseLength ?? 0) > 0
              ? o.map.baseLength!
              : _baseMetrajByMapId[o.map.id]!
    };
    _orderKgByMapId = {
      for (final o in _orders)
        if ((o.map.orderKg ?? 0) > 0 || _orderKgByMapId[o.map.id] != null)
          o.map.id: (o.map.orderKg ?? 0) > 0
              ? o.map.orderKg!
              : _orderKgByMapId[o.map.id]!
    };
    _adminMetricSignatures.removeWhere((id, _) => !maps.containsKey(id));
    if (snapshots.isNotEmpty) {
      _rememberSnapshotVersion(snapshots.last);
      // A revision only certifies the current window's rows. Hidden cached
      // pages must not make an old detail row appear to cover a newer action.
      final activeSnapshots = [
        for (final window in _adminModuleWindows(_module))
          for (final page in window.pages)
            if (page.snapshot != null) page.snapshot!,
      ];
      final currentIds = {
        for (final snapshot in activeSnapshots)
          for (final map in snapshot.maps) map.map.id
      };
      Map<String, T> current<T>(Map<String, T> values) => {
            for (final entry in values.entries)
              if (currentIds.contains(entry.key)) entry.key: entry.value
          };
      final currentRevision = activeSnapshots.isEmpty
          ? null
          : activeSnapshots.map((s) => s.revision ?? 0).reduce(min);
      _canonicalQueueSnapshot = AdminApparatusQueueSnapshot(
        sequences: {
          for (final e in _sequenceByApparatus.entries)
            e.key: e.value.where(currentIds.contains).toList()
        },
        sequenceVersions: Map.of(_sequenceVersions),
        sequenceRevisions: Map.of(_sequenceRevisions),
        visibleOrderIds: {
          for (final e in _visibleOrderIdsByApparatus.entries)
            e.key: e.value.where(currentIds.contains).toList()
        },
        queueStates: {
          for (final e in _queueStatesByApparatus.entries)
            e.key: current(e.value)
        },
        queuePolicies: Map.of(_queuePoliciesByApparatus),
        orderControls: current(_orderControlsByOrderId),
        earlyClosingOrderIds: _earlyClosingOrderIds.intersection(currentIds),
        queueActionControls: {
          for (final e in _queueActionControlsByApparatus.entries)
            e.key: current(e.value)
        },
        stageStates: current(_stageStatesByOrderId),
        orderStatuses: current(_orderStatusesByOrderId),
        orderCustomers: current(_customerByMapId),
        maps: _orders.where((o) => currentIds.contains(o.map.id)).toList(),
        revision: currentRevision,
        epoch: snapshots.last.epoch,
      );
    }
    _queueSnapshotNeedsReconcile = _sequenceNeedsSnapshot.isNotEmpty ||
        _adminModuleWindows(_module).any((window) => !window.loaded || window.dirty);
    _resumeSequenceMoves();
  }

  Future<void> _loadAdminPageMetrics(
      AdminProductionOrderPage page, String account) async {
    for (final order in page.snapshot?.maps ?? <ProductionMapSaved>[]) {
      final id = order.map.id;
      final template = page.calculationTemplates[id];
      final templates = [if (template != null) template];
      final signature =
          jsonEncode([order.map.toJson(), template?.toJson()]).hashCode;
      if (_adminMetricSignatures[id] == signature) continue;
      _adminMetricSignatures[id] = signature;
      final kg = _productionMapOrderKg(order.map, templates);
      final base = await _productionMapBaseMetrajForOrder(order.map, templates);
      if (!mounted ||
          account != _adminPageAccount ||
          _adminMetricSignatures[id] != signature) {
        return;
      }
      _updateScreenState(() {
        if (kg != null) _orderKgByMapId = {..._orderKgByMapId, id: kg};
        if (base != null) {
          _baseMetrajByMapId = {..._baseMetrajByMapId, id: base};
        }
      });
    }
  }

  List<ProductionMapSaved> _adminSequenceOrders(AdminApparatus apparatus) {
    final window = _adminWindow('sequence', apparatus: apparatus.id);
    final orders = window.orders;
    if (_queuePoliciesByApparatus[apparatus.id]?.policy ==
        ApparatusQueuePolicy.freePick) {
      return orders;
    }
    return _applyApparatusOrderSequence(
        orders: orders,
        sequence: _projectSequenceMoves(
            apparatus.id,
            _sequenceByApparatus[apparatus.id] ??
                orders.map((o) => o.map.id).toList()));
  }

  void _adminSearchChanged(String value) {
    _adminSearchDebounce?.cancel();
    _adminSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final query = String.fromCharCodes(value.trim().runes.take(120));
      if (query == _adminPageSearch) return;
      _updateScreenState(() {
        _adminPageSearch = query;
        _selectedMoveOrderIds.clear();
        _rebuildAdminPageState();
      });
      unawaited(_ensureAdminModule(_module));
    });
  }

  Widget _wrapAdminModule(_OpenedOrderModule module, Widget child) {
    if (!_adminPaging || module == _OpenedOrderModule.move) return child;
    final windows = _adminModuleWindows(module);
    return windows.isEmpty ? child : _adminWindowWidget(windows.single, child);
  }

  Widget _wrapAdminMovePane(bool top, Widget child) {
    if (!_adminPaging) return child;
    final windows = _adminModuleWindows(_OpenedOrderModule.move);
    return windows.length != 2
        ? child
        : _adminWindowWidget(windows[top ? 0 : 1], child);
  }

  Widget _adminWindowWidget(_AdminOrderWindow window, Widget child) =>
      _AdminOrderPageViewport(
        key: ValueKey(window),
        window: window,
        child: child,
        onMore: () => unawaited(_loadAdminWindow(window, append: true)),
        onRetry: () => unawaited(_loadAdminWindow(window, force: true)),
      );
}

/// Layout notifications and offscreen tabs never start pagination. Only user
/// scrolling (or the explicit button) requests the next bounded page.
class _AdminOrderPageViewport extends StatefulWidget {
  const _AdminOrderPageViewport(
      {super.key,
      required this.window,
      required this.child,
      required this.onMore,
      required this.onRetry});
  final _AdminOrderWindow window;
  final Widget child;
  final VoidCallback onMore;
  final VoidCallback onRetry;
  @override
  State<_AdminOrderPageViewport> createState() =>
      _AdminOrderPageViewportState();
}

class _AdminOrderPageViewportState extends State<_AdminOrderPageViewport> {
  bool _userScrolling = false;
  @override
  Widget build(BuildContext context) {
    final window = widget.window;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis != Axis.vertical) return false;
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _userScrolling = true;
        }
        if (notification is UserScrollNotification &&
            notification.direction != ScrollDirection.idle) {
          _userScrolling = true;
        }
        if (_userScrolling &&
            notification is ScrollUpdateNotification &&
            notification.metrics.extentAfter < 400 &&
            window.inFlight == null &&
            window.error == null &&
            window.cursor != null) {
          // One fetch per gesture; a rebuild must not drain the remaining list.
          _userScrolling = false;
          widget.onMore();
        }
        if (notification is ScrollEndNotification) _userScrolling = false;
        return false;
      },
      child: Column(children: [
        Expanded(
            child: !window.loaded && window.inFlight != null
                ? const Center(child: CircularProgressIndicator())
                : PageStorage(
                    bucket: window.storage,
                    child: KeyedSubtree(
                        key: const PageStorageKey('admin-order-window'),
                        child: widget.child))),
        if (window.inFlight != null && window.loaded)
          const LinearProgressIndicator(),
        if (window.error != null)
          ListTile(
              dense: true,
              title: Text(window.error!),
              trailing: IconButton(
                  onPressed: widget.onRetry, icon: const Icon(Icons.refresh)))
        else if (window.cursor != null && window.inFlight == null)
          TextButton(
              onPressed: widget.onMore,
              child: Text('${window.length} / ${window.total} · Yana 20 ta')),
      ]),
    );
  }
}
