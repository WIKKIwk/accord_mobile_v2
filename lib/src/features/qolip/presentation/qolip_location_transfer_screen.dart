import 'package:flutter/material.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/qolip_cell_picker_sheet.dart';
import 'widgets/qolip_dock.dart';
import 'widgets/qolip_navigation_drawer.dart';

class QolipLocationTransferScreen extends StatefulWidget {
  const QolipLocationTransferScreen({super.key});

  @override
  State<QolipLocationTransferScreen> createState() =>
      _QolipLocationTransferScreenState();
}

class _QolipLocationTransferScreenState
    extends State<QolipLocationTransferScreen> {
  late Future<QolipBlocksResult> _blocksFuture;
  Future<List<QolipLocationEntry>>? _locationsFuture;
  final TextEditingController _quantityController = TextEditingController();
  String? _sourceBlockName;
  String? _targetBlockName;
  QolipLocationEntry? _selectedSource;
  String? _targetCell;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _blocksFuture = _loadBlocks();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<QolipBlocksResult> _loadBlocks() async {
    final data = await MobileApi.instance.qolipBlocksData();
    if (!mounted) {
      return data;
    }
    if (data.blocks.isEmpty) {
      setState(() {
        _sourceBlockName = null;
        _targetBlockName = null;
        _locationsFuture = null;
        _selectedSource = null;
        _targetCell = null;
      });
      return data;
    }

    final sourceStillExists = _sourceBlockName != null &&
        data.blocks.any((block) => _sameName(block.name, _sourceBlockName!));
    if (!sourceStillExists) {
      final first = data.blocks.first;
      setState(() {
        _sourceBlockName = first.name;
        _targetBlockName = first.name;
        _locationsFuture = _loadLocations(first.name);
        _selectedSource = null;
        _targetCell = null;
      });
    }
    return data;
  }

  Future<List<QolipLocationEntry>> _loadLocations(String block) {
    return MobileApi.instance.qolipLocations(block);
  }

  bool _sameName(String left, String right) {
    return left.trim().toLowerCase() == right.trim().toLowerCase();
  }

  QolipBlock? _blockByName(List<QolipBlock> blocks, String? name) {
    if (name == null || name.trim().isEmpty) {
      return null;
    }
    for (final block in blocks) {
      if (_sameName(block.name, name)) {
        return block;
      }
    }
    return null;
  }

  List<QolipBlock> _targetBlocks(
    QolipBlocksResult data,
    QolipLocationEntry source,
  ) {
    if (data.supportsCrossBlockMove && data.blocks.isNotEmpty) {
      return data.blocks;
    }
    final sourceBlock = _blockByName(data.blocks, source.block);
    return [
      sourceBlock ??
          QolipBlock(name: source.block, warehouse: source.warehouse),
    ];
  }

  void _selectSourceBlock(String? name) {
    if (name == null || name.trim().isEmpty) {
      return;
    }
    setState(() {
      _sourceBlockName = name;
      _targetBlockName = name;
      _locationsFuture = _loadLocations(name);
      _selectedSource = null;
      _targetCell = null;
      _quantityController.clear();
    });
  }

  void _selectSource(QolipLocationEntry? source) {
    setState(() {
      _selectedSource = source;
      _targetBlockName = source?.block ?? _targetBlockName;
      _targetCell = null;
      _quantityController.text = source == null ? '' : '${source.quantity}';
    });
  }

  void _selectTargetBlock(String? name) {
    setState(() {
      _targetBlockName = name;
      _targetCell = null;
    });
  }

  Future<void> _reload() async {
    setState(() {
      _sourceBlockName = null;
      _targetBlockName = null;
      _locationsFuture = null;
      _selectedSource = null;
      _targetCell = null;
      _quantityController.clear();
      _blocksFuture = _loadBlocks();
    });
    await _blocksFuture;
  }

  Future<void> _reloadLocations() async {
    final block = _sourceBlockName;
    if (block == null) {
      return;
    }
    setState(() => _locationsFuture = _loadLocations(block));
    await _locationsFuture;
  }

  Future<void> _pickTargetCell(QolipBlocksResult data) async {
    final source = _selectedSource;
    final targetBlock = _blockByName(data.blocks, _targetBlockName);
    if (source == null || targetBlock == null) {
      return;
    }
    final cell = await showQolipCellPickerSheet(
      context,
      title: '${targetBlock.name}: yacheykani tanlang',
      excludeCellLabel: _sameName(source.block, targetBlock.name)
          ? source.locationLabel
          : null,
    );
    if (!mounted || cell == null) {
      return;
    }
    final normalized = normalizeQolipCellLabel(cell);
    if (normalized == null) {
      return;
    }
    setState(() => _targetCell = normalized);
  }

  Future<void> _transfer(QolipBlocksResult data) async {
    final source = _selectedSource;
    final targetBlock = _blockByName(data.blocks, _targetBlockName);
    final cell = _targetCell;
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    if (source == null || targetBlock == null) {
      _showMessage('Avval ko‘chiriladigan qolipni tanlang');
      return;
    }
    if (cell == null) {
      _showMessage('Avval boriladigan yacheykani tanlang');
      return;
    }
    if (quantity <= 0 || quantity > source.quantity) {
      _showMessage('Qolip soni 1 dan ${source.quantity} gacha bo‘lishi kerak');
      return;
    }

    final rowLetter = cell.substring(0, 1);
    final columnNumber = int.tryParse(cell.substring(1));
    if (columnNumber == null) {
      _showMessage('Yacheyka noto‘g‘ri tanlangan');
      return;
    }

    setState(() => _saving = true);
    try {
      final moved = await MobileApi.instance.qolipMoveLocation(
        locationId: source.id,
        targetBlock: targetBlock,
        quantity: quantity,
        rowLetter: rowLetter,
        columnNumber: columnNumber,
      );
      if (!mounted) {
        return;
      }
      final reachedTarget = _sameName(moved.block, targetBlock.name) &&
          _sameName(moved.warehouse, targetBlock.warehouse) &&
          _sameName(moved.qolipCode, source.qolipCode) &&
          moved.rowLetter.trim().toUpperCase() == rowLetter &&
          moved.columnNumber == columnNumber;
      if (!reachedTarget) {
        _showMessage(
          'Server targetni tasdiqlamadi: ${moved.block} / ${moved.locationLabel}',
        );
        return;
      }
      _showMessage(
        '${source.itemName} ${targetBlock.name} / $cell ga ko‘chirildi',
      );
      setState(() {
        _selectedSource = null;
        _targetCell = null;
        _quantityController.clear();
        _locationsFuture = _loadLocations(source.block);
      });
    } catch (error) {
      if (mounted) {
        _showMessage(
          qolipErrorMessage(error, fallback: 'Ko‘chirish amalga oshmadi'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _openDrawerRoute(String route) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current != route) {
      Navigator.of(context).pushReplacementNamed(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: 'Joylashuv transferi',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      drawer: QolipNavigationDrawer(
        selectedIndex: 4,
        onNavigate: _openDrawerRoute,
      ),
      bottom: const QolipDock(activeTab: null),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: FutureBuilder<QolipBlocksResult>(
        future: _blocksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError) {
            return AppRetryState(onRetry: _reload);
          }
          final data = snapshot.data ??
              const QolipBlocksResult(warehouses: [], blocks: []);
          if (data.blocks.isEmpty) {
            return const Center(child: Text('Blok mavjud emas'));
          }
          return _buildTransferForm(data);
        },
      ),
    );
  }

  Widget _buildTransferForm(QolipBlocksResult data) {
    final sourceBlock = _blockByName(data.blocks, _sourceBlockName);
    final targetBlock = _blockByName(data.blocks, _targetBlockName);
    final targetBlocks = _selectedSource == null
        ? const <QolipBlock>[]
        : _targetBlocks(data, _selectedSource!);
    final validTargetBlock = _blockByName(targetBlocks, targetBlock?.name);

    return ListView(
      children: [
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Qolipni boshqa joyga ko‘chirish',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Manba qolipni tanlang, keyin boriladigan blok va yacheykani belgilang.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'qolip-transfer-source-block-${sourceBlock?.name ?? ''}',
                  ),
                  initialValue: sourceBlock?.name,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Manba bloki',
                    prefixIcon: Icon(Icons.view_module_outlined),
                  ),
                  items: [
                    for (final block in data.blocks)
                      DropdownMenuItem(
                        value: block.name,
                        child: Text(block.name),
                      ),
                  ],
                  onChanged: _saving ? null : _selectSourceBlock,
                ),
                const SizedBox(height: 14),
                if (_locationsFuture != null)
                  FutureBuilder<List<QolipLocationEntry>>(
                    future: _locationsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done &&
                          !snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(child: AppLoadingIndicator()),
                        );
                      }
                      if (snapshot.hasError) {
                        return AppRetryState(onRetry: _reloadLocations);
                      }
                      final locations =
                          snapshot.data ?? const <QolipLocationEntry>[];
                      final selectedId = locations.any(
                        (item) => item.id == _selectedSource?.id,
                      )
                          ? _selectedSource?.id
                          : null;
                      return DropdownButtonFormField<String>(
                        key: ValueKey<String>(
                          'qolip-transfer-source-item-${_sourceBlockName ?? ''}',
                        ),
                        initialValue: selectedId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Ko‘chiriladigan qolip',
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                        ),
                        items: [
                          for (final item in locations.where(
                            (item) => item.quantity > 0,
                          ))
                            DropdownMenuItem(
                              value: item.id,
                              child: Text(
                                _locationTitle(item),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _saving
                            ? null
                            : (id) => _selectSource(
                                  id == null
                                      ? null
                                      : locations.firstWhere(
                                          (item) => item.id == id,
                                        ),
                                ),
                      );
                    },
                  ),
                if (_selectedSource != null) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'qolip-transfer-target-${_selectedSource?.id ?? ''}',
                    ),
                    initialValue: validTargetBlock?.name,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Boriladigan blok',
                      prefixIcon: Icon(Icons.drive_file_move_outlined),
                    ),
                    items: [
                      for (final block in targetBlocks)
                        DropdownMenuItem(
                          value: block.name,
                          child: Text(block.name),
                        ),
                    ],
                    onChanged: _saving ? null : _selectTargetBlock,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _saving || validTargetBlock == null
                        ? null
                        : () => _pickTargetCell(data),
                    icon: const Icon(Icons.grid_on_rounded),
                    label: Text(
                      _targetCell == null
                          ? 'Yacheyka tanlash'
                          : 'Yacheyka: $_targetCell',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _quantityController,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Miqdor',
                      helperText: 'Maksimal ${_selectedSource!.quantity} ta',
                      prefixIcon: const Icon(Icons.numbers_rounded),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _transfer(data),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.swap_horiz_rounded),
                    label: Text(
                      _saving ? 'Ko‘chirilmoqda...' : 'Joylashuvni ko‘chirish',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _locationTitle(QolipLocationEntry item) {
    final itemName =
        item.itemName.trim().isEmpty ? item.qolipCode : item.itemName.trim();
    final cell = item.locationLabel.trim().isEmpty
        ? 'Joylashmagan'
        : item.locationLabel.trim();
    return '$itemName • ${item.qolipCode} • $cell • ${item.quantity} ta';
  }
}
