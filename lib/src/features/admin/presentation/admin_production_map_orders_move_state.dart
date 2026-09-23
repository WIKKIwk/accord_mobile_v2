part of 'admin_production_map_orders_screen.dart';

class _ApparatusTransferReasonDialog extends StatefulWidget {
  const _ApparatusTransferReasonDialog({
    required this.orderCount,
    required this.from,
    required this.to,
  });
  final int orderCount;
  final AdminApparatus from;
  final AdminApparatus to;

  @override
  State<_ApparatusTransferReasonDialog> createState() =>
      _ApparatusTransferReasonDialogState();
}

class _ApparatusTransferReasonDialogState
    extends State<_ApparatusTransferReasonDialog> {
  late final TextEditingController _controller;
  String _validationMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Text(context.l10n.adminText('production.transfer.title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.adminText(
                'production.transfer.message',
                values: {
                  'count': widget.orderCount,
                  'from': widget.from.name,
                  'to': widget.to.name,
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('apparatus-transfer-reason'),
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: context.l10n.adminText(
                  'production.transfer.reason',
                ),
                hintText: context.l10n.adminText(
                  'production.transfer.hint',
                ),
                errorText:
                    _validationMessage.isEmpty ? null : _validationMessage,
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () {
                  final reason = _controller.text.trim();
                  if (reason.isEmpty) {
                    setState(() {
                      _validationMessage = context.l10n.adminText(
                        'production.transfer.required',
                      );
                    });
                    return;
                  }
                  Navigator.of(context).pop(reason);
                },
                child: Text(
                  context.l10n.adminText('production.transfer.move'),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.adminText('action.cancel')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension _AdminProductionMapOrdersMoveState
    on _AdminProductionMapOrdersScreenState {
  void _syncMoveApparatusDefaults(List<AdminApparatus> source) {
    final defaults = _moveApparatusDefaults(
      source: source,
      currentTop: _moveTopApparatus,
      currentBottom: _moveBottomApparatus,
    );
    _moveTopApparatus = defaults.top;
    _moveBottomApparatus = defaults.bottom;
  }

  List<ProductionMapSaved> _moveOrdersForApparatus({
    required AdminApparatus source,
    required AdminApparatus target,
  }) {
    if (_isMoveUnassignedApparatus(source)) {
      if (_isMoveUnassignedApparatus(target)) {
        return const [];
      }
      return _alternativeOrdersForApparatus(target);
    }
    if (_isMoveUnassignedApparatus(target)) {
      return _ordersForApparatus(source)
          .where(
            (order) =>
                _canMoveOrderToApparatus(order, target, source: source) ||
                _isUnassignedAlternativeCandidateForApparatus(
                  order: order,
                  apparatus: source,
                ),
          )
          .toList(growable: false);
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
    if (widget.readOnly ||
        _sequenceReorderPending ||
        _searchQuery.trim().isNotEmpty) {
      return;
    }
    final apparatus = _selectedApparatus;
    if (apparatus == null) {
      return;
    }
    final expectedVersion = _sequenceVersions[apparatus.id.trim()] ?? '';
    if (expectedVersion.isEmpty) {
      showAdminTopNotice(context,
          'Navbatni xavfsiz surish hali tayyor emas. Server va navbatni yangilang.',
          icon: Icons.warning_amber_rounded);
      return;
    }
    final orders = List<ProductionMapSaved>.from(
      _ordersForApparatus(apparatus),
    );
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= orders.length ||
        newIndex < 0 ||
        newIndex >= orders.length) {
      return;
    }
    final previousOrderIds = List<String>.from(
        _sequenceByApparatus[apparatus.id.trim()] ?? const []);
    final moved = orders.removeAt(oldIndex);
    orders.insert(newIndex, moved);
    final apparatusKey = apparatus.id.trim();
    final orderIds =
        orders.map((order) => order.map.id).toList(growable: false);
    final optimisticIds = List<String>.from(previousOrderIds)
      ..remove(moved.map.id);
    final before =
        newIndex + 1 < orderIds.length ? orderIds[newIndex + 1] : null;
    final after =
        before == null && newIndex > 0 ? orderIds[newIndex - 1] : null;
    final target = before != null
        ? optimisticIds.indexOf(before)
        : after != null
            ? optimisticIds.indexOf(after) + 1
            : optimisticIds.length;
    optimisticIds.insert(
        target < 0 ? optimisticIds.length : target, moved.map.id);
    _updateScreenState(() {
      _sequenceReorderPending = true;
      _sequenceByApparatus[apparatusKey] = optimisticIds;
    });
    await _persistApparatusSequence(
      apparatus: apparatusKey,
      orderIds: orderIds,
      previousOrderIds: previousOrderIds,
      movedOrderId: moved.map.id,
      expectedVersion: expectedVersion,
    );
  }

  Future<void> _persistApparatusSequence({
    required String apparatus,
    required List<String> orderIds,
    required List<String> previousOrderIds,
    required String movedOrderId,
    required String expectedVersion,
  }) async {
    final epochAtStart = _lastAppliedSnapshotEpoch;
    final index = orderIds.indexOf(movedOrderId);
    final before = index + 1 < orderIds.length ? orderIds[index + 1] : null;
    final after = before == null && index > 0 ? orderIds[index - 1] : null;
    final random = Random.secure();
    final key = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    try {
      final result = await MobileApi.instance.adminMoveProductionMapSequence(
        apparatus: apparatus,
        orderId: movedOrderId,
        beforeOrderId: before,
        afterOrderId: after,
        expectedVersion: expectedVersion,
        idempotencyKey: key,
      );
      if (!mounted) return;
      final stillCurrent = _lastAppliedSnapshotEpoch == epochAtStart &&
          _sequenceVersions[apparatus] == expectedVersion;
      if (stillCurrent) {
        _updateScreenState(() {
          _sequenceByApparatus[apparatus] = result.orderIds;
          _sequenceVersions[apparatus] = result.version;
        });
      }
      final visibleIds = orderIds.toSet();
      final savedIndex = result.orderIds
          .where(visibleIds.contains)
          .toList()
          .indexOf(movedOrderId);
      if (stillCurrent && result.adjusted) {
        showAdminTopNotice(
          context,
          context.l10n.adminText('sequence.nearest_position',
              values: {'position': savedIndex + 1}),
          icon: Icons.info_outline,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (_lastAppliedSnapshotEpoch == epochAtStart &&
          _sequenceVersions[apparatus] == expectedVersion) {
        _updateScreenState(() {
          _sequenceByApparatus[apparatus] = previousOrderIds;
        });
      }
      showAdminTopNotice(
        context,
        _adminActionErrorText(
          error,
          context.l10n.adminText('item.loading_failed'),
        ),
        icon: Icons.warning_amber_rounded,
      );
    } finally {
      if (mounted) {
        // A timeout can mean "committed but reply lost". Never resend an old
        // list or overwrite a newer live snapshot; reconcile from the server.
        _queueSnapshotGeneration++;
        _queueSnapshotNeedsReconcile = true;
        _sequenceVersions.remove(apparatus);
        await _refreshQueueSnapshot();
        if (mounted) _updateScreenState(() => _sequenceReorderPending = false);
      }
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
    required AdminApparatus source,
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
    // Dispatch changes backend-owned visibility as well as map metadata.
    // Discard pre-save reads and reconcile without waiting for the next poll.
    _queueSnapshotGeneration++;
    _queueSnapshotNeedsReconcile = true;
    unawaited(_refreshQueueSnapshot());
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
      icon: Icons.warning_amber_rounded,
    );
    await _load();
  }

  ApparatusQueueOrderState _moveOrderQueueState(
    ProductionMapSaved order,
    AdminApparatus apparatus,
  ) {
    final states = _queueStatesForApparatus(
      apparatus,
      queueStatesByApparatus: _queueStatesByApparatus,
    );
    return apparatusQueueOrderStateFromRaw(states[order.map.id.trim()]);
  }

  Future<String?> _askApparatusTransferReason({
    required int orderCount,
    required AdminApparatus from,
    required AdminApparatus to,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (context) => _ApparatusTransferReasonDialog(
        orderCount: orderCount,
        from: from,
        to: to,
      ),
    );
  }

  Future<void> _moveOrdersBetweenApparatus({
    required List<ProductionMapSaved> orders,
    required AdminApparatus from,
    required AdminApparatus to,
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
        from.id.trim() == to.id.trim() ||
        _isMoveUnassignedApparatus(from) ||
        _isMoveUnassignedApparatus(to) ||
        orders.isEmpty) {
      return;
    }
    final blocked = orders.any(
      (order) => !_canMoveOrderToApparatus(order, to, source: from),
    );
    if (blocked) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('production.move.invalid_target'),
        icon: Icons.warning_amber_rounded,
      );
      return;
    }
    final orderIds = _productionMapOrderIdSet(orders);
    final inProgressOrders = orders
        .where(
          (order) =>
              _moveOrderQueueState(order, from) ==
              ApparatusQueueOrderState.inProgress,
        )
        .toList(growable: false);
    if (inProgressOrders.isNotEmpty) {
      _clearMoveDragState();
      showAdminTopNotice(
        context,
        context.l10n.adminText('production.move.in_progress'),
        icon: Icons.warning_amber_rounded,
      );
      return;
    }
    final pausedOrders = orders
        .where(
          (order) =>
              _moveOrderQueueState(order, from) ==
              ApparatusQueueOrderState.paused,
        )
        .toList(growable: false);
    final pendingOrders = orders
        .where(
          (order) =>
              _moveOrderQueueState(order, from) ==
              ApparatusQueueOrderState.pending,
        )
        .toList(growable: false);
    _clearMoveDragState();
    String? transferReason;
    if (pausedOrders.isNotEmpty) {
      transferReason = await _askApparatusTransferReason(
        orderCount: pausedOrders.length,
        from: from,
        to: to,
      );
      if (transferReason == null || !mounted) {
        return;
      }
    }
    try {
      final savedById = <String, ProductionMapSaved>{};
      final transferTimestamp = DateTime.now().microsecondsSinceEpoch;
      for (var index = 0; index < pausedOrders.length; index++) {
        final order = pausedOrders[index];
        final saved = await MobileApi.instance.adminTransferProductionMapOrder(
          orderId: order.map.id,
          fromApparatus: from.id,
          toApparatus: to.id,
          reason: transferReason!,
          idempotencyKey:
              'app-transfer-${order.map.id.trim()}-$transferTimestamp-$index',
        );
        savedById[order.map.id.trim()] = saved;
      }
      if (pendingOrders.isNotEmpty) {
        final saved =
            await MobileApi.instance.adminMoveProductionMapOrdersBatch(
          mapIds: pendingOrders
              .map((order) => order.map.id)
              .toList(growable: false),
          fromApparatus: from.id,
          toApparatus: to.id,
        );
        savedById.addAll(
          _savedProductionMapOrdersByIdOrThrow(
            saved: saved,
            expectedOrderIds: _productionMapOrderIdSet(pendingOrders),
            incompleteMessage: context.l10n.adminText(
              'production.move.incomplete',
            ),
          ),
        );
      }
      if (!mounted) {
        return;
      }
      final completeSavedById = _savedProductionMapOrdersByIdOrThrow(
        saved: savedById.values.toList(growable: false),
        expectedOrderIds: orderIds,
        incompleteMessage: context.l10n.adminText(
          'production.move.incomplete',
        ),
      );
      _applySavedMoveOrders(
        orderIds: orderIds,
        savedById: completeSavedById,
      );
      await _refreshLive();
      if (!mounted) {
        return;
      }
      showAdminTopNotice(
        context,
        _moveOrdersSuccessText(context.l10n, orders.length),
      );
    } catch (error) {
      await _resyncAfterMoveActionError(
        error,
        context.l10n.adminText('production.move.failed'),
      );
    }
  }

  Future<void> _returnOrdersToUnassigned({
    required List<ProductionMapSaved> orders,
    required AdminApparatus source,
  }) async {
    if (widget.readOnly || orders.isEmpty) {
      return;
    }
    final convertedMaps = _returnAssignedMapsToAlternatives(
      orders: orders,
      source: source,
    );
    if (convertedMaps == null) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('production.move.not_unassigned'),
        icon: Icons.warning_amber_rounded,
      );
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
        incompleteMessage: context.l10n.adminText(
          'production.move.return_incomplete',
        ),
      );
      _applySavedMoveOrders(orderIds: orderIds, savedById: savedById);
      showAdminTopNotice(
        context,
        _returnOrdersToUnassignedSuccessText(context.l10n, orders.length),
      );
    } catch (error) {
      await _resyncAfterMoveActionError(
        error,
        context.l10n.adminText('production.move.return_failed'),
      );
    }
  }

  Future<void> _assignAlternativeOrdersToApparatus({
    required List<ProductionMapSaved> orders,
    required AdminApparatus apparatus,
  }) async {
    if (widget.readOnly || orders.isEmpty) {
      return;
    }
    final blocked = orders.any(
      (order) => !_isAlternativeOrderForApparatus(order, apparatus),
    );
    if (blocked) {
      showAdminTopNotice(
        context,
        context.l10n.adminText('production.move.invalid_target'),
        icon: Icons.warning_amber_rounded,
      );
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
        incompleteMessage: context.l10n.adminText(
          'production.move.assign_incomplete',
        ),
      );
      _applySavedMoveOrders(orderIds: orderIds, savedById: savedById);
      showAdminTopNotice(
        context,
        _assignAlternativeOrdersSuccessText(context.l10n, orders.length),
      );
    } catch (error) {
      await _resyncAfterMoveActionError(
        error,
        context.l10n.adminText('production.move.assign_failed'),
      );
    }
  }

  Future<void> _pickMoveApparatus({required bool top}) async {
    final anchor = top ? _moveBottomApparatus : _moveTopApparatus;
    final pickerApparatus = _movePickerApparatusOptions(anchor);
    final unassignedOrderCount =
        anchor == null || _isMoveUnassignedApparatus(anchor)
            ? 0
            : _alternativeOrdersForApparatus(anchor).length;
    final picked = await showModalBottomSheet<AdminApparatus>(
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

  List<AdminApparatus> _movePickerApparatusOptions(
    AdminApparatus? oppositeApparatus,
  ) {
    return _movePickerApparatusOptionsForList(
      apparatus: _apparatus,
      oppositeApparatus: oppositeApparatus,
    );
  }

  List<ProductionMapSaved> _alternativeOrdersForApparatus(
    AdminApparatus apparatus,
  ) {
    return _alternativeOrdersForApparatusList(
      orders: _orders,
      apparatus: apparatus,
    );
  }
}
