part of 'qolip_storage_screen.dart';

class QolipPaddonScreen extends StatefulWidget {
  const QolipPaddonScreen({super.key, required this.code});
  final String code;
  @override
  State<QolipPaddonScreen> createState() => _QolipPaddonScreenState();
}

class _QolipPaddonScreenState extends State<QolipPaddonScreen>
    with _StorageSessionState<QolipPaddonScreen> {
  final _scope = currentSessionReadScope();
  final _intent = QolipStorageIntent();
  QolipPaddonDetail? _detail;
  Map<String, dynamic>? _lastInspection;
  bool _loading = true, _saving = false;
  int _generation = 0;
  Object? _failure;
  String? _pendingAction;
  List<String> _pendingCodes = [];
  Map<String, ValueNotifier<bool>>? _expandedProductNotifiers;
  ValueNotifier<bool> _productExpanded(String key) =>
      (_expandedProductNotifiers ??= <String, ValueNotifier<bool>>{})
          .putIfAbsent(key, () => ValueNotifier<bool>(false));
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    for (final notifier
        in _expandedProductNotifiers?.values ?? <ValueNotifier<bool>>[]) {
      notifier.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final detail = await MobileApi.instance.qolipPaddonDetail(widget.code);
      if (mounted && generation == _generation) _detail = detail;
    } catch (e) {
      if (mounted && generation == _generation) _failure = e;
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  bool _sameScope() {
    if (!_sessionExpired && _scope == currentSessionReadScope()) return true;
    _message(context, _s(context, 'session_changed'));
    return false;
  }

  Future<void> _add({bool scan = false}) async {
    if (_saving ||
        _loading ||
        _detail?.paddon.editable != true ||
        !_sameScope()) {
      return;
    }
    final selected = await Navigator.of(context).push<List<QolipStorageMold>>(
        MaterialPageRoute(
            builder: (_) => _MoldPicker(
                warehouse: _detail!.paddon.warehouse,
                paddonCode: widget.code,
                scanInitially: scan)));
    if (!mounted || selected == null || selected.isEmpty) return;
    await _act('add', codes: selected.map((e) => e.code).toList());
  }

  Future<void> _inspect() async {
    final codes = await _storageDialog<List<String>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _InspectionDialog(
            expected: _detail!.items.map((m) => m.code).toList()));
    if (!mounted || codes == null) return;
    await _act('inspect', codes: codes);
  }

  Future<void> _act(String action, {List<String> codes = const []}) async {
    if (_saving || _detail == null || !_sameScope()) return;
    final detail = _detail!;
    final label = action == 'archive' ? 'archive_action' : action;
    final hint = switch (action) {
      'archive' => 'archive_hint',
      'restore' => 'restore_hint',
      'lock' || 'unlock' => 'lock_hint',
      'remove' => 'remove_hint',
      'inspect' => 'inspect_hint',
      _ => 'confirm',
    };
    final reviewed = codes.isEmpty && action != 'inspect'
        ? detail.items.map((m) => m.code).toList()
        : codes;
    if (!await _confirm(
        context,
        '${_s(context, label)} — ${detail.paddon.code}',
        '${_s(context, hint)}\n\n${reviewed.join('\n')}')) {
      return;
    }
    if (!mounted || !_sameScope()) return;
    // Use the revision the user reviewed, even if a refresh completed meanwhile.
    final sorted = codes.toList()..sort();
    final body = <String, dynamic>{
      'action': action,
      'code': detail.paddon.code,
      'expected_revision': detail.paddon.revision,
      'qolip_codes': sorted
    };
    body['request_id'] = _intent.keyFor(body);
    setState(() {
      _saving = true;
      _pendingAction = action;
      _pendingCodes = sorted;
    });
    try {
      final saved = await MobileApi.instance.qolipPaddonAction(body);
      if (!mounted) return;
      _generation++;
      setState(() {
        _detail = null;
        _lastInspection = saved.inspection;
        _pendingAction = null;
        _pendingCodes = [];
      });
      _intent.complete();
      QolipDataRevision.notifyLocationsChanged();
      _message(context, _s(context, 'saved'));
      await _load();
    } catch (e) {
      if (mounted) {
        _error(context, e);
        if (e is MobileApiException && e.statusCode == 409) {
          _intent.complete();
          await _load();
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionExpired) return sessionExpiredPage(context);
    final detail = _detail;
    final enabled = !_saving && !_loading && detail != null;
    return AppShell(
      title: widget.code,
      subtitle: '',
      nativeTopBar: true,
      showProfileAction: false,
      appBarBottomLoading: _saving || _loading,
      contentPadding: EdgeInsets.zero,
      actions: [
        IconButton(
          tooltip: _s(context, 'scan_paddon'),
          onPressed: () => _qr(context, widget.code, paddon: true),
          icon: const Icon(Icons.qr_code_2_rounded),
        ),
        IconButton(
          tooltip: _s(context, 'refresh'),
          onPressed: _saving || _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      bottom: QolipDock(
        activeTab: null,
        primaryActions: [
          if (detail?.paddon.editable == true)
            AdminFabMenuAction(
              title: _s(context, 'scan_add'),
              icon: Icons.qr_code_scanner_rounded,
              enabled: enabled,
              onTap: () => unawaited(_add(scan: true)),
            ),
          if (detail?.paddon.editable == true)
            AdminFabMenuAction(
              title: _s(context, 'add'),
              icon: Icons.playlist_add_rounded,
              enabled: enabled,
              onTap: () => unawaited(_add()),
            ),
          AdminFabMenuAction(
            title: _s(context, 'inspect'),
            icon: Icons.fact_check_outlined,
            enabled: enabled,
            onTap: () => unawaited(_inspect()),
          ),
        ],
      ),
      child: ColoredBox(
        color: AppTheme.shellStart(context),
        child: detail == null
            ? _failure != null
                ? AppRetryState(onRetry: _load, message: _s(context, 'failed'))
                : const Center(child: AppLoadingIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                      4, 4, 4, MediaQuery.viewPaddingOf(context).bottom + 120),
                  children: [
                    _header(context, detail, enabled: enabled),
                    if (_failure != null)
                      AppRetryState(
                          onRetry: _load, message: _s(context, 'failed')),
                    if (_pendingAction != null) ...[
                      const SizedBox(height: 12),
                      PaddonPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_s(context, 'failed')),
                            if (_pendingCodes.isNotEmpty)
                              Text(_pendingCodes.join(', ')),
                            TextButton(
                              onPressed: !enabled
                                  ? null
                                  : () => _act(_pendingAction!,
                                      codes: _pendingCodes),
                              child: Text(_s(context, 'retry')),
                            ),
                          ],
                        ),
                      ),
                    ],
                    PaddonSectionHeader(title: _s(context, 'contents')),
                    if (detail.items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          _s(context, 'empty'),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      )
                    else
                      _contents(context, detail, enabled: enabled),
                    if (_lastInspection != null) ...[
                      const SizedBox(height: 16),
                      PaddonPanel(
                          child: _inspectionResult(context, _lastInspection!)),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _contents(BuildContext context, QolipPaddonDetail detail,
      {required bool enabled}) {
    final groups = _groupStorageProducts(detail.items);
    return M3SegmentSpacedColumn(children: [
      for (var i = 0; i < groups.length; i++)
        _productCard(context, groups[i], i, groups.length,
            editable: detail.paddon.editable, enabled: enabled),
    ]);
  }

  Widget _productCard(
      BuildContext context, _StorageProductGroup group, int index, int count,
      {required bool editable, required bool enabled}) {
    final expanded = _productExpanded(group.key);
    final byCode = <String, QolipStorageMold>{
      for (final mold in group.visibleMolds) _pickerMoldKey(mold): mold,
    };
    final products = _storageProductRows(group, byCode.values);
    return ValueListenableBuilder<bool>(
      key: ValueKey('qolip-paddon-product-listener-${group.key}'),
      valueListenable: expanded,
      builder: (context, isExpanded, _) => QolipProductContainerCard(
        key: ValueKey('qolip-paddon-product-${group.key}'),
        expandKey: ValueKey('qolip-paddon-product-expand-${group.key}'),
        slot: M3SegmentedListGeometry.standaloneListSlotForIndex(index, count),
        container: QolipProductContainer(
          code: group.code,
          name: group.unlinked ? _s(context, 'unlinked_molds') : group.name,
          itemGroup: '',
          children: products,
        ),
        imageUrl: '',
        loading: false,
        errorMessage: null,
        onRetry: () async {},
        expanded: isExpanded,
        containerSelectionMode: false,
        qolipSelectionMode: true,
        selectedContainer: false,
        selectedQolipCodes: const {},
        reworkCodes: {
          for (final mold in byCode.values)
            if (mold.inRework) _pickerMoldKey(mold),
        },
        sharing: false,
        onShare: null,
        onToggle: () => expanded.value = !expanded.value,
        onLongPress: null,
        onToggleQolip: (_) {},
        onPrintCodeQr: (_) {},
        onCopyCode: (_) {},
        onEditQolip: (_) {},
        onAdd: () {},
        codeRowBuilder: (product) {
          final mold = byCode[_productKey(product.qolipCode)]!;
          void showDetails() => unawaited(_moldDetails(context, mold));
          return QolipCodeRow(
            key: ValueKey('qolip-paddon-mold-${mold.code}'),
            product: product,
            selectionMode: false,
            selected: false,
            isInRework: mold.inRework,
            onTap: showDetails,
            onCodeTap: showDetails,
            onLongPress: null,
            onEdit: () {},
            codeTooltip: _s(context, 'mold_details'),
            subtitle: [
              if (group.unlinked && mold.name.isNotEmpty) mold.name,
              if (mold.size > 0) '${mold.size}',
              if (mold.color.isNotEmpty) mold.color,
            ].join(' • '),
            trailing: editable
                ? IconButton(
                    tooltip: _s(context, 'remove'),
                    onPressed: enabled
                        ? () => _act('remove', codes: [mold.code])
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  )
                : const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, QolipPaddonDetail detail,
      {required bool enabled}) {
    final p = detail.paddon;
    final style = Theme.of(context).textTheme;
    final compactButton = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
    return PaddonPanel(
      key: const ValueKey('qolip-paddon-summary'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(p.code,
                  style:
                      style.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          const SizedBox(width: 8),
          QolipPaddonPrintButton(code: p.code, filled: true, enabled: enabled),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warehouse_outlined, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(p.warehouse)),
        ]),
        if (p.location.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.place_outlined, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(p.location)),
          ]),
        ],
        if (p.note.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(p.note, style: style.bodyMedium),
        ],
        const SizedBox(height: 14),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                avatar: Icon(
                    p.archived
                        ? Icons.archive_outlined
                        : p.locked
                            ? Icons.lock_outline_rounded
                            : Icons.lock_open_rounded,
                    size: 18),
                label: Text(_status(context, p)),
              ),
              PaddonMetric(
                  label: _s(context, 'molds'), value: '${detail.items.length}'),
            ]),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (!p.archived)
            OutlinedButton.icon(
              style: compactButton,
              onPressed:
                  !enabled ? null : () => _act(p.locked ? 'unlock' : 'lock'),
              icon: Icon(
                  p.locked
                      ? Icons.lock_open_rounded
                      : Icons.lock_outline_rounded,
                  size: 18),
              label: Text(_s(context, p.locked ? 'unlock' : 'lock')),
            ),
          OutlinedButton.icon(
            style: compactButton,
            onPressed: !enabled
                ? null
                : () => _act(p.archived ? 'restore' : 'archive'),
            icon: Icon(
                p.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                size: 18),
            label: Text(_s(context, p.archived ? 'restore' : 'archive_action')),
          ),
        ]),
      ]),
    );
  }
}

Widget _inspectionResult(
        BuildContext context, Map<String, dynamic> inspection) =>
    Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final key in ['found', 'missing', 'unexpected'])
              Text(
                  '${_s(context, key)}: ${(inspection[key] as List? ?? const []).join(', ')}')
          ],
        ));

class QolipArchiveDetailScreen extends StatefulWidget {
  const QolipArchiveDetailScreen({super.key, required this.entry});
  final QolipArchiveEntry entry;
  @override
  State<QolipArchiveDetailScreen> createState() =>
      QolipArchiveDetailScreenState();
}

class QolipArchiveDetailScreenState extends State<QolipArchiveDetailScreen>
    with _StorageSessionState<QolipArchiveDetailScreen> {
  final _scope = currentSessionReadScope();
  final _intent = QolipStorageIntent();
  bool _saving = false, _restored = false;
  Map<String, dynamic>? _restoreBody;
  Future<void> _restore() async {
    if (_saving || _restored) return;
    if (_sessionExpired || _scope != currentSessionReadScope()) {
      _message(context, _s(context, 'session_changed'));
      return;
    }
    if (!await _confirm(context, _s(context, 'restore'),
        '${widget.entry.code}\n${_s(context, 'restore_hint')}')) {
      return;
    }
    if (!mounted || _sessionExpired || _scope != currentSessionReadScope()) {
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.entry.kind == 'paddon') {
        if (_restoreBody == null) {
          final current =
              await MobileApi.instance.qolipPaddonDetail(widget.entry.code);
          if (!mounted ||
              _sessionExpired ||
              _scope != currentSessionReadScope()) {
            return;
          }
          if (current.paddon.archiveEntryId != widget.entry.id) {
            throw const MobileApiException(
                code: 'qolip_archive_changed',
                message: 'Archive visit changed',
                statusCode: 409);
          }
          _restoreBody = {
            'action': 'restore',
            'code': widget.entry.code,
            'expected_revision': current.paddon.revision
          };
          _restoreBody!['request_id'] = _intent.keyFor(_restoreBody!);
        }
        if (!mounted ||
            _sessionExpired ||
            _scope != currentSessionReadScope()) {
          return;
        }
        await MobileApi.instance.qolipPaddonAction(_restoreBody!);
      } else {
        final body = <String, dynamic>{
          'action': 'restore',
          'entry_ids': [widget.entry.id]
        };
        body['request_id'] = _intent.keyFor(body);
        await MobileApi.instance.qolipArchiveAction(body);
      }
      _intent.complete();
      QolipDataRevision.notifyLocationsChanged();
      if (mounted) {
        setState(() => _restored = true);
        _message(context, _s(context, 'saved'));
      }
    } catch (e) {
      if (e is MobileApiException && e.statusCode == 409) {
        _restoreBody = null;
        _intent.complete();
      }
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionExpired) return sessionExpiredPage(context);
    final entry = widget.entry;
    final rawItems = entry.snapshot['items'] as List? ??
        (entry.snapshot['mold'] is Map
            ? [entry.snapshot['mold']]
            : entry.snapshot.containsKey('qolip_code')
                ? [entry.snapshot]
                : const []);
    final items = rawItems
        .whereType<Map>()
        .map((m) => QolipStorageMold.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(entry.code), actions: [
        IconButton(
            onPressed: () =>
                _qr(context, entry.code, paddon: entry.kind == 'paddon'),
            icon: const Icon(Icons.qr_code))
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_saving) const LinearProgressIndicator(),
        Text(_s(context, entry.isOpen && !_restored ? 'archived' : 'returned'),
            style: Theme.of(context).textTheme.titleLarge),
        Text(entry.warehouse),
        Text(
            '${_s(context, 'archived_by')}: ${entry.archivedBy}\n${qolipReworkDate(entry.archivedAt)}'),
        if (entry.restoredAt != null)
          Text(
              '${_s(context, 'restored_by')}: ${entry.restoredBy}\n${qolipReworkDate(entry.restoredAt!)}'),
        if (entry.note.isNotEmpty) Text(entry.note),
        if (entry.isOpen && !_restored)
          FilledButton.icon(
              onPressed: _saving ? null : _restore,
              icon: const Icon(Icons.unarchive_outlined),
              label: Text(_s(context, 'restore'))),
        if (entry.kind == 'paddon')
          TextButton(
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                      builder: (_) => QolipPaddonScreen(code: entry.code))),
              child: Text(_s(context, 'current_detail'))),
        const Divider(),
        Text(_s(context, 'snapshot'),
            style: Theme.of(context).textTheme.titleMedium),
        for (final mold in items)
          ListTile(
              title: Text(mold.code),
              subtitle:
                  Text('${mold.productNames}\n${mold.size} • ${mold.color}'),
              isThreeLine: true,
              onTap: () => _moldDetails(context, mold, archivedSnapshot: true)),
      ]),
    );
  }
}
