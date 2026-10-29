import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/navigation/app_root_navigation.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/session/session.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/paddon_widgets.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import '../../admin/presentation/widgets/admin_drawer_navigation.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../shared/models/app_models.dart';
import '../state/qolip_data_revision.dart';
import 'qolip_code_details_sheet.dart';
import 'qolip_mileage_sheet.dart';
import 'qolip_paddon_print.dart';
import 'qolip_products_screen.dart'
    show QolipProductContainer, QolipProductContainerCard, QolipCodeRow;
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

part 'qolip_storage_detail.dart';
part 'qolip_storage_picker.dart';
part 'qolip_storage_picker_products.dart';
part 'qolip_storage_picker_scanning.dart';

mixin _StorageSessionState<T extends StatefulWidget> on State<T> {
  final _initialScope = currentSessionReadScope();
  bool _sessionExpired = false;
  @override
  void initState() {
    super.initState();
    AppSession.instance.revision.addListener(_sessionRevision);
  }

  void _sessionRevision() {
    if (_initialScope != currentSessionReadScope() && mounted) {
      setState(() => _sessionExpired = true);
    }
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionRevision);
    super.dispose();
  }

  Widget sessionExpiredPage(BuildContext context) => Scaffold(
      appBar: AppBar(),
      body: Center(child: Text(_s(context, 'session_changed'))));
}

class _StorageOverlay extends StatelessWidget {
  const _StorageOverlay({required this.scope, required this.child});
  final String scope;
  final Widget child;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
      valueListenable: AppSession.instance.revision,
      builder: (context, _, __) => scope == currentSessionReadScope()
          ? child
          : AlertDialog(content: Text(_s(context, 'session_changed'))));
}

Future<T?> _storageDialog<T>(
    {required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true}) {
  final scope = currentSessionReadScope();
  return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) =>
          _StorageOverlay(scope: scope, child: builder(context)));
}

String _s(BuildContext context, String key) =>
    context.l10n.qolipStorageText(key);
String _status(BuildContext context, QolipPaddon p) => _s(
    context,
    p.archived
        ? 'archived'
        : p.locked
            ? 'locked'
            : 'open');
String _moldStatus(BuildContext context, QolipStorageMold m,
    [String? warehouse]) {
  if (warehouse != null &&
      m.warehouse.toLowerCase() != warehouse.toLowerCase()) {
    return _s(context, 'wrong_warehouse');
  }
  if (m.custodyMismatch) return _s(context, 'wrong_warehouse');
  if (m.archived) return _s(context, 'archived');
  if (m.inUse) return _s(context, 'in_use');
  if (m.inRework) return _s(context, 'in_rework');
  if (m.transferring) return _s(context, 'transferring');
  if (m.paddonCode.isNotEmpty) {
    return '${_s(context, 'in_paddon')}: ${m.paddonCode}';
  }
  return _s(context, 'available');
}

void _message(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
String _storageErrorMessage(BuildContext context, Object error) {
  final code = error is MobileApiException ? error.code : '';
  final key = switch (code) {
    'session_scope_changed' => 'session_changed',
    'qolip_in_use' => 'in_use',
    'qolip_in_rework' => 'in_rework',
    'qolip_in_transfer' => 'transferring',
    'qolip_warehouse_mismatch' ||
    'qolip_storage_warehouse_changed' =>
      'wrong_warehouse',
    'qolip_paddon_locked' => 'locked_error',
    'qolip_archived' => 'archived_error',
    'qolip_in_paddon' => 'in_paddon_error',
    'qolip_paddon_empty' => 'empty_error',
    'qolip_storage_forbidden' || 'forbidden' => 'forbidden_error',
    'qolip_paddon_capacity' ||
    'qolip_storage_too_many_items' =>
      'capacity_error',
    'qolip_storage_not_found' => 'not_found',
    _ => error is MobileApiException && error.statusCode == 409
        ? 'changed'
        : 'failed',
  };
  return _s(context, key);
}

void _error(BuildContext context, Object error) =>
    _message(context, _storageErrorMessage(context, error));

Future<bool> _confirm(BuildContext context, String title, String body) async =>
    await _storageDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(child: Text(body)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(_s(context, 'cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(_s(context, 'confirm'))),
              ],
            )) ==
    true;
Future<void> _qr(BuildContext context, String code, {bool paddon = false}) =>
    _storageDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(code),
              content: SizedBox(
                  width: 240,
                  height: 240,
                  child:
                      QrImageView(data: paddon ? 'qolip-paddon:$code' : code)),
              actions: [
                TextButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: code));
                    },
                    child: Text(_s(context, 'copy'))),
              ],
            ));
Future<void> _moldDetails(BuildContext context, QolipStorageMold m,
    {bool archivedSnapshot = false}) {
  final scope = currentSessionReadScope();
  final productCodes = m.products
      .map((product) => (product['code']?.toString() ?? '').trim())
      .where((code) => code.isNotEmpty)
      .toList();
  final product = QolipProduct(
    code: productCodes.isEmpty ? m.itemCode : productCodes.join(', '),
    name: m.productNames,
    itemGroup: '',
    qolipCode: m.code,
    qolipSetId: m.setId,
    warehouse: m.warehouse,
    qolipSize: m.size,
    qolipColor: m.color,
  );
  return showQolipCodeDetailsSheet(
    context,
    product: product,
    loadMileage: !archivedSnapshot,
    wrap: (child) => _StorageOverlay(scope: scope, child: child),
    onPayloadTap: () async {
      if (scope == currentSessionReadScope()) {
        await Clipboard.setData(ClipboardData(text: m.code));
      }
    },
    onReprint: archivedSnapshot || m.archived
        ? null
        : () => reprintQolipCodeQr(context, product, scope: scope),
    additionalDetails: [
      if (m.setId.isNotEmpty) RpsQrDetail(_s(context, 'set'), m.setId),
      if (m.warehouse.isNotEmpty)
        RpsQrDetail(_s(context, 'warehouse'), m.warehouse),
      if (m.color.isNotEmpty)
        RpsQrDetail(context.l10n.qolipText('products.color'), m.color),
      if (m.paddonCode.isNotEmpty)
        RpsQrDetail(_s(context, 'in_paddon'), m.paddonCode),
    ],
    afterDetails: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!archivedSnapshot && (m.paddonCode.isEmpty || m.archived))
          Text(_moldStatus(sheetContext, m)),
        TextButton(
          onPressed: () => showQolipMileageSheet(sheetContext, m.code,
              wrap: (child) => _StorageOverlay(scope: scope, child: child)),
          child: Text(_s(sheetContext, 'mileage')),
        ),
      ],
    ),
  );
}

class QolipStorageScreen extends StatefulWidget {
  const QolipStorageScreen({super.key, this.archive = false});
  final bool archive;
  @override
  State<QolipStorageScreen> createState() => _QolipStorageScreenState();
}

class _QolipStorageScreenState extends State<QolipStorageScreen>
    with _StorageSessionState<QolipStorageScreen> {
  final _search = TextEditingController();
  FocusNode? _searchFocus;
  FocusNode get _searchFocusNode => _searchFocus ??= FocusNode();
  final _intent = QolipStorageIntent();
  final _scope = currentSessionReadScope();
  Timer? _debounce;
  List<QolipPaddon> _paddons = [];
  List<QolipArchiveEntry> _archive = [];
  int? _next;
  int _generation = 0;
  bool _loading = false, _saving = false, _history = false;
  String _kind = 'all';
  String _warehouseFilter = '';
  DateTimeRange? _dateFilter;
  List<QolipStorageMold>? _pendingArchiveMolds;
  Map<String, String>? _createDraft;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation++;
    _searchFocus?.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _load());
  }

  bool _sameScope() {
    if (!_sessionExpired && _scope == currentSessionReadScope()) return true;
    _message(context, _s(context, 'session_changed'));
    return false;
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _next == null)) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      if (widget.archive) {
        final page = await MobileApi.instance.qolipArchive(
            status: _history ? 'all' : 'open',
            warehouse: _warehouseFilter,
            from: _dateFilter?.start,
            to: _dateFilter?.end,
            query: _search.text.trim(),
            offset: more ? _next! : 0);
        if (!mounted || generation != _generation) return;
        _archive = [if (more) ..._archive, ...page.items];
        _next = page.nextOffset;
      } else {
        final page = await MobileApi.instance.qolipPaddons(
            query: _search.text.trim(), offset: more ? _next! : 0);
        if (!mounted || generation != _generation) return;
        _paddons = [if (more) ..._paddons, ...page.items];
        _next = page.nextOffset;
      }
    } catch (e) {
      if (mounted && generation == _generation) _failure = e;
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(String code) async {
    if (!_sameScope()) return;
    await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => QolipPaddonScreen(code: code)));
    if (mounted) await _load();
  }

  Future<void> _filterWarehouse() async {
    try {
      final warehouses =
          (await MobileApi.instance.qolipBlocksData()).warehouses;
      if (!mounted || !_sameScope()) return;
      final selected = await _storageDialog<String>(
          context: context,
          builder: (context) =>
              SimpleDialog(title: Text(_s(context, 'warehouse')), children: [
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, ''),
                    child: Text(_s(context, 'all'))),
                for (final w in warehouses)
                  SimpleDialogOption(
                      onPressed: () => Navigator.pop(context, w),
                      child: Text(w)),
              ]));
      if (!mounted || selected == null) return;
      setState(() => _warehouseFilter = selected);
      await _load();
    } catch (e) {
      if (mounted) _error(context, e);
    }
  }

  Future<void> _filterDates() async {
    final selected = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 1)),
        initialDateRange: _dateFilter);
    if (!mounted || selected == null) return;
    setState(() => _dateFilter = selected);
    await _load();
  }

  Future<void> _scanPaddon() async {
    final raw = await showRawMaterialScanDialog(context,
        title: _s(context, 'scan_paddon'),
        manualLabel: _s(context, 'scan_paddon'));
    if (!mounted || raw == null || !_sameScope()) return;
    final code = qolipPaddonCodeFromQr(raw);
    if (code == null) {
      _message(context, _s(context, 'invalid_paddon_qr'));
      return;
    }
    await _open(code);
  }

  Future<void> _create() async {
    if (_saving || !_sameScope()) return;
    setState(() => _saving = true);
    try {
      final warehouses =
          (await MobileApi.instance.qolipBlocksData()).warehouses;
      if (!mounted || !_sameScope()) return;
      if (warehouses.isEmpty) {
        _message(context, _s(context, 'no_warehouse'));
        return;
      }
      final draft = await _storageDialog<Map<String, String>>(
          context: context,
          builder: (_) => _PaddonCreateDialog(
              warehouses: warehouses, initial: _createDraft));
      if (!mounted || draft == null || !_sameScope()) return;
      _createDraft = draft;
      final body = <String, dynamic>{'action': 'create', ...draft};
      body['request_id'] = _intent.keyFor(body);
      final detail = await MobileApi.instance.qolipPaddonAction(body);
      _intent.complete();
      if (!mounted) return;
      _createDraft = null;
      await _open(detail.paddon.code);
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archiveMolds() async {
    if (_saving || !_sameScope()) return;
    final molds = _pendingArchiveMolds ??
        await Navigator.of(context).push<List<QolipStorageMold>>(
            MaterialPageRoute(builder: (_) => const _MoldPicker()));
    if (!mounted || molds == null || molds.isEmpty || !_sameScope()) return;
    _pendingArchiveMolds = molds;
    final codes = molds.map((m) => m.code).toList()..sort();
    if (!await _confirm(context, _s(context, 'archive_action'),
        '${_s(context, 'archive_hint')}\n\n${codes.join('\n')}')) {
      return;
    }
    if (!mounted || !_sameScope()) return;
    setState(() => _saving = true);
    final body = <String, dynamic>{'action': 'archive', 'qolip_codes': codes};
    body['request_id'] = _intent.keyFor(body);
    try {
      await MobileApi.instance.qolipArchiveAction(body);
      _pendingArchiveMolds = null;
      _intent.complete();
      QolipDataRevision.notifyLocationsChanged();
      if (mounted) {
        _message(context, _s(context, 'saved'));
        await _load();
      }
    } catch (e) {
      if (mounted) _error(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _entry(QolipArchiveEntry entry) async {
    if (!_sameScope()) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => QolipArchiveDetailScreen(entry: entry)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionExpired) return sessionExpiredPage(context);
    final rows =
        _archive.where((e) => _kind == 'all' || e.kind == _kind).toList();
    final canGoBack = ModalRoute.of(context)?.canPop ?? false;
    return AppShell(
      title: widget.archive ? _s(context, 'archive') : '',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: widget.archive,
      profileActionListenable: widget.archive ? null : _searchFocusNode,
      showProfileActionResolver:
          widget.archive ? null : () => !_searchFocusNode.hasFocus,
      titleWidget: widget.archive
          ? null
          : AdminCatalogSearchField(
              controller: _search,
              focusNode: _searchFocusNode,
              hintText: _s(context, 'paddons_search'),
              onChanged: _onSearchChanged,
              onClear: () {
                _search.clear();
                _onSearchChanged('');
              },
              searchCloseKey: const ValueKey('qolip-paddons-search-close'),
              leadingIcon:
                  canGoBack ? Icons.arrow_back_rounded : Icons.menu_rounded,
              leadingTooltip: canGoBack
                  ? MaterialLocalizations.of(context).backButtonTooltip
                  : MaterialLocalizations.of(context).openAppDrawerTooltip,
              onBackWithContext: (searchContext) {
                final navigator = Navigator.of(searchContext);
                if (navigator.canPop()) {
                  unawaited(navigator.maybePop());
                } else {
                  AppShellDrawerScope.maybeOf(searchContext)?.openDrawer();
                }
              },
            ),
      appBarBottomLoading: _loading || _saving,
      contentPadding: EdgeInsets.zero,
      actions: [
        ListenableBuilder(
          listenable: _searchFocusNode,
          builder: (context, _) => !widget.archive && _searchFocusNode.hasFocus
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: _s(context, 'refresh'),
                  onPressed: _loading || _saving ? null : () => _load(),
                  icon: const Icon(Icons.refresh_rounded),
                ),
        ),
      ],
      drawer: QolipNavigationDrawer(
        selectedIndex: -1,
        selectedRouteName:
            widget.archive ? AppRoutes.qolipArchive : AppRoutes.qolipPaddons,
        onNavigate: (route) => AdminDrawerNavigation.openRoute(context, route),
      ),
      bottom: QolipDock(
        activeTab: null,
        primaryActions: widget.archive
            ? null
            : [
                AdminFabMenuAction(
                  title: _s(context, 'create'),
                  icon: Icons.add_rounded,
                  enabled: !_saving,
                  onTap: () => unawaited(_create()),
                ),
                AdminFabMenuAction(
                  title: _s(context, 'scan_paddon'),
                  icon: Icons.qr_code_scanner_rounded,
                  enabled: !_saving,
                  onTap: () => unawaited(_scanPaddon()),
                ),
                AdminFabMenuAction(
                  title:
                      '${_s(context, 'molds')}: ${_s(context, 'archive_action')}',
                  icon: Icons.archive_outlined,
                  enabled: !_saving,
                  onTap: () => unawaited(_archiveMolds()),
                ),
              ],
      ),
      child: Material(
        color: AppTheme.shellStart(context),
        child: RefreshIndicator(
          onRefresh: () => _load(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
                4, 4, 4, MediaQuery.viewPaddingOf(context).bottom + 120),
            children: [
              if (!widget.archive) ...[
                PaddonPanel(
                  key: const ValueKey('qolip-paddons-summary'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_s(context, 'paddon_summary'),
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(_s(context, 'paddons_hint')),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        PaddonMetric(
                            label: _s(context, 'loaded_paddons'),
                            value: '${_paddons.length}'),
                        PaddonMetric(
                            label: _s(context, 'molds'),
                            value:
                                '${_paddons.fold<int>(0, (n, p) => n + p.itemCount)}'),
                      ]),
                    ],
                  ),
                ),
              ],
              if (widget.archive)
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: _s(context, 'search'),
                    filled: true,
                    fillColor:
                        Theme.of(context).colorScheme.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
              if (widget.archive) ...[
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    onPressed: _filterWarehouse,
                    icon: const Icon(Icons.warehouse_outlined),
                    label: Text(_warehouseFilter.isEmpty
                        ? _s(context, 'warehouse')
                        : _warehouseFilter),
                  ),
                  OutlinedButton.icon(
                    onPressed: _filterDates,
                    icon: const Icon(Icons.date_range),
                    label: Text(_dateFilter == null
                        ? _s(context, 'dates')
                        : '${qolipStorageDate(_dateFilter!.start)} – ${qolipStorageDate(_dateFilter!.end)}'),
                  ),
                  if (_warehouseFilter.isNotEmpty || _dateFilter != null)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _warehouseFilter = '';
                          _dateFilter = null;
                        });
                        _load();
                      },
                      child: Text(_s(context, 'clear_filters')),
                    ),
                ]),
                SwitchListTile(
                  title: Text(_s(context, 'history')),
                  subtitle: Text(_s(context, _history ? 'all' : 'current')),
                  value: _history,
                  onChanged: _saving
                      ? null
                      : (v) {
                          setState(() => _history = v);
                          _load();
                        },
                ),
                Wrap(spacing: 8, children: [
                  for (final kind in ['all', 'paddon', 'qolip'])
                    ChoiceChip(
                      label: Text(_s(
                          context,
                          kind == 'paddon'
                              ? 'paddons'
                              : kind == 'qolip'
                                  ? 'molds'
                                  : 'all')),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ]),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _archiveMolds,
                  icon: const Icon(Icons.archive_outlined),
                  label: Text(
                      '${_s(context, 'molds')}: ${_s(context, 'archive_action')}'),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : _scanPaddon,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(_s(context, 'scan_paddon')),
                ),
              ],
              if (_pendingArchiveMolds != null)
                ListTile(
                  title: Text(
                      '${_s(context, 'selected')}: ${_pendingArchiveMolds!.length}'),
                  trailing: TextButton(
                    onPressed: _saving
                        ? null
                        : () => setState(() {
                              _pendingArchiveMolds = null;
                              _intent.complete();
                            }),
                    child: Text(_s(context, 'cancel')),
                  ),
                ),
              PaddonSectionHeader(
                title: _s(context, widget.archive ? 'archive' : 'paddon_list'),
                count: '${widget.archive ? rows.length : _paddons.length}',
              ),
              if (_failure != null)
                AppRetryState(
                    onRetry: () => _load(), message: _s(context, 'failed')),
              if (_loading &&
                  (widget.archive ? rows.isEmpty : _paddons.isEmpty))
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: AppLoadingIndicator())),
              if (!_loading &&
                  _failure == null &&
                  (widget.archive ? rows.isEmpty : _paddons.isEmpty))
                PaddonEmptyState(
                  title: _s(context, 'empty'),
                  message: widget.archive ? '' : _s(context, 'paddons_empty'),
                ),
              if (widget.archive)
                for (final e in rows)
                  ListTile(
                    leading: Icon(e.kind == 'paddon'
                        ? Icons.inventory_2_outlined
                        : Icons.layers_outlined),
                    title: Text(e.code),
                    subtitle: Text(
                        '${e.warehouse} • ${qolipReworkDate(e.archivedAt)}\n${_s(context, e.isOpen ? 'archived' : 'returned')}'),
                    isThreeLine: true,
                    onTap: () => _entry(e),
                    trailing: const Icon(Icons.chevron_right),
                  )
              else if (_paddons.isNotEmpty)
                M3SegmentSpacedColumn(children: [
                  for (var i = 0; i < _paddons.length; i++)
                    PaddonListCard(
                      key: ValueKey('qolip-paddon-card-${_paddons[i].code}'),
                      slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                          i, _paddons.length),
                      code: _paddons[i].code,
                      countLabel:
                          '${_s(context, 'molds')}: ${_paddons[i].itemCount}',
                      subtitle: [
                        _status(context, _paddons[i]),
                        _paddons[i].warehouse,
                        if (_paddons[i].location.isNotEmpty)
                          _paddons[i].location,
                      ].join(' • '),
                      icon: _paddons[i].locked
                          ? Icons.lock_outline_rounded
                          : Icons.inventory_2_rounded,
                      onTap: () => _open(_paddons[i].code),
                    ),
                ]),
              if (_next != null)
                TextButton(
                  onPressed: _loading ? null : () => _load(more: true),
                  child: Text(_s(context, 'more')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaddonCreateDialog extends StatefulWidget {
  const _PaddonCreateDialog({required this.warehouses, this.initial});
  final Map<String, String>? initial;
  final List<String> warehouses;
  @override
  State<_PaddonCreateDialog> createState() => _PaddonCreateDialogState();
}

class _PaddonCreateDialogState extends State<_PaddonCreateDialog> {
  String? _warehouse;
  final _location = TextEditingController(), _note = TextEditingController();
  @override
  void initState() {
    super.initState();
    if (widget.warehouses.length == 1) _warehouse = widget.warehouses.single;
    final initial = widget.initial;
    if (initial != null) {
      if (widget.warehouses.contains(initial['warehouse'])) {
        _warehouse = initial['warehouse'];
      }
      _location.text = initial['location'] ?? '';
      _note.text = initial['note'] ?? '';
    }
  }

  @override
  void dispose() {
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(_s(context, 'create')),
          content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
                initialValue: _warehouse,
                isExpanded: true,
                decoration:
                    InputDecoration(labelText: _s(context, 'warehouse')),
                items: widget.warehouses
                    .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                    .toList(),
                onChanged: (w) => setState(() => _warehouse = w)),
            TextField(
                controller: _location,
                maxLength: 200,
                decoration:
                    InputDecoration(labelText: _s(context, 'location'))),
            TextField(
                controller: _note,
                maxLength: 1000,
                decoration: InputDecoration(labelText: _s(context, 'note'))),
          ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(_s(context, 'cancel'))),
            FilledButton(
                onPressed: _warehouse == null
                    ? null
                    : () => Navigator.pop(context, {
                          'warehouse': _warehouse!,
                          'location': _location.text.trim(),
                          'note': _note.text.trim()
                        }),
                child: Text(_s(context, 'create'))),
          ]);
}
