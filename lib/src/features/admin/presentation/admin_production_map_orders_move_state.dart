part of 'admin_production_map_orders_screen.dart';

extension _AdminProductionMapOrdersMoveState
    on _AdminProductionMapOrdersScreenState {
  void _syncMoveApparatusDefaults(List<AdminWarehouse> source) {
    final defaults = _moveApparatusDefaults(
      source: source,
      currentTop: _moveTopApparatus,
      currentBottom: _moveBottomApparatus,
    );
    _moveTopApparatus = defaults.top;
    _moveBottomApparatus = defaults.bottom;
  }

  List<ProductionMapSaved> _moveOrdersForApparatus({
    required AdminWarehouse source,
    required AdminWarehouse target,
  }) {
    if (_isMoveUnassignedApparatus(source)) {
      if (_isMoveUnassignedApparatus(target)) {
        return const [];
      }
      return _alternativeOrdersForApparatus(target);
    }
    if (_isMoveUnassignedApparatus(target)) {
      return _ordersForApparatus(source);
    }
    return _ordersForApparatus(source)
        .where(
          (order) => _canMoveOrderToApparatus(order, target, source: source),
        )
        .toList(growable: false);
  }

  Future<void> _reorderSelectedApparatusOrders(
    int oldIndex,
    int newIndex,
  ) async {
    if (widget.readOnly) {
      return;
    }
    final apparatus = _selectedApparatus;
    if (apparatus == null) {
      return;
    }
    final orders = List<ProductionMapSaved>.from(
      _ordersForApparatus(apparatus),
    );
    if (oldIndex == newIndex) {
      return;
    }
    final previousOrderIds =
        orders.map((order) => order.map.id).toList(growable: false);
    final moved = orders.removeAt(oldIndex);
    orders.insert(newIndex, moved);
    final apparatusKey = apparatus.warehouse.trim();
    final orderIds =
        orders.map((order) => order.map.id).toList(growable: false);
    _updateScreenState(() {
      _sequenceByApparatus[apparatusKey] = orderIds;
    });
    await _persistApparatusSequence(
      apparatus: apparatusKey,
      orderIds: orderIds,
      previousOrderIds: previousOrderIds,
    );
  }

  Future<void> _persistApparatusSequence({
    required String apparatus,
    required List<String> orderIds,
    required List<String> previousOrderIds,
  }) async {
    try {
      await MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: apparatus,
        orderIds: orderIds,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _updateScreenState(() {
        _sequenceByApparatus[apparatus] = previousOrderIds;
      });
      showAdminTopNotice(
        context,
        _adminActionErrorText(error, 'Ketma-ketlik saqlanmadi'),
      );
    }
  }

  void _toggleMoveOrderSelection(String orderId) {
    if (widget.readOnly) {
      return;
    }
    final normalized = orderId.trim();
    _updateScreenState(() {
      if (_selectedMoveOrderIds.contains(normalized)) {
        _selectedMoveOrderIds.remove(normalized);
      } else {
        _selectedMoveOrderIds.add(normalized);
      }
    });
  }

  _MoveDragPayload _buildMoveDragPayload({
    required ProductionMapSaved order,
    required AdminWarehouse source,
    required List<ProductionMapSaved> zoneOrders,
  }) {
    return _moveDragPayload(
      order: order,
      source: source,
      zoneOrders: zoneOrders,
      selectedOrderIds: _selectedMoveOrderIds,
    );
  }

  void _clearMoveDragState() {
    _updateScreenState(() {
      _draggingMoveOrders = const [];
      _draggingMoveSource = null;
    });
  }

  void _applySavedMoveOrders({
    required Set<String> orderIds,
    required Map<String, ProductionMapSaved> savedById,
  }) {
    _updateScreenState(() {
      _selectedMoveOrderIds.removeAll(orderIds);
      _orders = _mergeSavedProductionMapOrders(_orders, savedById);
    });
  }

  Future<void> _resyncAfterMoveActionError(
    Object error,
    String fallbackMessage,
  ) async {
    if (!mounted) {
      return;
    }
    showAdminTopNotice(
      context,
      _adminActionErrorText(error, fallbackMessage),
    );
    await _load();
  }

  Future<void> _moveOrdersBetweenApparatus({
    required List<ProductionMapSaved> orders,
    required AdminWarehouse from,
    required AdminWarehouse to,
  }) async {
    if (_isMoveUnassignedApparatus(from) && !_isMoveUnassignedApparatus(to)) {
      await _assignAlternativeOrdersToApparatus(orders: orders, apparatus: to);
      return;
    }
    if (!_isMoveUnassignedApparatus(from) && _isMoveUnassignedApparatus(to)) {
      await _returnOrdersToUnassigned(orders: orders, source: from);
      return;
    }
    if (widget.readOnly ||
        from.warehouse.trim() == to.warehouse.trim() ||
        _isMoveUnassignedApparatus(from) ||
        _isMoveUnassignedApparatus(to) ||
        orders.isEmpty) {
      return;
    }
    final blocked = orders.any(
      (order) => !_canMoveOrderToApparatus(order, to, source: from),
    );
    if (blocked) {
      showAdminTopNotice(context, 'Tanlangan zakazlar bu aparatga tushmaydi');
      return;
    }
    final orderIds = _productionMapOrderIdSet(orders);
    _clearMoveDragState();
    try {
      final saved = await MobileApi.instance.adminMoveProductionMapOrdersBatch(
        mapIds: orders.map((order) => order.map.id).toList(growable: false),
        fromApparatus: from.warehouse,
        toApparatus: to.warehouse,
      );
      if (!mounted) {
        return;
      }
      final savedById = _savedProductionMapOrdersByIdOrThrow(
        saved: saved,
        expectedOrderIds: orderIds,
        incompleteMessage: 'Zakazlar to‘liq ko‘chirilmadi',
      );
      _applySavedMoveOrders(orderIds: orderIds, savedById: savedById);
      showAdminTopNotice(context, _moveOrdersSuccessText(orders.length));
    } catch (error) {
      await _resyncAfterMoveActionError(error, 'Zakaz ko‘chirilmadi');
    }
  }

  Future<void> _returnOrdersToUnassigned({
    required List<ProductionMapSaved> orders,
    required AdminWarehouse source,
  }) async {
    if (widget.readOnly || orders.isEmpty) {
      return;
    }
    final convertedMaps = _returnAssignedMapsToAlternatives(
      orders: orders,
      source: source,
    );
    if (convertedMaps == null) {
      showAdminTopNotice(context, 'Bu zakaz tanlanmagan holatga qaytmaydi');
      return;
    }
    final orderIds = _productionMapOrderIdSet(orders);
    _clearMoveDragState();
    try {
      final saved = await _saveProductionMapDefinitions(convertedMaps);
      if (!mounted) {
        return;
      }
      final savedById = _savedProductionMapOrdersByIdOrThrow(
        saved: saved,
        expectedOrderIds: orderIds,
        incompleteMessage: 'Zakazlar to‘liq tanlanmagan holatga qaytmadi',
      );
      _applySavedMoveOrders(orderIds: orderIds, savedById: savedById);
      showAdminTopNotice(
        context,
        _returnOrdersToUnassignedSuccessText(orders.length),
      );
    } catch (error) {
      await _resyncAfterMoveActionError(
        error,
        'Zakaz tanlanmagan holatga qaytmadi',
      );
    }
  }

  Future<void> _assignAlternativeOrdersToApparatus({
    required List<ProductionMapSaved> orders,
    required AdminWarehouse apparatus,
  }) async {
    if (widget.readOnly || orders.isEmpty) {
      return;
    }
    final blocked = orders.any(
      (order) => !_isAlternativeOrderForApparatus(order, apparatus),
    );
    if (blocked) {
      showAdminTopNotice(context, 'Tanlangan zakazlar bu aparatga tushmaydi');
      return;
    }
    final orderIds = _productionMapOrderIdSet(orders);
    _clearMoveDragState();
    try {
      final assignedMaps = _assignAlternativeMapsToApparatus(
        orders: orders,
        apparatus: apparatus,
      );
      final saved = await _saveProductionMapDefinitions(assignedMaps);
      if (!mounted) {
        return;
      }
      final savedById = _savedProductionMapOrdersByIdOrThrow(
        saved: saved,
        expectedOrderIds: orderIds,
        incompleteMessage: 'Zakazlar to‘liq biriktirilmadi',
      );
      _applySavedMoveOrders(orderIds: orderIds, savedById: savedById);
      showAdminTopNotice(
        context,
        _assignAlternativeOrdersSuccessText(orders.length),
      );
    } catch (error) {
      await _resyncAfterMoveActionError(error, 'Zakaz biriktirilmadi');
    }
  }

  Future<void> _pickMoveApparatus({required bool top}) async {
    final anchor = top ? _moveBottomApparatus : _moveTopApparatus;
    final pickerApparatus = _movePickerApparatusOptions(anchor);
    final unassignedOrderCount =
        anchor == null || _isMoveUnassignedApparatus(anchor)
            ? 0
            : _alternativeOrdersForApparatus(anchor).length;
    final picked = await showModalBottomSheet<AdminWarehouse>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ApparatusPickerSheet(
        apparatus: pickerApparatus,
        selected: top ? _moveTopApparatus : _moveBottomApparatus,
        orderCountFor: (apparatus) => _ordersForApparatus(apparatus).length,
        showUnassigned: anchor != null && !_isMoveUnassignedApparatus(anchor),
        unassignedOrderCount: unassignedOrderCount,
      ),
    );
    if (picked == null || !mounted) {
      return;
    }
    _updateScreenState(() {
      if (top) {
        _moveTopApparatus = picked;
      } else {
        _moveBottomApparatus = picked;
      }
    });
  }

  List<AdminWarehouse> _movePickerApparatusOptions(
    AdminWarehouse? oppositeApparatus,
  ) {
    return _movePickerApparatusOptionsForList(
      apparatus: _apparatus,
      oppositeApparatus: oppositeApparatus,
    );
  }

  List<ProductionMapSaved> _alternativeOrdersForApparatus(
    AdminWarehouse apparatus,
  ) {
    return _alternativeOrdersForApparatusList(
      orders: _orders,
      apparatus: apparatus,
    );
  }
}
