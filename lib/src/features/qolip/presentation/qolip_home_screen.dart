import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_surface_tab_bar.dart';
import '../../gscale/gscale_mobile_app.dart'
    show
        DiscoveredServer,
        discoverServers,
        discoverServersFast,
        driverUrlForRs,
        loadLastUsedServer,
        printTargetLabel;
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

class QolipHomeScreen extends StatefulWidget {
  const QolipHomeScreen({super.key});

  @override
  State<QolipHomeScreen> createState() => _QolipHomeScreenState();
}

class _QolipHomeScreenState extends State<QolipHomeScreen> {
  late Future<QolipBlocksResult> _blocksFuture;
  final Map<String, Future<List<QolipLocationEntry>>> _locations = {};

  @override
  void initState() {
    super.initState();
    _blocksFuture = _loadBlocks();
  }

  Future<QolipBlocksResult> _loadBlocks() async {
    final result = await MobileApi.instance.qolipBlocksData();
    return QolipBlocksResult(
      warehouses: result.warehouses
          .where((warehouse) => warehouse.trim().isNotEmpty)
          .toList(growable: false),
      blocks: result.blocks
          .where((block) => block.name.trim().isNotEmpty)
          .toList(growable: false),
    );
  }

  Future<void> _reloadBlocks() async {
    setState(() {
      _locations.clear();
      _blocksFuture = _loadBlocks();
    });
    await _blocksFuture;
  }

  Future<List<QolipLocationEntry>> _locationsFor(String block) {
    final key = block.trim().toLowerCase();
    return _locations.putIfAbsent(
      key,
      () => MobileApi.instance.qolipLocations(block),
    );
  }

  void _refreshBlock(String block) {
    final key = block.trim().toLowerCase();
    setState(() {
      _locations[key] = MobileApi.instance.qolipLocations(block);
    });
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  Future<void> _printCellQr(
    QolipBlock block,
    String rowLetter,
    int columnNumber,
  ) async {
    final option = await _showQolipPrinterPicker(context);
    if (!mounted || option == null) {
      return;
    }
    try {
      final printer = _qolipPrinterChoice(option.printerLabel);
      final cellQr = await MobileApi.instance.qolipPrintCellQr(
        block: block,
        rowLetter: rowLetter,
        columnNumber: columnNumber,
        driverUrl: option.driverUrl,
        printer: printer,
        printMode: printer == 'godex' ? 'label' : 'rfid',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${cellQr.locationLabel} QR chop etildi: ${cellQr.qrPayload}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yachayka QR chop etilmadi')),
      );
    }
  }

  Future<void> _openFabAction(QolipBlocksResult data) async {
    if (data.warehouses.isEmpty) {
      return;
    }
    final action = await showModalBottomSheet<_QolipFabAction>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(
                        _QolipFabAction.createBlock,
                      ),
                      icon: const Icon(Icons.view_module_rounded),
                      label: const Text('Blok qo‘shish'),
                    ),
                    if (data.blocks.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).pop(
                          _QolipFabAction.attachQolip,
                        ),
                        icon: const Icon(Icons.add_location_alt_rounded),
                        label: const Text('Qolipni omborga biriktirish'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    if (action == null || !mounted) {
      return;
    }
    if (action == _QolipFabAction.createBlock) {
      final created = await showModalBottomSheet<QolipBlock>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.32),
        builder: (context) => _QolipBlockCreateSheet(
          warehouses: data.warehouses,
        ),
      );
      if (created != null && mounted) {
        await _reloadBlocks();
      }
      return;
    }
    await _openAttachSheet(
      data.blocks,
      mode: _QolipAttachMode.productSpec,
    );
  }

  Future<void> _openAttachSheet(
    List<QolipBlock> blocks, {
    required _QolipAttachMode mode,
    QolipBlock? initialBlock,
    String? rowLetter,
    int? columnNumber,
  }) async {
    final savedBlock = await showModalBottomSheet<QolipBlock>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => _QolipAttachSheet(
        mode: mode,
        blocks: blocks,
        initialBlock: initialBlock,
        initialRowLetter: rowLetter,
        initialColumnNumber: columnNumber,
      ),
    );
    if (savedBlock != null && mounted) {
      _refreshBlock(savedBlock.name);
    }
  }

  Future<void> _openBlockCreateSheet({
    required List<String> warehouses,
    String initialWarehouse = '',
  }) async {
    final created = await showModalBottomSheet<QolipBlock>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => _QolipBlockCreateSheet(
        warehouses: warehouses,
        initialWarehouse: initialWarehouse,
        showWarehouseField: false,
      ),
    );
    if (created != null && mounted) {
      await _reloadBlocks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Qolipchi',
      subtitle: '',
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: QolipNavigationDrawer(
        selectedIndex: 0,
        onNavigate: _openDrawerRoute,
      ),
      bottom: const QolipDock(activeTab: QolipDockTab.home),
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
          final blocks = data.blocks;
          if (blocks.isEmpty) {
            return Stack(
              children: [
                Center(
                  child: Text(
                    data.warehouses.isEmpty
                        ? 'Block biriktirilmagan'
                        : 'Blok qo‘shilmagan',
                  ),
                ),
                if (data.warehouses.isNotEmpty)
                  Positioned(
                    right: 16,
                    bottom: MediaQuery.viewPaddingOf(context).bottom + 112,
                    child: FloatingActionButton.extended(
                      onPressed: () => _openFabAction(data),
                      icon: const Icon(Icons.view_module_rounded),
                      label: const Text('Blok'),
                    ),
                  ),
              ],
            );
          }
          return Stack(
            children: [
              DefaultTabController(
                length: blocks.length + 1,
                child: Builder(
                  builder: (context) {
                    final tabController = DefaultTabController.of(context);
                    var lastBlockIndex = tabController.index.clamp(
                      0,
                      blocks.length - 1,
                    );
                    return Column(
                      children: [
                        AdminSurfaceTabBar(
                          controller: tabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          onTap: (index) {
                            if (index != blocks.length) {
                              lastBlockIndex = index;
                              return;
                            }
                            final selectedBlock = blocks[lastBlockIndex];
                            tabController.index = lastBlockIndex;
                            unawaited(
                              _openBlockCreateSheet(
                                warehouses: data.warehouses,
                                initialWarehouse: selectedBlock.warehouse,
                              ),
                            );
                          },
                          tabs: [
                            for (final block in blocks)
                              Tab(height: 38, text: block.name),
                            const Tab(
                              height: 38,
                              iconMargin: EdgeInsets.zero,
                              icon: Icon(Icons.add_rounded, size: 20),
                            ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              for (final block in blocks)
                                _QolipBlockGrid(
                                  block: block,
                                  future: _locationsFor(block.name),
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
                                ),
                              const SizedBox.shrink(),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                right: 16,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 112,
                child: FloatingActionButton.extended(
                  onPressed: () => _openFabAction(data),
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('Biriktirish'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _QolipFabAction { createBlock, attachQolip }

enum _QolipAttachMode { productSpec, cellPlacement }

class _QolipBlockGrid extends StatelessWidget {
  const _QolipBlockGrid({
    required this.block,
    required this.future,
    required this.onRefresh,
    required this.onAttachAt,
    required this.onPrintCellQr,
  });

  final QolipBlock block;
  final Future<List<QolipLocationEntry>> future;
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
  static const int _gridRowCount = 9;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QolipLocationEntry>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return const Center(child: AppLoadingIndicator());
        }
        if (snapshot.hasError) {
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
        final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 104;
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
                        label: '$occupiedCells ta joy band',
                      ),
                      _QolipStatChip(
                        icon: Icons.layers_rounded,
                        label: '$totalQty ta qolip',
                      ),
                      if (unplaced.isNotEmpty)
                        _QolipStatChip(
                          icon: Icons.warning_amber_rounded,
                          label: '${unplaced.length} ta joylashmagan',
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
                    onCellTap: (cellLabel, items) =>
                        _openCellAction(context, cellLabel, items),
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
                              'Bu blokda hali qolip yo‘q',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pastdagi Biriktirish tugmasi orqali qo‘shing',
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
                      'Joylashmagan',
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

  Future<void> _openCellAction(
    BuildContext context,
    String cellLabel,
    List<QolipLocationEntry> items,
  ) async {
    final rowLetter = _cellRowLetter(cellLabel);
    final columnNumber = _cellColumnNumber(cellLabel);
    if (rowLetter == null || columnNumber == null) {
      return;
    }
    if (items.isEmpty) {
      await onAttachAt(block, rowLetter, columnNumber);
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _openCellDetail(
      context,
      cellLabel,
      items,
      onAdd: () => onAttachAt(block, rowLetter, columnNumber),
    );
  }

  Future<void> _openCellQrPrint(
    BuildContext context,
    String cellLabel,
  ) async {
    final rowLetter = _cellRowLetter(cellLabel);
    final columnNumber = _cellColumnNumber(cellLabel);
    if (rowLetter == null || columnNumber == null) {
      return;
    }
    await onPrintCellQr(block, rowLetter, columnNumber);
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
    required Future<void> Function() onAdd,
  }) async {
    if (items.isEmpty) {
      return;
    }
    final scheme = Theme.of(context).colorScheme;
    final addRequested = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Joy $cellLabel',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                for (final item in items) ...[
                  _QolipUnplacedTile(item: item),
                  const SizedBox(height: 4),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.add_location_alt_rounded),
                    label: const Text('Shu joyga qolip qo‘shish'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (addRequested == true && context.mounted) {
      await onAdd();
    }
  }
}

class _QolipGridTable extends StatelessWidget {
  const _QolipGridTable({
    required this.letters,
    required this.rowCount,
    required this.byCell,
    required this.onCellTap,
    required this.onCellLongPress,
  });

  final List<String> letters;
  final int rowCount;
  final Map<String, List<QolipLocationEntry>> byCell;
  final void Function(String cellLabel, List<QolipLocationEntry> items)
      onCellTap;
  final void Function(String cellLabel) onCellLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.14),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 42, height: 36),
                for (final letter in letters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _GridHeaderCell(label: letter, isColumn: true),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var rowNumber = 1; rowNumber <= rowCount; rowNumber++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    _GridHeaderCell(label: '$rowNumber', isColumn: false),
                    for (final letter in letters)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _GridDataCell(
                          cellLabel: '$letter$rowNumber',
                          items: byCell['$letter$rowNumber'] ?? const [],
                          onTap: onCellTap,
                          onLongPress: () =>
                              onCellLongPress('$letter$rowNumber'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _QolipStatChipTone { normal, warning }

class _QolipStatChip extends StatelessWidget {
  const _QolipStatChip({
    required this.icon,
    required this.label,
    this.tone = _QolipStatChipTone.normal,
  });

  final IconData icon;
  final String label;
  final _QolipStatChipTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = tone == _QolipStatChipTone.warning
        ? scheme.errorContainer.withValues(alpha: 0.55)
        : scheme.primaryContainer.withValues(alpha: 0.45);
    final foreground = tone == _QolipStatChipTone.warning
        ? scheme.onErrorContainer
        : scheme.onPrimaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GridHeaderCell extends StatelessWidget {
  const _GridHeaderCell({required this.label, required this.isColumn});

  final String label;
  final bool isColumn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: isColumn ? 76 : 42,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isColumn
              ? scheme.primaryContainer.withValues(alpha: 0.55)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isColumn
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
    );
  }
}

class _GridDataCell extends StatelessWidget {
  const _GridDataCell({
    required this.cellLabel,
    required this.items,
    required this.onTap,
    required this.onLongPress,
  });

  final String cellLabel;
  final List<QolipLocationEntry> items;
  final void Function(String cellLabel, List<QolipLocationEntry> items) onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = items.isNotEmpty;
    final qty = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final title = filled ? items.first.itemName : '';

    return Material(
      color: filled
          ? scheme.secondaryContainer
          : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      elevation: filled ? 1 : 0,
      shadowColor: scheme.shadow.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(cellLabel, items),
        onLongPress: onLongPress,
        child: SizedBox(
          width: 76,
          height: 64,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: filled
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.layers_rounded,
                            size: 14,
                            color: scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '$qty ta',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      Icons.add_box_outlined,
                      size: 18,
                      color: scheme.outlineVariant.withValues(alpha: 0.75),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _QolipUnplacedTile extends StatelessWidget {
  const _QolipUnplacedTile({required this.item});

  final QolipLocationEntry item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Material(
        color: scheme.surface,
        elevation: 2,
        shadowColor: scheme.shadow.withValues(alpha: 0.14),
        surfaceTintColor: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 34,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.content_cut_rounded,
                    size: 17,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.qolipCode} • ${item.size} • ${item.quantity} ta',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QolipPrinterOption {
  const _QolipPrinterOption({
    required this.server,
    required this.driverUrl,
    required this.printerLabel,
  });

  final DiscoveredServer server;
  final String driverUrl;
  final String printerLabel;
}

Future<_QolipPrinterOption?> _showQolipPrinterPicker(BuildContext context) {
  return showModalBottomSheet<_QolipPrinterOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _QolipPrinterPickerSheet(),
  );
}

class _QolipPrinterPickerSheet extends StatefulWidget {
  const _QolipPrinterPickerSheet();

  @override
  State<_QolipPrinterPickerSheet> createState() =>
      _QolipPrinterPickerSheetState();
}

class _QolipPrinterPickerSheetState extends State<_QolipPrinterPickerSheet> {
  final http.Client _client = http.Client();
  List<_QolipPrinterOption> _options = const [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrinters());
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _loadPrinters() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final preferredEndpoint = await loadLastUsedServer();
      final fast = await discoverServersFast(
        _client,
        preferredEndpoint: preferredEndpoint,
      );
      var options = await _connectedQolipPrinters(_client, fast.servers);
      if (options.isEmpty) {
        final full = await discoverServers(
          _client,
          preferredEndpoint: preferredEndpoint,
        );
        options = await _connectedQolipPrinters(_client, [
          ...fast.servers,
          ...full.servers,
        ]);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _options = options;
        _loading = false;
        _error = options.isEmpty ? 'Printer ulangan RPS topilmadi' : '';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _options = const [];
        _loading = false;
        _error = 'Printer ulangan RPS topilmadi';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FractionallySizedBox(
      heightFactor: 0.62,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Printerni tanlang',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _loading ? null : () => unawaited(_loadPrinters()),
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Yangilash',
                  ),
                ],
              ),
              if (_loading) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
              if (!_loading && _error.isNotEmpty) ...[
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _error,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final option = _options[index];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: scheme.surfaceContainerHighest,
                      leading: const Icon(Icons.print_rounded),
                      title: Text(
                        printTargetLabel(option.server),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${option.printerLabel} • ${option.driverUrl}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).pop(option),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<List<_QolipPrinterOption>> _connectedQolipPrinters(
  http.Client client,
  List<DiscoveredServer> servers,
) async {
  final seen = <String>{};
  final uniqueServers = <DiscoveredServer>[];
  for (final server in servers) {
    if (seen.add(server.endpoint.baseUrl)) {
      uniqueServers.add(server);
    }
  }
  final options = await Future.wait(
    uniqueServers.map((server) => _connectedQolipPrinter(client, server)),
  );
  return [
    for (final option in options)
      if (option != null) option,
  ];
}

Future<_QolipPrinterOption?> _connectedQolipPrinter(
  http.Client client,
  DiscoveredServer server,
) async {
  try {
    final response = await client
        .get(Uri.parse('${server.endpoint.baseUrl}/v1/mobile/monitor/state'))
        .timeout(const Duration(seconds: 2));
    if (response.statusCode < 200 || response.statusCode > 299) {
      return null;
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final printerRaw = (payload['printer'] as Map?)?.cast<String, dynamic>() ??
        ((payload['state'] as Map?)?['printer'] as Map?)
            ?.cast<String, dynamic>();
    if (printerRaw == null) {
      return null;
    }
    final connected = _qolipJsonBool(printerRaw['connected']) ||
        _qolipJsonBool(printerRaw['ok']);
    if (!connected) {
      return null;
    }
    final kind = _qolipJsonText(printerRaw['kind'], fallback: 'printer');
    return _QolipPrinterOption(
      server: server,
      driverUrl: driverUrlForRs(server).replaceFirst(RegExp(r'/+$'), ''),
      printerLabel: _qolipJsonText(printerRaw['label'], fallback: kind),
    );
  } catch (_) {
    return null;
  }
}

bool _qolipJsonBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
  return false;
}

String _qolipJsonText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _qolipPrinterChoice(String printerLabel) {
  final normalized = printerLabel.trim().toLowerCase();
  return normalized.contains('godex') ? 'godex' : 'zebra';
}

List<QolipProduct> _qolipProductsWithSavedCodeOnly(
  List<QolipProduct> products,
) {
  return products
      .where(
        (product) =>
            product.hasQolipSpec &&
            product.qolipCode.trim().isNotEmpty &&
            product.qolipSize > 0,
      )
      .toList(growable: false);
}

class _QolipBlockCreateSheet extends StatefulWidget {
  const _QolipBlockCreateSheet({
    required this.warehouses,
    this.initialWarehouse = '',
    this.showWarehouseField = true,
  });

  final List<String> warehouses;
  final String initialWarehouse;
  final bool showWarehouseField;

  @override
  State<_QolipBlockCreateSheet> createState() => _QolipBlockCreateSheetState();
}

class _QolipBlockCreateSheetState extends State<_QolipBlockCreateSheet> {
  final _block = TextEditingController();
  String? _warehouse;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialWarehouse.trim();
    _warehouse = initial.isNotEmpty
        ? initial
        : widget.warehouses.isEmpty
            ? null
            : widget.warehouses.first;
  }

  @override
  void dispose() {
    _block.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final warehouse = _warehouse?.trim() ?? '';
    final block = _block.text.trim();
    if (warehouse.isEmpty || block.isEmpty || _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await MobileApi.instance.qolipCreateBlock(
        warehouse: warehouse,
        block: block,
      );
      if (mounted) {
        Navigator.of(context).pop(created);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool get _canSave {
    return (_warehouse?.trim().isNotEmpty ?? false) &&
        _block.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
              Text(
                'Blok qo‘shish',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              if (widget.showWarehouseField) ...[
                DropdownButtonFormField<String>(
                  initialValue: _warehouse,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Ombor'),
                  items: [
                    for (final warehouse in widget.warehouses)
                      DropdownMenuItem(
                        value: warehouse,
                        child: Text(warehouse),
                      ),
                  ],
                  onChanged: (value) => setState(() => _warehouse = value),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _block,
                decoration: const InputDecoration(labelText: 'Blok nomi'),
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave && !_saving ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Saqlash'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QolipAttachSheet extends StatefulWidget {
  const _QolipAttachSheet({
    required this.mode,
    required this.blocks,
    this.initialBlock,
    this.initialRowLetter,
    this.initialColumnNumber,
  });

  final _QolipAttachMode mode;
  final List<QolipBlock> blocks;
  final QolipBlock? initialBlock;
  final String? initialRowLetter;
  final int? initialColumnNumber;

  @override
  State<_QolipAttachSheet> createState() => _QolipAttachSheetState();
}

class _QolipAttachSheetState extends State<_QolipAttachSheet> {
  final _qolipCode = TextEditingController();
  final _size = TextEditingController();
  final _quantity = TextEditingController();
  QolipBlock? _block;
  QolipProduct? _product;
  String? _rowLetter;
  int? _columnNumber;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _block = _initialBlock();
    _rowLetter = widget.initialRowLetter;
    _columnNumber = widget.initialColumnNumber;
  }

  @override
  void dispose() {
    _qolipCode.dispose();
    _size.dispose();
    _quantity.dispose();
    super.dispose();
  }

  QolipBlock? _initialBlock() {
    if (widget.mode == _QolipAttachMode.productSpec) {
      return null;
    }
    if (widget.blocks.isEmpty) {
      return null;
    }
    final initial = widget.initialBlock;
    if (initial == null) {
      return widget.blocks.first;
    }
    for (final block in widget.blocks) {
      if (block.name == initial.name && block.warehouse == initial.warehouse) {
        return block;
      }
    }
    return widget.blocks.first;
  }

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<QolipProduct>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (context) {
        return M3AsyncPickerSheet<QolipProduct>(
          title: 'Tayyor mahsulot tanlang',
          hintText: 'Mahsulot nomi bilan qidiring',
          pageSize: 80,
          cacheKey: widget.mode == _QolipAttachMode.cellPlacement
              ? null
              : 'qolip:products',
          loadPage: (query, offset, limit) {
            if (offset > 0) {
              return Future.value(const <QolipProduct>[]);
            }
            final future = MobileApi.instance.qolipProducts(
              query: query,
              limit: limit,
              withQolipOnly: widget.mode == _QolipAttachMode.cellPlacement,
            );
            if (widget.mode != _QolipAttachMode.cellPlacement) {
              return future;
            }
            return future.then(_qolipProductsWithSavedCodeOnly);
          },
          itemTitle: (item) {
            final name = item.name.trim();
            return name.isEmpty ? item.code : name;
          },
          itemSubtitle: (item) {
            final parts = [
              item.code.trim(),
              item.itemGroup.trim(),
              if (item.hasQolipSpec)
                '${item.qolipCode.trim()} • ${item.qolipSize}',
            ].where((value) => value.isNotEmpty).toList(growable: false);
            return parts.join(' • ');
          },
          onSelected: (item) => Navigator.of(context).pop(item),
        );
      },
    );
    if (picked != null && mounted) {
      setState(() {
        _product = picked;
        if (widget.mode == _QolipAttachMode.productSpec &&
            picked.hasQolipSpec) {
          _qolipCode.text = picked.qolipCode;
          _size.text = picked.qolipSize > 0 ? '${picked.qolipSize}' : '';
        }
      });
    }
  }

  Future<void> _save() async {
    final product = _product;
    final size = int.tryParse(_size.text.trim());
    final quantity = int.tryParse(_quantity.text.trim());
    if (_saving || product == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      if (widget.mode == _QolipAttachMode.productSpec) {
        if (_qolipCode.text.trim().isEmpty || size == null || size <= 0) {
          return;
        }
        await MobileApi.instance.qolipSaveProductSpec(
          product: product,
          qolipCode: _qolipCode.text,
          size: size,
        );
      } else {
        final block = _block;
        final hasPartialLocation =
            (_rowLetter == null) != (_columnNumber == null);
        if (block == null ||
            quantity == null ||
            quantity <= 0 ||
            !product.hasQolipSpec ||
            hasPartialLocation) {
          return;
        }
        await MobileApi.instance.qolipSaveLocation(
          block: block,
          product: product,
          quantity: quantity,
          rowLetter: _rowLetter ?? '',
          columnNumber: _columnNumber,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(
          widget.mode == _QolipAttachMode.cellPlacement ? _block : null,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool get _canSave {
    final size = int.tryParse(_size.text.trim()) ?? 0;
    final quantity = int.tryParse(_quantity.text.trim()) ?? 0;
    if (widget.mode == _QolipAttachMode.productSpec) {
      return _product != null && _qolipCode.text.trim().isNotEmpty && size > 0;
    }
    return _block != null &&
        _product != null &&
        _product!.hasQolipSpec &&
        quantity > 0 &&
        _rowLetter != null &&
        _columnNumber != null;
  }

  String get _title {
    return widget.mode == _QolipAttachMode.productSpec
        ? 'Qolipni omborga biriktirish'
        : 'Qolipni joyga qo‘shish';
  }

  String _productLabel(QolipProduct product) {
    final parts = [
      product.name.trim().isEmpty ? product.code.trim() : product.name.trim(),
      if (product.hasQolipSpec)
        '${product.qolipCode.trim()} • ${product.qolipSize}',
    ].where((value) => value.isNotEmpty).toList(growable: false);
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
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
              Text(
                _title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              if (widget.mode == _QolipAttachMode.cellPlacement &&
                  _block != null &&
                  _rowLetter != null &&
                  _columnNumber != null) ...[
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Joy'),
                  child: Text('${_block!.name} • $_rowLetter$_columnNumber'),
                ),
                const SizedBox(height: 12),
              ],
              InkWell(
                onTap: _pickProduct,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tayyor mahsulot',
                    suffixIcon: Icon(Icons.search_rounded),
                  ),
                  child: Text(
                    _product == null
                        ? 'Mahsulot nomi bilan qidirish'
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
                  decoration: const InputDecoration(labelText: 'Qolip code'),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _size,
                  decoration: const InputDecoration(labelText: 'Razmeri'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
              ] else ...[
                if (_product != null && _product!.hasQolipSpec) ...[
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Qolip'),
                    child: Text(
                      '${_product!.qolipCode} • ${_product!.qolipSize}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _quantity,
                  decoration: const InputDecoration(labelText: 'Qolip soni'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave && !_saving ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Saqlash'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
