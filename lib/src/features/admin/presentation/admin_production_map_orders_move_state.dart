part of 'admin_production_map_orders_screen.dart';

class _PendingSequenceMove {
  _PendingSequenceMove({
    required this.orderId,
    required this.beforeId,
    required this.afterId,
    required this.scope,
    required this.visibleOrderIds,
  });

  final String orderId;
  final String? beforeId;
  final String? afterId;
  final String scope;
  final Set<String> visibleOrderIds;
  String? expectedVersion;
  String? idempotencyKey;
  int conflicts = 0;
  int connectionFailures = 0;
  bool requestedVersion = false;
}

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
    if (widget.readOnly || _searchQuery.trim().isNotEmpty) {
      return;
    }
    final apparatus = _selectedApparatus;
    if (apparatus == null) {
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
    final moved = orders[oldIndex];
    final movedState = _moveOrderQueueState(moved, apparatus);
    final isMovedFrozen = adminProductionMapOrderControlFor(
      _orderControlsByOrderId,
      moved.map.id.trim(),
    ).isFrozen;
    if (movedState.isActive || isMovedFrozen) {
      return;
    }

    var lastActiveIndex = -1;
    for (var i = 0; i < orders.length; i++) {
      if (i == oldIndex) continue;
      if (_moveOrderQueueState(orders[i], apparatus).isActive) {
        lastActiveIndex = i;
      }
    }
    var targetIndex = newIndex;
    if (lastActiveIndex != -1 && targetIndex <= lastActiveIndex) {
      targetIndex = lastActiveIndex + 1;
    }
    if (targetIndex >= orders.length) {
      targetIndex = orders.length - 1;
    }
    if (oldIndex == targetIndex) {
      return;
    }

    orders.removeAt(oldIndex);
    orders.insert(targetIndex, moved);
    final apparatusKey = apparatus.id.trim();
    final orderIds = orders.map((order) => order.map.id).toList();
    final before = targetIndex + 1 < orderIds.length
        ? orderIds[targetIndex + 1] : null;
    final after = before == null && targetIndex > 0
        ? orderIds[targetIndex - 1] : null;
    _updateScreenState(() {
      _pendingSequenceMoves.putIfAbsent(apparatusKey, () => []).add(
        _PendingSequenceMove(
          orderId: moved.map.id, beforeId: before, afterId: after,
          scope: _sequenceWriteScope,
          visibleOrderIds: orderIds.toSet(),
        ),
      );
    });
    await _drainSequenceMoves(apparatusKey);
  }

  String get _sequenceWriteScope =>
      '${MobileApi.baseUrl}|${AppSession.instance.profile?.role}|${AppSession.instance.profile?.ref}';

  // Keep server state separate from local drag intentions. A live snapshot or
  // an acknowledgement must never erase a drag that is still waiting to send.
  Map<String, List<String>> get _displaySequenceByApparatus => {
    for (final entry in _sequenceByApparatus.entries)
      entry.key: _projectSequenceMoves(entry.key, entry.value),
  };

  List<String> _projectSequenceMoves(String apparatus, List<String> canonical) {
    final ids = List<String>.from(canonical);
    for (final move in _pendingSequenceMoves[apparatus] ?? <_PendingSequenceMove>[]) {
      if (move.scope != _sequenceWriteScope || !ids.contains(move.orderId)) continue;
      if (move.beforeId != null && !ids.contains(move.beforeId)) continue;
      if (move.afterId != null && !ids.contains(move.afterId)) continue;
      ids.remove(move.orderId);
      final index = move.beforeId != null ? ids.indexOf(move.beforeId!)
          : move.afterId != null ? ids.indexOf(move.afterId!) + 1 : ids.length;
      ids.insert(index, move.orderId);
    }
    return ids;
  }

  void _requestSequenceReconcile(String apparatus) {
    _sequenceNeedsSnapshot.add(apparatus);
    _queueSnapshotGeneration++;
    _queueSnapshotNeedsReconcile = true;
    unawaited(_refreshQueueSnapshot());
  }

  void _resumeSequenceMoves() {
    // Snapshot application runs inside setState. Start writes after that
    // atomic state update, and retain transport backoff across polling reads.
    scheduleMicrotask(() {
      if (!mounted) return;
      for (final apparatus in _pendingSequenceMoves.keys.toList()) {
        if (!_sequenceRetryTimers.containsKey(apparatus)) {
          unawaited(_drainSequenceMoves(apparatus));
        }
      }
    });
  }

  void _cancelSequenceMoves(String apparatus, String message) {
    _sequenceRetryTimers.remove(apparatus)?.cancel();
    _updateScreenState(() => _pendingSequenceMoves.remove(apparatus));
    showAdminTopNotice(context, message, icon: Icons.warning_amber_rounded);
    _requestSequenceReconcile(apparatus);
  }

  Future<void> _drainSequenceMoves(String apparatus) async {
    if (!mounted || _sequenceRetryTimers.containsKey(apparatus) ||
        !_sequenceWritesInFlight.add(apparatus)) {
      return;
    }
    try {
      while (mounted) {
        final pending = _pendingSequenceMoves[apparatus];
        if (pending == null || pending.isEmpty) break;
        final move = pending.first;
        if (move.scope != _sequenceWriteScope) {
          _updateScreenState(() => _pendingSequenceMoves.remove(apparatus));
          break;
        }
        if (_sequenceNeedsSnapshot.contains(apparatus)) break;
        if (move.expectedVersion == null) {
          final version = _sequenceVersions[apparatus] ?? '';
          if (version.isEmpty) {
            if (move.requestedVersion) {
              _cancelSequenceMoves(apparatus,
                  'Server navbat versiyasini bermadi. Sahifani yangilang.');
            } else {
              move.requestedVersion = true;
              _requestSequenceReconcile(apparatus);
            }
            break;
          }
          final ids = _sequenceByApparatus[apparatus] ?? const <String>[];
          if (!ids.contains(move.orderId) ||
              (move.beforeId != null && !ids.contains(move.beforeId)) ||
              (move.afterId != null && !ids.contains(move.afterId))) {
            _cancelSequenceMoves(apparatus,
                'Buyurtmalar tarkibi o‘zgardi. Yangilangan navbatda qayta suring.');
            break;
          }
          move.expectedVersion = version;
          final random = Random.secure();
          move.idempotencyKey = List.generate(16,
              (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
        }
        final epoch = _lastAppliedSnapshotEpoch;
        try {
          final result = await MobileApi.instance.adminMoveProductionMapSequence(
            apparatus: apparatus, orderId: move.orderId,
            beforeOrderId: move.beforeId, afterOrderId: move.afterId,
            expectedVersion: move.expectedVersion!,
            idempotencyKey: move.idempotencyKey!,
          );
          if (!mounted) return;
          if (move.scope != _sequenceWriteScope) {
            _updateScreenState(() => _pendingSequenceMoves.remove(apparatus));
            return;
          }
          final responseEpoch = result.epoch.isEmpty ? epoch : result.epoch;
          final currentVersion = _sequenceVersions[apparatus];
          final currentRevision = _sequenceRevisions[apparatus];
          final stillCurrent = responseEpoch == _lastAppliedSnapshotEpoch &&
              (currentRevision == null || result.revision == null ||
                  result.revision! >= currentRevision) &&
              (currentVersion == move.expectedVersion || currentVersion == result.version);
          _queueSnapshotGeneration++;
          _queueSnapshotNeedsReconcile = true;
          _updateScreenState(() {
            if (stillCurrent) {
              _sequenceByApparatus[apparatus] = result.orderIds;
              _sequenceVersions[apparatus] = result.version;
              if (result.revision != null) {
                _sequenceRevisions[apparatus] = result.revision!;
              }
            }
            pending.removeAt(0);
            if (pending.isEmpty) _pendingSequenceMoves.remove(apparatus);
          });
          if (result.adjusted && stillCurrent) {
            final position = result.orderIds.where(move.visibleOrderIds.contains)
                .toList().indexOf(move.orderId) + 1;
            showAdminTopNotice(context,
                context.l10n.adminText('sequence.nearest_position',
                    values: {'position': position}),
                icon: Icons.info_outline);
          }
          if (!stillCurrent) {
            _requestSequenceReconcile(apparatus);
            break;
          }
        } catch (error) {
          if (!mounted) return;
          if (move.scope != _sequenceWriteScope) {
            _updateScreenState(() => _pendingSequenceMoves.remove(apparatus));
            break;
          }
          if (error is MobileApiException && error.code == 'queue_reorder_conflict' &&
              move.conflicts++ < 3) {
            // A 409 definitively did not commit this attempt. Rebase this
            // intention only after a fresh snapshot, with a NEW command key.
            move.expectedVersion = null;
            move.idempotencyKey = null;
            _requestSequenceReconcile(apparatus);
            break;
          }
          final transient = error is TimeoutException || error is http.ClientException ||
              (error is MobileApiException &&
                  (error.statusCode == 408 || error.statusCode == 429 ||
                   (error.statusCode ?? 0) >= 500));
          if (transient) {
            // The write may already have committed. Keep the exact body/key;
            // retry receipts in PostgreSQL survive backend restarts.
            move.connectionFailures++;
            if (move.connectionFailures == 1) {
              showAdminTopNotice(context,
                  'Aloqa tiklangach, navbatdagi o‘zgarishlar saqlanadi.',
                  icon: Icons.info_outline);
            }
            final delay = 1 << min(move.connectionFailures - 1, 3);
            _sequenceRetryTimers.remove(apparatus)?.cancel();
            _sequenceRetryTimers[apparatus] = Timer(Duration(seconds: delay), () {
              _sequenceRetryTimers.remove(apparatus);
              if (mounted) unawaited(_drainSequenceMoves(apparatus));
            });
          } else {
            _cancelSequenceMoves(apparatus, _adminActionErrorText(error,
                'Ketma-ketlik saqlanmadi. Navbat qayta yuklanmoqda.'));
          }
          break;
        }
      }
    } finally {
      _sequenceWritesInFlight.remove(apparatus);
      if (mounted && !_sequenceNeedsSnapshot.contains(apparatus)) {
        // Reconcile action controls as well as ordering. Never clear a valid
        // fingerprint while this read is pending or if the network is down.
        unawaited(_refreshQueueSnapshot());
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
