part of 'qolip_storage_screen.dart';

extension _MoldPickerScanning on _MoldPickerState {
  bool _currentScan(int generation) =>
      _current &&
      _scanMode &&
      !_reviewOpen &&
      generation == _scanGeneration;

  void _invalidateScans() {
    _scanGeneration++;
    _scanQueue = Future<void>.value();
    _queuedCodes.clear();
    _pendingScans = 0;
    _feedbackTimer?.cancel();
    _scanStatus = '';
    _scanFeedback = null;
  }

  void _changeMode(bool scan) {
    if (!_current || _reviewOpen ||
        _loadingProductKey != null || scan == _scanMode) return;
    _updatePicker(() {
      // A lookup from an earlier camera session must not enter a later one.
      _invalidateScans();
      _scanMode = scan;
      _generation++;
      _loading = false;
      _searchPending = false;
      _debounce?.cancel();
    });
    if (!scan) unawaited(_load());
  }

  void _scanMessage(String message, ProductionQuickScanFeedback feedback) {
    _feedbackTimer?.cancel();
    _updatePicker(() {
      _scanStatus = message;
      _scanFeedback = feedback;
    });
    _feedbackTimer = Timer(const Duration(seconds: 2), () {
      if (_current) _updatePicker(() => _scanFeedback = null);
    });
  }

  Future<void> _stageScan(String raw) async {
    if (!_currentScan(_scanGeneration)) return;
    final String code;
    try {
      code = rawMaterialBarcodeFromQr(raw).trim();
    } on FormatException {
      _scanMessage(
          _s(context, 'not_found'), ProductionQuickScanFeedback.rejected);
      return;
    }
    final key = code.toLowerCase();
    if (code.isEmpty || _queuedCodes.contains(key)) return;
    if (qolipPaddonCodeFromQr(code) != null) {
      _scanMessage(
          _s(context, 'invalid_mold_qr'), ProductionQuickScanFeedback.rejected);
      return;
    }
    if (_selected.containsKey(key)) {
      _scanMessage('$code — ${_s(context, 'duplicate')}',
          ProductionQuickScanFeedback.none);
      return;
    }
    if (_selected.length + _pendingScans >= 1000) {
      _scanMessage(
          _s(context, 'capacity_error'), ProductionQuickScanFeedback.rejected);
      return;
    }
    final generation = _scanGeneration;
    _updatePicker(() {
      _queuedCodes.add(key);
      _pendingScans++;
    });
    // Reuse the production scanner's concurrent detection mode, but serialize
    // exact mold lookups so fast scans stay queued and can be reviewed together.
    final operation = _scanQueue.then((_) async {
      try {
        if (!mounted || !await _continueAfterDiscard() ||
            !_currentScan(generation)) return;
        final page = await MobileApi.instance.qolipStorageMolds(code: code);
        if (!mounted || !await _continueAfterDiscard() ||
            !_currentScan(generation)) return;
        final mold = page.items.singleOrNull;
        if (mold == null ||
            _pickerMoldKey(mold) != key ||
            page.nextOffset != null) {
          _scanMessage('$code — ${_s(context, 'not_found')}',
              ProductionQuickScanFeedback.rejected);
          return;
        }
        if (!_eligible(mold)) {
          _scanMessage(
              '${mold.code} — ${_moldStatus(context, mold, widget.warehouse)}',
              ProductionQuickScanFeedback.rejected);
          return;
        }
        if (_selected.containsKey(_pickerMoldKey(mold))) {
          _scanMessage('${mold.code} — ${_s(context, 'duplicate')}',
              ProductionQuickScanFeedback.none);
          return;
        }
        _updatePicker(() => _selected[_pickerMoldKey(mold)] = mold);
        _scanMessage('${mold.code} — ${_s(context, 'scan_accepted')}',
            ProductionQuickScanFeedback.accepted);
      } catch (error) {
        if (await _continueAfterDiscard() && mounted && _currentScan(generation)) {
          _scanMessage(_storageErrorMessage(context, error),
              ProductionQuickScanFeedback.rejected);
        }
      } finally {
        if (mounted && generation == _scanGeneration) {
          _updatePicker(() {
            _queuedCodes.remove(key);
            _pendingScans--;
          });
        }
      }
    });
    _scanQueue = operation;
    await operation;
  }

  List<Widget> _scannerWidgets(BuildContext context) {
    final selected = _selected.values.toList(growable: false);
    return [
      if (!_reviewOpen)
        ProductionQuickScannerPanel(
          key: const ValueKey('qolip-inline-qr-scanner'),
          statusText:
              _scanStatus.isEmpty ? _s(context, 'scan_ready') : _scanStatus,
          busy: _pendingScans > 0,
          feedback: _scanFeedback,
          allowConcurrentDetections: true,
          onCodeDetected: _stageScan,
        ),
      if (_scanStatus.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Text(_scanStatus,
              key: const ValueKey('qolip-scan-status'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _scanFeedback == ProductionQuickScanFeedback.rejected
                      ? Theme.of(context).colorScheme.error
                      : null)),
        ),
      if (_pendingScans > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Text(_s(context, 'scan_pending')),
        ),
      PaddonSectionHeader(
          title: _s(context, 'selection_review'), count: '${_selected.length}'),
      if (_selected.isEmpty)
        PaddonEmptyState(
            title: _s(context, 'selected_empty'),
            message: _s(context, 'scan_ready'),
            icon: Icons.qr_code_scanner_rounded)
      else
        M3SegmentSpacedColumn(
          key: const ValueKey('qolip-scanned-molds'),
          children: [
            for (var i = 0; i < selected.length; i++)
              _selectedCard(context, selected[i], i),
          ],
        ),
    ];
  }

  Widget _selectedCard(
          BuildContext context, QolipStorageMold mold, int index) =>
      PaddonListCard(
        key: ValueKey('qolip-scanned-mold-${mold.code}'),
        slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
            index, _selected.length),
        code: mold.code,
        countLabel: '${_s(context, 'quantity')}: ${mold.quantity}',
        subtitle: [
          if (mold.productNames.isNotEmpty) mold.productNames,
          '${_s(context, 'set')}: ${mold.setId}'
        ].join('\n'),
        icon: Icons.layers_outlined,
        onTap: () => unawaited(_reviewMold(mold)),
        trailing: IconButton(
          tooltip: _s(context, 'deselect'),
          onPressed: () => _toggle(mold, false),
          icon: const Icon(Icons.close_rounded),
        ),
      );
}
