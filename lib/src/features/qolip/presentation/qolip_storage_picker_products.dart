part of 'qolip_storage_screen.dart';

String _productKey(String code) => code.trim().toLowerCase();
String _pickerMoldKey(QolipStorageMold mold) => mold.code.trim().toLowerCase();
bool _hasLinkedProduct(QolipStorageMold mold) => mold.products
    .any((product) => (product['code']?.toString() ?? '').trim().isNotEmpty);

class _PickerProduct {
  _PickerProduct({required this.code, required this.name});

  final String code;
  final String name;
  final List<QolipStorageMold> visibleMolds = [];

  bool get unlinked => code.isEmpty;
  String get key => unlinked ? 'unlinked' : 'product:${_productKey(code)}';

  bool contains(QolipStorageMold mold) => unlinked
      ? !_hasLinkedProduct(mold)
      : mold.products.any((product) =>
          _productKey(product['code']?.toString() ?? '') == _productKey(code));
}

extension _MoldPickerProducts on _MoldPickerState {
  List<_PickerProduct> _groupProducts() {
    final groups = <String, _PickerProduct>{};
    final query = _search.text.trim().toLowerCase();
    for (final mold in _molds) {
      final codeMatches = query.isEmpty ||
          mold.code.toLowerCase().contains(query) ||
          mold.setId.toLowerCase().contains(query);
      final products = !_hasLinkedProduct(mold)
          ? <Map<String, dynamic>>[{}]
          : mold.products.where((product) =>
              (product['code']?.toString() ?? '').trim().isNotEmpty);
      for (final item in products) {
        final code = (item['code']?.toString() ?? '').trim();
        final name = (item['name']?.toString() ?? '').trim();
        if (!codeMatches &&
            !code.toLowerCase().contains(query) &&
            !name.toLowerCase().contains(query) &&
            !(code.isEmpty && mold.name.toLowerCase().contains(query))) {
          continue;
        }
        final candidate = _PickerProduct(code: code, name: name);
        groups
            .putIfAbsent(candidate.key, () => candidate)
            .visibleMolds
            .add(mold);
      }
    }
    final sorted = groups.values.toList();
    sorted.sort((a, b) {
      if (a.unlinked != b.unlinked) return a.unlinked ? 1 : -1;
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.code.compareTo(b.code);
    });
    return sorted;
  }

  bool? _productSelection(_PickerProduct group) {
    final selected = _selected.values.where(group.contains).toList();
    if (selected.isEmpty) return false;
    final complete = _productMolds[group.key];
    if (complete == null) return null;
    final eligible = complete.where(_eligible).map(_pickerMoldKey).toSet();
    return eligible.isNotEmpty && eligible.every(_selected.containsKey)
        ? true
        : null;
  }

  Future<List<QolipStorageMold>?> _loadProduct(_PickerProduct group) async {
    if (!_current || _busy || _listPending) return null;
    final generation = _generation;
    setState(() {
      _loadingProductKey = group.key;
      _productErrors.remove(group.key);
    });
    try {
      final found = <String, QolipStorageMold>{};
      var offset = 0;
      while (true) {
        final page = await MobileApi.instance.qolipStorageMolds(
          query: group.code,
          offset: offset,
        );
        if (!await _continueAfterDiscard() ||
            !_current ||
            generation != _generation) return null;
        for (final mold in page.items.where(group.contains)) {
          found[_pickerMoldKey(mold)] = mold;
        }
        final next = page.nextOffset;
        if (next == null) break;
        if (next <= offset || next >= 10000) {
          throw const MobileApiException(
              code: 'qolip_product_load_limit', message: 'Incomplete product');
        }
        offset = next;
      }
      final molds = found.values.toList()
        ..sort((a, b) => _pickerMoldKey(a).compareTo(_pickerMoldKey(b)));
      var removedUnavailable = false;
      setState(() {
        _productMolds[group.key] = molds;
        for (final mold in molds) {
          final key = _pickerMoldKey(mold);
          if (_selected.containsKey(key)) {
            if (_eligible(mold)) {
              _selected[key] = mold;
            } else {
              _selected.remove(key);
              removedUnavailable = true;
            }
          }
        }
      });
      if (removedUnavailable) _message(context, _s(context, 'changed'));
      return molds;
    } catch (error) {
      if (await _continueAfterDiscard() &&
          _current &&
          generation == _generation) {
        setState(() => _productErrors[group.key] = error);
        if (!_expandedProducts.contains(group.key)) {
          _message(
              context,
              error is MobileApiException &&
                      error.code == 'qolip_product_load_limit'
                  ? _s(context, 'product_load_limit')
                  : _s(context, 'failed'));
        }
      }
      return null;
    } finally {
      if (mounted && _loadingProductKey == group.key) {
        setState(() => _loadingProductKey = null);
      }
    }
  }

  Future<void> _expandProduct(_PickerProduct group) async {
    if (!_current || _busy || _listPending) return;
    if (_expandedProducts.contains(group.key)) {
      setState(() => _expandedProducts.remove(group.key));
      return;
    }
    setState(() => _expandedProducts.add(group.key));
    if (!_productMolds.containsKey(group.key) ||
        _productErrors.containsKey(group.key)) {
      await _loadProduct(group);
    }
  }

  Future<void> _toggleProduct(_PickerProduct group) async {
    if (!_current || _busy || _listPending) return;
    final deselect = _productSelection(group) == true;
    final molds = _productErrors.containsKey(group.key)
        ? await _loadProduct(group)
        : _productMolds[group.key] ?? await _loadProduct(group);
    if (!await _continueAfterDiscard() || !_current || molds == null) return;
    final eligible = molds.where(_eligible).toList();
    final unavailable = molds.length - eligible.length;
    if (!deselect && unavailable > 0) {
      setState(() => _expandedProducts.add(group.key));
    }
    if (!deselect && eligible.isEmpty) {
      _message(context, _s(context, 'no_available_molds'));
      return;
    }
    if (!deselect &&
        {..._selected.keys, ...eligible.map(_pickerMoldKey)}.length > 1000) {
      _message(context, _s(context, 'capacity_error'));
      return;
    }
    setState(() {
      if (deselect) {
        _selected.removeWhere((_, mold) => group.contains(mold));
      } else {
        for (final mold in eligible) {
          _selected[_pickerMoldKey(mold)] = mold;
        }
      }
    });
    if (!deselect && unavailable > 0) {
      _message(context, '${_s(context, 'unavailable_molds')}: $unavailable');
    }
  }

  Widget _productGroupList(BuildContext context) {
    final groups = _groupProducts();
    if (groups.isEmpty) {
      return PaddonEmptyState(
          title: _s(context, 'empty'), icon: Icons.layers_outlined);
    }
    return M3SegmentSpacedColumn(
        key: const ValueKey('qolip-picker-products'),
        children: [
          for (var i = 0; i < groups.length; i++)
            _productGroupCard(context, groups[i], i, groups.length),
        ]);
  }

  Widget _productGroupCard(
      BuildContext context, _PickerProduct group, int index, int count) {
    final expanded = _expandedProducts.contains(group.key);
    final loading = _loadingProductKey == group.key;
    final molds = _productMolds[group.key];
    final error = _productErrors[group.key];
    final canToggle = !_busy && !_listPending;
    final canSelect = canToggle &&
        (molds == null ||
            molds.any(_eligible) ||
            _productSelection(group) != false);
    final displayMolds = molds ?? group.visibleMolds;
    final byCode = <String, QolipStorageMold>{
      for (final mold in displayMolds) _pickerMoldKey(mold): mold,
    };
    final products = [
      for (final mold in byCode.values)
        QolipProduct(
          code: group.code,
          name: group.name,
          itemGroup: '',
          qolipCode: mold.code,
          qolipSetId: mold.setId,
          warehouse: mold.warehouse,
          qolipSize: mold.size,
          qolipColor: mold.color,
          isInUse: mold.inUse,
          isInRework: mold.inRework,
        ),
    ];
    final slot =
        M3SegmentedListGeometry.standaloneListSlotForIndex(index, count);
    return QolipProductContainerCard(
      key: ValueKey('qolip-picker-product-${group.key}'),
      expandKey: ValueKey('qolip-picker-product-expand-${group.key}'),
      slot: slot,
      container: QolipProductContainer(
        code: group.code,
        name: group.unlinked ? _s(context, 'unlinked_molds') : group.name,
        itemGroup: '',
        children: products,
      ),
      imageUrl: '',
      expanded: expanded,
      loading: loading,
      errorMessage: error == null
          ? null
          : error is MobileApiException &&
                  error.code == 'qolip_product_load_limit'
              ? _s(context, 'product_load_limit')
              : _s(context, 'failed'),
      onRetry: () async {
        await _loadProduct(group);
      },
      containerSelectionMode: false,
      qolipSelectionMode: true,
      selectedContainer: _productSelection(group) == true,
      selectedQolipCodes: const {},
      reworkCodes: {
        for (final mold in displayMolds)
          if (mold.inRework) _pickerMoldKey(mold),
      },
      sharing: false,
      onShare: null,
      onToggle: canToggle ? () => _expandProduct(group) : null,
      onLongPress: null,
      onToggleQolip: (_) {},
      onPrintCodeQr: (_) {},
      onCopyCode: (_) {},
      onEditQolip: (_) {},
      onAdd: () {},
      showMoldCount: molds != null,
      emptyContent: Padding(
          padding: const EdgeInsets.all(16), child: Text(_s(context, 'empty'))),
      selectionControl: Checkbox(
        key: ValueKey('qolip-picker-product-select-${group.key}'),
        tristate: true,
        value: _productSelection(group),
        onChanged: canSelect ? (_) => _toggleProduct(group) : null,
      ),
      codeRowBuilder: (product) {
        final mold = byCode[product.qolipCode.trim().toLowerCase()]!;
        final selected = _selected.containsKey(_pickerMoldKey(mold));
        final selectable = canToggle && _eligible(mold);
        void toggle() => _toggle(mold, !selected);
        return QolipCodeRow(
          key: ValueKey('qolip-picker-mold-${mold.code}'),
          product: product,
          selectionMode: true,
          selected: selected,
          enabled: selectable,
          onTap: toggle,
          onCodeTap: toggle,
          onLongPress: null,
          onEdit: () {},
          isInRework: mold.inRework,
          codeTooltip: _s(context, 'select_molds'),
          subtitle: [
            if (group.unlinked && mold.name.isNotEmpty) mold.name,
            if (mold.size > 0) '${mold.size}',
            _moldStatus(context, mold, widget.warehouse),
          ].join(' • '),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: _s(context, 'mold_details'),
              icon: const Icon(Icons.info_outline),
              onPressed: canToggle ? () => _reviewMold(mold) : null,
            ),
            Checkbox(
              value: selected,
              onChanged:
                  selectable ? (value) => _toggle(mold, value == true) : null,
            ),
          ]),
        );
      },
    );
  }
}
