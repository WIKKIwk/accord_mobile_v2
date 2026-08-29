import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/native_bluetooth_printer.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_service.dart';
import '../../../core/print_transport.dart';
import '../../../core/widgets/feedback/app_dialog_action_row.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../admin/presentation/widgets/admin_create_hub_sheet.dart';
import '../../gscale/gscale_mobile_app.dart'
    show DiscoveredServer, driverUrlForRs, showPrintDevicePicker;
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../qolip_batch.dart';
import '../qolip_search_matcher.dart';
import '../state/qolip_data_revision.dart';
import 'qolip_cell_qr_scan_screen.dart';
import 'qolip_color_picker.dart';
import 'widgets/qolip_cell_picker_sheet.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

part 'qolip_home_screen__QolipHomeScreenState_methods_01.dart';
part 'qolip_home_screen__QolipHomeScreenState_methods_02.dart';
part 'qolip_home_screen__QolipHomeScreenState_methods_03.dart';
part 'qolip_home_screen__QolipHomeScreenState_methods_04.dart';
part 'qolip_home_screen__QolipBlockGrid_methods_05.dart';
part 'qolip_home_screen__QolipAttachSheetState_methods_06.dart';
part 'qolip_home_screen__QolipAttachSheetState_methods_07.dart';
part 'qolip_home_screen_widgets_part_01.dart';
part 'qolip_home_screen_models_part_02.dart';
part 'qolip_home_screen_declarations_part_03.dart';
part 'qolip_home_screen_widgets_part_04.dart';
part 'qolip_home_screen_helpers_part_05.dart';

class _QolipHomeScreenState extends State<QolipHomeScreen>
    with SingleTickerProviderStateMixin {
  static const _blockOrderPreferenceKey = 'qolip.home.block_order';

  late Future<QolipBlocksResult> _blocksFuture;
  final Map<String, Future<List<QolipLocationEntry>>> _locations = {};
  final Map<String, List<QolipLocationEntry>> _resolvedLocations = {};
  final Map<String, int> _locationGenerations = {};
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<QolipBlock> _orderedBlocks = const <QolipBlock>[];
  Map<String, int> _blockSearchMatchCounts = const <String, int>{};
  String _searchQuery = '';
  TabController? _blockTabController;
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  bool _supportsCrossBlockMove = false;

  @override
  void initState() {
    super.initState();
    _blocksFuture = _loadBlocks();
    QolipDataRevision.locations.addListener(_handleLocationsChanged);
  }

  @override
  void dispose() {
    QolipDataRevision.locations.removeListener(_handleLocationsChanged);
    _blockTabController?.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppShell(
      title: '',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: l10n.qolipText('home.search'),
        onChanged: _onSearchChanged,
        onClear: () {
          _searchController.clear();
          _onSearchChanged('');
        },
        onBackWithContext: (context) =>
            AppShellDrawerScope.maybeOf(context)?.openDrawer(),
        leadingIcon: Icons.menu_rounded,
        leadingTooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      ),
      drawer: QolipNavigationDrawer(
        selectedIndex: 0,
        onNavigate: _openDrawerRoute,
      ),
      bottom: ValueListenableBuilder<bool>(
        valueListenable: adminCreateHubMenuOpen,
        builder: (context, menuOpen, _) => QolipDock(
          activeTab: QolipDockTab.home,
          showPrimaryFab: !menuOpen,
          onPrimaryFabTap: () => unawaited(_openHomeFabHub()),
        ),
      ),
      contentPadding: EdgeInsets.zero,
      child: FutureBuilder<QolipBlocksResult>(
        future: _blocksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError) {
            return AppRetryState(onRetry: _reloadBlocks);
          }
          final data = snapshot.data ??
              const QolipBlocksResult(warehouses: [], blocks: []);
          final blocks = _orderedBlocks.isEmpty && data.blocks.isNotEmpty
              ? data.blocks
              : _orderedBlocks;
          if (blocks.isEmpty) {
            return Center(
              child: Text(
                data.warehouses.isEmpty
                    ? l10n.qolipText('home.no_blocks_attached')
                    : l10n.qolipText('home.no_blocks_added'),
              ),
            );
          }
          final tabController = _ensureBlockTabController(blocks.length + 1);
          var lastBlockIndex = tabController.index.clamp(
            0,
            blocks.length - 1,
          );
          return Stack(
            children: [
              Column(
                children: [
                  _QolipBlockTabBar(
                    controller: tabController,
                    blocks: blocks,
                    searchMatchCounts: _blockSearchMatchCounts,
                    onTap: (index) {
                      lastBlockIndex = index;
                    },
                    onReorder: (oldIndex, newIndex) => _reorderBlocks(
                      tabController,
                      oldIndex,
                      newIndex,
                    ),
                    onAdd: () {
                      final selectedBlock = blocks[lastBlockIndex];
                      tabController.index = lastBlockIndex;
                      unawaited(
                        _openBlockCreateSheet(
                          warehouses: data.warehouses,
                          initialWarehouse: selectedBlock.warehouse,
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final block in blocks)
                          _QolipBlockGrid(
                            block: block,
                            future: _locationsFor(block.name),
                            initialLocations:
                                _resolvedLocations[_blockKey(block)],
                            searchQuery: _searchQuery,
                            onRefresh: () async {
                              _refreshBlock(block.name);
                              await _locationsFor(block.name);
                            },
                            onAttachAt: (
                              block,
                              rowLetter,
                              columnNumber,
                            ) =>
                                _openAttachSheet(
                              blocks,
                              mode: _QolipAttachMode.cellPlacement,
                              initialBlock: block,
                              rowLetter: rowLetter,
                              columnNumber: columnNumber,
                            ),
                            onPrintCellQr: _printCellQr,
                            onMove: _moveQolip,
                            onMoveSelected: _moveQolips,
                            onMoveToCell: (
                              item,
                              rowLetter,
                              columnNumber,
                              cellLabel,
                            ) =>
                                _moveQolipToCell(
                              item,
                              targetBlock: block,
                              rowLetter: rowLetter,
                              columnNumber: columnNumber,
                              cellLabel: cellLabel,
                            ),
                            onTake: _takeQolip,
                          ),
                        const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QolipBlockGrid extends StatelessWidget {
  const _QolipBlockGrid({
    required this.block,
    required this.future,
    required this.initialLocations,
    required this.searchQuery,
    required this.onRefresh,
    required this.onAttachAt,
    required this.onPrintCellQr,
    required this.onMove,
    required this.onMoveSelected,
    required this.onMoveToCell,
    required this.onTake,
  });

  final QolipBlock block;
  final Future<List<QolipLocationEntry>> future;
  final List<QolipLocationEntry>? initialLocations;
  final String searchQuery;
  final Future<void> Function() onRefresh;
  final Future<void> Function(
    QolipBlock block,
    String rowLetter,
    int columnNumber,
  ) onAttachAt;
  final Future<void> Function(
    QolipBlock block,
    String rowLetter,
    int columnNumber,
  ) onPrintCellQr;
  final Future<void> Function(
    QolipLocationEntry item, {
    String? excludeCellLabel,
  }) onMove;
  final Future<void> Function(List<QolipLocationEntry> items) onMoveSelected;
  final Future<bool> Function(
    QolipLocationEntry item,
    String rowLetter,
    int columnNumber,
    String cellLabel,
  ) onMoveToCell;
  final Future<void> Function(QolipLocationEntry item) onTake;

  static const List<String> _letters = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];
  static const int _gridRowCount = 13;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<List<QolipLocationEntry>>(
      future: future,
      initialData: initialLocations,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError && !snapshot.hasData) {
          return AppRetryState(onRetry: onRefresh);
        }
        final locations = snapshot.data ?? const <QolipLocationEntry>[];
        final byCell = <String, List<QolipLocationEntry>>{};
        final unplaced = <QolipLocationEntry>[];
        for (final location in locations) {
          final label = location.locationLabel.trim().toUpperCase();
          if (label.isEmpty) {
            unplaced.add(location);
          } else {
            byCell.putIfAbsent(label, () => []).add(location);
          }
        }
        final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 320;
        var occupiedCells = 0;
        var totalQty = 0;
        for (final entry in byCell.entries) {
          if (entry.value.isEmpty) {
            continue;
          }
          occupiedCells++;
          for (final item in entry.value) {
            totalQty += item.quantity;
          }
        }
        for (final item in unplaced) {
          totalQty += item.quantity;
        }
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: EdgeInsets.fromLTRB(4, 8, 4, bottomPadding),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _QolipStatChip(
                        icon: Icons.grid_view_rounded,
                        label: l10n.qolipText(
                          'home.occupied_count',
                          values: {'count': occupiedCells},
                        ),
                      ),
                      _QolipStatChip(
                        icon: Icons.layers_rounded,
                        label: l10n.qolipText(
                          'home.mold_count_stat',
                          values: {'count': totalQty},
                        ),
                      ),
                      if (unplaced.isNotEmpty)
                        _QolipStatChip(
                          icon: Icons.warning_amber_rounded,
                          label: l10n.qolipText(
                            'home.unplaced_count',
                            values: {'count': unplaced.length},
                          ),
                          tone: _QolipStatChipTone.warning,
                        ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _QolipGridTable(
                    letters: _letters,
                    rowCount: _gridRowCount,
                    byCell: byCell,
                    searchQuery: searchQuery,
                    onCellTap: (cellLabel, items) =>
                        _openCellAction(context, cellLabel, items, locations),
                    onCellLongPress: (cellLabel) =>
                        _openCellQrPrint(context, cellLabel),
                  ),
                ),
                if (occupiedCells == 0 && unplaced.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 18, 12, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 36,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.qolipText('home.no_molds'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.qolipText('home.attach_hint'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (unplaced.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Text(
                      l10n.qolipText('home.unplaced'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  for (final item in unplaced) _QolipUnplacedTile(item: item),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static String? _cellRowLetter(String cellLabel) {
    final letters = cellLabel.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.isEmpty) {
      return null;
    }
    return letters.toUpperCase();
  }

  static int? _cellColumnNumber(String cellLabel) {
    return int.tryParse(cellLabel.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  static Future<void> _openCellDetail(
    BuildContext context,
    String cellLabel,
    List<QolipLocationEntry> items, {
    required List<QolipLocationEntry> unplaced,
    required List<QolipLocationEntry> movableIn,
    required Future<void> Function(QolipLocationEntry item) onTake,
    required Future<void> Function(QolipLocationEntry item) onMoveOut,
    required Future<void> Function(List<QolipLocationEntry> items)
        onMoveSelected,
    required Future<bool> Function(QolipLocationEntry item) onMoveToCell,
    required Future<void> Function() onAdd,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final selectedKeys = <String>{};
    final action = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: scheme.surface,
      builder: (context) {
        final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selectionMode = selectedKeys.isNotEmpty;
            final selectedItems = items
                .where((item) => selectedKeys.contains(item.id))
                .toList(growable: false);

            void toggleSelection(QolipLocationEntry item) {
              setSheetState(() {
                if (!selectedKeys.add(item.id)) {
                  selectedKeys.remove(item.id);
                }
              });
            }

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectionMode
                                ? l10n.qolipCount(selectedItems.length)
                                : l10n.qolipText(
                                    'home.cell',
                                    values: {'cell': cellLabel},
                                  ),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (selectionMode)
                          IconButton.filled(
                            key: const ValueKey('qolip-bulk-move-button'),
                            onPressed: () => Navigator.of(context).pop(
                              _QolipCellBulkMoveSelection(
                                items: selectedItems,
                              ),
                            ),
                            tooltip: l10n.qolipText('home.move'),
                            icon: const Icon(
                              Icons.drive_file_move_outlined,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      fit: FlexFit.loose,
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          for (final item in items) ...[
                            _QolipCellActionTile(
                              item: item,
                              selected: selectedKeys.contains(item.id),
                              onLongPress: () => toggleSelection(item),
                              onTap: selectionMode
                                  ? () => toggleSelection(item)
                                  : null,
                              onTake: selectionMode
                                  ? null
                                  : () => Navigator.of(context).pop(
                                        _QolipCellItemSelection(
                                          item: item,
                                          action: _QolipCellItemAction.take,
                                        ),
                                      ),
                              onMove: selectionMode
                                  ? null
                                  : () => Navigator.of(context).pop(
                                        _QolipCellItemSelection(
                                          item: item,
                                          action: _QolipCellItemAction.moveOut,
                                        ),
                                      ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (unplaced.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: selectionMode
                              ? null
                              : () => Navigator.of(context)
                                  .pop(_QolipCellSheetAction.placeUnplaced),
                          icon: const Icon(Icons.warning_amber_rounded),
                          label: Text(
                            l10n.qolipText(
                              'home.unplaced_molds',
                              values: {'count': unplaced.length},
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (movableIn.isNotEmpty) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: selectionMode
                              ? null
                              : () => Navigator.of(context)
                                  .pop(_QolipCellSheetAction.moveIn),
                          icon: const Icon(Icons.move_down_rounded),
                          label: Text(
                            l10n.qolipText(
                              'home.move_from_other',
                              values: {'count': movableIn.length},
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: selectionMode
                            ? null
                            : () => Navigator.of(context)
                                .pop(_QolipCellSheetAction.add),
                        icon: const Icon(Icons.add_location_alt_rounded),
                        label: Text(l10n.qolipText('home.add_here')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!context.mounted || action == null) {
      return;
    }
    if (action == _QolipCellSheetAction.add) {
      await onAdd();
      return;
    }
    if (action == _QolipCellSheetAction.placeUnplaced) {
      final picked = await _pickQolipLocation(
        context,
        title: l10n.qolipText('home.choose_unplaced'),
        options: unplaced,
      );
      if (picked != null && context.mounted) {
        await onMoveToCell(picked);
      }
      return;
    }
    if (action == _QolipCellSheetAction.moveIn) {
      final picked = await _pickQolipLocation(
        context,
        title: l10n.qolipText('home.choose_move'),
        options: movableIn,
      );
      if (picked != null && context.mounted) {
        await onMoveToCell(picked);
      }
      return;
    }
    if (action is _QolipCellItemSelection) {
      switch (action.action) {
        case _QolipCellItemAction.take:
          await onTake(action.item);
        case _QolipCellItemAction.moveOut:
          await onMoveOut(action.item);
      }
      return;
    }
    if (action is _QolipCellBulkMoveSelection) {
      await onMoveSelected(action.items);
    }
  }

  static Future<QolipLocationEntry?> _pickQolipLocation(
    BuildContext context, {
    required String title,
    required List<QolipLocationEntry> options,
  }) {
    final l10n = context.l10n;
    return showModalBottomSheet<QolipLocationEntry>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              for (final item in options)
                ListTile(
                  leading: const Icon(Icons.layers_rounded),
                  title: Text(
                    item.itemName.trim().isEmpty
                        ? item.qolipCode
                        : item.itemName,
                  ),
                  subtitle: Text(
                    [
                      item.qolipCode,
                      '${item.size}',
                      l10n.qolipCount(item.quantity),
                      if (item.locationLabel.trim().isNotEmpty)
                        item.locationLabel,
                    ].where((value) => value.trim().isNotEmpty).join(' • '),
                  ),
                  onTap: () => Navigator.of(context).pop(item),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _QolipAttachSheetState extends State<_QolipAttachSheet> {
  final _qolipCode = TextEditingController();
  final _size = TextEditingController();
  late final Future<Set<String>> _placedQolipCodesFuture;
  Future<List<QolipProduct>>? _productsFuture;
  QolipBlock? _block;
  QolipProduct? _product;
  List<QolipProduct> _selectedProducts = const <QolipProduct>[];
  List<QolipProduct> _savedProductSpecs = const <QolipProduct>[];
  final List<String> _selectedColors = <String>[];
  final List<int> _pantonNumbers = <int>[1];
  bool _batchCodesExpanded = false;
  String? _rowLetter;
  int? _columnNumber;
  bool _saving = false;
  bool _printingQr = false;

  @override
  void initState() {
    super.initState();
    _block = _initialBlock();
    _product = widget.initialProduct;
    _selectedProducts = widget.initialProduct == null
        ? const <QolipProduct>[]
        : <QolipProduct>[widget.initialProduct!];
    _rowLetter = widget.initialRowLetter;
    _columnNumber = widget.initialColumnNumber;
    _placedQolipCodesFuture = widget.mode == _QolipAttachMode.cellPlacement
        ? _loadPlacedQolipCodes()
        : Future.value(const <String>{});
  }

  @override
  void dispose() {
    _qolipCode.dispose();
    _size.dispose();
    super.dispose();
  }

  QolipBatchCodeDraft? get _batchDraft => parseQolipBatchCode(_qolipCode.text);

  bool get _canAddPanton {
    final draft = _batchDraft;
    return draft == null || _pantonNumbers.length < draft.count;
  }

  bool get _canSave {
    final size = int.tryParse(_size.text.trim()) ?? 0;
    if (widget.mode == _QolipAttachMode.productSpec) {
      final draft = _batchDraft;
      final colorsValid = draft != null &&
          (draft.count == 1
              ? _selectedColors.length <= 1
              : _selectedColors.length == draft.count);
      return _savedProductSpecs.isEmpty &&
          _product != null &&
          draft != null &&
          colorsValid &&
          size > 0;
    }
    return _block != null &&
        _selectedProducts.isNotEmpty &&
        _selectedProducts.every((product) => product.hasQolipSpec) &&
        _rowLetter != null &&
        _columnNumber != null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final productSpecSaved = _savedProductSpecs.isNotEmpty;
    final batchDraft = _batchDraft;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, bottomInset + 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _title(l10n),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  if (widget.mode == _QolipAttachMode.cellPlacement)
                    IconButton.filledTonal(
                      onPressed: _scanQolipQr,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      tooltip: l10n.qolipText('home.qr_scan_tooltip'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              if (widget.mode == _QolipAttachMode.cellPlacement &&
                  _block != null &&
                  _rowLetter != null &&
                  _columnNumber != null) ...[
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.qolipText('home.location'),
                  ),
                  child: Text('${_block!.name} • $_rowLetter$_columnNumber'),
                ),
                const SizedBox(height: 12),
              ],
              InkWell(
                onTap: productSpecSaved || widget.lockProduct
                    ? null
                    : _pickProduct,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: widget.mode == _QolipAttachMode.cellPlacement
                        ? l10n.qolipText('home.code_or_product')
                        : l10n.qolipText('home.ready_product'),
                    suffixIcon: widget.lockProduct
                        ? const Icon(Icons.lock_outline_rounded)
                        : const Icon(Icons.search_rounded),
                  ),
                  child: Text(
                    _selectedProducts.length > 1
                        ? l10n.qolipText(
                            'products.mold_count',
                            values: {'count': _selectedProducts.length},
                          )
                        : _product == null
                            ? widget.mode == _QolipAttachMode.cellPlacement
                                ? l10n.qolipText(
                                    'home.mold_code_or_product_hint',
                                  )
                                : l10n.qolipText(
                                    'home.product_search_hint',
                                  )
                            : _productLabel(_product!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (widget.mode == _QolipAttachMode.productSpec) ...[
                TextField(
                  controller: _qolipCode,
                  enabled: !productSpecSaved,
                  decoration: InputDecoration(
                    labelText: l10n.qolipText('home.mold_code_label'),
                  ),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                if (batchDraft != null) ...[
                  const SizedBox(height: 10),
                  Material(
                    key: const ValueKey('qolip-batch-preview'),
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => setState(
                        () => _batchCodesExpanded = !_batchCodesExpanded,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l10n.qolipText(
                                      'products.mold_count',
                                      values: {'count': batchDraft.count},
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                Icon(
                                  _batchCodesExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                ),
                              ],
                            ),
                            if (_batchCodesExpanded) ...[
                              const SizedBox(height: 6),
                              Column(
                                key:
                                    const ValueKey('qolip-batch-preview-codes'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final code in batchDraft.codes)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text(code),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _size,
                  enabled: !productSpecSaved,
                  decoration: InputDecoration(
                    labelText: l10n.qolipText('home.size_label'),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.qolipText(
                    'home.color_label',
                    values: {
                      'selected': _selectedColors.length,
                      'total': batchDraft?.count ?? 1,
                    },
                  ),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                QolipColorPicker(
                  selectedColors: _selectedColors,
                  pantonNumbers: _pantonNumbers,
                  maxSelectedColors: batchDraft?.count ?? 1,
                  enabled: !productSpecSaved,
                  onAddPanton:
                      !productSpecSaved && _canAddPanton ? _addPanton : null,
                  onColorsChanged: (colors) => setState(() {
                    _selectedColors
                      ..clear()
                      ..addAll(colors);
                  }),
                ),
              ] else ...[
                if (_selectedProducts.isNotEmpty &&
                    _selectedProducts.every(
                      (product) => product.hasQolipSpec,
                    )) ...[
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.qolipText('home.mold_label'),
                    ),
                    child: Text(
                      _selectedProducts.length == 1
                          ? '${_selectedProducts.single.qolipCode} • ${_selectedProducts.single.qolipSize}'
                          : l10n.qolipText(
                              'products.mold_count',
                              values: {'count': _selectedProducts.length},
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: widget.mode == _QolipAttachMode.productSpec &&
                        productSpecSaved
                    ? FilledButton.icon(
                        onPressed: _printingQr ? null : _printSavedCodeQr,
                        icon: _printingQr
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.qr_code_2_rounded),
                        label: Text(l10n.qolipText('action.print_qr')),
                      )
                    : FilledButton(
                        onPressed: _canSave && !_saving ? _save : null,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.qolipText('action.save')),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
