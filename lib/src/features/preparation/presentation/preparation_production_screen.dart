import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../app/app_router.dart';
import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/urdu_aware_text.dart';
import '../../../core/print_service.dart';
import '../../../core/session/session.dart';
import '../../../core/session/session_read_scope.dart';
import '../../../core/widgets/feedback/rps_qr_reprint_sheet.dart';
import '../../../core/widgets/lists/m3_segmented_list.dart';
import '../../../core/widgets/scroll/top_refresh_scroll_physics.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/progress_printer_picker.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_catalog_list_row.dart';
import '../../admin/presentation/widgets/admin_expandable_filter_chip.dart';
import '../models/preparation_models.dart';
import 'preparation_navigation.dart';

class PreparationProductionScreen extends StatefulWidget {
  const PreparationProductionScreen({super.key});
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

/// Only the visible journal polls. Late replies cannot cross accounts, filters
/// or disposed routes, and requests never overlap.
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

  Future<_JournalPage<T>> request(int offset);
  String identity(T item);
  void received(PreparationProductionPage page) {}
  void clearSummary() {}

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
      if (canRefresh && !_busy) unawaited(load(silent: true));
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
    if (wasPaused &&
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
        setState(() => loading = false);
        if (_queued) {
          _queued = false;
          unawaited(load());
        }
      }
    }
  }

  Widget journal({
    required List<Widget> children,
    required String empty,
    EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(8, 8, 8, 136),
  }) =>
      AppRefreshIndicator(
        onRefresh: load,
        allowRefreshOnShortContent: true,
        child: ListView(
          physics: const TopRefreshScrollPhysics(),
          padding: padding,
          children: [
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
                              onPressed: _busy ? null : () => load(),
                              child: const UrduAwareText('Qayta urinish')),
                      ]))),
            ...children,
            if (!loading && error == null && items.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(24),
                  child: UrduAwareText(empty)),
            if (hasMore && currentAccount)
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton(
                      key: const ValueKey('production-load-more'),
                      onPressed: _busy ? null : () => load(append: true),
                      child: const UrduAwareText('Yana yuklash'))),
          ],
        ),
      );

  @override
  void dispose() {
    _epoch++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AppSession.instance.revision.removeListener(_sessionChanged);
    super.dispose();
  }
}

class _ProductionOrdersState extends _JournalState<PreparationProductionScreen,
    PreparationProductionOrder> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;
  String _query = '', _status = 'all';
  bool _statusExpanded = false;
  @override
  Future<_JournalPage<PreparationProductionOrder>> request(int offset) async {
    final page = await MobileApi.instance.preparationProductionOrders(
        query: _query, status: _status, offset: offset);
    return _JournalPage(page, page.orders);
  }

  @override
  String identity(PreparationProductionOrder item) => item.id;
  void _searchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _filter);
  }

  void _filter() {
    _searchDebounce?.cancel();
    if (!currentAccount) return;
    _query = _search.text.trim();
    unawaited(load());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: 'Ishlab chiqarish',
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
            hintText: 'Buyurtma, homashyo yoki formula',
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
                navigator.pushNamedAndRemoveUntil(
                    AppRoutes.preparation, (route) => false);
              }
            },
          ),
        ),
        contentPadding: EdgeInsets.zero,
        drawer: const PreparationDrawer(
            selectedRouteName: AppRoutes.preparationProduction),
        bottom: const PreparationDock(showPrimaryFab: false),
        child: Column(children: [
          IgnorePointer(
            ignoring: !currentAccount,
            child: AdminExpandableFilterChip<String>(
              chipKey: const ValueKey('production-status-filter'),
              label: 'Holat',
              emptyLabel: 'Barchasi',
              icon: Icons.filter_list_rounded,
              selectedValue: _status,
              options: const [
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
                setState(() {
                  _status = status;
                  _statusExpanded = false;
                });
                _filter();
              },
            ),
          ),
          Expanded(
              child: journal(
                  empty: 'Hali ishlab chiqarish yozuvlari yo‘q.',
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 136),
                  children: [
                    M3SegmentSpacedColumn(children: [
                      for (final (index, order) in items.indexed)
                        _JournalListRow(
                          key: ValueKey('production-order:${order.id}'),
                          slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                              index, items.length),
                          icon: Icons.receipt_long_outlined,
                          title: '${order.displayCode} • ${order.title}',
                          subtitle: [
                            order.customerName,
                            '${order.batchCount} ta ishlab chiqarish',
                            if (order.activeBatchCount > 0)
                              '${order.activeBatchCount} ta davom etmoqda',
                            _date(order.lastActivityAt)
                          ].where((value) => value.isNotEmpty).join(' • '),
                          metrics:
                              '${order.rollCount} ta rulon • ${preparationDisplay(order.netKg)} kg • ${preparationDisplay(order.lengthM)} m',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => PreparationProductionOrderScreen(
                                  orderId: order.id),
                            ),
                          ),
                        ),
                    ]),
                  ])),
        ]),
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
        bottom: const PreparationDock(showPrimaryFab: false),
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
                    title: order.title,
                    subtitle: order.customerName,
                    metrics:
                        '${order.rollCount} ta rulon • ${preparationDisplay(order.netKg)} kg • ${preparationDisplay(order.lengthM)} m',
                  ),
                for (final (index, batch) in items.indexed)
                  _JournalListRow(
                    key: ValueKey('production-batch:${batch.id}'),
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                        index + (_order == null ? 0 : 1),
                        items.length + (_order == null ? 0 : 1)),
                    icon: Icons.inventory_2_outlined,
                    title: batch.displayItem,
                    subtitle:
                        '${batch.formulaName}\n${batch.active ? 'Davom etmoqda' : 'Yakunlangan'} • ${batch.warehouse} • ${_date(batch.lastActivityAt)}',
                    metrics:
                        '${batch.rollCount} ta rulon • ${preparationDisplay(batch.netKg)} kg • ${preparationDisplay(batch.lengthM)} m',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PreparationProductionBatchScreen(
                            batchId: batch.id),
                      ),
                    ),
                  ),
              ]),
            ]),
      );
}

class _ProductionBatchState extends _JournalState<
    PreparationProductionBatchScreen, PreparationProductionRoll> {
  PreparationProductionBatch? _batch;
  @override
  Future<_JournalPage<PreparationProductionRoll>> request(int offset) async {
    final page = await MobileApi.instance
        .preparationProductionBatch(widget.batchId, offset: offset);
    return _JournalPage(page, page.rolls);
  }

  @override
  String identity(PreparationProductionRoll item) => item.epc;
  @override
  void received(PreparationProductionPage page) =>
      _batch = (page as PreparationProductionBatchPage).batch;
  @override
  void clearSummary() => _batch = null;
  @override
  void didUpdateWidget(PreparationProductionBatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.batchId != widget.batchId) {
      items = [];
      _batch = null;
      unawaited(load());
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: _batch?.displayItem ?? 'Ishlab chiqarish',
        subtitle: '',
        nativeTopBar: true,
        contentPadding: EdgeInsets.zero,
        bottom: const PreparationDock(showPrimaryFab: false),
        child: journal(
          empty: 'Hali rulon kirim qilinmagan.',
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 136),
          children: [
            M3SegmentSpacedColumn(children: [
              if (_batch case final batch?) ...[
                _JournalListRow(
                  key: const ValueKey('production-batch-summary'),
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      0, items.length + 2),
                  icon: Icons.inventory_2_outlined,
                  title: batch.active ? 'Davom etmoqda' : 'Yakunlangan',
                  subtitle:
                      '${batch.warehouse}\nBoshlangan: ${_date(batch.startedAt)}${batch.endedAt.isEmpty ? '' : '\nTugagan: ${_date(batch.endedAt)}'}',
                  metrics:
                      '${batch.rollCount} ta rulon • ${preparationDisplay(batch.netKg)} kg • ${preparationDisplay(batch.lengthM)} m',
                ),
                _ProductionRecipe(
                  key: const ValueKey('production-batch-recipe'),
                  formula: batch.formula,
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      1, items.length + 2),
                ),
              ],
              for (final (index, roll) in items.indexed)
                _JournalListRow(
                  key: ValueKey('production-roll:${roll.epc}'),
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index + (_batch == null ? 0 : 2),
                      items.length + (_batch == null ? 0 : 2)),
                  icon: Icons.qr_code_2_rounded,
                  title: roll.epc,
                  titleMaxLines: 2,
                  subtitle: '${_date(roll.printedAt)} • ${roll.warehouse}',
                  metrics:
                      '${preparationDisplay(roll.netKg)} kg${roll.lengthM == null ? '' : ' • ${preparationDisplay(roll.lengthM!)} m'}${roll.widthMm == null ? '' : ' • ${preparationDisplay(roll.widthMm!)} mm'}${roll.micron == null ? '' : ' • ${preparationDisplay(roll.micron!)} mkm'}',
                  onTap: () => _showRoll(context, roll, _batch?.orderId ?? ''),
                ),
            ]),
          ],
        ),
      );
}

class _JournalListRow extends StatelessWidget {
  const _JournalListRow({
    super.key,
    required this.slot,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.metrics,
    this.titleMaxLines = 1,
    this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final IconData icon;
  final String title, subtitle, metrics;
  final int titleMaxLines;
  final VoidCallback? onTap;

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
        l10n.uiText(metrics),
      ].join('\n'),
      subtitleMaxLines: 8,
      onTap: onTap,
    );
  }
}

class _ProductionRecipe extends StatelessWidget {
  const _ProductionRecipe({super.key, required this.formula, this.slot});
  final Map<String, dynamic>? formula;
  final M3SegmentVerticalSlot? slot;
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
        );
      }
      return const Card.filled(
          child: Padding(
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
        for (final screw in (recipe['formulas'] as List? ?? const [])
            .whereType<Map>()) ...[
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
        child: content,
      );
    }
    return Card.filled(child: content);
  }
}

String _date(String raw) {
  final value = DateTime.tryParse(raw)?.toLocal();
  if (value == null) return raw.isEmpty ? '—' : raw;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}.${two(value.month)}.${value.year} ${two(value.hour)}:${two(value.minute)}';
}

Future<void> _showRoll(
  BuildContext context,
  PreparationProductionRoll roll,
  String orderId,
) {
  final scope = currentSessionReadScope();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => RpsQrReprintSheet(
      payload: roll.epc,
      itemName: roll.itemName.isEmpty ? roll.itemCode : roll.itemName,
      showCloseButton: false,
      reprintButtonKey: ValueKey('production-roll-reprint-${roll.epc}'),
      onReprint: () => _reprintRoll(sheetContext, roll, orderId, scope),
      errorMessage: (error) => error is MobileApiException
          ? error.message
          : error is PlatformException && error.message?.isNotEmpty == true
              ? error.message!
              : error.toString().replaceFirst('Bad state: ', ''),
      detailsContent: _ProductionRecipe(formula: roll.formula),
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
  if (!currentSession()) throw const RpsQrReprintCancelled();
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
    final response = await http.post(
      Uri.parse('${server.endpoint.baseUrl}/v1/mobile/driver/print'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        ...prepared.printRequest.toJson(),
        if (printer.printer.isNotEmpty) 'printer': printer.printer,
        if (printer.printMode.isNotEmpty) 'print_mode': printer.printMode,
      }),
    ).timeout(const Duration(seconds: 15));
    final payload = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode > 299 ||
        payload is! Map || payload['ok'] != true) {
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
