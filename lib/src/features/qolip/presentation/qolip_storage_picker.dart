part of 'qolip_storage_screen.dart';

class _MoldPicker extends StatefulWidget {
  const _MoldPicker(
      {this.warehouse, this.paddonCode, this.scanInitially = false});
  final String? warehouse;
  final String? paddonCode;
  final bool scanInitially;
  @override
  State<_MoldPicker> createState() => _MoldPickerState();
}

class _MoldPickerState extends State<_MoldPicker>
    with _StorageSessionState<_MoldPicker> {
  final _scope = currentSessionReadScope();
  final _search = TextEditingController();
  final _selected = <String, QolipStorageMold>{};
  final _queuedCodes = <String>{};
  List<QolipStorageMold> _molds = [];
  Timer? _debounce, _feedbackTimer;
  Future<void> _scanQueue = Future<void>.value();
  int? _next;
  int _generation = 0, _scanGeneration = 0, _pendingScans = 0;
  bool _loading = false, _selectingSet = false, _leaving = false;
  bool _scanMode = false, _reviewOpen = false;
  String _scanStatus = '';
  ProductionQuickScanFeedback? _scanFeedback;
  Object? _failure;
  String? _loadingProductKey;
  bool? _searchPending;
  Completer<bool>? _discardDecision;
  Set<String>? _expandedProductKeys;
  Map<String, List<QolipStorageMold>>? _productMoldCache;
  Map<String, Object>? _productLoadErrors;
  ValueNotifier<int>? _selectionNotifier, _activityNotifier;
  Map<String, ValueNotifier<int>>? _productNotifiers;
  ValueNotifier<int> get _selectionChanges =>
      _selectionNotifier ??= ValueNotifier<int>(0);
  ValueNotifier<int> get _activityChanges =>
      _activityNotifier ??= ValueNotifier<int>(0);
  ValueNotifier<int> _productChanges(String key) =>
      (_productNotifiers ??= <String, ValueNotifier<int>>{})
          .putIfAbsent(key, () => ValueNotifier<int>(0));
  Listenable get _pickerChanges =>
      Listenable.merge([_selectionChanges, _activityChanges]);
  Set<String> get _expandedProducts => _expandedProductKeys ??= <String>{};
  Map<String, List<QolipStorageMold>> get _productMolds =>
      _productMoldCache ??= <String, List<QolipStorageMold>>{};
  Map<String, Object> get _productErrors =>
      _productLoadErrors ??= <String, Object>{};

  bool get _current =>
      mounted &&
      !_sessionExpired &&
      !_leaving &&
      _scope == currentSessionReadScope();
  bool get _busy =>
      _selectingSet || _loadingProductKey != null || _pendingScans > 0;
  bool get _listPending =>
      _loading || _searchPending == true || _failure != null;
  bool _eligible(QolipStorageMold mold) =>
      mold.available &&
      (widget.warehouse == null ||
          mold.warehouse.toLowerCase() == widget.warehouse!.toLowerCase());
  void _updatePicker(VoidCallback update) => setState(update);

  void _notifySelectionChanged(Iterable<QolipStorageMold> molds,
      {Iterable<String> extraProducts = const []}) {
    final keys = <String>{...extraProducts};
    for (final mold in molds) {
      if (!_hasLinkedProduct(mold)) {
        keys.add('unlinked');
      } else {
        for (final product in mold.products) {
          final code = _productKey(product['code']?.toString() ?? '');
          if (code.isNotEmpty) keys.add('product:$code');
        }
      }
    }
    for (final key in keys) {
      final notifier = _productNotifiers?[key];
      if (notifier != null) notifier.value++;
    }
    _selectionChanges.value++;
  }

  void _notifyProductChanged(String key) {
    final notifier = _productNotifiers?[key];
    if (notifier != null) notifier.value++;
  }

  void _selectMolds(Iterable<QolipStorageMold> molds,
      {Iterable<String> extraProducts = const []}) {
    final changed = <QolipStorageMold>[];
    for (final mold in molds) {
      final key = _pickerMoldKey(mold);
      final previous = _selected[key];
      if (previous != null) changed.add(previous);
      _selected[key] = mold;
      changed.add(mold);
    }
    if (changed.isNotEmpty || extraProducts.isNotEmpty) {
      _notifySelectionChanged(changed, extraProducts: extraProducts);
    }
  }

  @override
  void initState() {
    super.initState();
    _scanMode = widget.scanInitially;
    if (!_scanMode) _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _feedbackTimer?.cancel();
    _search.dispose();
    _generation++;
    _invalidateScans();
    final decision = _discardDecision;
    if (decision != null && !decision.isCompleted) decision.complete(false);
    _selectionNotifier?.dispose();
    _activityNotifier?.dispose();
    for (final notifier
        in _productNotifiers?.values ?? <ValueNotifier<int>>[]) {
      notifier.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!_current || (more && (_loading || _next == null))) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failure = null;
      _searchPending = false;
      if (!more) {
        _expandedProducts.clear();
        _productMolds.clear();
        _productErrors.clear();
      }
    });
    try {
      final page = await MobileApi.instance.qolipStorageMolds(
          query: _search.text.trim(), offset: more ? _next! : 0);
      if (!_current || generation != _generation) return;
      _molds = [if (more) ..._molds, ...page.items];
      _next = page.nextOffset;
      for (final mold in page.items) {
        final key = _pickerMoldKey(mold);
        if (_selected.containsKey(key)) {
          if (_eligible(mold)) {
            _selected[key] = mold;
          } else {
            _selected.remove(key);
          }
        }
      }
    } catch (e) {
      if (_current && generation == _generation) _failure = e;
    } finally {
      if (_current && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _toggle(QolipStorageMold mold, bool selected) {
    if (!_current ||
        _selectingSet ||
        _loadingProductKey != null ||
        (!_scanMode && _listPending) ||
        !_eligible(mold)) return;
    final key = _pickerMoldKey(mold);
    if (selected && !_selected.containsKey(key) && _selected.length >= 1000) {
      _message(context, _s(context, 'capacity_error'));
      return;
    }
    final previous = _selected[key];
    if (selected == (previous != null)) return;
    if (selected) {
      _selected[key] = mold;
    } else {
      _selected.remove(key);
      _feedbackTimer?.cancel();
      _scanStatus = '';
      _scanFeedback = null;
    }
    _notifySelectionChanged([selected ? mold : previous!]);
    if (_scanMode) setState(() {});
  }

  void _selectLoaded() {
    if (!_current || _busy || _listPending) return;
    final eligible = _molds.where(_eligible).toList();
    if ({..._selected.keys, ...eligible.map(_pickerMoldKey)}.length > 1000) {
      _message(context, _s(context, 'capacity_error'));
      return;
    }
    _selectMolds(eligible);
  }

  Future<void> _selectSet() async {
    if (!_current || _busy || _listPending) return;
    final sets = _molds
        .map((m) => m.setId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (sets.isEmpty) {
      _message(context, _s(context, 'empty'));
      return;
    }
    final id = await _storageDialog<String>(
        context: context,
        builder: (context) =>
            SimpleDialog(title: Text(_s(context, 'choose_set')), children: [
              for (final id in sets)
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, id),
                    child: Text(id))
            ]));
    if (!mounted || !_current || id == null) return;
    setState(() => _selectingSet = true);
    try {
      final molds = await MobileApi.instance
          .qolipStorageSet(id, warehouse: widget.warehouse);
      if (!await _continueAfterDiscard() || !_current) return;
      if ({..._selected.keys, ...molds.map(_pickerMoldKey)}.length > 1000) {
        _message(context, _s(context, 'capacity_error'));
        return;
      }
      if (!await _confirm(context, _s(context, 'choose_set'),
              '$id\n\n${molds.map((m) => m.code).join('\n')}') ||
          !_current) {
        return;
      }
      _selectMolds(molds);
    } catch (e) {
      if (await _continueAfterDiscard() && mounted && _current) {
        if (e is MobileApiException && e.code == 'qolip_set_unavailable') {
          await _storageDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                      content: SingleChildScrollView(
                          child: Text(
                              '${_s(context, 'set_unavailable')}\n\n${e.details.join('\n')}')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(_s(context, 'cancel')))
                      ]));
        } else {
          _error(context, e);
        }
      }
    } finally {
      if (_current) setState(() => _selectingSet = false);
    }
  }

  Future<void> _reviewMold(QolipStorageMold mold) async {
    if (!_current || _busy || _reviewOpen) return;
    setState(() => _reviewOpen = true);
    try {
      await _moldDetails(context, mold);
    } finally {
      if (_current) setState(() => _reviewOpen = false);
    }
  }

  Future<void> _finish() async {
    if (!_current ||
        _busy ||
        _loading ||
        _searchPending == true ||
        _selected.isEmpty) return;
    final result = _selected.values.toList();
    setState(() {
      _leaving = true;
      _invalidateScans();
    });
    await Future<void>.delayed(Duration.zero);
    if (mounted) Navigator.pop(context, result);
  }

  Future<bool> _confirmDiscard() async {
    if (!_current || _reviewOpen) return false;
    if (_selected.isEmpty && !_busy) return true;
    final decision = Completer<bool>();
    _discardDecision = decision;
    setState(() => _reviewOpen = true);
    var confirmed = false;
    try {
      confirmed = await _confirm(context, _s(context, 'leave'),
          '${_s(context, 'selected')}: ${_selected.length}');
      if (!_current) return false;
      setState(() => _reviewOpen = false);
      return confirmed;
    } finally {
      if (identical(_discardDecision, decision)) _discardDecision = null;
      if (!decision.isCompleted) decision.complete(_current && !confirmed);
    }
  }

  Future<bool> _continueAfterDiscard() async {
    final decision = _discardDecision;
    return decision == null || await decision.future;
  }

  Future<void> _leave() async {
    if (!await _confirmDiscard() || !_current) return;
    setState(() {
      _leaving = true;
      _generation++;
      _invalidateScans();
    });
    await Future<void>.delayed(Duration.zero);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _navigateFromPicker(String route) async {
    if (!await _confirmDiscard() || !_current) return;
    final navigator = Navigator.of(context);
    setState(() {
      _leaving = true;
      _generation++;
      _invalidateScans();
    });
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _scope != currentSessionReadScope()) return;
    navigator.pop();
    AppRootNavigation.replaceRootRoute(navigator.context, route);
  }

  void _onDockTab(QolipDockTab tab) {
    final route = switch (tab) {
      QolipDockTab.home => AppRoutes.qolipHome,
      QolipDockTab.products => AppRoutes.qolipProducts,
      QolipDockTab.tasks => AppRoutes.qolipTasks,
    };
    unawaited(_navigateFromPicker(route));
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionExpired) return sessionExpiredPage(context);
    return ListenableBuilder(
      listenable: _pickerChanges,
      builder: (context, child) => PopScope(
        canPop: _leaving || (_selected.isEmpty && !_busy),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_leave());
        },
        child: child!,
      ),
      child: AppShell(
        title: _s(context, 'select_molds'),
        subtitle: '',
        nativeTopBar: true,
        showProfileAction: false,
        contentPadding: EdgeInsets.zero,
        appBarBottomLoading: _loading || _selectingSet || _pendingScans > 0,
        bottom: QolipDock(
          activeTab: null,
          onTabSelected: _onDockTab,
          onChatSelected: () => unawaited(_navigateFromPicker(AppRoutes.chat)),
        ),
        floatingActionButton: ListenableBuilder(
          listenable: _pickerChanges,
          builder: (context, _) => FloatingActionButton.extended(
            key: const ValueKey('qolip-picker-confirm'),
            heroTag: null,
            onPressed:
                _selected.isEmpty || _busy || _loading || _searchPending == true
                    ? null
                    : _finish,
            icon: const Icon(Icons.check_rounded),
            label: Text('${_s(context, 'confirm')} (${_selected.length})'),
          ),
        ),
        child: Material(
          color: AppTheme.shellStart(context),
          child: ListView(
            key: const ValueKey('qolip-picker-list'),
            padding: EdgeInsets.fromLTRB(
                4, 4, 4, MediaQuery.viewPaddingOf(context).bottom + 140),
            children: [
              PaddonPanel(
                key: const ValueKey('qolip-picker-summary'),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.paddonCode != null) ...[
                        Text(widget.paddonCode!,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                      ],
                      if (widget.warehouse != null) ...[
                        Row(children: [
                          const Icon(Icons.warehouse_outlined, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(widget.warehouse!))
                        ]),
                        const SizedBox(height: 8),
                      ],
                      if (!_scanMode) Text(_s(context, 'picker_hint')),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ListenableBuilder(
                          listenable: _selectionChanges,
                          builder: (context, _) => PaddonMetric(
                              label: _s(context, 'selected'),
                              value: '${_selected.length}'),
                        ),
                      ]),
                    ]),
              ),
              const SizedBox(height: 12),
              ListenableBuilder(
                listenable: _activityChanges,
                builder: (context, _) => SegmentedButton<bool>(
                  expandedInsets: EdgeInsets.zero,
                  segments: [
                    ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.checklist_rounded),
                        label: Text(_s(context, 'list_mode'))),
                    ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: Text(_s(context, 'scan_mode'))),
                  ],
                  selected: {_scanMode},
                  onSelectionChanged:
                      _selectingSet || _reviewOpen || _loadingProductKey != null
                          ? null
                          : (values) => _changeMode(values.single),
                ),
              ),
              const SizedBox(height: 12),
              if (_scanMode)
                ..._scannerWidgets(context)
              else
                ..._listWidgets(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _listWidgets(BuildContext context) => [
        ListenableBuilder(
          listenable: _activityChanges,
          builder: (context, _) => TextField(
            controller: _search,
            enabled: !_busy,
            decoration: InputDecoration(
              hintText: _s(context, 'search'),
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none),
            ),
            onChanged: (_) {
              _debounce?.cancel();
              setState(() {
                _searchPending = true;
                _generation++;
                _loading = false;
              });
              _debounce =
                  Timer(const Duration(milliseconds: 300), () => _load());
            },
          ),
        ),
        ListenableBuilder(
          listenable: _activityChanges,
          builder: (context, _) => Wrap(spacing: 8, runSpacing: 4, children: [
            TextButton.icon(
                onPressed: _busy || _listPending ? null : _selectLoaded,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(_s(context, 'select_loaded_short'))),
            TextButton.icon(
                onPressed: _busy || _listPending ? null : _selectSet,
                icon: const Icon(Icons.layers_outlined, size: 18),
                label: Text(_s(context, 'choose_set'))),
          ]),
        ),
        SizedBox(
          key: const ValueKey('qolip-picker-selected-strip'),
          height: 44,
          child: ListenableBuilder(
            listenable: _pickerChanges,
            builder: (context, _) => _selected.isEmpty
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(_s(context, 'selected_empty'),
                        style: Theme.of(context).textTheme.bodySmall),
                  )
                : ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final m in _selected.values)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: InputChip(
                            label: Text(m.code),
                            onDeleted: _busy ? null : () => _toggle(m, false),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        PaddonSectionHeader(
            title: _s(context, 'loaded_products'),
            count: '${_groupProducts().length}'),
        if (_failure != null)
          AppRetryState(onRetry: _load, message: _s(context, 'failed')),
        if (_loading && _molds.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: AppLoadingIndicator())),
        if (!_loading && _failure == null && _molds.isEmpty)
          PaddonEmptyState(
              title: _s(context, 'empty'), icon: Icons.layers_outlined),
        if (_molds.isNotEmpty) _productGroupList(context),
        if (_next != null)
          TextButton(
              onPressed: _loading ? null : () => _load(more: true),
              child: Text(_s(context, 'more'))),
      ];
}

class _InspectionDialog extends StatefulWidget {
  const _InspectionDialog({required this.expected});
  final List<String> expected;
  @override
  State<_InspectionDialog> createState() => _InspectionDialogState();
}

class _InspectionDialogState extends State<_InspectionDialog> {
  final _codes = <String, String>{};
  bool _scanning = false;
  Future<void> _scan() async {
    setState(() => _scanning = true);
    final raw = await showRawMaterialScanDialog(context,
        title: _s(context, 'scan'), manualLabel: _s(context, 'scan'));
    if (!mounted) return;
    setState(() {
      _scanning = false;
      if (raw != null && raw.trim().isNotEmpty) {
        final code = rawMaterialBarcodeFromQr(raw);
        _codes[code.toLowerCase()] = code;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final expected = {for (final c in widget.expected) c.toLowerCase(): c};
    final found = _codes.keys
        .where(expected.containsKey)
        .map((c) => expected[c]!)
        .toList();
    final missing = expected.keys
        .where((c) => !_codes.containsKey(c))
        .map((c) => expected[c]!)
        .toList();
    final unexpected = _codes.keys
        .where((c) => !expected.containsKey(c))
        .map((c) => _codes[c]!)
        .toList();
    return AlertDialog(
        title: Text(_s(context, 'inspect')),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_s(context, 'inspect_hint')),
                OutlinedButton.icon(
                    onPressed: _scanning ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(_s(context, 'scan'))),
                Text(
                    '${_s(context, 'found')} (${found.length}): ${found.join(', ')}'),
                Text(
                    '${_s(context, 'missing')} (${missing.length}): ${missing.join(', ')}'),
                Text(
                    '${_s(context, 'unexpected')} (${unexpected.length}): ${unexpected.join(', ')}'),
                Wrap(children: [
                  for (final c in _codes.entries)
                    InputChip(
                        label: Text(c.value),
                        onDeleted: () => setState(() => _codes.remove(c.key)))
                ]),
              ])),
        ),
        actions: [
          TextButton(
              onPressed: _scanning ? null : () => Navigator.pop(context),
              child: Text(_s(context, 'cancel'))),
          FilledButton(
              onPressed: _scanning
                  ? null
                  : () => Navigator.pop(context, _codes.values.toList()),
              child: Text(_s(context, 'save'))),
        ]);
  }
}
