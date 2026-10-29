part of 'qolip_storage_screen.dart';

class _ArchiveMoldList extends StatefulWidget {
  const _ArchiveMoldList(
      {required this.entries, required this.onEntry, this.showStatus = true});

  final List<QolipArchiveEntry> entries;
  final ValueChanged<QolipArchiveEntry> onEntry;
  final bool showStatus;

  @override
  State<_ArchiveMoldList> createState() => _ArchiveMoldListState();
}

class _ArchiveMoldListState extends State<_ArchiveMoldList> {
  final _scope = currentSessionReadScope();
  final _expanded = <String, ValueNotifier<bool>>{};
  _StorageProductImages? _imageResolver;

  bool get _current => mounted && _scope == currentSessionReadScope();

  Map<QolipStorageMold, QolipArchiveEntry> _molds() {
    final result = Map<QolipStorageMold, QolipArchiveEntry>.identity();
    for (final entry in widget.entries) {
      final savedMold = entry.snapshot['mold'];
      final snapshot = savedMold is Map
          ? Map<String, dynamic>.from(savedMold)
          : Map<String, dynamic>.from(entry.snapshot);
      if ((snapshot['qolip_code'] as String?)?.trim().isNotEmpty != true) {
        snapshot['qolip_code'] = entry.code;
      }
      snapshot['warehouse'] ??= entry.warehouse;
      result[QolipStorageMold.fromJson(snapshot)] = entry;
    }
    return result;
  }

  _StorageProductImages get _images => _imageResolver ??= _StorageProductImages(
        isCurrent: () => _current,
        groups: () => _groupStorageProducts(_molds().keys),
      );

  @override
  void initState() {
    super.initState();
    _images.request();
  }

  @override
  void didUpdateWidget(covariant _ArchiveMoldList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries != widget.entries) _images.request();
  }

  @override
  void dispose() {
    _imageResolver?.dispose();
    for (final notifier in _expanded.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entriesByMold = _molds();
    final groups = _groupStorageProducts(entriesByMold.keys);
    return M3SegmentSpacedColumn(children: [
      for (var i = 0; i < groups.length; i++)
        _card(context, groups[i], entriesByMold, i, groups.length),
    ]);
  }

  Widget _card(
      BuildContext context,
      _StorageProductGroup group,
      Map<QolipStorageMold, QolipArchiveEntry> entriesByMold,
      int index,
      int count) {
    final expanded =
        _expanded.putIfAbsent(group.key, () => ValueNotifier(false));
    final entriesByProduct = Map<QolipProduct, QolipArchiveEntry>.identity();
    final moldsByProduct = Map<QolipProduct, QolipStorageMold>.identity();
    final products = <QolipProduct>[];
    for (final mold in group.visibleMolds) {
      final product = _storageProductRows(group, [mold]).single;
      products.add(product);
      entriesByProduct[product] = entriesByMold[mold]!;
      moldsByProduct[product] = mold;
    }
    return ListenableBuilder(
      key: ValueKey('qolip-archive-product-listener-${group.key}'),
      listenable: Listenable.merge([expanded, _images.changes(group.key)]),
      builder: (context, _) => QolipProductContainerCard(
        key: ValueKey('qolip-archive-product-${group.key}'),
        expandKey: ValueKey('qolip-archive-product-expand-${group.key}'),
        slot: M3SegmentedListGeometry.standaloneListSlotForIndex(index, count),
        container: QolipProductContainer(
          code: group.code,
          name: group.unlinked ? _s(context, 'unlinked_molds') : group.name,
          itemGroup: '',
          children: products,
        ),
        imageUrl: _images.imageUrl(group.key),
        imageProviderCache: _images.providers,
        loading: false,
        errorMessage: null,
        onRetry: () async {},
        expanded: expanded.value,
        containerSelectionMode: false,
        qolipSelectionMode: true,
        selectedContainer: false,
        selectedQolipCodes: const {},
        reworkCodes: const {},
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
          final entry = entriesByProduct[product]!;
          final mold = moldsByProduct[product]!;
          void showDetails() {
            if (_current) widget.onEntry(entry);
          }

          return QolipCodeRow(
            key: ValueKey('qolip-archive-mold-${entry.id}-${mold.code}'),
            product: product,
            selectionMode: false,
            selected: false,
            onTap: showDetails,
            onCodeTap: showDetails,
            onLongPress: null,
            onEdit: () {},
            codeTooltip: _s(context, 'mold_details'),
            subtitle: [
              if (group.unlinked && mold.name.isNotEmpty) mold.name,
              if (mold.size > 0) '${mold.size}',
              if (mold.color.isNotEmpty) mold.color,
              if (widget.showStatus)
                _s(context, entry.isOpen ? 'archived' : 'returned'),
              if (widget.showStatus && entry.parentPaddonCode.isNotEmpty)
                entry.parentPaddonCode,
            ].join(' • '),
            trailing: const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
