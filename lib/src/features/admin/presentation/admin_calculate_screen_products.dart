part of 'admin_calculate_screen.dart';

class _ProductControllers {
  _ProductControllers({OrderProduct? value})
      : id = value?.id ??
            'p-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
        itemCode = value?.itemCode ?? '',
        product = TextEditingController(text: value?.product ?? ''),
        width = TextEditingController(
            text: value == null ? '' : _fmtInput(value.frameProductSizeMm)),
        count = TextEditingController(text: value?.frameCount.toString() ?? '');

  static int _sequence = 0;
  final String id;
  String itemCode;
  final TextEditingController product;
  final TextEditingController width;
  final TextEditingController count;
  Iterable<TextEditingController> get controllers => [product, width, count];
  double get _widthValue {
    final parsed = double.tryParse(width.text.trim().replaceAll(',', '.'));
    return parsed != null && parsed.isFinite ? parsed : 0;
  }

  OrderProduct get value => OrderProduct(
        id: id,
        itemCode: itemCode,
        product: product.text.trim(),
        frameProductSizeMm: _widthValue,
        frameCount: int.tryParse(count.text.trim()) ?? 0,
      );
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}

extension _CalculateProducts on _AdminCalculateScreenState {
  List<OrderProduct> get _activeProducts => _multipleProducts
      ? _products.map((row) => row.value).toList(growable: false)
      : const [];
  String get _activeItemCode =>
      _multipleProducts ? (_products.firstOrNull?.itemCode ?? '') : _itemCode;
  double get _activeFrameSize =>
      _multipleProducts ? 0 : _parseRequiredDouble(_frameProductSizeMm.text);
  double get _activeFrameCount => _multipleProducts
      ? _activeProducts
          .fold<int>(0, (sum, row) => sum + row.frameCount)
          .toDouble()
      : _parseRequiredDouble(_frameCount.text);
  double get _usefulWidth => _multipleProducts
      ? _activeProducts.fold<double>(0, (sum, row) => sum + row.widthMm)
      : _activeFrameSize * _activeFrameCount;

  void _replaceProducts(List<OrderProduct> values) {
    for (final row in _products) {
      row.dispose();
    }
    _products.clear();
    for (final value in values) {
      final row = _ProductControllers(value: value);
      for (final controller in row.controllers) {
        controller.addListener(_productInputChanged);
      }
      _products.add(row);
    }
    _multipleProducts = values.isNotEmpty;
  }

  void _productInputChanged() {
    if (!_applyingTemplate && mounted) setState(() {});
  }

  void _forkLayoutTemplate() {
    if (widget.openedOrder != null || _templateId.isEmpty) return;
    _templateId = 'quick-${DateTime.now().microsecondsSinceEpoch}';
    _orderCode = 'Z-$_templateId';
    _templateVariantId = _templateId;
    _templateIsFork = _sourceMapId.isNotEmpty;
    _savedOrderRequestId = '';
    _savedOrderRequestSignature = '';
  }

  void _setMultipleProducts(bool enabled) {
    if (_orderEditDimensionsLocked) return;
    setState(() {
      _forkLayoutTemplate();
      if (enabled && _products.isEmpty) {
        final row = _ProductControllers();
        row.itemCode = _itemCode;
        row.product.text = _product.text;
        row.width.text = _frameProductSizeMm.text;
        row.count.text = _frameCount.text;
        for (final controller in row.controllers) {
          controller.addListener(_productInputChanged);
        }
        _products.add(row);
      } else if (enabled && _products.isNotEmpty) {
        final row = _products.first;
        row.itemCode = _itemCode;
        row.product.text = _product.text;
        row.width.text = _frameProductSizeMm.text;
        row.count.text = _frameCount.text;
      } else if (!enabled && _products.isNotEmpty) {
        final row = _products.first;
        _itemCode = row.itemCode;
        _product.text = row.product.text;
        _frameProductSizeMm.text = row.width.text;
        _frameCount.text = row.count.text;
      }
      _multipleProducts = enabled;
      _result = null;
      _lastCalculatedSignature = '';
    });
  }

  void _addProduct() {
    if (_orderEditDimensionsLocked) return;
    if (_products.length >= 64) return;
    final row = _ProductControllers();
    for (final controller in row.controllers) {
      controller.addListener(_productInputChanged);
    }
    setState(() {
      _forkLayoutTemplate();
      _products.add(row);
    });
  }

  void _removeProduct(_ProductControllers row) {
    if (_orderEditDimensionsLocked) return;
    if (_products.length <= 1) return;
    setState(() {
      _forkLayoutTemplate();
      _products.remove(row);
    });
    row.dispose();
  }

  void _moveProduct(int index, int delta) {
    if (_orderEditDimensionsLocked) return;
    final next = index + delta;
    if (next < 0 || next >= _products.length) return;
    setState(() {
      _forkLayoutTemplate();
      _products.insert(next, _products.removeAt(index));
    });
  }

  String? _productsValidationError() {
    if (!_multipleProducts) return null;
    final l10n = context.l10n;
    if (_customerRef.isEmpty)
      return l10n.adminText('calculate.products_customer');
    if (_products.isEmpty || _activeFrameCount > 1024 || !_usefulWidth.isFinite)
      return l10n.adminText('calculate.products_invalid');
    for (final row in _activeProducts) {
      if (row.itemCode.isEmpty ||
          row.product.isEmpty ||
          !row.frameProductSizeMm.isFinite ||
          row.frameProductSizeMm <= 0 ||
          row.frameCount < 1 ||
          row.frameCount > 1024) {
        return l10n.adminText('calculate.products_invalid');
      }
    }
    return null;
  }

  List<Widget> _productChildren(AppLocalizations l10n) => [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(l10n.adminText('calculate.products_order_hint'),
              style: Theme.of(context).textTheme.bodySmall),
        ),
        for (var index = 0; index < _products.length; index++)
          Padding(
            key: ValueKey('calculate-product-${_products[index].id}'),
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(
                            l10n.adminText('calculate.product_number',
                                values: {'number': index + 1}),
                            style: Theme.of(context).textTheme.titleSmall)),
                    if (_products.length > 1) ...[
                      IconButton(
                          onPressed:
                              !_orderEditDimensionsLocked && index > 0 ? () => _moveProduct(index, -1) : null,
                          tooltip: l10n.adminText('calculate.product_left'),
                          icon: const Icon(Icons.arrow_upward, size: 20)),
                      IconButton(
                          onPressed: !_orderEditDimensionsLocked && index < _products.length - 1
                              ? () => _moveProduct(index, 1)
                              : null,
                          tooltip: l10n.adminText('calculate.product_right'),
                          icon: const Icon(Icons.arrow_downward, size: 20)),
                      IconButton(
                          onPressed: _orderEditDimensionsLocked ? null : () => _removeProduct(_products[index]),
                          tooltip: l10n.adminText('calculate.remove_product'),
                          icon: const Icon(Icons.close, size: 20)),
                    ],
                  ]),
                  _PickerInput(
                      enabled: !_orderEditDimensionsLocked,
                      label: l10n.adminText('calculate.product_select'),
                      value: _products[index].product.text,
                      required: true,
                      dense: true,
                      height: _calculateFieldHeight,
                      onTap: () =>
                          _openProductPicker(target: _products[index])),
                  _NumberInput(
                      controller: _products[index].width,
                      enabled: !_orderEditDimensionsLocked,
                      label: l10n.adminText('calculate.product_width'),
                      suffixText: 'mm',
                      required: true),
                  _NumberInput(
                      controller: _products[index].count,
                      enabled: !_orderEditDimensionsLocked,
                      label: l10n.adminText('calculate.frame_count'),
                      suffixText: l10n.adminText('calculate.pieces_suffix'),
                      required: true,
                      validator: (value) {
                        final count = int.tryParse(value?.trim() ?? '');
                        return count == null || count < 1 || count > 1024
                            ? l10n.adminText('calculate.invalid')
                            : null;
                      }),
                ]),
          ),
        OutlinedButton.icon(
            onPressed: !_orderEditDimensionsLocked && _products.length < 64 ? _addProduct : null,
            icon: const Icon(Icons.add),
            label: Text(l10n.adminText('calculate.add_product'))),
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
                l10n.adminText('calculate.products_total', values: {
                  'count': _fmtInput(_activeFrameCount),
                  'width':
                      _usefulWidth.isFinite ? _fmtInput(_usefulWidth) : '—',
                }),
                style: Theme.of(context).textTheme.bodyMedium)),
      ];

  Widget _productResult(CalculateResponse response, AppLocalizations l10n) {
    final result = response.results.firstOrNull;
    if (result == null) return const SizedBox.shrink();
    final expectedMeters =
        result.roundedLength * (1 - response.wastePercent / 100);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.adminText('calculate.products_output'),
                style: Theme.of(context).textTheme.titleSmall),
            for (final product in _activeProducts)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${product.product}: ${_fmtInput(product.frameProductSizeMm)} mm × ${product.frameCount} · '
                    '≈ ${_fmtInput(expectedMeters * result.totalGsm * product.widthMm / 1000000)} kg',
                  )),
          ],
        ));
  }
}
