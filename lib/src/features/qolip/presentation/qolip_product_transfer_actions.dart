part of 'qolip_product_transfer_screen.dart';

extension _QolipProductTransferActions on _QolipProductTransferScreenState {
  Future<void> _reload() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final molds = await MobileApi.instance
          .qolipProducts(limit: 20000, withQolipOnly: true);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _molds = molds;
        final available = _forProduct(_selectedProduct)
            .where((m) => !m.isInUse)
            .map((m) => m.qolipCode.trim().toLowerCase())
            .toSet();
        _selected.removeWhere((code) => !available.contains(code));
      });
    } catch (error) {
      if (mounted && generation == _loadGeneration)
        setState(() => _loadError = error);
    } finally {
      if (mounted && generation == _loadGeneration)
        setState(() => _loading = false);
    }
  }

  Future<void> _pickProduct(bool source) async {
    final pages = <String, List<QolipProduct>>{};
    final picked = await showModalBottomSheet<QolipProduct>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: kM3PickerSheetAnimation,
      builder: (sheetContext) => M3AsyncPickerSheet<QolipProduct>(
        title: _text(source ? 'source' : 'target'),
        hintText: context.l10n.qolipText('home.product_customer_search'),
        pageSize: 80,
        loadPage: (query, offset, limit) async {
          if (!pages.containsKey(query)) {
            final products = source && query.trim().isEmpty
                ? _molds
                : await MobileApi.instance.qolipProducts(
                    query: query,
                    limit: 20000,
                    withQolipOnly: source,
                  );
            final opposite = source ? _target : _source;
            final unique = <String, QolipProduct>{};
            for (final product in products) {
              final code = product.code.trim().toLowerCase();
              if (code.isNotEmpty &&
                  code != opposite?.code.trim().toLowerCase()) {
                unique.putIfAbsent(code, () => product);
              }
            }
            pages[query] = unique.values.toList();
          }
          return pages[query]!.skip(offset).take(limit).toList();
        },
        itemTitle: (product) => product.name,
        itemSubtitle: (product) => [
          product.code,
          ...product.customerNames,
          product.itemGroup
        ].where((s) => s.trim().isNotEmpty).join(' • '),
        itemKey: (product) => product.code.trim().toLowerCase(),
        onSelected: (product) => Navigator.of(sheetContext).pop(product),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (_selectedProduct?.code == (source ? _source?.code : _target?.code)) {
        _selected.clear();
        _selectedProduct = null;
      }
      if (source) {
        _source = picked;
      } else {
        _target = picked;
      }
    });
  }

  void _toggle(String code, QolipProduct product) {
    if (_selectedProduct?.code != product.code) {
      _selected.clear();
    }
    if (!_selected.contains(code) && _selected.length >= 100) {
      _message(_text('limit'));
      return;
    }
    setState(() {
      _selectedProduct = product;
      if (!_selected.add(code)) _selected.remove(code);
    });
  }

  Future<void> _scanSource() async {
    setState(() => _scanning = true);
    try {
      final code = await Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => const QolipRawQrScanScreen(),
      ));
      if (code == null || !mounted) return;
      final result = await MobileApi.instance.qolipScanQr(code);
      final product = result.product;
      if (product == null) throw StateError(_text('scan_failed'));
      await _reload();
      if (!mounted) return;
      final matches = _molds.where((m) =>
          m.qolipCode.trim().toLowerCase() ==
          product.qolipCode.trim().toLowerCase());
      if (matches.isEmpty) throw StateError(_text('scan_failed'));
      final mold = matches.first;
      setState(() {
        _source = mold;
        _selectedProduct = mold;
        if (_target?.code == mold.code) _target = null;
        _selected.clear();
        if (!mold.isInUse) _selected.add(mold.qolipCode.trim().toLowerCase());
      });
      if (mold.isInUse) _message(context.l10n.qolipErrorText('qolip_in_use'));
    } catch (error) {
      if (mounted) _showError(error, _text('scan_failed'));
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _move(List<String> codes,
      {required QolipProduct from, required QolipProduct to}) async {
    final source = from;
    final target = to;
    if (_saving || codes.isEmpty) return;
    final available = _forProduct(source)
        .where((m) => !m.isInUse)
        .map((m) => m.qolipCode.trim().toLowerCase())
        .toSet();
    if (codes.length > 100 || codes.any((code) => !available.contains(code)))
      return;
    setState(() {
      _saving = true;
      _dragging = null;
    });
    try {
      final confirmed = await showM3ConfirmDialog(
        context: context,
        title: _text('title'),
        message: _text('confirm', values: {
          'from': '${source.name} (${source.code})',
          'to': '${target.name} (${target.code})',
          'codes': codes
              .map((code) => _molds
                  .firstWhere((m) => m.qolipCode.trim().toLowerCase() == code)
                  .qolipCode)
              .join(', '),
          'count': codes.length,
        }),
        cancelLabel: context.l10n.qolipText('action.cancel'),
        confirmLabel: _text('confirm_action'),
        verticalActions: true,
      );
      if (confirmed != true || !mounted) return;
      final sorted = codes.toList()..sort();
      final signature = jsonEncode([source.code, target.code, sorted]);
      if (_requestSignature != signature) {
        _requestSignature = signature;
        final random = Random.secure();
        _requestId = List.generate(16,
                (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
            .join();
      }
      final saved = await MobileApi.instance.qolipTransferProducts(
        requestId: _requestId!,
        fromItemCode: source.code,
        toItemCode: target.code,
        qolipCodes: sorted,
      );
      if (!mounted) return;
      final movedCodes = sorted.toSet();
      setState(() {
        // Publish only the validated server result, in both panes at once.
        // Keep moved molds first so they are visible without another gesture.
        ++_loadGeneration;
        _molds = [
          ...saved,
          ..._molds.where((mold) =>
              !movedCodes.contains(mold.qolipCode.trim().toLowerCase())),
        ];
        _dragging = null;
        _requestSignature = null;
        _requestId = null;
        _selected.clear();
        _selectedProduct = null;
      });
      final destinationScroll =
          _source?.code.trim().toLowerCase() == target.code.trim().toLowerCase()
              ? _topScrollController
              : _bottomScrollController;
      if (destinationScroll.hasClients) destinationScroll.jumpTo(0);
      QolipDataRevision.notifyLocationsChanged();
      _message(_text('success', values: {'count': codes.length}));
    } catch (error) {
      if (mounted) _showError(error, _text('failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(Object error, String fallback) {
    if (error is MobileApiException) {
      if (error.code == 'qolip_product_transfer_conflict') {
        _message(_text('conflict'));
        return;
      }
      _message(context.l10n.qolipErrorText(error.code, fallback: fallback));
    } else {
      _message(fallback);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}
