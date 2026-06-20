import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/mobile_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/shell/app_loading_indicator.dart';
import '../../../core/widgets/shell/app_retry_state.dart';
import '../../../core/widgets/shell/app_shell.dart';
import '../../shared/models/app_models.dart';
import 'widgets/qolip_navigation_drawer.dart';

class QolipHomeScreen extends StatefulWidget {
  const QolipHomeScreen({super.key});

  @override
  State<QolipHomeScreen> createState() => _QolipHomeScreenState();
}

class _QolipHomeScreenState extends State<QolipHomeScreen> {
  late Future<List<QolipBlock>> _blocksFuture;
  final Map<String, Future<List<QolipLocationEntry>>> _locations = {};

  @override
  void initState() {
    super.initState();
    _blocksFuture = _loadBlocks();
  }

  Future<List<QolipBlock>> _loadBlocks() async {
    final blocks = await MobileApi.instance.qolipBlocks();
    return blocks
        .where((block) => block.name.trim().isNotEmpty)
        .toList(growable: false);
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

  Future<void> _openFabAction(List<QolipBlock> blocks) async {
    if (blocks.isEmpty) {
      return;
    }
    final openForm = await showModalBottomSheet<bool>(
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
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('Qolipni omborga biriktirish'),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (openForm != true || !mounted) {
      return;
    }
    final savedBlock = await showModalBottomSheet<QolipBlock>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => _QolipAttachSheet(blocks: blocks),
    );
    if (savedBlock != null && mounted) {
      _refreshBlock(savedBlock.name);
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
      contentPadding: EdgeInsets.zero,
      child: FutureBuilder<List<QolipBlock>>(
        future: _blocksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const Center(child: AppLoadingIndicator());
          }
          if (snapshot.hasError) {
            return AppRetryState(onRetry: _reloadBlocks);
          }
          final blocks = snapshot.data ?? const <QolipBlock>[];
          if (blocks.isEmpty) {
            return const Center(child: Text('Block biriktirilmagan'));
          }
          return Stack(
            children: [
              DefaultTabController(
                length: blocks.length,
                child: Column(
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surface,
                      child: TabBar(
                        isScrollable: true,
                        tabs: [
                          for (final block in blocks)
                            Tab(height: 42, text: block.name),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          for (final block in blocks)
                            _QolipBlockGrid(
                              block: block,
                              future: _locationsFor(block.name),
                              onRefresh: () async {
                                _refreshBlock(block.name);
                                await _locationsFor(block.name);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 18,
                bottom: MediaQuery.viewPaddingOf(context).bottom + 22,
                child: FloatingActionButton(
                  onPressed: () => _openFabAction(blocks),
                  child: const Icon(Icons.add_rounded),
                ),
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
    required this.onRefresh,
  });

  final QolipBlock block;
  final Future<List<QolipLocationEntry>> future;
  final Future<void> Function() onRefresh;

  static const List<String> _rows = [
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
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              padding: EdgeInsets.fromLTRB(8, 10, 8, bottomPadding),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                    block.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _QolipGridTable(rows: _rows, byCell: byCell),
                ),
                if (unplaced.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Joylashmagan',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in unplaced) _QolipUnplacedTile(item: item),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QolipGridTable extends StatelessWidget {
  const _QolipGridTable({required this.rows, required this.byCell});

  final List<String> rows;
  final Map<String, List<QolipLocationEntry>> byCell;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const _GridHeaderCell(label: ''),
              for (var col = 1; col <= 9; col++) _GridHeaderCell(label: '$col'),
            ],
          ),
          for (final row in rows)
            Row(
              children: [
                _GridHeaderCell(label: row),
                for (var col = 1; col <= 9; col++)
                  _GridDataCell(items: byCell['$row$col'] ?? const []),
              ],
            ),
        ],
      ),
    );
  }
}

class _GridHeaderCell extends StatelessWidget {
  const _GridHeaderCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 58,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(color: scheme.outlineVariant),
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _GridDataCell extends StatelessWidget {
  const _GridDataCell({required this.items});

  final List<QolipLocationEntry> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final qty = items.fold<int>(0, (sum, item) => sum + item.quantity);
    final title = items.isEmpty ? '' : items.first.itemName;
    return Container(
      width: 86,
      height: 58,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: items.isEmpty ? scheme.surface : scheme.secondaryContainer,
        border: Border(
          right: BorderSide(color: scheme.outlineVariant),
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: items.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const Spacer(),
                Text(
                  '$qty ta',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                ),
              ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ListTile(
          dense: true,
          title: Text(item.itemName),
          subtitle:
              Text('${item.qolipCode} • ${item.size} • ${item.quantity} ta'),
        ),
      ),
    );
  }
}

class _QolipAttachSheet extends StatefulWidget {
  const _QolipAttachSheet({required this.blocks});

  final List<QolipBlock> blocks;

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
    _block = widget.blocks.isEmpty ? null : widget.blocks.first;
  }

  @override
  void dispose() {
    _qolipCode.dispose();
    _size.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _pickProduct() async {
    final picked = await showModalBottomSheet<QolipProduct>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (context) => const _QolipProductPickerSheet(),
    );
    if (picked != null && mounted) {
      setState(() => _product = picked);
    }
  }

  Future<void> _save() async {
    final block = _block;
    final product = _product;
    final size = int.tryParse(_size.text.trim());
    final quantity = int.tryParse(_quantity.text.trim());
    final hasPartialLocation = (_rowLetter == null) != (_columnNumber == null);
    if (block == null ||
        product == null ||
        _qolipCode.text.trim().isEmpty ||
        size == null ||
        size <= 0 ||
        quantity == null ||
        quantity <= 0 ||
        hasPartialLocation ||
        _saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await MobileApi.instance.qolipSaveLocation(
        block: block,
        product: product,
        qolipCode: _qolipCode.text,
        size: size,
        quantity: quantity,
        rowLetter: _rowLetter ?? '',
        columnNumber: _columnNumber,
      );
      if (mounted) {
        Navigator.of(context).pop(block);
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
    return _block != null &&
        _product != null &&
        _qolipCode.text.trim().isNotEmpty &&
        size > 0 &&
        quantity > 0 &&
        ((_rowLetter == null && _columnNumber == null) ||
            (_rowLetter != null && _columnNumber != null));
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
                'Qolipni omborga biriktirish',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<QolipBlock>(
                initialValue: _block,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Blok'),
                items: [
                  for (final block in widget.blocks)
                    DropdownMenuItem(value: block, child: Text(block.name)),
                ],
                onChanged: (value) => setState(() => _block = value),
              ),
              const SizedBox(height: 12),
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
                        ? 'Mahsulot qidirish'
                        : '${_product!.name} • ${_product!.code}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _quantity,
                decoration: const InputDecoration(labelText: 'Qolip soni'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _rowLetter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Harf'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('-')),
                        for (final row in _QolipBlockGrid._rows)
                          DropdownMenuItem(value: row, child: Text(row)),
                      ],
                      onChanged: (value) => setState(() {
                        _rowLetter = value;
                        if (value == null) {
                          _columnNumber = null;
                        }
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _columnNumber,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Son'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('-')),
                        for (var number = 1; number <= 9; number++)
                          DropdownMenuItem(
                            value: number,
                            child: Text('$number'),
                          ),
                      ],
                      onChanged: _rowLetter == null
                          ? null
                          : (value) => setState(() => _columnNumber = value),
                    ),
                  ),
                ],
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

class _QolipProductPickerSheet extends StatefulWidget {
  const _QolipProductPickerSheet();

  @override
  State<_QolipProductPickerSheet> createState() =>
      _QolipProductPickerSheetState();
}

class _QolipProductPickerSheetState extends State<_QolipProductPickerSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  late Future<List<QolipProduct>> _future;

  @override
  void initState() {
    super.initState();
    _future = MobileApi.instance.qolipProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _future = MobileApi.instance.qolipProducts(query: value);
      });
    });
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Tayyor mahsulot qidirish',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: _searchChanged,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.5,
                child: FutureBuilder<List<QolipProduct>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done &&
                        !snapshot.hasData) {
                      return const Center(child: AppLoadingIndicator());
                    }
                    if (snapshot.hasError) {
                      return AppRetryState(
                        onRetry: () async {
                          setState(() {
                            _future = MobileApi.instance.qolipProducts(
                              query: _search.text,
                            );
                          });
                          await _future;
                        },
                      );
                    }
                    final items = snapshot.data ?? const <QolipProduct>[];
                    if (items.isEmpty) {
                      return const Center(child: Text('Mahsulot topilmadi'));
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(item.code),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
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
