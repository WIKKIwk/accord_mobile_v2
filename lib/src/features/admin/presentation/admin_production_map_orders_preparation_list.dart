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

  bool get _current => mounted && _scope == currentSessionReadScope();

  @override
  void initState() {
    super.initState();
    _scope = currentSessionReadScope();
    WidgetsBinding.instance.addObserver(this);
    AppSession.instance.revision.addListener(_sessionChanged);
    _scrollController.addListener(_scrollChanged);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      _apparatus =
          await AdminSequenceApparatusStore.instance.loadSavedApparatusId() ??
              '';
    } catch (_) {
      // A missing device preference must not prevent the server's first picker.
    }
    if (_current) await _reload();
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

  Future<void> _reload() {
    final pending = _read;
    if (pending != null) {
      _reloadQueued = true;
      return pending;
    }
    return _loadPage();
  }

  Future<void> _loadMore() {
    if (_read != null || _window?.nextCursor == null) {
      return _read ?? Future.value();
    }
    return _loadPage(append: true);
  }

  Future<void> _loadPage({bool append = false}) {
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
        var next = await MobileApi.instance.preparationOrders(
            apparatus: apparatus, search: search, cursor: cursor);
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
        while (!append &&
            pageRows.length < retainedLength &&
            next.nextCursor != null) {
          final usedCursor = next.nextCursor;
          final following = await MobileApi.instance.preparationOrders(
              apparatus: baseline.apparatusId,
              search: search,
              cursor: usedCursor);
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
        setState(() {
          _window = next;
          _apparatus = next.apparatusId;
          if (!append) {
            _rows.clear();
            _presentationOrders.clear();
            _imagesEnabled.clear();
          }
          _rows.addAll(pageRows);
          for (final row in pageRows) {
            _presentationOrders[row.id] = row.toPresentationOrder();
          }
          _loading = false;
        });
        _listRevision.value++;
        // Paint every visible text row before any thumbnail provider is
        // mounted. Offscreen rows remain unbuilt by the sliver list.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_current || generation != _generation) return;
          setState(() => _imagesEnabled.addAll(pageRows.map((row) => row.id)));
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
        unawaited(_reload());
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
        MobileApi.instance.preparationOrdersLive(_window!, search: _search);
    _live = source.listen((event) {
      if (!_current || generation != _liveGeneration || event is! Map) return;
      _reconnectAttempt = 0;
      if (event['type'] == 'invalidate' || event['resync'] == true) {
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
      }
    }, onError: (Object _, StackTrace __) => reconnect(), onDone: reconnect);
  }

  void _changeQuery({String? apparatus, String? search}) {
    _generation++;
    _read = null;
    _reloadQueued = false;
    _stopLive();
    setState(() {
      _apparatus = apparatus ?? _apparatus;
      _search = search ?? _search;
      _rows.clear();
      _presentationOrders.clear();
      _imagesEnabled.clear();
      _filterExpanded = false;
      _loading = true;
    });
    _listRevision.value++;
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    unawaited(_reload());
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
              onRefresh: _reload,
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
