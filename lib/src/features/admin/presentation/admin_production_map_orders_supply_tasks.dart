part of 'admin_production_map_orders_screen.dart';

/// Role-scoped task rows never initialize the global production snapshot.
class _SupplyTasksScreenState extends State<AdminProductionMapOrdersScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  SupplyTaskWindow? _window;
  List<ProductionMapSaved> _orders = const [];
  StreamSubscription<SupplyTaskMessage>? _live;
  Timer? _reconnect;
  Timer? _searchDebounce;
  Timer? _firstMessage;
  Future<void>? _read;
  Object? _error;
  String _scope = '';
  String _apparatusId = '';
  String _search = '';
  int _limit = 10;
  int _generation = 0;
  int _socketGeneration = 0;
  int _reconnectAttempt = 0;
  int _repairBudget = 1;
  bool _loading = true;
  bool _foreground = true;
  bool _openingDetail = false;
  final Set<String> _retiredEpochs = {};

  String get _kind => widget.materialTasksMode ? 'material' : 'qolip';
  bool get _current => mounted && _scope == currentSessionReadScope();

  @override
  void initState() {
    super.initState();
    _scope = currentSessionReadScope();
    WidgetsBinding.instance.addObserver(this);
    AppSession.instance.revision.addListener(_sessionChanged);
    unawaited(_start());
  }

  Future<void> _start() async {
    final saved =
        await AdminSequenceApparatusStore.instance.loadSavedApparatusId();
    if (!_current) return;
    _apparatusId = saved ?? '';
    await _refresh(fresh: false);
  }

  void _sessionChanged() {
    if (!_current) {
      _generation++;
      _stopLive();
      if (mounted) {
        setState(() {
          _window = null;
          _orders = const [];
          _loading = false;
          _error = const MobileApiException(code: 'unauthorized', message: '');
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      if (_current && _read == null) {
        if (_window == null) {
          unawaited(_refresh());
        } else {
          _connect();
        }
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _stopLive();
    }
  }

  Future<void> _refresh({bool fresh = true}) {
    final existing = _read;
    if (existing != null) return existing;
    final pending = _loadWindow(fresh: fresh);
    _read = pending;
    return pending.whenComplete(() {
      if (identical(_read, pending)) {
        _read = null;
        if (_current && _window != null && _error == null) _connect();
      }
    });
  }

  Future<void> _loadWindow({required bool fresh}) async {
    if (!_current) return;
    final generation = ++_generation;
    final apparatus = _apparatusId;
    final limit = _limit;
    final search = _search;
    _stopLive();
    setState(() => _error = null);
    try {
      final loader = widget.supplyTaskWindowLoader;
      final next = loader != null
          ? await loader(
              kind: _kind, apparatus: apparatus, limit: limit, search: search)
          : await SupplyTasksWarmStore.instance.read(
              kind: _kind,
              apparatus: apparatus,
              limit: limit,
              search: search,
              fresh: fresh);
      if (!_current || generation != _generation) return;
      if (next.kind != _kind || next.limit != limit || next.search != search) {
        throw const FormatException('Mismatched task window');
      }
      _publish(next);
    } catch (error) {
      if (!_current || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = error;
        if (error is MobileApiException &&
            (error.statusCode == 401 || error.statusCode == 403)) {
          _window = null;
          _orders = const [];
        }
      });
    }
  }

  void _publish(SupplyTaskWindow next) {
    if (_retiredEpochs.contains(next.epoch)) {
      throw const FormatException('Retired task epoch');
    }
    if (_window != null && _window!.epoch != next.epoch) {
      _retiredEpochs.add(_window!.epoch);
    }
    final changed = _window?.version != next.version ||
        _window?.scope != next.scope ||
        _window?.epoch != next.epoch;
    void apply() {
      if (changed) {
        _orders = [for (final row in next.rows) row.toPresentationOrder()];
      }
      _window = next;
      _apparatusId = next.apparatusId;
      _loading = false;
      _error = null;
    }

    if (changed || _loading || _error != null) {
      setState(apply);
    } else {
      // An unrelated commit advances continuity without rebuilding any rows.
      apply();
    }
    if (widget.supplyTaskWindowLoader == null) {
      SupplyTasksWarmStore.instance.remember(next);
    }
  }

  void _stopLive() {
    _socketGeneration++;
    _reconnect?.cancel();
    _reconnect = null;
    _firstMessage?.cancel();
    _firstMessage = null;
    unawaited(_live?.cancel());
    _live = null;
  }

  void _connect() {
    if (!_current || !_foreground || _window == null) return;
    _stopLive();
    final generation = _socketGeneration;
    final baseline = _window!;
    final stream = (widget.supplyTaskEventsLoader ??
        MobileApi.instance.supplyTaskLive)(baseline);
    _firstMessage = Timer(
        const Duration(seconds: 10), () => _scheduleReconnect(generation));
    _live = stream.listen((message) {
      if (!_current || !_foreground || generation != _socketGeneration) return;
      try {
        final current = _window!;
        final next = message.applyTo(current);
        _firstMessage?.cancel();
        _firstMessage = null;
        if (next.kind != current.kind ||
            (next.apparatusId != current.apparatusId &&
                message is! SupplyTaskSnapshot) ||
            next.limit != current.limit ||
            next.search != current.search) {
          throw const FormatException('Task stream changed query');
        }
        if (next.revision > current.revision ||
            next.epoch != current.epoch ||
            next.scope != current.scope) {
          _repairBudget = 1;
        }
        _reconnectAttempt = 0;
        if (!identical(next, current)) _publish(next);
      } catch (error) {
        _streamError(error, generation);
      }
    },
        onError: (Object error) => _streamError(error, generation),
        onDone: () => _scheduleReconnect(generation));
  }

  void _streamError(Object error, int generation) {
    if (!_current || generation != _socketGeneration) return;
    if (error is FormatException ||
        (error is MobileApiException &&
            const {'supply_tasks_resync', 'supply_tasks_invalid'}
                .contains(error.code))) {
      _stopLive();
      if (_repairBudget > 0) {
        _repairBudget--;
        unawaited(_refresh());
      } else {
        setState(() => _error = error);
      }
      return;
    }
    if (error is MobileApiException &&
        (error.statusCode == 401 ||
            error.statusCode == 403 ||
            const {'unauthorized', 'forbidden'}.contains(error.code))) {
      _stopLive();
      if (widget.supplyTaskWindowLoader == null) {
        SupplyTasksWarmStore.instance.invalidate(kind: _kind);
      }
      setState(() {
        _window = null;
        _orders = const [];
        _error = error;
      });
      return;
    }
    _scheduleReconnect(generation);
  }

  void _scheduleReconnect(int generation) {
    if (!_current ||
        !_foreground ||
        generation != _socketGeneration ||
        _reconnect != null) {
      return;
    }
    unawaited(_live?.cancel());
    _live = null;
    _firstMessage?.cancel();
    _firstMessage = null;
    final delay = productionMapLiveReconnectDelay(_reconnectAttempt++);
    // This timer reconnects the socket; it never polls an HTTP list.
    _reconnect = Timer(delay, () {
      _reconnect = null;
      _connect();
    });
  }

  Future<void> _changeWindow(
      {String? apparatus, int? limit, String? search}) async {
    _generation++;
    _stopLive();
    _read = null;
    _repairBudget = 1;
    setState(() {
      _apparatusId = apparatus ?? _apparatusId;
      _limit = limit ?? _limit;
      _search = search ?? _search;
      _loading = true;
    });
    await _refresh();
  }

  void _searchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (_current) {
        unawaited(_changeWindow(search: value.trim().toLowerCase()));
      }
    });
  }

  Future<ProductionMapSaved> _fullOrder(ProductionMapSaved summary) async {
    final scope = _scope;
    final full = await (widget.supplyOrderDetailLoader ??
        MobileApi.instance.adminProductionMap)(summary.map.id);
    if (!_current ||
        scope != currentSessionReadScope() ||
        full.map.id != summary.map.id) {
      throw const MobileApiException(code: 'order_not_available', message: '');
    }
    return full;
  }

  Future<void> _showMaterialDetail(ProductionMapSaved summary) async {
    if (_openingDetail || !_current) return;
    _openingDetail = true;
    final scope = _scope;
    bool current() => _current && scope == currentSessionReadScope();
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
        builder: (_) => _AdminInitialDetailHost(
          isCurrent: current,
          load: () async => AdminApparatusQueueSnapshot(
              maps: [await _fullOrder(summary)],
              sequences: const {},
              visibleOrderIds: const {},
              queueStates: const {},
              queuePolicies: const {},
              orderControls: const {}),
          onReady: (_) {},
          builder: (detail, error, retry) {
            final full = detail?.maps.single ?? summary;
            return _ReadOnlyOrderDetailSheet(
              order: full,
              apparatusCatalog: _window?.apparatus ?? const [],
              detailPending: detail == null,
              detailError: error,
              onRetryDetail: retry,
              baseMetraj: full.map.baseLength,
              orderKg: full.map.orderKg,
              customerName: full.map.customerName,
              allowWipQrReprint: false,
            );
          },
        ),
      );
    } finally {
      _openingDetail = false;
    }
  }

  void _navigate(String route) {
    if (ModalRoute.of(context)?.settings.name != route) {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = widget.materialTasksMode;
    final window = _window;
    return AppShell(
      drawer: material
          ? MaterialTaminotchiNavigationDrawer(
              selectedRouteName: AppRoutes.materialTasks,
              onNavigate: _navigate,
            )
          : QolipNavigationDrawer(
              selectedIndex: 0,
              selectedRouteName: AppRoutes.qolipTasks,
              onNavigate: _navigate),
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
        hintText: material
            ? 'Material vazifalari'
            : context.l10n.qolipText('nav.tasks'),
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
      bottom: material
          ? const MaterialTaminotchiDock(
              activeTab: MaterialTaminotchiDockTab.tasks)
          : const QolipDock(activeTab: QolipDockTab.tasks),
      bottomDockFadeStrength: null,
      contentPadding: EdgeInsets.zero,
      child: _loading
          ? const Align(
              alignment: Alignment.topCenter,
              child: _OrdersConnectionProgress())
          : Column(children: [
              if (_error != null)
                AppRetryState(
                    onRetry: _refresh,
                    message: material
                        ? 'Material vazifalari yuklanmadi'
                        : context.l10n.qolipText('tasks.load_failed')),
              if (window != null)
                Expanded(
                    child: _QolipTasksPage(
                  key: ValueKey('compact-$_kind-tasks'),
                  materialMode: material,
                  taskWindow: window,
                  apparatus: window.apparatus,
                  selected: window.apparatus
                      .where((a) => a.id == window.apparatusId)
                      .firstOrNull,
                  orders: _orders,
                  customers: {
                    for (final row in window.rows) row.id: row.customerName
                  },
                  searchQuery: window.search,
                  bottomPadding: MediaQuery.viewPaddingOf(context).bottom + 136,
                  onShowOrder: _showMaterialDetail,
                  hydrateOrder: _fullOrder,
                  onRefresh: _refresh,
                  onLimitChanged: (limit) =>
                      unawaited(_changeWindow(limit: limit)),
                  onSelect: (item) {
                    unawaited(AdminSequenceApparatusStore.instance
                        .saveApparatus(item));
                    unawaited(_changeWindow(apparatus: item.id));
                  },
                )),
            ]),
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
    super.dispose();
  }
}
