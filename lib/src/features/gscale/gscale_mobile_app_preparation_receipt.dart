part of 'gscale_mobile_app.dart';

extension _PreparationReceiptPreset on _OperatorDashboardPageState {
  bool get _isPreparationFormulaReceipt =>
      widget.controlOnly && widget.freshForm;

  bool get _usesReceiptOrderContext =>
      _isMaterialReceipt || _isPreparationFormulaReceipt;

  String get _preparationPresetProblem {
    final conflict = _preparationPresetConflictMessage;
    if (conflict.isNotEmpty) return conflict;
    return _isPreparationFormulaReceipt && !_preparationPresetApplied
        ? _preparationPresetError
        : '';
  }

  void _restartPreparationReceiptPreset() {
    _preparationPresetGeneration++;
    _preparationPresetOrderId = widget.linkedOrderId.trim();
    _preparationPresetApplied = false;
    _preparationPresetLoading = true;
    _preparationPresetError = '';
    _preparationPresetItem = null;
    if (_authoritativeRsBatch?.active != true) {
      _runWithoutSavingControlPrefs(_clearPreparationReceiptFields);
    }
    unawaited(_loadControlDraftPreferences());
  }

  String get _preparationPresetConflictMessage {
    final batch = _authoritativeRsBatch;
    if (!_isPreparationFormulaReceipt ||
        _preparationPresetApplied ||
        batch?.active != true) {
      return '';
    }
    if (batch!.orderId != _preparationPresetOrderId ||
        (_preparationPresetItem != null &&
            batch.itemCode != _preparationPresetItem!.itemCode)) {
      return 'Boshqa homashyo yoki order uchun batch faol. Avval uni to‘xtating.';
    }
    if (_preparationPresetItem == null) {
      return 'Tanlangan homashyo tekshirilmaguncha faol batchdan chop etib bo‘lmaydi.';
    }
    return '';
  }

  void _clearPreparationReceiptFields() {
    _draftOrderId = widget.linkedOrderId.trim();
    _selectedItem = null;
    _selectedWarehouse = null;
    _draftContextSaved = false;
    _batchContextEditing = false;
    _warehouseMode = 'manual';
    _defaultWarehouse = '';
    _defaultWarehouseController.clear();
    _widthController.clear();
    _micronController.clear();
    _lengthController.clear();
    _manualQtyController.clear();
    _manualDuplicateController.clear();
    _babinaWeightController.clear();
    _babinaEnabled = false;
    _quantitySource = 'scale';
    _materialSupplier = '';
    _manualQtyTapBackup = '';
    _manualQtyTapCleared = false;
  }

  void _tryApplyPreparationReceiptPreset() {
    if (!_isPreparationFormulaReceipt ||
        _preparationPresetApplied ||
        _preparationPresetLoading ||
        !_rpsBatchStateResolved ||
        _authoritativeRsBatch?.active == true ||
        _preparationPresetItem == null ||
        widget.linkedOrderId.trim() != _preparationPresetOrderId) {
      return;
    }
    _runWithoutSavingControlPrefs(() {
      _clearPreparationReceiptFields();
      _selectedItem = _preparationPresetItem;
      _preparationPresetApplied = true;
    });
    _scheduleSaveControlPrefs();
  }

  Future<void> _loadPreparationReceiptPreset(OperatorControlDraft draft) async {
    if (!_isPreparationFormulaReceipt || _preparationPresetApplied) return;
    final generation = ++_preparationPresetGeneration;
    if (_authoritativeRsBatch?.active != true) {
      _runWithoutSavingControlPrefs(() {
        _updatePreparationReceipt(() {
          _clearPreparationReceiptFields();
          // Printer settings describe the device, not the new receipt.
          _batchPrinter =
              draft.printer.isNotEmpty ? draft.printer : _batchPrinter;
          _batchPrintMode =
              draft.printMode.isNotEmpty ? draft.printMode : _batchPrintMode;
          if (_batchPrinter == 'godex') {
            _batchPrintMode = 'label';
          }
        });
      });
    }
    final scope = _materialWarehouseUserKey;
    final orderId = _preparationPresetOrderId;
    final identities = {
      widget.initialMaterialId?.trim().toLowerCase() ?? '',
      widget.initialMaterialName?.trim().toLowerCase() ?? '',
    }..remove('');
    bool current() =>
        mounted &&
        generation == _preparationPresetGeneration &&
        _isPreparationFormulaReceipt &&
        scope == _materialWarehouseUserKey &&
        widget.linkedOrderId.trim() == orderId &&
        !_preparationPresetApplied;
    try {
      if (orderId.isEmpty || identities.isEmpty) {
        throw const MobileApiException(
          code: 'preparation_receipt_invalid',
          message: 'Buyurtma yoki homashyo ma’lumoti topilmadi.',
        );
      }
      final matches = <String, SupplierItem>{};
      for (final query in identities) {
        var offset = 0;
        while (true) {
          final items = await MobileApi.instance.gscaleItemsPage(
            query: query,
            orderId: orderId,
            offset: offset,
            limit: 200,
            useBackend: true,
          );
          if (!current()) return;
          for (final item in items) {
            if (identities.contains(item.code.trim().toLowerCase()) ||
                identities.contains(item.name.trim().toLowerCase())) {
              matches[item.code] = item;
            }
          }
          if (items.length < 200) break;
          offset += items.length;
        }
      }
      if (matches.length != 1) {
        throw MobileApiException(
          code: 'preparation_receipt_material',
          message: matches.isEmpty
              ? 'Tanlangan homashyoga mos Rulon katalog mahsuloti topilmadi.'
              : 'Homashyoga bir nechta katalog mahsuloti mos keldi. Homashyoni tanlang.',
        );
      }
      if (!current()) return;
      final item = matches.values.single;
      _updatePreparationReceipt(() {
        _preparationPresetItem = MobileItem(
          itemCode: item.code,
          itemName: item.name.isEmpty ? item.code : item.name,
          requiresDimensions: item.requiresDimensions,
        );
        _preparationPresetLoading = false;
        _preparationPresetError = '';
        _tryApplyPreparationReceiptPreset();
        _errorText = _preparationPresetConflictMessage;
      });
    } catch (error) {
      if (!current()) return;
      _updatePreparationReceipt(() {
        _preparationPresetLoading = false;
        _preparationPresetError =
            error is MobileApiException ? error.message : error.toString();
      });
    }
  }
}
