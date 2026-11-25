import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/urdu_aware_text.dart';
import '../../../core/navigation/app_root_navigation.dart';
import '../../../core/print_service.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/progress_printer_picker.dart';
import '../../admin/presentation/raw_material_scan_dialog.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_catalog_list_row.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../../admin/presentation/widgets/admin_expandable_filter_chip.dart';
import '../../admin/presentation/widgets/admin_surface_tab_bar.dart';
import '../../admin/presentation/widgets/admin_top_notice.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_dock.dart';
import '../../material_taminotchi/presentation/widgets/material_taminotchi_navigation_drawer.dart';
import '../../shared/models/app_models.dart' show UserRole;
import '../models/preparation_models.dart';
import 'material_paddon_details_sheet.dart';
import 'material_paddon_receipt_dialog.dart';
import 'preparation_navigation.dart';

part 'preparation_production_notes.dart';
part 'preparation_production_paddon_picker.dart';
part 'preparation_production_sync.dart';

class PreparationProductionScreen extends StatefulWidget {
  const PreparationProductionScreen({super.key}) : materialPaddonsOnly = false;
  const PreparationProductionScreen.materialPaddons({super.key})
      : materialPaddonsOnly = true;

  final bool materialPaddonsOnly;
  @override
  State<PreparationProductionScreen> createState() => _ProductionOrdersState();
}

class PreparationProductionOrderScreen extends StatefulWidget {
  const PreparationProductionOrderScreen({super.key, required this.orderId});
  final String orderId;
  @override
  State<PreparationProductionOrderScreen> createState() =>
      _ProductionOrderState();
}

class PreparationProductionBatchScreen extends StatefulWidget {
  const PreparationProductionBatchScreen({super.key, required this.batchId});
  final String batchId;
  @override
  State<PreparationProductionBatchScreen> createState() =>
      _ProductionBatchState();
}

class _JournalPage<T> {
  const _JournalPage(this.page, this.items);
  final PreparationProductionPage page;
  final List<T> items;
}

/// Paged reads shared by the journal lists and detail screens.
abstract class _JournalState<W extends StatefulWidget, T> extends State<W>
    with WidgetsBindingObserver {
  final _scope = currentSessionReadScope();
  Timer? _timer;
  int _epoch = 0;
  int _loadedPages = 0;
  bool _busy = false, _queued = false, _valid = true, loading = true;
  bool hasMore = false;
  int? nextOffset;
  String? error;
  List<T> items = [];
  AppLifecycleState? _lifecycle;

  bool _scanningPaddon = false;

  AdminFabMenuAction _paddonScanAction({VoidCallback? onChanged}) =>
      AdminFabMenuAction(
        title: 'Paddon QR skaneri',
        icon: Icons.qr_code_scanner_rounded,
        onTap: () => _scanPaddon(onChanged: onChanged),
      );

  List<AdminFabMenuAction> get _ordinaryJournalActions => [
    if (currentAccount &&
        AppSession.instance.profile?.role == UserRole.tayyorlovMasteri &&
        AppSession.instance.can('preparation.access'))
      _paddonScanAction(),
  ];

  Future<void> _scanPaddon({VoidCallback? onChanged}) async {
    if (_scanningPaddon || !currentAccount) return;
    _scanningPaddon = true;
    try {
      final scanned = await showRawMaterialScanDialog(
        context,
        title: 'Paddon QR skaneri',
        manualLabel: 'Paddon kodi',
      );
      if (!mounted || !currentAccount || scanned == null) {
        return;
      }
      final code = materialPaddonCodeFromQr(scanned);
      if (code == null) {
        throw const FormatException(
          'Xomashyo paddonining QR kodini skanerlang',
        );
      }
      final paddon = await MobileApi.instance.materialPaddonByCode(code);
      if (!mounted || !currentAccount) return;
      if (paddon == null) {
        throw const FormatException(
          'Paddon topilmadi yoki sizga biriktirilmagan',
        );
      }
      if (ModalRoute.isCurrentOf(context) == false) return;
      await showMaterialPaddonDetails(
        context,
        paddon,
        onChanged: onChanged ?? () {},
      );
    } catch (error) {
      if (!mounted || !currentAccount) return;
      final message = switch (error) {
        MobileApiException() => error.message,
        FormatException() => error.message,
        _ => 'Paddonni yuklab bo‘lmadi',
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: UrduAwareText(message)));
    } finally {
      _scanningPaddon = false;
    }
  }

  Future<_JournalPage<T>> request(int offset);
  String identity(T item);
  void received(PreparationProductionPage page) {}
  void clearSummary() {}

  bool get _pollPages => true;
  bool get _userReadBusy => _busy;
  bool get currentAccount => _valid && _scope == currentSessionReadScope();
  bool get canRefresh =>
      mounted &&
      currentAccount &&
      (_lifecycle == null || _lifecycle == AppLifecycleState.resumed) &&
      ModalRoute.of(context)?.isCurrent != false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycle = WidgetsBinding.instance.lifecycleState;
    AppSession.instance.revision.addListener(_sessionChanged);
    unawaited(load());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_pollPages && canRefresh && !_busy) unawaited(load(silent: true));
    });
  }

  void _sessionChanged() {
    if (!mounted || currentAccount) return;
    _valid = false;
    _epoch++;
    _queued = false;
    _timer?.cancel();
    setState(() {
      items = [];
      clearSummary();
      hasMore = false;
      loading = false;
      error = 'Akkaunt o‘zgargan. Sahifani qayta oching';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasPaused =
        _lifecycle != null && _lifecycle != AppLifecycleState.resumed;
    _lifecycle = state;
    if (_pollPages &&
        wasPaused &&
        state == AppLifecycleState.resumed &&
        canRefresh &&
        !_busy) {
      unawaited(load(silent: true));
    }
  }

  Future<void> load({bool append = false, bool silent = false}) async {
    if (!mounted || !currentAccount) return;
    if (_busy) {
      if (!silent && !append) {
        _epoch++;
        _queued = true;
      }
      return;
    }
    final offset = append ? nextOffset : 0;
    if (offset == null) return;
    final epoch = ++_epoch;
    _busy = true;
    if (!silent) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      // Refresh exactly the window the user opened, rather than replacing a
      // paged journal with its first page every time the timer fires.
      final refreshPages =
          silent && !append && _loadedPages > 0 ? _loadedPages : 1;
      final refreshed = <T>[];
      var readOffset = offset;
      var readPages = 0;
      late _JournalPage<T> result;
      while (readPages < refreshPages) {
        result = await request(readOffset);
        if (!mounted || !currentAccount || epoch != _epoch) return;
        if (result.page.hasMore &&
            (result.page.nextOffset ?? 0) <= readOffset) {
          throw const FormatException('Keyingi sahifa ma’lumoti noto‘g‘ri');
        }
        refreshed.addAll(result.items);
        readPages++;
        if (!result.page.hasMore) break;
        readOffset = result.page.nextOffset!;
      }
      setState(() {
        final merged = <String, T>{
          if (append)
            for (final item in items) identity(item): item,
          for (final item in refreshed) identity(item): item,
        };
        items = merged.values.toList(growable: false);
        _loadedPages = append ? _loadedPages + readPages : readPages;
        hasMore = result.page.hasMore;
        nextOffset = result.page.nextOffset;
        error = null;
        received(result.page);
      });
    } catch (failure) {
      if (mounted && currentAccount && epoch == _epoch) {
        setState(() => error = failure is MobileApiException
            ? failure.message
            : 'Ma’lumotlarni yuklab bo‘lmadi. Qayta urinib ko‘ring');
      }
    } finally {
      _busy = false;
      if (mounted && currentAccount) {
        if (epoch == _epoch) setState(() => loading = false);
        if (_queued) {
          _queued = false;
          unawaited(load());
        }
      }
    }
  }

  Widget journal({
    List<Widget> children = const [],
    IndexedWidgetBuilder? rowBuilder,
    required String empty,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(8, 8, 8, 136),
  }) {
    final leading = <Widget>[
      if (loading && items.isEmpty)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: AppLoadingIndicator())),
      if (loading && items.isNotEmpty) const LinearProgressIndicator(),
      if (error != null)
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              UrduAwareText(error!),
              if (currentAccount)
                TextButton(
                  key: const ValueKey('production-retry'),
                  onPressed: _userReadBusy ? null : () => load(),
                  child: const UrduAwareText('Qayta urinish'),
                ),
            ]),
          ),
        ),
    ];
    final trailing = <Widget>[
      if (!loading && error == null && items.isEmpty)
        Padding(padding: const EdgeInsets.all(24), child: UrduAwareText(empty)),
      if (hasMore && currentAccount)
        Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton(
            key: const ValueKey('production-load-more'),
            onPressed: _userReadBusy ? null : () => load(append: true),
            child: const UrduAwareText('Yana yuklash'),
          ),
        ),
    ];
    return AppRefreshIndicator(
      onRefresh: load,
      allowRefreshOnShortContent: true,
      child: CustomScrollView(
        physics: const TopRefreshScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: padding,
            sliver: SliverMainAxisGroup(slivers: [
              SliverList.list(children: [...leading, ...children]),
              if (rowBuilder != null)
                SliverList.builder(
                    itemCount: items.length, itemBuilder: rowBuilder),
              SliverList.list(children: trailing),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _epoch++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AppSession.instance.revision.removeListener(_sessionChanged);
    super.dispose();
  }
}

enum _ProductionView { orders, batches, rolls, paddons }

class _ProductionOrdersState
    extends _JournalState<PreparationProductionScreen, PreparationProductionRow>
    with
        SingleTickerProviderStateMixin,
        _ProductionRollNotes<PreparationProductionScreen,
            PreparationProductionRow>,
        _ProductionJournalSync {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  String _query = '', _status = 'all';
  String _paddonStatus = 'all';
  final _selectedBatches = <String, _ProductionNoteTarget>{};
  bool _statusExpanded = false;
  late _ProductionView _view = widget.materialPaddonsOnly
      ? _ProductionView.paddons
      : _ProductionView.batches;
  bool get _showPaddons => _view == _ProductionView.paddons;
  @override
  _JournalFilter get _journalFilter =>
      (view: _view, query: _query, status: _showPaddons ? _paddonStatus : _status);
  late final _tabs = TabController(
    length: _ProductionView.values.length,
    initialIndex: _ProductionView.batches.index,
    vsync: this,
  );

  @override
  Future<_JournalPage<PreparationProductionRow>> request(int offset) async {
    final api = MobileApi.instance;
    switch (_view) {
      case _ProductionView.orders:
        final page = await api.preparationProductionOrders(
            query: _query, status: _status, offset: offset);
        return _JournalPage(page, page.orders);
      case _ProductionView.batches:
        final page = await api.preparationProductionBatches(
            query: _query, status: _status, offset: offset);
        return _JournalPage(page, page.batches);
      case _ProductionView.rolls:
        final page = await api.preparationProductionRolls(
            query: _query, status: _status, offset: offset);
        return _JournalPage(page, page.rolls);
      case _ProductionView.paddons:
        final page = await api.materialPaddons(
            query: _query, status: _paddonStatus, offset: offset);
        return _JournalPage(page, page.paddons);
    }
  }

  @override
  String identity(PreparationProductionRow item) => item.journalKey;

  @override
  void clearSummary() {
    super.clearSummary();
    clearRollNotes();
    _selectedBatches.clear();
  }

  void _searchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _filter);
  }

  void _filter({_ProductionView? view, String? status}) {
    _searchDebounce?.cancel();
    if (!currentAccount) return;
    final query = String.fromCharCodes(_search.text.trim().runes.take(200));
    final nextView = view ?? _view;
    final activeStatus =
        nextView == _ProductionView.paddons ? _paddonStatus : _status;
    if (nextView == _view &&
        (status ?? activeStatus) == activeStatus &&
        query == _query) {
      return;
    }
    _stopJournalSync();
    _epoch++;
    _queued = false;
    setState(() {
      _view = nextView;
      if (status != null) {
        if (_showPaddons) {
          _paddonStatus = status;
        } else {
          _status = status;
        }
      }
      _query = query;
      _statusExpanded = false;
      _selectedRolls.clear();
      _selectedBatches.clear();
      _restoreJournal(_cachedJournal);
    });
    if (_cachedJournal == null) {
      unawaited(load());
    } else {
      _scheduleJournalWatch();
    }
  }

  Future<void> _receivePaddon() async {
    final code = await showMaterialPaddonReceipt(context);
    if (!mounted || !currentAccount || code == null || !_showPaddons) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: UrduAwareText('Paddon $code kirim qilindi')),
    );
    if (_query.isEmpty && _paddonStatus == 'all' && _search.text.isEmpty) {
      await load();
    } else {
      _search.clear();
      _filter(status: 'all');
    }
  }

  Future<void> _openPaddon(PreparationMaterialPaddon paddon) =>
      showMaterialPaddonDetails(
        context,
        paddon,
        onChanged: _refreshPaddons,
      );

  void _refreshPaddons() {
    if (mounted && currentAccount && _showPaddons) {
      unawaited(load(silent: true));
    }
  }

  bool _canSelectBatch(PreparationProductionBatch batch) =>
      _view == _ProductionView.batches &&
      currentAccount &&
      AppSession.instance.profile?.role == UserRole.tayyorlovMasteri &&
      AppSession.instance.can('preparation.access') &&
      batch.canAttachNote;

  void _toggleBatch(PreparationProductionBatch batch) {
    if (!_canSelectBatch(batch)) return;
    setState(() {
      if (_selectedBatches.containsKey(batch.id)) {
        _selectedBatches.remove(batch.id);
      } else if (_selectedBatches.length < preparationNoteSelectionLimit) {
        _selectedBatches[batch.id] = _batchNoteTarget(batch, batch.note);
      }
    });
  }

  bool _isCurrentBatchSelection(Iterable<String> ids) =>
      mounted &&
      currentAccount &&
      _view == _ProductionView.batches &&
      ids.length == _selectedBatches.length &&
      ids.every(_selectedBatches.containsKey);

  Future<void> _editSelectedBatchNotes() async {
    if (!currentAccount || _selectedBatches.isEmpty) return;
    final targets = Map<String, _ProductionNoteTarget>.of(_selectedBatches);
    for (final batch in items.whereType<PreparationProductionBatch>()) {
      if (targets[batch.id] case final target?) {
        targets[batch.id] =
            _batchNoteTarget(batch, _latestNote(batch.note, target.note));
      }
    }
    bool currentSelection() => _isCurrentBatchSelection(targets.keys);
    final saved = await _editProductionBatchNotes(
      context,
      targets: targets,
      currentAccount: currentSelection,
      refresh: () => unawaited(load()),
    );
    if (saved == null || !currentSelection()) return;
    setState(_selectedBatches.clear);
    unawaited(load(silent: true));
  }

  Future<void> _attachSelectedBatches() async {
    if (!currentAccount || _selectedBatches.isEmpty) return;
    final ids = _selectedBatches.keys.toList(growable: false);
    final result = await _pickProductionPaddon(
      context,
      batchIds: ids,
      currentAccount: () => _isCurrentBatchSelection(ids),
    );
    if (result != null && _isCurrentBatchSelection(result.batchIds)) {
      setState(_selectedBatches.clear);
    }
  }

  List<AdminFabMenuAction> get _journalFabActions {
    final selectedCount = _selectedBatches.length;
    if (selectedCount == 0) {
      return _selectedRolls.isEmpty ? _paddonActions : _rollFabActions;
    }
    return [
      AdminFabMenuAction(
        title: selectedCount == 1
            ? 'Batchga eslatma'
            : '$selectedCount ta batchga eslatma',
        icon: Icons.edit_note_rounded,
        onTap: _editSelectedBatchNotes,
      ),
      AdminFabMenuAction(
        title: 'Paddonga biriktirish',
        icon: Icons.inventory_2_outlined,
        onTap: _attachSelectedBatches,
      ),
      AdminFabMenuAction(
        title: 'Tanlovni bekor qilish',
        icon: Icons.close_rounded,
        onTap: () {
          if (mounted && currentAccount) setState(_selectedBatches.clear);
        },
      ),
    ];
  }

  List<AdminFabMenuAction> get _paddonActions => [
    if (_showPaddons &&
        currentAccount &&
        !loading &&
        error == null &&
        AppSession.instance.can(
          widget.materialPaddonsOnly ? 'gscale.print' : 'preparation.access',
        ))
      AdminFabMenuAction(
        title: 'Paddon qo‘shish',
        icon: Icons.inventory_2_outlined,
        onTap: _receivePaddon,
      ),
    if (currentAccount &&
        AppSession.instance.can(
          widget.materialPaddonsOnly
              ? 'gscale.catalog.read'
              : 'preparation.access',
        ))
      _paddonScanAction(onChanged: _refreshPaddons),
  ];

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    if (!widget.materialPaddonsOnly) _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: widget.materialPaddonsOnly
            ? 'Xomashyo paddonlari'
            : 'Tayyorlov hisobi',
        subtitle: '',
        nativeTopBar: true,
        automaticallyImplyNativeLeading: false,
        profileActionListenable: _searchFocus,
        showProfileActionResolver: () => !_searchFocus.hasFocus,
        titleWidget: IgnorePointer(
          ignoring: !currentAccount,
          child: AdminCatalogSearchField(
            key: const ValueKey('production-search'),
            controller: _search,
            focusNode: _searchFocus,
            hintText: _showPaddons
                ? 'Paddon, partiya yoki xomashyo'
                : 'Nomi, buyurtma yoki QR',
            onChanged: _searchChanged,
            onClear: () {
              _search.clear();
              _filter();
            },
            onBack: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                AppRootNavigation.replaceRootRoute(
                    context,
                    widget.materialPaddonsOnly
                        ? AppRoutes.materialHome
                        : AppRoutes.preparation);
              }
            },
          ),
        ),
        contentPadding: EdgeInsets.zero,
        drawer: widget.materialPaddonsOnly
            ? MaterialTaminotchiNavigationDrawer(
                selectedRouteName: AppRoutes.materialPaddons,
                onNavigate: (route) =>
                    AppRootNavigation.replaceRootRoute(context, route),
              )
            : const PreparationDrawer(
                selectedRouteName: AppRoutes.preparationProduction),
        bottom: widget.materialPaddonsOnly
            ? const MaterialTaminotchiDock()
            : PreparationDock(primaryFabActions: _journalFabActions),
        child: Stack(children: [
          Column(children: [
            if (!widget.materialPaddonsOnly)
              IgnorePointer(
                ignoring: !currentAccount,
                child: AdminSurfaceTabBar(
                  key: const ValueKey('production-view-tabs'),
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  onTap: (index) =>
                      _filter(view: _ProductionView.values[index]),
                  tabs: [
                    for (final (key, label) in const [
                      ('orders', 'Buyurtmalar'),
                      ('batches', 'Batchlar'),
                      ('rolls', 'Rulonlar'),
                      ('paddons', 'Paddonlar'),
                    ])
                      Tab(
                          key: ValueKey('production-view-$key'),
                          text: AppLocalizations.of(context).uiText(label)),
                  ],
                ),
              ),
            IgnorePointer(
              ignoring: !currentAccount,
              child: AdminExpandableFilterChip<String>(
                chipKey: ValueKey(_showPaddons
                    ? 'paddon-balance-filter'
                    : 'production-status-filter'),
                label: _showPaddons ? 'Qoldiq' : 'Holat',
                emptyLabel: 'Barchasi',
                icon: Icons.filter_list_rounded,
                selectedValue: _showPaddons ? _paddonStatus : _status,
                options: _showPaddons
                    ? const [
                        AdminFilterChipOption(
                            key: ValueKey('paddon-balance-all'),
                            value: 'all',
                            label: 'Barchasi'),
                        AdminFilterChipOption(
                            key: ValueKey('paddon-balance-available'),
                            value: 'available',
                            label: 'Qoldig‘i bor'),
                        AdminFilterChipOption(
                            key: ValueKey('paddon-balance-empty'),
                            value: 'empty',
                            label: 'Bo‘sh'),
                      ]
                    : const [
                        AdminFilterChipOption(
                            key: ValueKey('production-status-all'),
                            value: 'all',
                            label: 'Barchasi'),
                        AdminFilterChipOption(
                            key: ValueKey('production-status-active'),
                            value: 'active',
                            label: 'Davom etmoqda'),
                        AdminFilterChipOption(
                            key: ValueKey('production-status-completed'),
                            value: 'completed',
                            label: 'Yakunlangan'),
                      ],
                expanded: _statusExpanded,
                onToggle: () =>
                    setState(() => _statusExpanded = !_statusExpanded),
                onSelect: (status) {
                  setState(() => _statusExpanded = false);
                  _filter(status: status);
                },
              ),
            ),
            Expanded(
                child: journal(
                    empty: _showPaddons
                        ? 'Xomashyo paddonlari topilmadi.'
                        : 'Hali ishlab chiqarish yozuvlari yo‘q.',
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 136),
                    rowBuilder: (context, index) {
                      final item = items[index];
                      final slot =
                          M3SegmentedListGeometry.standaloneListSlotForIndex(
                              index, items.length);
                      final row = switch (item) {
                        PreparationProductionOrder() =>
                          _productionOrderRow(context, item, slot),
                        PreparationProductionBatch() => _productionBatchRow(
                            context,
                            item,
                            slot,
                            showOrder: true,
                            selecting: _selectedBatches.isNotEmpty,
                            selected: _selectedBatches.containsKey(item.id),
                            onLongPress: _canSelectBatch(item)
                                ? () => _toggleBatch(item)
                                : null,
                          ),
                        PreparationProductionRoll() =>
                          rollRow(item, slot, showMaterial: true),
                        PreparationMaterialPaddon() =>
                          _materialPaddonRow(item, slot, () => _openPaddon(item)),
                      };
                      return Padding(
                        key: ValueKey('${_view.name}:${item.journalKey}'),
                        padding: const EdgeInsets.only(
                            bottom: M3SegmentedListGeometry.gap),
                        child: row,
                      );
                    })),
          ]),
          if (widget.materialPaddonsOnly && _paddonActions.isNotEmpty)
            PositionedDirectional(
              end: 16,
              bottom: 16,
              child: AdminFabOverlayActionMenu(
                key: const ValueKey('material-paddons-fab'),
                actions: _paddonActions,
                closedLabel: 'Amallar',
                openLabel: 'Yopish',
                closedIcon: Icons.add_rounded,
              ),
            ),
        ]),
      );
}

Color _productionHeaderColor(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return Color.alphaBlend(
    scheme.primaryContainer.withValues(alpha: 0.6),
    scheme.surfaceContainerLowest,
  );
}

class _ProductionOrderState extends _JournalState<
    PreparationProductionOrderScreen, PreparationProductionBatch> {
  PreparationProductionOrder? _order;
  @override
  Future<_JournalPage<PreparationProductionBatch>> request(int offset) async {
    final page = await MobileApi.instance
        .preparationProductionOrder(widget.orderId, offset: offset);
    return _JournalPage(page, page.batches);
  }

  @override
  String identity(PreparationProductionBatch item) => item.id;
  @override
  void received(PreparationProductionPage page) =>
      _order = (page as PreparationProductionOrderPage).order;
  @override
  void clearSummary() => _order = null;
  @override
  void didUpdateWidget(PreparationProductionOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId) {
      items = [];
      _order = null;
      unawaited(load());
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: _order == null
            ? 'Buyurtma ishlab chiqarishi'
            : 'Buyurtma: ${_order!.displayCode}',
        subtitle: '',
        nativeTopBar: true,
        contentPadding: EdgeInsets.zero,
        bottom: PreparationDock(primaryFabActions: _ordinaryJournalActions),
        child: journal(
            empty: 'Bu buyurtma bo‘yicha ishlab chiqarish yozuvi yo‘q.',
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 136),
            children: [
              M3SegmentSpacedColumn(children: [
                if (_order case final order?)
                  _JournalListRow(
                    key: const ValueKey('production-order-summary'),
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                        0, items.length + 1),
                    icon: Icons.receipt_long_outlined,
                    backgroundColor: _productionHeaderColor(context),
                    title: order.title,
                    subtitle: [
                      order.customerName,
                      if (order.legacyNote case final note?
                          when note.text.isNotEmpty)
                        'Buyurtma eslatmasi: ${note.text}',
                    ].where((line) => line.isNotEmpty).join('\n'),
                    metrics:
                        '${order.rollCount} ta rulon • ${preparationDisplay(order.netKg)} kg • ${preparationDisplay(order.lengthM)} m',
                  ),
                for (final (index, batch) in items.indexed)
                  _productionBatchRow(
                    context,
                    batch,
                    M3SegmentedListGeometry.standaloneListSlotForIndex(
                        index + (_order == null ? 0 : 1),
                        items.length + (_order == null ? 0 : 1)),
                  ),
              ]),
            ]),
      );
}

class _ProductionBatchState extends _JournalState<
        PreparationProductionBatchScreen, PreparationProductionRoll>
    with
        _ProductionRollNotes<PreparationProductionBatchScreen,
            PreparationProductionRoll> {
  PreparationProductionBatch? _batch;
  PreparationOutputNote? _savedBatchNote;

  PreparationOutputNote? get _batchNote =>
      _latestNote(_batch?.note, _savedBatchNote);

  @override
  Future<_JournalPage<PreparationProductionRoll>> request(int offset) async {
    final page = await MobileApi.instance
        .preparationProductionBatch(widget.batchId, offset: offset);
    return _JournalPage(page, page.rolls);
  }

  @override
  String identity(PreparationProductionRoll item) => item.journalKey;
  @override
  void received(PreparationProductionPage page) =>
      _batch = (page as PreparationProductionBatchPage).batch;
  @override
  void clearSummary() {
    _batch = null;
    _savedBatchNote = null;
    clearRollNotes();
  }

  @override
  void didUpdateWidget(PreparationProductionBatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.batchId != widget.batchId) {
      items = [];
      clearSummary();
      unawaited(load());
    }
  }

  Future<void> _editBatchNote(PreparationProductionBatch batch) async {
    if (!currentAccount || !batch.canAttachNote || _batch?.id != batch.id) {
      return;
    }
    bool currentBatch() => mounted && currentAccount && _batch?.id == batch.id;
    final saved = await _editProductionBatchNotes(
      context,
      targets: {batch.id: _batchNoteTarget(batch, _batchNote)},
      currentAccount: currentBatch,
      refresh: () => unawaited(load()),
    );
    if (saved == null || !currentBatch()) return;
    setState(() => _savedBatchNote = saved[batch.id]);
    unawaited(load(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    final batch = _batch;
    final note = _batchNote;
    final headerColor = _productionHeaderColor(context);
    final showNote = batch?.canAttachNote == true;
    final headerCount = batch == null
        ? 0
        : showNote
            ? 3
            : 2;
    final rowCount = items.length + headerCount;
    M3SegmentVerticalSlot slot(int index) =>
        M3SegmentedListGeometry.standaloneListSlotForIndex(index, rowCount);
    return AppShell(
      title: _batch?.displayItem ?? 'Tayyorlov hisobi',
      subtitle: '',
      nativeTopBar: true,
      contentPadding: EdgeInsets.zero,
      bottom: PreparationDock(
        primaryFabActions:
            _selectedRolls.isEmpty ? _ordinaryJournalActions : _rollFabActions,
      ),
      child: journal(
        empty: 'Hali rulon kirim qilinmagan.',
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 136),
        children: [
          M3SegmentSpacedColumn(children: [
            if (batch != null) ...[
              _JournalListRow(
                key: const ValueKey('production-batch-summary'),
                slot: slot(0),
                icon: Icons.inventory_2_outlined,
                backgroundColor: headerColor,
                title: batch.active ? 'Davom etmoqda' : 'Yakunlangan',
                subtitle:
                    '${batch.warehouse}\nBoshlangan: ${_date(batch.startedAt)}${batch.endedAt.isEmpty ? '' : '\nTugagan: ${_date(batch.endedAt)}'}',
                metrics:
                    '${batch.rollCount} ta rulon • ${preparationDisplay(batch.netKg)} kg • ${preparationDisplay(batch.lengthM)} m',
              ),
              _ProductionRecipe(
                key: const ValueKey('production-batch-recipe'),
                formula: batch.formula,
                slot: slot(1),
                backgroundColor: headerColor,
              ),
              if (showNote)
                _JournalListRow(
                  key: const ValueKey('production-batch-note'),
                  slot: slot(2),
                  icon: Icons.edit_note_rounded,
                  title: note?.text.isNotEmpty == true
                      ? 'Batch eslatmasi'
                      : 'Batchga eslatma',
                  subtitle: note?.text ?? '',
                  metrics: note != null && note.text.isNotEmpty
                      ? _noteAudienceLabel(context, note.audience)
                      : '',
                  onTap: currentAccount ? () => _editBatchNote(batch) : null,
                ),
            ],
            for (final (index, roll) in items.indexed)
              rollRow(
                roll,
                slot(index + headerCount),
                batchOrderId: batch?.orderId ?? '',
                batchNote: note,
              ),
          ]),
        ],
      ),
    );
  }
}

String _nonEmpty(String preferred, String fallback, String otherwise) =>
    preferred.isNotEmpty
        ? preferred
        : fallback.isNotEmpty
            ? fallback
            : otherwise;

String _orderLabel(String code, String id, String title) => [
      _nonEmpty(code, id, ''),
      title
    ].where((line) => line.isNotEmpty).join(' • ');

Widget _productionOrderRow(
  BuildContext context,
  PreparationProductionOrder order,
  M3SegmentVerticalSlot slot,
) =>
    _JournalListRow(
      key: ValueKey('production-order:${order.id}'),
      slot: slot,
      icon: Icons.receipt_long_outlined,
      title: _orderLabel(order.code, order.id, order.title),
      subtitle: [
        order.customerName,
        '${order.batchCount} ta ishlab chiqarish',
        if (order.activeBatchCount > 0)
          '${order.activeBatchCount} ta davom etmoqda',
        _date(order.lastActivityAt),
      ].where((line) => line.isNotEmpty).join(' • '),
      metrics:
          '${order.rollCount} ta rulon • ${preparationDisplay(order.netKg)} kg • ${preparationDisplay(order.lengthM)} m',
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => PreparationProductionOrderScreen(orderId: order.id),
      )),
    );

Widget _productionBatchRow(
  BuildContext context,
  PreparationProductionBatch batch,
  M3SegmentVerticalSlot slot, {
  bool showOrder = false,
  bool selecting = false,
  bool selected = false,
  VoidCallback? onLongPress,
}) =>
    _JournalListRow(
      key: ValueKey('production-batch:${batch.id}'),
      slot: slot,
      icon: selected
          ? Icons.check_circle_rounded
          : selecting
              ? Icons.radio_button_unchecked_rounded
              : Icons.inventory_2_outlined,
      onLongPress: onLongPress,
      title: batch.displayItem,
      subtitle: [
        if (showOrder && batch.orderId.isNotEmpty)
          _orderLabel(batch.orderCode, batch.orderId, batch.orderTitle),
        batch.formulaName,
        '${batch.active ? 'Davom etmoqda' : 'Yakunlangan'} • ${batch.warehouse} • ${_date(batch.lastActivityAt)}',
      ].join('\n'),
      metrics:
          '${batch.rollCount} ta rulon • ${preparationDisplay(batch.netKg)} kg • ${preparationDisplay(batch.lengthM)} m',
      onTap: selecting
          ? onLongPress
          : () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PreparationProductionBatchScreen(batchId: batch.id),
              )),
    );

Widget _materialPaddonRow(
  PreparationMaterialPaddon paddon,
  M3SegmentVerticalSlot slot,
  VoidCallback onTap,
) => _JournalListRow(
  key: ValueKey('preparation-paddon:${paddon.id}'),
  slot: slot,
  icon: Icons.inventory_2_outlined,
  title: paddon.title,
  titleMaxLines: 2,
  subtitle: paddon.name.isEmpty
      ? paddon.warehouse
      : '${paddon.warehouse} • ${paddon.code}',
  metrics: materialPaddonBalance(paddon),
  onTap: onTap,
);

class _JournalListRow extends StatelessWidget {
  const _JournalListRow({
    super.key,
    required this.slot,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.metrics,
    this.backgroundColor,
    this.titleMaxLines = 1,
    this.onTap,
    this.onLongPress,
  });

  final M3SegmentVerticalSlot slot;
  final IconData icon;
  final String title, subtitle, metrics;
  final Color? backgroundColor;
  final int titleMaxLines;
  final VoidCallback? onTap, onLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminCatalogListRow(
      slot: slot,
      icon: icon,
      title: l10n.uiText(title),
      titleMaxLines: titleMaxLines,
      subtitle: [
        if (subtitle.isNotEmpty) l10n.uiText(subtitle),
        if (metrics.isNotEmpty) l10n.uiText(metrics),
      ].join('\n'),
      subtitleMaxLines: 8,
      backgroundColor: backgroundColor,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _ProductionRecipe extends StatelessWidget {
  const _ProductionRecipe({
    super.key,
    required this.formula,
    this.slot,
    this.backgroundColor,
  });
  final Map<String, dynamic>? formula;
  final M3SegmentVerticalSlot? slot;
  final Color? backgroundColor;
  @override
  Widget build(BuildContext context) {
    final recipe = formula;
    if (recipe == null || recipe.isEmpty) {
      if (slot != null) {
        return AdminCatalogListRow(
          slot: slot!,
          icon: Icons.functions_rounded,
          title: AppLocalizations.of(context).uiText('Formula qayd etilmagan'),
          subtitle: '',
          backgroundColor: backgroundColor,
        );
      }
      return Card.filled(
          color: backgroundColor,
          child: const Padding(
              padding: EdgeInsets.all(16),
              child: UrduAwareText('Formula qayd etilmagan')));
    }
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        UrduAwareText('Shnek formulasi: ${recipe['variant_name'] ?? '—'}',
            style: slot == null
                ? Theme.of(context).textTheme.titleMedium
                : Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
        if (recipe['variant_code'] != null)
          UrduAwareText('Formula kodi: ${recipe['variant_code']}'),
        UrduAwareText(
            'Saqlangan tarkib • ${_date(recipe['captured_at']?.toString() ?? '')}'),
        for (final screw
            in (recipe['formulas'] as List? ?? const []).whereType<Map>()) ...[
          const SizedBox(height: 12),
          UrduAwareText(
              'Shnek ${screw['name']} • ${preparationDisplay(screw['share_percent']?.toString() ?? '—')}%',
              style: Theme.of(context).textTheme.titleSmall),
          for (final line
              in (screw['lines'] as List? ?? const []).whereType<Map>())
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: UrduAwareText(
                    '${line['name'] ?? line['item_code']} — ${preparationDisplay(line['percent']?.toString() ?? '—')}%')),
        ],
      ]),
    );
    if (slot != null) {
      return M3SegmentFilledSurface(
        slot: slot!,
        cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot!),
        backgroundColor: backgroundColor,
        child: content,
      );
    }
    return Card.filled(color: backgroundColor, child: content);
  }
}

String _date(String raw) {
  final value = DateTime.tryParse(raw)?.toLocal();
  if (value == null) return raw.isEmpty ? '—' : raw;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} ${two(value.hour)}:${two(value.minute)}';
}

Widget _rollNoteDetails(BuildContext context, PreparationOutputNote note) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        UrduAwareText(note.text),
        Text(_noteAudienceLabel(context, note.audience)),
      ],
    );

Future<void> _showRoll(
  BuildContext context,
  PreparationProductionRoll roll,
  String orderId, {
  PreparationOutputNote? batchNote,
  PreparationOutputNote? rollNote,
}) {
  final scope = currentSessionReadScope();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (sheetContext) => RpsQrReprintSheet(
      payload: roll.epc,
      itemName: roll.itemName.isEmpty ? roll.itemCode : roll.itemName,
      showInlineDragHandle: false,
      showCloseButton: false,
      reprintButtonKey: ValueKey('production-roll-reprint-${roll.epc}'),
      onReprint: () => _reprintRoll(sheetContext, roll, orderId, scope),
      errorMessage: (error) => error is MobileApiException
          ? error.message
          : error is PlatformException && error.message?.isNotEmpty == true
              ? error.message!
              : error.toString().replaceFirst('Bad state: ', ''),
      detailsContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (batchNote != null && batchNote.text.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: const UrduAwareText('Batch eslatmasi'),
              subtitle: _rollNoteDetails(context, batchNote),
            ),
          if (rollNote != null && rollNote.text.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sticky_note_2_outlined),
              title: const UrduAwareText('Rulon eslatmasi'),
              subtitle: _rollNoteDetails(context, rollNote),
            ),
          _ProductionRecipe(formula: roll.formula),
        ],
      ),
      details: [
        RpsQrDetail('Kirim raqami', roll.receiptName),
        RpsQrDetail('Netto', '${preparationDisplay(roll.netKg)} kg'),
        if (roll.grossKg != null)
          RpsQrDetail('Brutto', '${preparationDisplay(roll.grossKg!)} kg'),
        if (roll.lengthM != null)
          RpsQrDetail('Metraj', '${preparationDisplay(roll.lengthM!)} m'),
        if (roll.widthMm != null)
          RpsQrDetail('Eni', '${preparationDisplay(roll.widthMm!)} mm'),
        if (roll.micron != null)
          RpsQrDetail('Mikron', '${preparationDisplay(roll.micron!)} mkm'),
        RpsQrDetail('Ombor', roll.warehouse),
        RpsQrDetail('Chop etilgan', _date(roll.printedAt)),
      ],
    ),
  );
}

Future<String?> _reprintRoll(
  BuildContext context,
  PreparationProductionRoll roll,
  String orderId,
  String scope,
) async {
  bool currentSession() =>
      context.mounted && scope == currentSessionReadScope();
  if (!currentSession()) throw const RpsQrReprintCancelled();
  final prepared = await MobileApi.instance.adminPrepareRawMaterialStockReprint(
    barcode: roll.epc,
    orderId: orderId,
  );
  final barcode = roll.epc.trim().toUpperCase();
  if (prepared.reprintId.trim().isEmpty ||
      prepared.stock.barcode.trim().toUpperCase() != barcode ||
      prepared.printRequest.epc.trim().toUpperCase() != barcode ||
      (roll.receiptName.trim().isNotEmpty &&
          prepared.stock.sourceReceiptId.trim() != roll.receiptName.trim())) {
    throw const MobileApiException(
      code: 'raw_material_stock_reprint_identity_mismatch',
      message: 'Serverdagi QR identifikatori mos kelmadi',
    );
  }
  if (!context.mounted || !currentSession()) {
    throw const RpsQrReprintCancelled();
  }
  final printer = await pickProgressPrinter(context);
  if (!currentSession() || printer == null) {
    throw const RpsQrReprintCancelled();
  }
  if (printer.transport.isLocal) {
    final result = await PrintService.printRps(
      prepared.printRequest,
      printerProfile: printer.offlinePrinter,
      bluetoothPrinter: printer.bluetoothPrinter,
      transport: printer.transport,
    );
    if (!result.ok) throw StateError('Printer QR kodini chop etmadi');
  } else {
    final server = printer.server;
    if (server == null) throw StateError('Printer serveri tanlanmadi');
    final response = await http
        .post(
          Uri.parse('${server.endpoint.baseUrl}/v1/mobile/driver/print'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            ...prepared.printRequest.toJson(),
            if (printer.printer.isNotEmpty) 'printer': printer.printer,
            if (printer.printMode.isNotEmpty) 'print_mode': printer.printMode,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final payload = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode > 299 ||
        payload is! Map ||
        payload['ok'] != true) {
      final detail = payload is Map
          ? (payload['detail'] ?? payload['error'])?.toString().trim() ?? ''
          : '';
      throw StateError(
          detail.isEmpty ? 'Printer QR kodini chop etmadi' : detail);
    }
  }
  if (!currentSession()) {
    return 'QR chop etildi, lekin server tasdig‘i saqlanmadi';
  }
  try {
    await MobileApi.instance.adminConfirmRawMaterialStockReprint(
      barcode: prepared.stock.barcode,
      reprintId: prepared.reprintId,
    );
    return null;
  } catch (_) {
    return 'QR chop etildi, lekin server tasdig‘i saqlanmadi';
  }
}
