import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/native_bluetooth_printer.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_service.dart';
import '../../../core/print_transport.dart';
import '../../../core/widgets/feedback/app_dialog_action_row.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../admin/presentation/widgets/admin_catalog_search_field.dart';
import '../../gscale/gscale_mobile_app.dart'
    show DiscoveredServer, driverUrlForRs, showPrintDevicePicker;
import '../../shared/models/app_models.dart';
import '../../werka/presentation/widgets/m3_picker_sheet.dart';
import '../qolip_search_matcher.dart';
import '../state/qolip_data_revision.dart';
import 'qolip_cell_qr_scan_screen.dart';
import 'widgets/qolip_cell_picker_sheet.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

bool qolipMoveReachedTarget({
  required QolipLocationEntry moved,
  required QolipBlock targetBlock,
  required String qolipCode,
  required String rowLetter,
  required int columnNumber,
}) {
  return moved.block.trim().toLowerCase() ==
          targetBlock.name.trim().toLowerCase() &&
      moved.warehouse.trim().toLowerCase() ==
          targetBlock.warehouse.trim().toLowerCase() &&
      moved.qolipCode.trim().toLowerCase() == qolipCode.trim().toLowerCase() &&
      moved.rowLetter.trim().toUpperCase() == rowLetter.trim().toUpperCase() &&
      moved.columnNumber == columnNumber;
}

List<QolipBlock> qolipMoveTargetBlocks({
  required List<QolipBlock> blocks,
  required QolipLocationEntry source,
  required bool supportsCrossBlockMove,
}) {
  if (supportsCrossBlockMove && blocks.isNotEmpty) {
    return List<QolipBlock>.unmodifiable(blocks);
  }
  for (final block in blocks) {
    if (block.name.trim().toLowerCase() == source.block.trim().toLowerCase()) {
      return <QolipBlock>[block];
    }
  }
  return <QolipBlock>[
    QolipBlock(name: source.block, warehouse: source.warehouse),
  ];
}

class QolipHomeScreen extends StatefulWidget {
  const QolipHomeScreen({super.key});

  @override
  State<QolipHomeScreen> createState() => _QolipHomeScreenState();
}

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

  TabController _ensureBlockTabController(int length) {
    final existing = _blockTabController;
    if (existing != null && existing.length == length) {
      return existing;
    }
    final previousIndex = existing?.index ?? 0;
    final initialIndex = previousIndex < 0
        ? 0
        : previousIndex >= length
            ? length - 1
            : previousIndex;
    existing?.dispose();
    final controller = TabController(
      length: length,
      initialIndex: initialIndex,
      vsync: this,
      animationDuration: const Duration(milliseconds: 220),
    );
    _blockTabController = controller;
    return controller;
  }

  void _handleLocationsChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      for (final key in _locationGenerations.keys.toList(growable: false)) {
        _locationGenerations[key] = _locationGenerations[key]! + 1;
      }
      _locations.clear();
    });
    _refreshSearchMatches();
  }

  Future<QolipBlocksResult> _loadBlocks() async {
    final result = await MobileApi.instance.qolipBlocksData();
    final blocks = result.blocks
        .where((block) => block.name.trim().isNotEmpty)
        .toList(growable: false);
    final orderedBlocks = await _applySavedBlockOrder(blocks);
    _orderedBlocks = orderedBlocks;
    _supportsCrossBlockMove = result.supportsCrossBlockMove;
    if (_searchQuery.isNotEmpty) {
      _refreshSearchMatches();
    }
    return QolipBlocksResult(
      warehouses: result.warehouses
          .where((warehouse) => warehouse.trim().isNotEmpty)
          .toList(growable: false),
      blocks: orderedBlocks,
      supportsCrossBlockMove: result.supportsCrossBlockMove,
    );
  }

  Future<void> _reloadBlocks() async {
    setState(() {
      for (final key in _locationGenerations.keys.toList(growable: false)) {
        _locationGenerations[key] = _locationGenerations[key]! + 1;
      }
      _locations.clear();
      _resolvedLocations.clear();
      _blockSearchMatchCounts = const <String, int>{};
      _orderedBlocks = const <QolipBlock>[];
      _blocksFuture = _loadBlocks();
    });
    await _blocksFuture;
  }

  Future<List<QolipBlock>> _applySavedBlockOrder(
    List<QolipBlock> blocks,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final savedKeys =
        preferences.getStringList(_blockOrderPreferenceKey) ?? const <String>[];
    final byKey = <String, QolipBlock>{
      for (final block in blocks) _blockKey(block): block,
    };
    final ordered = <QolipBlock>[];
    for (final key in savedKeys) {
      final block = byKey.remove(key);
      if (block != null) {
        ordered.add(block);
      }
    }
    ordered.addAll(byKey.values);
    return ordered;
  }

  Future<void> _saveBlockOrder(List<QolipBlock> blocks) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _blockOrderPreferenceKey,
      blocks.map(_blockKey).toList(growable: false),
    );
  }

  String _blockKey(QolipBlock block) => block.name.trim().toLowerCase();

  void _reorderBlocks(
    TabController controller,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _orderedBlocks.length ||
        newIndex >= _orderedBlocks.length) {
      return;
    }
    final insertionIndex = newIndex;
    if (oldIndex == insertionIndex || insertionIndex < 0) {
      return;
    }
    final currentIndex = controller.index;
    final nextIndex = reorderedTabIndex(
      currentIndex,
      oldIndex: oldIndex,
      newIndex: insertionIndex,
    );
    final reordered = [..._orderedBlocks];
    final block = reordered.removeAt(oldIndex);
    reordered.insert(insertionIndex, block);
    setState(() => _orderedBlocks = reordered);
    unawaited(_saveBlockOrder(reordered));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.index != nextIndex) {
        controller.index = nextIndex;
      }
    });
  }

  Future<List<QolipLocationEntry>> _locationsFor(String block) {
    final key = block.trim().toLowerCase();
    return _locations.putIfAbsent(
      key,
      () => _startLocationLoad(block, key),
    );
  }

  Future<List<QolipLocationEntry>> _startLocationLoad(
    String block,
    String key,
  ) {
    final generation = (_locationGenerations[key] ?? 0) + 1;
    _locationGenerations[key] = generation;
    return _loadLocations(block, key, generation);
  }

  Future<List<QolipLocationEntry>> _loadLocations(
    String block,
    String key,
    int generation,
  ) async {
    final locations = List<QolipLocationEntry>.unmodifiable(
      await MobileApi.instance.qolipLocations(block),
    );
    if (_locationGenerations[key] == generation) {
      _resolvedLocations[key] = locations;
    }
    return locations;
  }

  Future<List<QolipLocationEntry>> _refreshBlockAndWait(String block) {
    final key = block.trim().toLowerCase();
    final next = _startLocationLoad(block, key);
    setState(() {
      _locations[key] = next;
    });
    unawaited(_refreshSearchAfter(next));
    return next;
  }

  void _refreshBlock(String block) {
    unawaited(_refreshBlockAndWait(block));
  }

  Future<Map<String, List<QolipLocationEntry>>> _refreshMovedBlocks(
    Iterable<String> blocks,
  ) async {
    final namesByKey = <String, String>{};
    for (final block in blocks) {
      final name = block.trim();
      if (name.isNotEmpty) {
        namesByKey.putIfAbsent(name.toLowerCase(), () => name);
      }
    }
    final entries = await Future.wait(
      namesByKey.entries.map((entry) async {
        return MapEntry(entry.key, await _refreshBlockAndWait(entry.value));
      }),
    );
    return Map<String, List<QolipLocationEntry>>.fromEntries(entries);
  }

  void _showBlockTab(QolipBlock block) {
    final index = _orderedBlocks.indexWhere(
      (item) =>
          item.name.trim().toLowerCase() == block.name.trim().toLowerCase(),
    );
    final controller = _blockTabController;
    if (controller != null && index >= 0 && index < controller.length) {
      controller.animateTo(index);
    }
  }

  Future<void> _refreshSearchAfter(
    Future<List<QolipLocationEntry>> future,
  ) async {
    try {
      await future;
    } catch (_) {
      return;
    }
    _refreshSearchMatches();
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == route) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    _searchDebounce?.cancel();
    _searchGeneration++;
    setState(() {
      _searchQuery = query;
      _blockSearchMatchCounts = query.isEmpty
          ? const <String, int>{}
          : qolipBlockSearchMatchCounts(_resolvedLocations, query);
    });
    if (query.isNotEmpty) {
      final generation = _searchGeneration;
      _searchDebounce = Timer(
        const Duration(milliseconds: 160),
        () => unawaited(_loadBlockSearchMatches(query, generation)),
      );
    }
  }

  void _refreshSearchMatches() {
    final query = _searchQuery;
    if (!mounted || query.isEmpty) {
      return;
    }
    final generation = ++_searchGeneration;
    unawaited(_loadBlockSearchMatches(query, generation));
  }

  Future<void> _loadBlockSearchMatches(
    String query,
    int generation,
  ) async {
    final blocks = List<QolipBlock>.of(_orderedBlocks);
    final entries = await Future.wait(
      blocks.map((block) async {
        final key = _blockKey(block);
        try {
          return MapEntry<String, List<QolipLocationEntry>?>(
            key,
            await _locationsFor(block.name),
          );
        } catch (_) {
          return MapEntry<String, List<QolipLocationEntry>?>(key, null);
        }
      }),
    );
    if (!mounted || generation != _searchGeneration || query != _searchQuery) {
      return;
    }
    final locationsByBlock = <String, List<QolipLocationEntry>>{
      for (final entry in entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    setState(() {
      _blockSearchMatchCounts = qolipBlockSearchMatchCounts(
        locationsByBlock,
        query,
      );
    });
  }

  Future<void> _printCellQr(
    QolipBlock block,
    String rowLetter,
    int columnNumber,
  ) async {
    final option = await showQolipPrinterPicker(context);
    if (!mounted || option == null) {
      return;
    }
    try {
      final printer = option.transport.isLocal
          ? option.transport.isBluetooth
              ? option.bluetoothPrinter!.printer
              : option.offlinePrinter!.printer
          : qolipPrinterChoiceForDriver(
              kind: option.printerKind,
              label: option.printerLabel,
            );
      final result = await MobileApi.instance.qolipPrintCellQr(
        block: block,
        rowLetter: rowLetter,
        columnNumber: columnNumber,
        driverUrl: option.driverUrl,
        printer: printer,
        printMode: option.transport.isLocal
            ? option.transport.isBluetooth
                ? option.bluetoothPrinter!.printMode
                : option.offlinePrinter!.printMode
            : printer == 'godex'
                ? 'label'
                : 'rfid',
        printTransport: option.transport,
      );
      if (option.transport.isLocal) {
        await PrintService.printRps(
          result.printJob,
          printerProfile: option.offlinePrinter,
          bluetoothPrinter: option.bluetoothPrinter,
          transport: option.transport,
        );
      }
      final cellQr = result.cellQr;
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

  Future<int?> _promptMoveQuantity(QolipLocationEntry item) async {
    if (item.quantity <= 1) {
      return 1;
    }
    final controller = TextEditingController(text: '${item.quantity}');
    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Qolip soni'),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  helperText: 'Eng ko‘pi ${item.quantity} ta',
                  errorText: errorText,
                ),
              ),
              actions: [
                AppDialogActionRow(
                  cancelLabel: 'Bekor',
                  confirmLabel: 'Davom',
                  gap: 8,
                  vertical: true,
                  onCancel: () => Navigator.of(context).pop(),
                  onConfirm: () {
                    final qty = int.tryParse(controller.text.trim()) ?? 0;
                    if (qty <= 0) {
                      setDialogState(() => errorText = 'Son noto‘g‘ri');
                      return;
                    }
                    if (qty > item.quantity) {
                      setDialogState(
                        () => errorText = 'Joyda faqat ${item.quantity} ta bor',
                      );
                      return;
                    }
                    Navigator.of(context).pop(qty);
                  },
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<bool> _moveQolipToCell(
    QolipLocationEntry item, {
    required QolipBlock targetBlock,
    required String rowLetter,
    required int columnNumber,
    required String cellLabel,
    int? quantity,
  }) async {
    final moveQty = quantity ?? await _promptMoveQuantity(item);
    if (moveQty == null) {
      return false;
    }
    try {
      final moved = await MobileApi.instance.qolipMoveLocation(
        locationId: item.id,
        targetBlock: targetBlock,
        quantity: moveQty,
        rowLetter: rowLetter,
        columnNumber: columnNumber,
      );
      if (!mounted) {
        return false;
      }
      final refreshed = await _refreshMovedBlocks([
        item.block,
        targetBlock.name,
        moved.block,
      ]);
      if (!mounted) {
        return false;
      }
      final reachedTarget = qolipMoveReachedTarget(
        moved: moved,
        targetBlock: targetBlock,
        qolipCode: item.qolipCode,
        rowLetter: rowLetter,
        columnNumber: columnNumber,
      );
      final targetLocations =
          refreshed[targetBlock.name.trim().toLowerCase()] ??
              const <QolipLocationEntry>[];
      final targetContainsMove = reachedTarget &&
          targetLocations.any(
            (location) =>
                location.id == moved.id &&
                location.qolipCode.trim().toLowerCase() ==
                    item.qolipCode.trim().toLowerCase(),
          );
      if (!targetContainsMove) {
        final actualLocation = moved.locationLabel.trim().isEmpty
            ? moved.block
            : '${moved.block} / ${moved.locationLabel}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Server target blokni tasdiqlamadi. Qolip hozir $actualLocation da.',
            ),
          ),
        );
        return false;
      }
      _showBlockTab(targetBlock);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${item.itemName} ${targetBlock.name} / $cellLabel ga ko‘chirildi',
          ),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            qolipErrorMessage(error, fallback: 'Ko‘chirish amalga oshmadi'),
          ),
        ),
      );
      return false;
    }
  }

  Future<void> _moveQolip(
    QolipLocationEntry item, {
    String? excludeCellLabel,
  }) async {
    final availableBlocks = qolipMoveTargetBlocks(
      blocks: _orderedBlocks,
      source: item,
      supportsCrossBlockMove: _supportsCrossBlockMove,
    );
    final targetBlock = await _pickQolipBlock(availableBlocks);
    if (targetBlock == null || !mounted) {
      return;
    }
    final movingInsideSourceBlock = targetBlock.name.trim().toLowerCase() ==
        item.block.trim().toLowerCase();
    final cellLabel = await showQolipCellPickerSheet(
      context,
      title: '${targetBlock.name}: yacheykani tanlang',
      excludeCellLabel: movingInsideSourceBlock ? excludeCellLabel : null,
    );
    if (cellLabel == null || !mounted) {
      return;
    }
    final normalizedCell = normalizeQolipCellLabel(cellLabel);
    final columnNumber = normalizedCell == null
        ? null
        : int.tryParse(normalizedCell.substring(1));
    if (normalizedCell == null || columnNumber == null) {
      return;
    }
    await _moveQolipToCell(
      item,
      targetBlock: targetBlock,
      rowLetter: normalizedCell.substring(0, 1),
      columnNumber: columnNumber,
      cellLabel: normalizedCell,
    );
  }

  Future<void> _takeQolip(QolipLocationEntry item) async {
    final taken = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => _QolipTakeSheet(item: item),
    );
    if (taken == true && mounted) {
      _refreshBlock(item.block);
    }
  }

  Future<void> _openIssueQolips(List<QolipBlock> blocks) async {
    if (blocks.isEmpty) {
      return;
    }
    List<QolipLocationEntry> locations;
    try {
      final locationsByBlock = await Future.wait(
        blocks.map((block) => _locationsFor(block.name)),
      );
      locations = locationsByBlock
          .expand((items) => items)
          .where((item) => item.quantity > 0)
          .toList(growable: false)
        ..sort((left, right) {
          final byName = left.itemName.toLowerCase().compareTo(
                right.itemName.toLowerCase(),
              );
          if (byName != 0) {
            return byName;
          }
          return left.qolipCode.toLowerCase().compareTo(
                right.qolipCode.toLowerCase(),
              );
        });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            qolipErrorMessage(error, fallback: 'Qoliplar yuklanmadi'),
          ),
        ),
      );
      return;
    }
    if (!mounted) {
      return;
    }
    if (locations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Berish uchun joylashtirilgan qolip yo‘q')),
      );
      return;
    }
    final selection = await showModalBottomSheet<_QolipLocationSelection>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (sheetContext) {
        return M3AsyncPickerSheet<QolipLocationEntry>(
          title: 'Beriladigan qolipni tanlang',
          hintText: 'Qolip code yoki mahsulot nomi',
          pageSize: 80,
          loadPage: (query, offset, limit) async {
            final filtered = locations.where((item) {
              return qolipLocationSearchMatches(query, item);
            }).toList(growable: false);
            return filtered.skip(offset).take(limit).toList(growable: false);
          },
          itemTitle: (item) =>
              item.itemName.trim().isEmpty ? item.qolipCode : item.itemName,
          itemSubtitle: (item) => [
            item.qolipCode,
            '${item.size}',
            item.block,
            item.locationLabel,
            '${item.quantity} ta',
          ].where((value) => value.trim().isNotEmpty).join(' • '),
          itemKey: (item) => item.id,
          onSelected: (item) => Navigator.of(sheetContext).pop(
            _QolipLocationSelection(
              locations: <QolipLocationEntry>[item],
              isMultiSelection: false,
            ),
          ),
          onMultiSelected: (items) => Navigator.of(sheetContext).pop(
            _QolipLocationSelection(
              locations: items,
              isMultiSelection: true,
            ),
          ),
          selectedCountLabel: (count) => '$count ta qolip tanlandi',
          confirmSelectionTooltip: 'Tanlangan qoliplarni tasdiqlash',
        );
      },
    );
    if (!mounted || selection == null || selection.locations.isEmpty) {
      return;
    }
    if (!selection.isMultiSelection) {
      await _takeQolip(selection.locations.single);
      return;
    }
    await _issueSelectedQolips(selection.locations);
  }

  Future<void> _issueSelectedQolips(
    List<QolipLocationEntry> locations,
  ) async {
    final worker = await _showQolipWorkerPicker(context);
    if (!mounted || worker == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Qoliplarni berasizmi?'),
        content: Text(
          '${locations.length} ta tanlangan qolipni ${worker.name}ga '
          'qarzga berasizmi? Har biridan 1 tadan beriladi.',
        ),
        actions: [
          AppDialogActionRow(
            cancelLabel: 'Bekor qilish',
            confirmLabel: 'Berish',
            gap: 8,
            vertical: true,
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    var issuedCount = 0;
    Object? firstError;
    for (final location in locations) {
      try {
        await MobileApi.instance.qolipIssueCheckout(
          locationId: location.id,
          quantity: 1,
          workerId: worker.id,
        );
        issuedCount++;
      } catch (error) {
        firstError ??= error;
      }
    }
    if (!mounted) {
      return;
    }
    for (final block in locations.map((item) => item.block).toSet()) {
      _refreshBlock(block);
    }
    final failedCount = locations.length - issuedCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failedCount == 0
              ? '$issuedCount ta qolip ${worker.name}ga berildi'
              : issuedCount == 0
                  ? qolipErrorMessage(
                      firstError ?? Exception('Qoliplar berilmadi'),
                      fallback: 'Qoliplar berilmadi',
                    )
                  : '$issuedCount ta qolip berildi, $failedCount tasi berilmadi',
        ),
      ),
    );
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

  Future<void> _scanQolipOrCell(List<QolipBlock> blocks) async {
    if (blocks.isEmpty) {
      return;
    }
    final qr = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const QolipUniversalQrScanScreen(),
      ),
    );
    if (qr == null || !mounted) {
      return;
    }
    try {
      final result = await MobileApi.instance.qolipScanQr(qr);
      if (!mounted) {
        return;
      }
      switch (result.kind) {
        case QolipScanKind.cell:
          final cell = result.cellQr;
          if (cell != null) {
            await _openScannedCellActions(blocks, cell);
          }
        case QolipScanKind.qolip:
          final product = result.product;
          if (product != null) {
            await _openScannedQolipActions(
              blocks,
              product,
              result.location,
            );
          }
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message =
          error is MobileApiException && error.code == 'qolip_code_not_found'
              ? 'QR bo‘yicha qolip yoki yachayka topilmadi'
              : qolipErrorMessage(
                  error,
                  fallback: 'QR tekshirish amalga oshmadi',
                );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  QolipBlock? _blockForCell(
    List<QolipBlock> blocks,
    QolipCellQr cell,
  ) {
    for (final block in blocks) {
      if (block.name.trim().toLowerCase() == cell.block.trim().toLowerCase() &&
          block.warehouse.trim().toLowerCase() ==
              cell.warehouse.trim().toLowerCase()) {
        return block;
      }
    }
    return null;
  }

  Future<void> _openScannedCellActions(
    List<QolipBlock> blocks,
    QolipCellQr cell,
  ) async {
    final block = _blockForCell(blocks, cell);
    if (block == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu yachayka sizga biriktirilmagan')),
      );
      return;
    }
    final locations = await MobileApi.instance.qolipLocations(block.name);
    if (!mounted) {
      return;
    }
    final blockKey = block.name.trim().toLowerCase();
    setState(() {
      _locationGenerations[blockKey] =
          (_locationGenerations[blockKey] ?? 0) + 1;
      _resolvedLocations[blockKey] = List<QolipLocationEntry>.unmodifiable(
        locations,
      );
      _locations[blockKey] = Future.value(_resolvedLocations[blockKey]!);
    });
    _refreshSearchMatches();
    final cellItems = locations.where((item) {
      return item.rowLetter.trim().toLowerCase() ==
              cell.rowLetter.trim().toLowerCase() &&
          item.columnNumber == cell.columnNumber;
    }).toList(growable: false);
    final action = await showModalBottomSheet<_ScannedCellAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Yachayka ${cell.locationLabel}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${block.name} • ${block.warehouse}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_ScannedCellAction.placeQolip),
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Qolip kiritish'),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: cellItems.isEmpty
                    ? null
                    : () =>
                        Navigator.of(context).pop(_ScannedCellAction.takeQolip),
                icon: const Icon(Icons.assignment_returned_rounded),
                label: Text(
                  cellItems.isEmpty
                      ? 'Qolip olish — yachayka bo‘sh'
                      : 'Qolip olish (${cellItems.length})',
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == _ScannedCellAction.placeQolip) {
      await _openAttachSheet(
        blocks,
        mode: _QolipAttachMode.cellPlacement,
        initialBlock: block,
        rowLetter: cell.rowLetter,
        columnNumber: cell.columnNumber,
      );
      return;
    }
    final selected = cellItems.length == 1
        ? cellItems.single
        : await _QolipBlockGrid._pickQolipLocation(
            context,
            title: '${cell.locationLabel} dan qolip tanlang',
            options: cellItems,
          );
    if (selected != null && mounted) {
      await _takeQolip(selected);
    }
  }

  Future<void> _openScannedQolipActions(
    List<QolipBlock> blocks,
    QolipProduct product,
    QolipLocationEntry? location,
  ) async {
    final action = await showModalBottomSheet<_ScannedQolipAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final title =
            product.name.trim().isEmpty ? product.qolipCode : product.name;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '${product.qolipCode} • ${product.qolipSize}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),
              Card.filled(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        location == null
                            ? Icons.location_off_rounded
                            : Icons.location_on_rounded,
                        color: location == null ? scheme.error : scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          location == null
                              ? 'Hozir yachaykaga joylashtirilmagan'
                              : '${location.block} • ${location.locationLabel} • ${location.quantity} ta',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_ScannedQolipAction.placeInCell),
                icon: const Icon(Icons.add_location_alt_rounded),
                label: Text(
                  location == null
                      ? 'Yachaykaga joylash'
                      : 'Boshqa yachaykaga joylash',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: location == null
                    ? null
                    : () => Navigator.of(context)
                        .pop(_ScannedQolipAction.issueToWorker),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Ishchiga berish'),
              ),
              if (location == null) ...[
                const SizedBox(height: 6),
                Text(
                  'Ishchiga berishdan oldin qolipni yachaykaga joylang.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _ScannedQolipAction.placeInCell:
        await _placeScannedQolip(blocks, product, location);
      case _ScannedQolipAction.issueToWorker:
        if (location != null) {
          await _takeQolip(location);
        }
    }
  }

  Future<void> _placeScannedQolip(
    List<QolipBlock> blocks,
    QolipProduct product,
    QolipLocationEntry? currentLocation,
  ) async {
    final method = await showModalBottomSheet<_QolipPlacementMethod>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Yachaykani qanday tanlaysiz?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_QolipPlacementMethod.scanCell),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Yachayka QR scan'),
              ),
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: () =>
                    Navigator.of(context).pop(_QolipPlacementMethod.selectCell),
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('Ro‘yxatdan tanlash'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || method == null) {
      return;
    }

    _QolipTargetCell? target;
    if (method == _QolipPlacementMethod.scanCell) {
      final cell = await Navigator.of(context).push<QolipCellQr>(
        MaterialPageRoute(
          builder: (context) => const QolipCellQrScanScreen(),
        ),
      );
      if (cell != null && mounted) {
        final block = _blockForCell(blocks, cell);
        if (block == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bu yachayka sizga biriktirilmagan'),
            ),
          );
          return;
        }
        target = _QolipTargetCell(
          block: block,
          rowLetter: cell.rowLetter,
          columnNumber: cell.columnNumber,
        );
      }
    } else {
      final block = await _pickQolipBlock(blocks);
      if (block != null && mounted) {
        final label = await showQolipCellPickerSheet(
          context,
          title: '${block.name}: yachaykani tanlang',
        );
        final normalized = normalizeQolipCellLabel(label ?? '');
        final columnNumber =
            normalized == null ? null : int.tryParse(normalized.substring(1));
        if (normalized != null && columnNumber != null) {
          target = _QolipTargetCell(
            block: block,
            rowLetter: normalized.substring(0, 1),
            columnNumber: columnNumber,
          );
        }
      }
    }
    if (target == null || !mounted) {
      return;
    }
    try {
      await MobileApi.instance.qolipSaveLocation(
        block: target.block,
        product: product,
        quantity: currentLocation?.quantity ?? 1,
        rowLetter: target.rowLetter,
        columnNumber: target.columnNumber,
      );
      if (!mounted) {
        return;
      }
      if (currentLocation != null) {
        _refreshBlock(currentLocation.block);
      }
      _refreshBlock(target.block.name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${product.qolipCode} ${target.block.name} • ${target.rowLetter}${target.columnNumber} ga joylandi',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            qolipErrorMessage(error, fallback: 'Qolip joylashtirilmadi'),
          ),
        ),
      );
    }
  }

  Future<QolipBlock?> _pickQolipBlock(List<QolipBlock> blocks) async {
    if (blocks.length == 1) {
      return blocks.single;
    }
    return showModalBottomSheet<QolipBlock>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text(
              'Blokni tanlang',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            for (final block in blocks)
              ListTile(
                leading: const Icon(Icons.view_module_rounded),
                title: Text(block.name),
                subtitle: Text(block.warehouse),
                onTap: () => Navigator.of(context).pop(block),
              ),
          ],
        );
      },
    );
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
      title: '',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: 'Mahsulot qidirish',
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
          final blocks = _orderedBlocks.isEmpty && data.blocks.isNotEmpty
              ? data.blocks
              : _orderedBlocks;
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
              Positioned(
                right: 16,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 112,
                child: FloatingActionButton.extended(
                  heroTag: 'qolip-attach-fab',
                  onPressed: () => _openFabAction(data),
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('Biriktirish'),
                ),
              ),
              if (data.blocks.isNotEmpty)
                Positioned(
                  right: 16,
                  bottom: MediaQuery.viewPaddingOf(context).bottom + 176,
                  child: FloatingActionButton.extended(
                    heroTag: 'qolip-scan-cell-fab',
                    onPressed: () => _scanQolipOrCell(data.blocks),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('QR Scan'),
                  ),
                ),
              if (data.blocks.isNotEmpty)
                Positioned(
                  right: 16,
                  bottom: MediaQuery.viewPaddingOf(context).bottom + 240,
                  child: FloatingActionButton.extended(
                    heroTag: 'qolip-issue-fab',
                    onPressed: () => _openIssueQolips(data.blocks),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Qolip berish'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

int reorderedTabIndex(
  int currentIndex, {
  required int oldIndex,
  required int newIndex,
}) {
  if (currentIndex == oldIndex) {
    return newIndex;
  }
  if (oldIndex < currentIndex && currentIndex <= newIndex) {
    return currentIndex - 1;
  }
  if (newIndex <= currentIndex && currentIndex < oldIndex) {
    return currentIndex + 1;
  }
  return currentIndex;
}

class _QolipBlockTabBar extends StatefulWidget {
  const _QolipBlockTabBar({
    required this.controller,
    required this.blocks,
    required this.searchMatchCounts,
    required this.onTap,
    required this.onReorder,
    required this.onAdd,
  });

  final TabController controller;
  final List<QolipBlock> blocks;
  final Map<String, int> searchMatchCounts;
  final ValueChanged<int> onTap;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onAdd;

  @override
  State<_QolipBlockTabBar> createState() => _QolipBlockTabBarState();
}

class _QolipBlockTabBarState extends State<_QolipBlockTabBar> {
  final Map<String, GlobalKey> _tabKeys = <String, GlobalKey>{};
  final Map<String, double> _dragTabCenters = <String, double>{};

  late int _selectedIndex;
  String? _draggingBlockKey;
  List<QolipBlock>? _dragOrder;
  int? _dragTargetIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.controller.index;
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _QolipBlockTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      _selectedIndex = widget.controller.index;
      widget.controller.addListener(_handleControllerChanged);
    }
    final activeKeys = widget.blocks.map(_blockKey).toSet();
    _tabKeys.removeWhere((key, _) => !activeKeys.contains(key));
    if (_draggingBlockKey != null && !activeKeys.contains(_draggingBlockKey)) {
      _resetDrag();
    }
  }

  void _handleControllerChanged() {
    final nextIndex = widget.controller.index;
    if (!mounted || nextIndex == _selectedIndex) {
      return;
    }
    setState(() => _selectedIndex = nextIndex);
  }

  String _blockKey(QolipBlock block) => block.name.trim().toLowerCase();

  GlobalKey _tabKeyFor(QolipBlock block) {
    final blockKey = _blockKey(block);
    return _tabKeys.putIfAbsent(blockKey, GlobalKey.new);
  }

  RenderBox? _renderBoxFor(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject;
    }
    return null;
  }

  void _startDrag(String blockKey, LongPressStartDetails _) {
    final centers = <String, double>{};
    for (final block in widget.blocks) {
      final key = _blockKey(block);
      final tabKey = _tabKeys[key];
      final box = tabKey == null ? null : _renderBoxFor(tabKey);
      if (box == null) {
        continue;
      }
      final origin = box.localToGlobal(Offset.zero);
      centers[key] = origin.dx + box.size.width / 2;
    }
    setState(() {
      _draggingBlockKey = blockKey;
      _dragOrder = List<QolipBlock>.of(widget.blocks);
      _dragTargetIndex = widget.blocks.indexWhere(
        (block) => _blockKey(block) == blockKey,
      );
      _dragTabCenters
        ..clear()
        ..addAll(centers);
    });
  }

  void _updateDrag(LongPressMoveUpdateDetails details) {
    final blockKey = _draggingBlockKey;
    if (blockKey == null) {
      return;
    }
    final targetIndex = _targetIndexFor(details.globalPosition.dx);
    if (targetIndex < 0 || targetIndex == _dragTargetIndex) {
      return;
    }
    final oldIndex = widget.blocks.indexWhere(
      (block) => _blockKey(block) == blockKey,
    );
    if (oldIndex < 0) {
      return;
    }
    final reordered = List<QolipBlock>.of(widget.blocks);
    final draggedBlock = reordered.removeAt(oldIndex);
    reordered.insert(targetIndex, draggedBlock);
    setState(() {
      _dragTargetIndex = targetIndex;
      _dragOrder = reordered;
    });
  }

  void _finishDrag(LongPressEndDetails details) {
    final blockKey = _draggingBlockKey;
    if (blockKey == null) {
      return;
    }
    final oldIndex = widget.blocks.indexWhere(
      (block) => _blockKey(block) == blockKey,
    );
    final newIndex = _targetIndexFor(details.globalPosition.dx);
    final targetIndex = newIndex < 0 ? _dragTargetIndex ?? -1 : newIndex;
    _resetDrag();
    if (oldIndex >= 0 && targetIndex >= 0 && oldIndex != targetIndex) {
      widget.onReorder(oldIndex, targetIndex);
    }
  }

  int _targetIndexFor(double globalX) {
    if (_dragTabCenters.isEmpty) {
      return -1;
    }
    var targetIndex = -1;
    for (var index = 0; index < widget.blocks.length; index++) {
      final center = _dragTabCenters[_blockKey(widget.blocks[index])];
      if (center != null && globalX >= center) {
        targetIndex = index;
      }
    }
    if (targetIndex < 0 && widget.blocks.isNotEmpty) {
      return 0;
    }
    return targetIndex;
  }

  void _resetDrag() {
    if (!mounted) {
      return;
    }
    setState(() {
      _draggingBlockKey = null;
      _dragOrder = null;
      _dragTargetIndex = null;
      _dragTabCenters.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayedBlocks = _dragOrder ?? widget.blocks;
    final tabWidths = <String, double>{
      for (final block in widget.blocks)
        _blockKey(block): _tabWidth(context, block),
    };
    var totalTabWidth = 0.0;
    final tabOffsets = <String, double>{};
    for (final block in displayedBlocks) {
      final key = _blockKey(block);
      tabOffsets[key] = totalTabWidth;
      totalTabWidth += tabWidths[key] ?? 72;
    }
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SizedBox(
        height: 38,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: _draggingBlockKey == null
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: totalTabWidth,
                    height: 38,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final block in displayedBlocks)
                          AnimatedPositioned(
                            key: ValueKey('qolip-tab-${_blockKey(block)}'),
                            left: tabOffsets[_blockKey(block)] ?? 0,
                            top: _draggingBlockKey == _blockKey(block) ? -1 : 0,
                            width: tabWidths[_blockKey(block)] ?? 72,
                            height: 38,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            child: _buildTab(context, block),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 42,
              child: Tooltip(
                message: 'Blok qo‘shish',
                child: InkWell(
                  onTap: widget.onAdd,
                  child: const Center(
                    child: Icon(Icons.add_rounded, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(BuildContext context, QolipBlock block) {
    final theme = Theme.of(context);
    final blockKey = _blockKey(block);
    final dragging = _draggingBlockKey == blockKey;
    final index = widget.blocks.indexWhere(
      (candidate) => _blockKey(candidate) == blockKey,
    );
    final selected = index >= 0 && _selectedIndex == index;
    final matchCount = widget.searchMatchCounts[blockKey] ?? 0;
    final hasMatch = matchCount > 0;
    final matchColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF81C784)
        : const Color(0xFF2E7D32);
    return GestureDetector(
      key: _tabKeyFor(block),
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) => _startDrag(blockKey, details),
      onLongPressMoveUpdate: _updateDrag,
      onLongPressEnd: _finishDrag,
      onLongPressCancel: _resetDrag,
      child: Semantics(
        button: true,
        selected: selected,
        label:
            hasMatch ? '${block.name}, $matchCount ta mos qolip' : block.name,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: dragging ? theme.colorScheme.surfaceContainerHigh : null,
            boxShadow: dragging
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
            border: Border(
              bottom: BorderSide(
                color: hasMatch
                    ? matchColor
                    : selected
                        ? theme.colorScheme.primary
                        : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: InkWell(
            onTap: () {
              if (index < 0) {
                return;
              }
              widget.controller.animateTo(index);
              widget.onTap(index);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    block.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasMatch
                          ? matchColor
                          : selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                      fontWeight: hasMatch ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                if (hasMatch) ...[
                  const SizedBox(width: 6),
                  _QolipSearchBadge(count: matchCount),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _tabWidth(BuildContext context, QolipBlock block) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
        );
    final textPainter = TextPainter(
      text: TextSpan(text: block.name, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final matchCount = widget.searchMatchCounts[_blockKey(block)] ?? 0;
    final matchWidth = matchCount > 0 ? 24.0 : 0.0;
    return (textPainter.width + 28 + matchWidth)
        .clamp(72.0, double.infinity)
        .toDouble();
  }
}

enum _QolipFabAction { createBlock, attachQolip }

enum _QolipAttachMode { productSpec, cellPlacement }

enum _ScannedCellAction { placeQolip, takeQolip }

enum _ScannedQolipAction { placeInCell, issueToWorker }

enum _QolipPlacementMethod { scanCell, selectCell }

class _QolipProductSelection {
  const _QolipProductSelection({
    required this.products,
    required this.isMultiSelection,
  });

  final List<QolipProduct> products;
  final bool isMultiSelection;
}

class _QolipLocationSelection {
  const _QolipLocationSelection({
    required this.locations,
    required this.isMultiSelection,
  });

  final List<QolipLocationEntry> locations;
  final bool isMultiSelection;
}

class _QolipTargetCell {
  const _QolipTargetCell({
    required this.block,
    required this.rowLetter,
    required this.columnNumber,
  });

  final QolipBlock block;
  final String rowLetter;
  final int columnNumber;
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
    List<QolipLocationEntry> blockLocations,
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
    final normalizedCell = cellLabel.trim().toUpperCase();
    final unplaced = blockLocations
        .where((item) => item.locationLabel.trim().isEmpty)
        .toList(growable: false);
    final movableIn = blockLocations.where((item) {
      final label = item.locationLabel.trim().toUpperCase();
      return label.isNotEmpty && label != normalizedCell;
    }).toList(growable: false);
    await _openCellDetail(
      context,
      cellLabel,
      items,
      unplaced: unplaced,
      movableIn: movableIn,
      onTake: onTake,
      onMoveOut: (item) => onMove(item, excludeCellLabel: cellLabel),
      onMoveToCell: (item) => onMoveToCell(
        item,
        rowLetter,
        columnNumber,
        normalizedCell,
      ),
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
    required List<QolipLocationEntry> unplaced,
    required List<QolipLocationEntry> movableIn,
    required Future<void> Function(QolipLocationEntry item) onTake,
    required Future<void> Function(QolipLocationEntry item) onMoveOut,
    required Future<bool> Function(QolipLocationEntry item) onMoveToCell,
    required Future<void> Function() onAdd,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: scheme.surface,
      builder: (context) {
        final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
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
                Flexible(
                  fit: FlexFit.loose,
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final item in items) ...[
                        _QolipCellActionTile(
                          item: item,
                          onTake: () => Navigator.of(context).pop(
                            _QolipCellItemSelection(
                              item: item,
                              action: _QolipCellItemAction.take,
                            ),
                          ),
                          onMove: () => Navigator.of(context).pop(
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
                      onPressed: () => Navigator.of(context)
                          .pop(_QolipCellSheetAction.placeUnplaced),
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: Text('Joylashmagan qolip (${unplaced.length})'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (movableIn.isNotEmpty) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context)
                          .pop(_QolipCellSheetAction.moveIn),
                      icon: const Icon(Icons.move_down_rounded),
                      label: Text(
                        'Boshqa joydan ko‘chirish (${movableIn.length})',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pop(_QolipCellSheetAction.add),
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
        title: 'Joylashmagan qolip tanlang',
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
        title: 'Ko‘chiriladigan qolip tanlang',
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
    }
  }

  static Future<QolipLocationEntry?> _pickQolipLocation(
    BuildContext context, {
    required String title,
    required List<QolipLocationEntry> options,
  }) {
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
                      '${item.quantity} ta',
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

enum _QolipCellSheetAction { add, placeUnplaced, moveIn }

enum _QolipCellItemAction { take, moveOut }

class _QolipCellItemSelection {
  const _QolipCellItemSelection({required this.item, required this.action});

  final QolipLocationEntry item;
  final _QolipCellItemAction action;
}

class _QolipGridTable extends StatelessWidget {
  const _QolipGridTable({
    required this.letters,
    required this.rowCount,
    required this.byCell,
    required this.searchQuery,
    required this.onCellTap,
    required this.onCellLongPress,
  });

  final List<String> letters;
  final int rowCount;
  final Map<String, List<QolipLocationEntry>> byCell;
  final String searchQuery;
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
                          searchQuery: searchQuery,
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
    required this.searchQuery,
    required this.onTap,
    required this.onLongPress,
  });

  final String cellLabel;
  final List<QolipLocationEntry> items;
  final String searchQuery;
  final void Function(String cellLabel, List<QolipLocationEntry> items) onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = items.isNotEmpty;
    final qty = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final title = filled ? items.first.itemName : '';
    final matchCount = qolipContainerSearchMatchCount(items, searchQuery);
    final highlighted = matchCount > 0;
    final green = const Color(0xFF2E7D32);
    final background = highlighted
        ? Color.alphaBlend(
            green.withValues(alpha: 0.22),
            scheme.secondaryContainer,
          )
        : filled
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest.withValues(alpha: 0.45);
    final foreground = highlighted ? green : scheme.onSecondaryContainer;

    return Material(
      color: background,
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
                          Icon(Icons.layers_rounded,
                              size: 14, color: foreground),
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
                                    color: foreground,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (highlighted) ...[
                            const SizedBox(width: 4),
                            _QolipSearchBadge(count: matchCount),
                          ],
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '$qty ta',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: foreground,
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

class _QolipSearchBadge extends StatelessWidget {
  const _QolipSearchBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF2E7D32),
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 18,
        child: Center(
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

class _QolipCellActionTile extends StatelessWidget {
  const _QolipCellActionTile({
    required this.item,
    required this.onTake,
    required this.onMove,
  });

  final QolipLocationEntry item;
  final VoidCallback onTake;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = item.itemName.trim().isEmpty ? item.qolipCode : item.itemName;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.64),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            Icon(Icons.layers_rounded, size: 20, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.qolipCode} • ${item.size} • ${item.quantity} ta',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FilledButton.tonal(
              onPressed: onMove,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 34),
              ),
              child: const Text('Ko‘chirish'),
            ),
            const SizedBox(width: 6),
            FilledButton.tonal(
              onPressed: onTake,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 34),
              ),
              child: const Text('Olish'),
            ),
          ],
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

Future<QolipWorkerOption?> _showQolipWorkerPicker(BuildContext context) {
  final workersFuture = MobileApi.instance.qolipWorkers();
  return showModalBottomSheet<QolipWorkerOption>(
    context: context,
    isDismissible: true,
    enableDrag: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    sheetAnimationStyle: kM3PickerSheetAnimation,
    builder: (sheetContext) {
      return M3AsyncPickerSheet<QolipWorkerOption>(
        title: 'Ishchini tanlang',
        hintText: 'Ishchi nomi bilan qidiring',
        pageSize: 80,
        loadPage: (query, offset, limit) async {
          final workers = await workersFuture;
          final filtered = workers
              .where((worker) => qolipWorkerSearchMatches(query, worker));
          return filtered.skip(offset).take(limit).toList(growable: false);
        },
        itemTitle: (worker) => worker.name,
        itemSubtitle: (worker) => worker.level,
        onSelected: (worker) => Navigator.of(sheetContext).pop(worker),
      );
    },
  );
}

class _QolipTakeSheet extends StatefulWidget {
  const _QolipTakeSheet({required this.item});

  final QolipLocationEntry item;

  @override
  State<_QolipTakeSheet> createState() => _QolipTakeSheetState();
}

class _QolipTakeSheetState extends State<_QolipTakeSheet> {
  late final TextEditingController _quantityController;
  QolipWorkerOption? _worker;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickWorker() async {
    if (_submitting) {
      return;
    }
    final picked = await _showQolipWorkerPicker(context);
    if (picked != null && mounted) {
      setState(() {
        _worker = picked;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (quantity <= 0) {
      setState(() => _error = 'Qolip soni noto‘g‘ri');
      return;
    }
    if (quantity > widget.item.quantity) {
      setState(() => _error = 'Joyda faqat ${widget.item.quantity} ta bor');
      return;
    }
    final worker = _worker;
    if (worker == null) {
      setState(() => _error = 'Ishchini tanlang');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await MobileApi.instance.qolipIssueCheckout(
        locationId: widget.item.id,
        quantity: quantity,
        workerId: worker.id,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = qolipErrorMessage(
            error,
            fallback: 'Qolip olish amalga oshmadi',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;
    final worker = _worker;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Qolip olish',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.itemName} • ${item.qolipCode} • ${item.quantity} ta',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _pickWorker,
                  icon: const Icon(Icons.person_search_rounded),
                  label: Text(
                    worker == null
                        ? 'Ishchini tanlang'
                        : worker.level.trim().isEmpty
                            ? worker.name
                            : '${worker.name} • ${worker.level}',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _quantityController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: 'Qolip soni',
                    helperText: 'Eng ko‘pi ${item.quantity} ta',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.assignment_returned_rounded),
                  label: const Text('Qarzga berish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QolipPrinterOption {
  const QolipPrinterOption({
    required this.server,
    required this.driverUrl,
    required this.printerKind,
    required this.printerLabel,
    this.transport = PrintTransport.wifi,
  })  : offlinePrinter = null,
        bluetoothPrinter = null;

  QolipPrinterOption.offline(UsbPrinterProfile profile)
      : server = null,
        driverUrl = offlineUsbDriverUrl,
        printerKind = profile.printer,
        printerLabel = profile.displayName,
        transport = PrintTransport.offline,
        offlinePrinter = profile,
        bluetoothPrinter = null;

  QolipPrinterOption.bluetooth(BluetoothPrinterProfile profile)
      : server = null,
        driverUrl = offlineUsbDriverUrl,
        printerKind = profile.printer,
        printerLabel = profile.displayName,
        transport = PrintTransport.bluetooth,
        offlinePrinter = null,
        bluetoothPrinter = profile;

  final DiscoveredServer? server;
  final String driverUrl;
  final String printerKind;
  final String printerLabel;
  final PrintTransport transport;
  final UsbPrinterProfile? offlinePrinter;
  final BluetoothPrinterProfile? bluetoothPrinter;
}

Future<QolipPrinterOption?> showQolipPrinterPicker(BuildContext context) async {
  final selection = await showPrintDevicePicker(context);
  if (selection == null) {
    return null;
  }
  if (selection.transport.isOffline) {
    final printer = selection.offlinePrinter;
    return printer == null ? null : QolipPrinterOption.offline(printer);
  }
  if (selection.transport.isBluetooth) {
    final printer = selection.bluetoothPrinter;
    return printer == null ? null : QolipPrinterOption.bluetooth(printer);
  }
  final server = selection.server;
  if (server == null) {
    return null;
  }
  final client = http.Client();
  try {
    return await _connectedQolipPrinter(client, server);
  } finally {
    client.close();
  }
}

Future<QolipPrinterOption?> _connectedQolipPrinter(
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
    return QolipPrinterOption(
      server: server,
      driverUrl: driverUrlForRs(server).replaceFirst(RegExp(r'/+$'), ''),
      printerKind: kind,
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

String qolipPrinterChoiceForDriver({
  required String kind,
  required String label,
}) {
  final normalizedKind = kind.trim().toLowerCase();
  if (normalizedKind == 'godex' ||
      normalizedKind == 'go-dex' ||
      normalizedKind == 'g500') {
    return 'godex';
  }
  if (normalizedKind == 'zebra' ||
      normalizedKind == 'zpl' ||
      normalizedKind == 'rfid') {
    return 'zebra';
  }
  final normalizedLabel = label.trim().toLowerCase();
  return normalizedLabel.contains('godex') ? 'godex' : 'zebra';
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

List<QolipProduct> qolipProductsAvailableForCellPlacement(
  List<QolipProduct> products,
  Set<String> placedQolipCodes,
) {
  final normalizedPlacedCodes = placedQolipCodes
      .map((code) => code.trim().toLowerCase())
      .where((code) => code.isNotEmpty)
      .toSet();
  return _qolipProductsWithSavedCodeOnly(products)
      .where(
        (product) =>
            !product.isInUse &&
            !normalizedPlacedCodes.contains(
              product.qolipCode.trim().toLowerCase(),
            ),
      )
      .toList(growable: false);
}

String qolipProductCustomerLabel(QolipProduct product) {
  final customers = product.customerNames
      .map((customer) => customer.trim())
      .where((customer) => customer.isNotEmpty)
      .join(', ');
  return customers.isEmpty ? 'Mijoz biriktirilmagan' : customers;
}

int qolipContainerSearchMatchCount(
  Iterable<QolipLocationEntry> items,
  String query,
) {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return 0;
  }
  var count = 0;
  for (final item in items) {
    if (qolipLocationSearchMatches(trimmedQuery, item)) {
      count += 1;
    }
  }
  return count;
}

Map<String, int> qolipBlockSearchMatchCounts(
  Map<String, List<QolipLocationEntry>> locationsByBlock,
  String query,
) {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) {
    return const <String, int>{};
  }
  return <String, int>{
    for (final entry in locationsByBlock.entries)
      entry.key.trim().toLowerCase():
          qolipContainerSearchMatchCount(entry.value, trimmedQuery),
  };
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
  late final Future<Set<String>> _placedQolipCodesFuture;
  Future<List<QolipProduct>>? _productsFuture;
  QolipBlock? _block;
  QolipProduct? _product;
  List<QolipProduct> _selectedProducts = const <QolipProduct>[];
  QolipProduct? _savedProductSpec;
  String? _rowLetter;
  int? _columnNumber;
  bool _saving = false;
  bool _printingQr = false;

  @override
  void initState() {
    super.initState();
    _block = _initialBlock();
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

  Future<Set<String>> _loadPlacedQolipCodes() async {
    final blockNames = widget.blocks
        .map((block) => block.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    final locationsByBlock = await Future.wait(
      blockNames.map(MobileApi.instance.qolipLocations),
    );
    return locationsByBlock
        .expand((locations) => locations)
        .where(
          (location) =>
              location.rowLetter.trim().isNotEmpty &&
              location.columnNumber != null,
        )
        .map((location) => location.qolipCode.trim().toLowerCase())
        .where((code) => code.isNotEmpty)
        .toSet();
  }

  Future<List<QolipProduct>> _loadProducts() {
    return _productsFuture ??= MobileApi.instance.qolipProducts(
      limit: 20000,
      withQolipOnly: widget.mode == _QolipAttachMode.cellPlacement,
    );
  }

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<_QolipProductSelection>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (sheetContext) {
        final isCellPlacement = widget.mode == _QolipAttachMode.cellPlacement;
        return M3AsyncPickerSheet<QolipProduct>(
          title: isCellPlacement ? 'Qolip tanlang' : 'Tayyor mahsulot tanlang',
          hintText: isCellPlacement
              ? 'Qolip code, mahsulot yoki customer nomi'
              : 'Mahsulot yoki customer nomi bilan qidiring',
          pageSize: 80,
          cacheKey: widget.mode == _QolipAttachMode.cellPlacement
              ? null
              : 'qolip:products',
          loadPage: (query, offset, limit) async {
            if (!isCellPlacement && query.trim().isEmpty) {
              if (offset > 0) {
                return const <QolipProduct>[];
              }
              return MobileApi.instance.qolipProducts(limit: limit);
            }
            final products = await _loadProducts();
            final available = isCellPlacement
                ? qolipProductsAvailableForCellPlacement(
                    products,
                    await _placedQolipCodesFuture,
                  )
                : products;
            final filtered = available.where(
              (product) => qolipProductSearchMatches(query, product),
            );
            return filtered.skip(offset).take(limit).toList(growable: false);
          },
          itemTitle: (item) {
            final name = item.name.trim();
            return name.isEmpty ? item.code : name;
          },
          itemSubtitle: (item) {
            final parts = isCellPlacement
                ? [
                    if (item.hasQolipSpec)
                      '${item.qolipCode.trim()} • ${item.qolipSize}',
                    item.code.trim(),
                  ]
                : [
                    qolipProductCustomerLabel(item),
                    item.itemGroup.trim(),
                    if (item.hasQolipSpec)
                      '${item.qolipCode.trim()} • ${item.qolipSize}',
                  ];
            final filtered = parts
                .where((value) => value.isNotEmpty)
                .toList(growable: false);
            return filtered.join(' • ');
          },
          onSelected: (item) => Navigator.of(sheetContext).pop(
            _QolipProductSelection(
              products: <QolipProduct>[item],
              isMultiSelection: false,
            ),
          ),
          onMultiSelected: isCellPlacement
              ? (items) => Navigator.of(sheetContext).pop(
                    _QolipProductSelection(
                      products: items,
                      isMultiSelection: true,
                    ),
                  )
              : null,
          itemKey: (item) => item.qolipCode.trim().toLowerCase(),
          selectedCountLabel: (count) => '$count ta qolip tanlandi',
          confirmSelectionTooltip: 'Tanlangan qoliplarni tasdiqlash',
        );
      },
    );
    if (picked != null && mounted) {
      if (picked.isMultiSelection) {
        await _confirmAndSaveSelectedProducts(picked.products);
        return;
      }
      setState(() {
        _product = picked.products.isEmpty ? null : picked.products.first;
        _selectedProducts = picked.products;
        if (widget.mode == _QolipAttachMode.productSpec &&
            _product?.hasQolipSpec == true) {
          _qolipCode.text = _product!.qolipCode;
          _size.text = _product!.qolipSize > 0 ? '${_product!.qolipSize}' : '';
        }
      });
    }
  }

  Future<void> _scanQolipQr() async {
    final qr = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const QolipRawQrScanScreen(),
      ),
    );
    if (qr == null || !mounted) {
      return;
    }
    try {
      final product = await MobileApi.instance.qolipProductByQr(qr);
      if (!mounted) {
        return;
      }
      setState(() {
        _product = product;
        _selectedProducts = <QolipProduct>[product];
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Qolip QR topilmadi')),
      );
    }
  }

  Future<void> _save() async {
    final product = _product;
    final size = int.tryParse(_size.text.trim());
    if (_saving || product == null) {
      return;
    }
    if (widget.mode == _QolipAttachMode.cellPlacement) {
      await _saveCellProducts(_selectedProducts);
      return;
    }
    setState(() => _saving = true);
    try {
      if (_qolipCode.text.trim().isEmpty || size == null || size <= 0) {
        return;
      }
      final saved = await MobileApi.instance.qolipSaveProductSpec(
        product: product,
        qolipCode: _qolipCode.text,
        size: size,
      );
      if (mounted) {
        setState(() {
          _product = saved;
          _selectedProducts = <QolipProduct>[saved];
          _savedProductSpec = saved;
          _qolipCode.text = saved.qolipCode;
          _size.text = saved.qolipSize > 0 ? '${saved.qolipSize}' : '';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmAndSaveSelectedProducts(
    List<QolipProduct> products,
  ) async {
    final block = _block;
    final rowLetter = _rowLetter;
    final columnNumber = _columnNumber;
    if (block == null || rowLetter == null || columnNumber == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Qoliplarni joylaysizmi?'),
        content: Text(
          '${products.length} ta tanlangan qolipni '
          '${block.name} • $rowLetter$columnNumber yachaykaga joylaysizmi?',
        ),
        actions: [
          AppDialogActionRow(
            cancelLabel: 'Bekor qilish',
            confirmLabel: 'Joylash',
            gap: 8,
            vertical: true,
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _saveCellProducts(products);
    }
  }

  Future<void> _saveCellProducts(List<QolipProduct> products) async {
    final block = _block;
    final rowLetter = _rowLetter;
    final columnNumber = _columnNumber;
    final validProducts = products
        .where((product) => product.hasQolipSpec)
        .toList(growable: false);
    if (_saving ||
        block == null ||
        rowLetter == null ||
        columnNumber == null ||
        validProducts.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    var savedCount = 0;
    Object? firstError;
    try {
      for (final product in validProducts) {
        try {
          await MobileApi.instance.qolipSaveLocation(
            block: block,
            product: product,
            quantity: 1,
            rowLetter: rowLetter,
            columnNumber: columnNumber,
          );
          savedCount++;
        } catch (error) {
          firstError ??= error;
        }
      }
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      if (savedCount == validProducts.length) {
        Navigator.of(context).pop(block);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              savedCount == 1
                  ? '${validProducts.single.qolipCode} $rowLetter$columnNumber ga joylandi'
                  : '$savedCount ta qolip $rowLetter$columnNumber ga joylandi',
            ),
          ),
        );
        return;
      }
      final failedCount = validProducts.length - savedCount;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            savedCount == 0
                ? qolipErrorMessage(
                    firstError ?? Exception('Qolip joylashtirilmadi'),
                    fallback: 'Qoliplar joylashtirilmadi',
                  )
                : '$savedCount ta qolip joylandi, $failedCount tasi joylanmadi',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _printSavedCodeQr() async {
    final saved = _savedProductSpec;
    if (_printingQr || saved == null) {
      return;
    }
    final option = await showQolipPrinterPicker(context);
    if (!mounted || option == null) {
      return;
    }
    setState(() => _printingQr = true);
    try {
      final printer = option.transport.isLocal
          ? option.transport.isBluetooth
              ? option.bluetoothPrinter!.printer
              : option.offlinePrinter!.printer
          : qolipPrinterChoiceForDriver(
              kind: option.printerKind,
              label: option.printerLabel,
            );
      final result = await MobileApi.instance.qolipPrintCodeQr(
        qolipCode: saved.qolipCode,
        driverUrl: option.driverUrl,
        printer: printer,
        printMode: option.transport.isLocal
            ? option.transport.isBluetooth
                ? option.bluetoothPrinter!.printMode
                : option.offlinePrinter!.printMode
            : printer == 'godex'
                ? 'label'
                : 'rfid',
        printTransport: option.transport,
      );
      if (option.transport.isLocal) {
        await PrintService.printRps(
          result.printJob,
          printerProfile: option.offlinePrinter,
          bluetoothPrinter: option.bluetoothPrinter,
          transport: option.transport,
        );
      }
      final qr = result.qolipQr;
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('${qr.qolipCode} QR chop etildi')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Qolip QR chop etilmadi')),
      );
    } finally {
      if (mounted) {
        setState(() => _printingQr = false);
      }
    }
  }

  bool get _canSave {
    final size = int.tryParse(_size.text.trim()) ?? 0;
    if (widget.mode == _QolipAttachMode.productSpec) {
      return _savedProductSpec == null &&
          _product != null &&
          _qolipCode.text.trim().isNotEmpty &&
          size > 0;
    }
    return _block != null &&
        _selectedProducts.isNotEmpty &&
        _selectedProducts.every((product) => product.hasQolipSpec) &&
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
    final productSpecSaved = _savedProductSpec != null;
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
                      _title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  if (widget.mode == _QolipAttachMode.cellPlacement)
                    IconButton.filledTonal(
                      onPressed: _scanQolipQr,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      tooltip: 'Qolip QR scan',
                    ),
                ],
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
                onTap: productSpecSaved ? null : _pickProduct,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: widget.mode == _QolipAttachMode.cellPlacement
                        ? 'Qolip code / mahsulot'
                        : 'Tayyor mahsulot',
                    suffixIcon: const Icon(Icons.search_rounded),
                  ),
                  child: Text(
                    _selectedProducts.length > 1
                        ? '${_selectedProducts.length} ta qolip tanlandi'
                        : _product == null
                            ? widget.mode == _QolipAttachMode.cellPlacement
                                ? 'Qolip code yoki mahsulot nomi'
                                : 'Mahsulot nomi bilan qidirish'
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
                  decoration: const InputDecoration(labelText: 'Qolip code'),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _size,
                  enabled: !productSpecSaved,
                  decoration: const InputDecoration(labelText: 'Razmeri'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                ),
              ] else ...[
                if (_selectedProducts.isNotEmpty &&
                    _selectedProducts.every(
                      (product) => product.hasQolipSpec,
                    )) ...[
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Qolip'),
                    child: Text(
                      _selectedProducts.length == 1
                          ? '${_selectedProducts.single.qolipCode} • ${_selectedProducts.single.qolipSize}'
                          : '${_selectedProducts.length} ta qolip tanlandi',
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
                        label: const Text('QR chiqarish'),
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
