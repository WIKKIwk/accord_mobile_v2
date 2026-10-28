part of 'qolip_storage_screen.dart';

class _MoldPicker extends StatefulWidget {
  const _MoldPicker({this.warehouse});
  final String? warehouse;
  @override
  State<_MoldPicker> createState() => _MoldPickerState();
}

class _MoldPickerState extends State<_MoldPicker>
    with _StorageSessionState<_MoldPicker> {
  final _scope = currentSessionReadScope();
  final _search = TextEditingController();
  final _selected = <String, QolipStorageMold>{};
  List<QolipStorageMold> _molds = [];
  Timer? _debounce;
  int? _next;
  int _generation = 0;
  bool _loading = false, _scanning = false, _leaving = false;
  Object? _failure;
  bool _eligible(QolipStorageMold mold) =>
      mold.available &&
      (widget.warehouse == null ||
          mold.warehouse.toLowerCase() == widget.warehouse!.toLowerCase());
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _generation++;
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _next == null)) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final page = await MobileApi.instance.qolipStorageMolds(
          query: _search.text.trim(), offset: more ? _next! : 0);
      if (!mounted || generation != _generation) return;
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
      if (mounted && generation == _generation) _failure = e;
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _scan() async {
    if (_scanning) return;
    final raw = await showRawMaterialScanDialog(context,
        title: _s(context, 'scan'), manualLabel: _s(context, 'scan'));
    if (!mounted || raw == null || raw.trim().isEmpty) return;
    final code = rawMaterialBarcodeFromQr(raw);
    setState(() => _scanning = true);
    try {
      final page = await MobileApi.instance.qolipStorageMolds(query: code);
      if (!mounted) return;
      final mold = page.items
          .where((m) => m.code.toLowerCase() == code.toLowerCase())
          .firstOrNull;
      if (mold == null) {
        _message(context, _s(context, 'not_found'));
        return;
      }
      if (!_eligible(mold)) {
        _message(context, _moldStatus(context, mold, widget.warehouse));
        return;
      }
      if (_selected.containsKey(mold.code.toLowerCase())) {
        _message(context, _s(context, 'duplicate'));
        return;
      }
      setState(() {
        _selected[mold.code.toLowerCase()] = mold;
      });
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _finish() async {
    if (_scope != currentSessionReadScope()) {
      _message(context, _s(context, 'session_changed'));
      return;
    }
    final result = _selected.values.toList();
    setState(() => _leaving = true);
    await Future<void>.delayed(Duration.zero);
    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => _sessionExpired
      ? sessionExpiredPage(context)
      : PopScope(
          canPop: _leaving || _selected.isEmpty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || _leaving) return;
            if (await _confirm(context, _s(context, 'leave'),
                    '${_s(context, 'selected')}: ${_selected.length}') &&
                mounted) {
              setState(() => _leaving = true);
              await Future<void>.delayed(Duration.zero);
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: Scaffold(
            appBar: AppBar(title: Text(_s(context, 'molds'))),
            bottomNavigationBar: SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton(
                      onPressed:
                          _selected.isEmpty || _scanning ? null : _finish,
                      child: Text(
                          '${_s(context, 'confirm')} (${_selected.length})'),
                    ))),
            body: Column(children: [
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                      controller: _search,
                      decoration: InputDecoration(
                          hintText: _s(context, 'search'),
                          prefixIcon: const Icon(Icons.search)),
                      onChanged: (_) {
                        _debounce?.cancel();
                        _debounce = Timer(
                            const Duration(milliseconds: 300), () => _load());
                      })),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: _scanning ? null : _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(_s(context, 'scan'))),
                TextButton(
                    onPressed: () => setState(() {
                          for (final m in _molds.where(_eligible)) {
                            _selected[m.code.toLowerCase()] = m;
                          }
                        }),
                    child: Text(_s(context, 'select_loaded'))),
              ]),
              if (_selected.isNotEmpty)
                SizedBox(
                    height: 44,
                    child:
                        ListView(scrollDirection: Axis.horizontal, children: [
                      for (final mold in _selected.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InputChip(
                              label: Text(mold.code),
                              onDeleted: () => setState(() =>
                                  _selected.remove(mold.code.toLowerCase()))),
                        )
                    ])),
              if (_loading || _scanning) const LinearProgressIndicator(),
              if (_failure != null)
                TextButton(
                    onPressed: () => _load(),
                    child: Text(_s(context, 'retry'))),
              Expanded(
                  child: ListView(children: [
                for (final m in _molds)
                  CheckboxListTile(
                    value: _selected.containsKey(m.code.toLowerCase()),
                    title: Text(m.code),
                    subtitle: Text(
                        '${m.productNames}\n${m.setId} • ${m.warehouse} • ${_moldStatus(context, m, widget.warehouse)}'),
                    isThreeLine: true,
                    secondary: IconButton(
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _moldDetails(context, m)),
                    onChanged: !_eligible(m)
                        ? null
                        : (v) => setState(() {
                              if (v == true) {
                                _selected[m.code.toLowerCase()] = m;
                              } else {
                                _selected.remove(m.code.toLowerCase());
                              }
                            }),
                  ),
                if (!_loading && _molds.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(_s(context, 'empty'))),
                if (_next != null)
                  TextButton(
                      onPressed: _loading ? null : () => _load(more: true),
                      child: Text(_s(context, 'more'))),
              ])),
            ]),
          ),
        );
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
