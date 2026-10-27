part of 'admin_production_map_orders_screen.dart';

/// The preparation master's sequence contains display labels only. Neither the
/// global queue nor the warehouse snapshot is needed to paint these rows.
class _PreparationOrdersListState extends State<AdminProductionMapOrdersScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();
  final _listRevision = ValueNotifier<int>(0);
  PreparationOrderListWindow? _window;
  final _rows = <PreparationOrderListRow>[];
  final _presentationOrders = <String, ProductionMapSaved>{};
  final _imagesEnabled = <String>{};
  StreamSubscription<Object>? _live;
  Timer? _reconnect;
  Timer? _searchDebounce;
  Future<void>? _read;
  String _scope = '';
  String _apparatus = '';
  String _search = '';
  String? _error;
  int _generation = 0;
  int _liveGeneration = 0;
  int _reconnectAttempt = 0;
  bool _loading = true;
  bool _foreground = true;
  bool _filterExpanded = false;
  bool _openingDetail = false;
  bool _reloadQueued = false;
  bool _forceReloadQueued = false;

  PreparationOrdersWarmStore get _store => PreparationOrdersWarmStore.instance;

  bool get _current => mounted && _scope == currentSessionReadScope();

  @override
  void initState() {
    super.initState();
    _scope = currentSessionReadScope();
    WidgetsBinding.instance.addObserver(this);
    AppSession.instance.revision.addListener(_sessionChanged);
    _scrollController.addListener(_scrollChanged);
    _apparatus = AdminSequenceApparatusStore.instance.cachedApparatusId ?? '';
    final cached = _store.peek(apparatus: _apparatus);
    if (cached != null) _applyWindow(cached, persist: false);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final selected =
          await AdminSequenceApparatusStore.instance.loadSavedApparatusId();
      if (!_current) return;
      if (selected != null && selected != _apparatus) {
        _apparatus = selected;
        final cached = _store.peek(apparatus: selected);
        if (cached != null) {
          _applyWindow(cached, persist: false);
        } else {
          _clearRows();
        }
      }
    } catch (_) {
      // A missing device preference must not prevent the server's first picker.
    }
    if (!_current) return;
    final read = _reload();
    // Optional disk storage must never hold up the network or the first frame.
    unawaited(_restoreCached(_generation, _apparatus, _search));
    await read;
  }

  Future<void> _restoreCached(
      int generation, String apparatus, String search) async {
    if (_rows.isNotEmpty) return;
    final cached = await _store.restore(apparatus: apparatus, search: search);
    if (!_current ||
        generation != _generation ||
        apparatus != _apparatus ||
        search != _search ||
        _window != null ||
        _read == null ||
        _error != null ||
        cached == null) return;
    _applyWindow(cached, persist: false, keepLoading: _read != null);
  }

  void _clearRows() {
    setState(() {
      _window = null;
      _rows.clear();
      _presentationOrders.clear();
      _imagesEnabled.clear();
    });
    _listRevision.value++;
  }

  bool _sameRow(PreparationOrderListRow a, PreparationOrderListRow b) =>
      a.id == b.id &&
      a.code == b.code &&
      a.orderNumber == b.orderNumber &&
      a.title == b.title &&
      a.customerName == b.customerName &&
      a.imageId == b.imageId &&
      a.position == b.position;

  void _applyWindow(PreparationOrderListWindow next,
      {bool persist = true, bool keepLoading = false}) {
    final previous = {for (final row in _rows) row.id: row};
    final ids = next.rows.map((row) => row.id).toSet();
    setState(() {
      _window = next;
      _apparatus = next.apparatusId;
      _rows
        ..clear()
        ..addAll(next.rows);
      _presentationOrders.removeWhere((id, _) => !ids.contains(id));
      _imagesEnabled.retainAll(ids);
      for (final row in next.rows) {
        final old = previous[row.id];
        if (old == null || !_sameRow(old, row)) {
          _presentationOrders[row.id] = row.toPresentationOrder();
        }
      }
      _loading = keepLoading;
      _error = null;
    });
    _listRevision.value++;
    if (persist) _store.remember(next, search: _search);
    final generation = _generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_current || generation != _generation) return;
      if (!_imagesEnabled.containsAll(ids)) {
        setState(() => _imagesEnabled.addAll(ids));
      }
    });
  }

  void _sessionChanged() {
    if (_current) return;
    _generation++;
    _stopLive();
    if (!mounted) return;
    setState(() {
      _window = null;
      _rows.clear();
      _presentationOrders.clear();
      _imagesEnabled.clear();
      _loading = false;
      _error = 'Akkaunt o‘zgargan. Sahifani qayta oching.';
    });
    _listRevision.value++;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (_current) unawaited(_reload());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _stopLive();
    }
  }

  void _scrollChanged() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 300 &&
        _window?.nextCursor != null &&
        _read == null &&
        _error == null) {
      unawaited(_loadMore());
    }
  }

  Future<void> _reload({bool force = false}) {
    final pending = _read;
    if (pending != null) {
      _reloadQueued = true;
      _forceReloadQueued |= force;
      return pending;
    }
    return _loadPage(force: force);
  }

  Future<void> _loadMore() {
    if (_read != null || _window?.nextCursor == null) {
      return _read ?? Future.value();
    }
    return _loadPage(append: true);
  }

  Future<void> _loadPage({bool append = false, bool force = false}) {
    if (!_current) return Future.value();
    final generation = ++_generation;
    final apparatus = _apparatus;
    final search = _search;
    final previous = _window;
    final retainedLength = append ? 0 : _rows.length;
    final cursor = append ? previous?.nextCursor : null;
    _stopLive();
    setState(() {
      _loading = true;
      _error = null;
    });
    late final Future<void> pending;
    pending = () async {
      try {
        var next = await _store.read(
            apparatus: apparatus,
            search: search,
            cursor: cursor,
            baseline: append ? null : previous,
            fresh: true,
            force: force);
        if (!_current || generation != _generation) return;
        if (append &&
            (next.version != previous!.version ||
                next.scope != previous.scope ||
                next.epoch != previous.epoch ||
                next.apparatusId != previous.apparatusId)) {
          _reloadQueued = true;
          return;
        }
        final pageRows = [...next.rows];
        // Refresh the already visible prefix, preserving deep scroll and an
        // open sheet from a later page. Every page must share one revision.
        final baseline = next;
        final retainedPrefix = max(retainedLength, _rows.length);
        while (!append &&
            pageRows.length < retainedPrefix &&
            next.nextCursor != null) {
          final usedCursor = next.nextCursor;
          final following = await _store.read(
              apparatus: baseline.apparatusId,
              search: search,
              cursor: usedCursor,
              fresh: true);
          if (!_current || generation != _generation) return;
          if (following.version != baseline.version ||
              following.scope != baseline.scope ||
              following.epoch != baseline.epoch ||
              following.apparatusId != baseline.apparatusId ||
              following.nextCursor == usedCursor ||
              following.rows.isEmpty) {
            throw const MobileApiException(
                code: 'preparation_orders_changed',
                statusCode: 409,
                message: 'Buyurtmalar o‘zgardi. Qayta yuklang.');
          }
          pageRows.addAll(following.rows);
          next = following;
        }
        final existingIds =
            append ? _rows.map((row) => row.id).toSet() : <String>{};
        if (pageRows.any((row) => !existingIds.add(row.id)) ||
            (append && next.nextCursor != null && next.nextCursor == cursor)) {
          throw const MobileApiException(
              code: 'preparation_orders_invalid',
              message: 'Buyurtmalar yuklanmadi. Qayta urinib ko‘ring.');
        }
        // The window always describes the whole visible prefix, including its
        // final cursor. Cache restores, 304s and live deltas share this baseline.
        _applyWindow(next.copyWith(rows: [
          if (append) ..._rows,
          ...pageRows,
        ]));
        // Paint every visible text row before any thumbnail provider is
        // mounted. Offscreen rows remain unbuilt by the sliver list.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_current || generation != _generation) return;
          _connectLive();
        });
      } catch (error) {
        if (!_current || generation != _generation) return;
        if (append && error is MobileApiException && error.statusCode == 409) {
          _reloadQueued = true;
        } else {
          setState(() {
            _error = error is MobileApiException
                ? error.message
                : 'Buyurtmalar yuklanmadi. Qayta urinib ko‘ring.';
            if (error is MobileApiException &&
                (error.statusCode == 401 || error.statusCode == 403)) {
              _window = null;
              _rows.clear();
              _presentationOrders.clear();
              _imagesEnabled.clear();
              unawaited(_store.forget(apparatus: apparatus, search: search));
            }
          });
          _listRevision.value++;
        }
      } finally {
        if (_current && generation == _generation) {
          setState(() => _loading = false);
        }
      }
    }()
        .whenComplete(() {
      if (!identical(_read, pending)) return;
      _read = null;
      if (_current && _foreground && _reloadQueued) {
        _reloadQueued = false;
        final force = _forceReloadQueued;
        _forceReloadQueued = false;
        unawaited(_reload(force: force));
      }
    });
    _read = pending;
    return pending;
  }

  void _stopLive() {
    _liveGeneration++;
    _reconnect?.cancel();
    _reconnect = null;
    unawaited(_live?.cancel());
    _live = null;
  }

  void _connectLive() {
    if (!_current || !_foreground || _window == null || _error != null) return;
    _stopLive();
    final generation = _liveGeneration;
    void reconnect() {
      if (!_current ||
          !_foreground ||
          generation != _liveGeneration ||
          widget.liveEventsLoader != null) {
        return;
      }
      _reconnect?.cancel();
      _reconnect =
          Timer(productionMapLiveReconnectDelay(_reconnectAttempt++), () {
        if (_current && generation == _liveGeneration) _connectLive();
      });
    }

    final Stream<Object> source = widget.liveEventsLoader?.call() ??
        MobileApi.instance.preparationOrdersLive(_window!,
            search: _search, length: max(30, _rows.length));
    _live = source.listen((event) {
      if (!_current || generation != _liveGeneration || event is! Map) return;
      _reconnectAttempt = 0;
      if (event['type'] == 'invalidate' || event['resync'] == true) {
        _stopLive();
        unawaited(_reload());
      } else if (event['type'] == 'error') {
        _stopLive();
        setState(() {
          _window = null;
          _rows.clear();
          _presentationOrders.clear();
          _imagesEnabled.clear();
          _error = 'Buyurtmalarga kirish huquqi o‘zgargan. Qayta yuklang.';
        });
        _listRevision.value++;
        unawaited(_store.forget(apparatus: _apparatus, search: _search));
      } else {
        _applyLiveEvent(event.cast<String, dynamic>());
      }
    }, onError: (Object _, StackTrace __) => reconnect(), onDone: reconnect);
  }

  void _applyLiveEvent(Map<String, dynamic> event) {
    final before = _window;
    if (before == null) return;
    if (event['epoch'] == before.epoch &&
        event['rev'] is int &&
        (event['rev'] as int) < before.revision) return;
    if (event['type'] == 'list_delta' &&
        event['epoch'] == before.epoch &&
        event['scope'] == before.scope &&
        event['version'] == before.version) return;
    try {
      switch (event['type']) {
        case 'ready':
        case 'checkpoint':
          if (event['epoch'] != before.epoch ||
              event['scope'] != before.scope ||
              (event['version'] != null &&
                  event['version'] != before.version) ||
              event['rev'] is! int) {
            throw const FormatException('Preparation baseline changed');
          }
          final revision = event['rev'] as int;
          if (revision < before.revision) return;
          // A checkpoint validates the existing rows without rebuilding them,
          // remounting thumbnails or restarting the socket.
          if (revision != before.revision) {
            _window = before.copyWith(revision: revision);
            _store.remember(_window!, search: _search);
          }
          if (_error != null) setState(() => _error = null);
        case 'list_snapshot':
          final next = PreparationOrderListWindow.fromJson(event);
          if (next.search != _search) {
            throw const FormatException('Preparation query changed');
          }
          _generation++;
          _applyWindow(next);
        case 'list_delta':
          final next = before.applyLiveDelta(event);
          if (next.search != _search) {
            throw const FormatException('Preparation query changed');
          }
          _generation++;
          _applyWindow(next);
      }
    } catch (_) {
      // A missing baseline gets one shared HTTP repair, with no repeated
      // invalidation loop while that read is running.
      _stopLive();
      unawaited(_reload());
    }
  }

  void _changeQuery({String? apparatus, String? search}) {
    _generation++;
    _read = null;
    _reloadQueued = false;
    _forceReloadQueued = false;
    _stopLive();
    setState(() {
      _apparatus = apparatus ?? _apparatus;
      _search = (search ?? _search).trim().toLowerCase();
      _window = null;
      _rows.clear();
      _presentationOrders.clear();
      _imagesEnabled.clear();
      _filterExpanded = false;
      _loading = true;
    });
    _listRevision.value++;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    final cached = _store.peek(apparatus: _apparatus, search: _search);
    if (cached != null) _applyWindow(cached, persist: false);
    final read = _reload();
    unawaited(_restoreCached(_generation, _apparatus, _search));
    unawaited(read);
  }

  void _searchChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (_current) _changeQuery(search: text.trim());
    });
  }

  Future<void> _showDetail(PreparationOrderListRow row) async {
    if (!_current || _openingDetail) return;
    _openingDetail = true;
    final listScope = _window!.scope;
    bool current() =>
        _current &&
        _window?.scope == listScope &&
        _rows.any((item) => item.id == row.id);
    final apparatus = _window!.apparatus;
    double? baseMetraj;
    double? orderKg;
    Future<AdminApparatusQueueSnapshot> load() async {
      final snapshot = await MobileApi.instance.preparationOrderDetail(row.id);
      if (!current()) {
        throw const MobileApiException(
            code: 'preparation_order_changed',
            message: 'Buyurtma o‘zgargan. Qayta oching.');
      }
      final map = snapshot.maps.single.map;
      final templates = snapshot.calculationTemplates.values.toList();
      baseMetraj = await _productionMapBaseMetrajForOrder(map, templates);
      orderKg = _productionMapOrderKg(map, templates);
      return snapshot;
    }

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        shape: _orderDetailSheetShape,
        clipBehavior: Clip.antiAlias,
        sheetAnimationStyle: AppMotion.sheetEaseOut,
        builder: (_) => ValueListenableBuilder<int>(
          valueListenable: _listRevision,
          builder: (_, __, ___) => _AdminInitialDetailHost(
            isCurrent: current,
            load: load,
            onReady: (_) {},
            builder: (detail, error, retry) {
              final saved = detail?.maps.single ??
                  _presentationOrders[row.id] ??
                  row.toPresentationOrder();
              return _ReadOnlyOrderDetailSheet(
                order: saved,
                apparatusCatalog: apparatus,
                detailPending: detail == null,
                detailError: error,
                onRetryDetail: retry,
                baseMetraj: baseMetraj ?? saved.map.baseLength,
                orderKg: orderKg ?? saved.map.orderKg,
                customerName:
                    detail?.orderCustomers[row.id] ?? row.customerName,
                queueStatesByApparatus: detail?.queueStates ?? const {},
                stageStatesByOrderId: detail?.stageStates ?? const {},
                queueActionControlsByApparatus:
                    detail?.queueActionControls ?? const {},
                initialOrderControls: detail?.orderControls ?? const {},
                allowWipQrReprint: false,
              );
            },
          ),
        ),
      );
    } finally {
      _openingDetail = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final window = _window;
    final rowIndices = {
      for (var index = 0; index < _rows.length; index++)
        ValueKey('preparation-order-${_rows[index].id}'): index,
    };
    return AppShell(
      drawer: PreparationDrawer(
        selectedRouteName: AppRoutes.supplySequence,
        onNavigate: (route) =>
            Navigator.of(context).pushReplacementNamed(route),
      ),
      title: '',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      profileActionListenable: _searchFocus,
      showProfileActionResolver: () => !_searchFocus.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocus,
        hintText: context.l10n.productionText('worker.queue.search.sequence'),
        onChanged: _searchChanged,
        onClear: () {
          _searchController.clear();
          _searchChanged('');
        },
        onBackWithContext: (context) =>
            AppShellDrawerScope.maybeOf(context)?.openDrawer(),
        leadingIcon: Icons.menu_rounded,
        leadingTooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      ),
      bottom: const PreparationDock(),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: _loading && _rows.isEmpty
          ? const Align(
              alignment: Alignment.topCenter,
              child: _OrdersConnectionProgress())
          : AppRefreshIndicator(
              onRefresh: () => _reload(force: true),
              allowRefreshOnShortContent: true,
              child: CustomScrollView(
                key: const ValueKey('preparation-orders-list'),
                controller: _scrollController,
                physics: const TopRefreshScrollPhysics(),
                slivers: [
                  if (_error != null)
                    SliverToBoxAdapter(
                        child: AppRetryState(
                      message: _error!,
                      onRetry: _reload,
                    )),
                  if (window != null)
                    SliverToBoxAdapter(
                        child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                      child: AdminSequenceApparatusFilter(
                        apparatus: window.apparatus,
                        selectedId: _apparatus,
                        expanded: _filterExpanded,
                        onToggle: () =>
                            setState(() => _filterExpanded = !_filterExpanded),
                        onSelect: (item) {
                          unawaited(AdminSequenceApparatusStore.instance
                              .saveApparatus(item));
                          _changeQuery(apparatus: item.id);
                        },
                      ),
                    )),
                  if (_rows.isEmpty && _error == null)
                    const SliverToBoxAdapter(
                        child: Padding(
                      padding: EdgeInsets.all(24),
                      child: UrduAwareText('Mos buyurtma topilmadi.'),
                    )),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    sliver: SliverList.builder(
                      itemCount: _rows.length,
                      findChildIndexCallback: (key) => rowIndices[key],
                      itemBuilder: (context, index) {
                        final row = _rows[index];
                        return Padding(
                          key: ValueKey('preparation-order-${row.id}'),
                          padding: const EdgeInsets.only(
                              bottom: M3SegmentedListGeometry.gap),
                          child: _SequenceOrderRow(
                            slot: M3SegmentedListGeometry
                                .standaloneListSlotForIndex(
                                    index, _rows.length),
                            order: _presentationOrders[row.id]!,
                            showApparatusCount: false,
                            imagesEnabled: _imagesEnabled.contains(row.id),
                            index: index,
                            position: row.position,
                            readOnly: true,
                            canReorder: false,
                            customerName: row.customerName,
                            onTap: () => _showDetail(row),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_loading)
                    const SliverToBoxAdapter(
                        child: Center(child: AppLoadingIndicator()))
                  else if (window?.nextCursor != null && _error == null)
                    SliverToBoxAdapter(
                        child: Center(
                            child: TextButton(
                      onPressed: _loadMore,
                      child: const UrduAwareText('Yana yuklash'),
                    ))),
                  SliverToBoxAdapter(
                      child: SizedBox(
                          height:
                              MediaQuery.viewPaddingOf(context).bottom + 136)),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _generation++;
    _stopLive();
    _searchDebounce?.cancel();
    AppSession.instance.revision.removeListener(_sessionChanged);
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    _listRevision.dispose();
    super.dispose();
  }
}
