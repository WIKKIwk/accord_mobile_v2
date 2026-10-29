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

  bool get _current =>
      mounted &&
      !_sessionExpired &&
      !_leaving &&
      _scope == currentSessionReadScope();
  bool get _busy => _selectingSet || _pendingScans > 0;
  bool _eligible(QolipStorageMold mold) =>
      mold.available &&
      (widget.warehouse == null ||
          mold.warehouse.toLowerCase() == widget.warehouse!.toLowerCase());
  void _updatePicker(VoidCallback update) => setState(update);

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
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (!_current || (more && (_loading || _next == null))) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final page = await MobileApi.instance.qolipStorageMolds(
          query: _search.text.trim(), offset: more ? _next! : 0);
      if (!_current || generation != _generation) return;
      _molds = [if (more) ..._molds, ...page.items];
      _next = page.nextOffset;
      for (final mold in page.items) {
        final key = mold.code.toLowerCase();
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
    if (!_current || _selectingSet || !_eligible(mold)) return;
    final key = mold.code.toLowerCase();
    if (selected && !_selected.containsKey(key) && _selected.length >= 1000) {
      _message(context, _s(context, 'capacity_error'));
      return;
    }
    setState(() {
      if (selected) {
        _selected[key] = mold;
      } else {
        _selected.remove(key);
        _feedbackTimer?.cancel();
        _scanStatus = '';
        _scanFeedback = null;
      }
    });
  }

  void _selectLoaded() {
    if (!_current || _busy) return;
    final eligible = _molds.where(_eligible).toList();
    if ({..._selected.keys, ...eligible.map((m) => m.code.toLowerCase())}
            .length >
        1000) {
      _message(context, _s(context, 'capacity_error'));
      return;
    }
    setState(() {
      for (final m in eligible) {
        _selected[m.code.toLowerCase()] = m;
      }
    });
  }

  Future<void> _selectSet() async {
    if (!_current || _busy) return;
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
      if (!mounted || !_current) return;
      if ({..._selected.keys, ...molds.map((m) => m.code.toLowerCase())}
              .length >
          1000) {
        _message(context, _s(context, 'capacity_error'));
        return;
      }
      if (!await _confirm(context, _s(context, 'choose_set'),
              '$id\n\n${molds.map((m) => m.code).join('\n')}') ||
          !_current) {
        return;
      }
      setState(() {
        for (final m in molds) {
          _selected[m.code.toLowerCase()] = m;
        }
      });
    } catch (e) {
      if (mounted && _current) {
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
    if (!_current || _busy || _loading || _selected.isEmpty) return;
    final result = _selected.values.toList();
    setState(() {
      _leaving = true;
      _invalidateScans();
    });
    await Future<void>.delayed(Duration.zero);
    if (mounted) Navigator.pop(context, result);
  }

  Future<void> _leave() async {
    if (!_current || _reviewOpen || _selectingSet) return;
    setState(() => _reviewOpen = true);
    final confirmed = await _confirm(context, _s(context, 'leave'),
        '${_s(context, 'selected')}: ${_selected.length}');
    if (!_current) return;
    setState(() => _reviewOpen = false);
    if (!confirmed) return;
    setState(() {
      _leaving = true;
      _invalidateScans();
    });
    await Future<void>.delayed(Duration.zero);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionExpired) return sessionExpiredPage(context);
    return PopScope(
      canPop: _leaving || (_selected.isEmpty && !_busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: AppShell(
        title: _s(context, 'select_molds'),
        subtitle: '',
        nativeTopBar: true,
        showProfileAction: false,
        contentPadding: EdgeInsets.zero,
        appBarBottomLoading: _loading || _busy,
        bottom: Material(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_pendingScans > 0) ...[
                  Text(_s(context, 'scan_pending'),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('qolip-picker-confirm'),
                      onPressed: _selected.isEmpty || _busy || _loading
                          ? null
                          : _finish,
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                          '${_s(context, 'confirm')} (${_selected.length})'),
                    )),
              ]),
            ),
          ),
        ),
        child: Material(
          color: AppTheme.shellStart(context),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                4, 4, 4, MediaQuery.viewPaddingOf(context).bottom + 100),
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
                        PaddonMetric(
                            label: _s(context, 'selected'),
                            value: '${_selected.length}'),
                        PaddonMetric(
                            label: _s(context, 'quantity'),
                            value:
                                '${_selected.values.fold<int>(0, (n, m) => n + m.quantity)}'),
                      ]),
                    ]),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
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
                onSelectionChanged: _selectingSet || _reviewOpen
                    ? null
                    : (values) => _changeMode(values.single),
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
        TextField(
          controller: _search,
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
            _debounce = Timer(const Duration(milliseconds: 300), () => _load());
          },
        ),
        Wrap(spacing: 8, runSpacing: 4, children: [
          TextButton.icon(
              onPressed: _busy ? null : _selectLoaded,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: Text(_s(context, 'select_loaded_short'))),
          TextButton.icon(
              onPressed: _busy ? null : _selectSet,
              icon: const Icon(Icons.layers_outlined, size: 18),
              label: Text(_s(context, 'choose_set'))),
        ]),
        if (_selected.isNotEmpty)
          SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final m in _selected.values)
                  Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: InputChip(
                        label: Text(m.code),
                        onDeleted: _busy ? null : () => _toggle(m, false),
                      )),
              ])),
        PaddonSectionHeader(
            title: _s(context, 'molds'), count: '${_molds.length}'),
        if (_failure != null)
          AppRetryState(onRetry: _load, message: _s(context, 'failed')),
        if (_loading && _molds.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: AppLoadingIndicator())),
        if (!_loading && _failure == null && _molds.isEmpty)
          PaddonEmptyState(
              title: _s(context, 'empty'), icon: Icons.layers_outlined),
        if (_molds.isNotEmpty)
          M3SegmentSpacedColumn(children: [
            for (var i = 0; i < _molds.length; i++)
              M3SegmentFilledSurface(
                key: ValueKey('qolip-picker-mold-${_molds[i].code}'),
                slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                    i, _molds.length),
                cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(
                    M3SegmentedListGeometry.standaloneListSlotForIndex(
                        i, _molds.length)),
                child: CheckboxListTile(
                  value: _selected.containsKey(_molds[i].code.toLowerCase()),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(_molds[i].code,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    if (_molds[i].productNames.isNotEmpty)
                      _molds[i].productNames,
                    '${_s(context, 'set')}: ${_molds[i].setId} • ${_molds[i].warehouse}',
                    _moldStatus(context, _molds[i], widget.warehouse)
                  ].join('\n')),
                  isThreeLine: true,
                  secondary: IconButton(
                      tooltip: _s(context, 'mold_details'),
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => _reviewMold(_molds[i])),
                  onChanged: !_eligible(_molds[i]) || _busy
                      ? null
                      : (v) => _toggle(_molds[i], v == true),
                ),
              ),
          ]),
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
