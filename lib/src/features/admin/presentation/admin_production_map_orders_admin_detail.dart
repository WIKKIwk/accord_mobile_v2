part of 'admin_production_map_orders_screen.dart';

_OrderCardTone _adminSequenceTone(String state) => switch (state) {
      'issue' => _OrderCardTone.issue,
      'frozen' => _OrderCardTone.frozen,
      'paused' => _OrderCardTone.paused,
      'in_progress' => _OrderCardTone.inProgress,
      'print_preflight' => _OrderCardTone.printPreflight,
      'print_preflight_passed' => _OrderCardTone.printPreflightPassed,
      'waiting_next_stage' => _OrderCardTone.waitingNextStage,
      'completed' => _OrderCardTone.completed,
      _ => _OrderCardTone.neutral,
    };

extension _AdminSequenceDetails on _AdminProductionMapOrdersScreenState {
  Map<String, AdminSequenceListRow> get _adminSequenceRows =>
      !_adminPaging || _selectedApparatus == null
          ? const {}
          : _adminWindow('sequence', apparatus: _selectedApparatus!.id)
              .sequenceRows;

  bool _adminPageBehindSequenceMoves(AdminProductionOrderPage page) =>
      page.epoch == _lastAppliedSnapshotEpoch &&
      page.sequenceRevisions.entries
          .any((entry) => entry.value < (_sequenceRevisions[entry.key] ?? 0));

  Future<AdminApparatusQueueSnapshot?> _readAdminSequenceDetail(
      AdminApparatus apparatus, String orderId) async {
    final account = _adminPageAccount;
    final window = _adminWindow('sequence', apparatus: apparatus.id);
    final loader = widget.orderDetailLoader ??
        MobileApi.instance.adminProductionOrderDetail;
    for (var attempt = 0; attempt < 2; attempt++) {
      final key = jsonEncode([account, apparatus.id, orderId]);
      if (attempt == 0 &&
          (window.dirty ||
              window.cacheNeedsValidation ||
              window.awaitingLive) &&
          !_adminPendingDetailReads.contains(key)) {
        _adminDetailReads.remove(key);
      }
      final future = _adminDetailReads.putIfAbsent(key, () {
        _adminPendingDetailReads.add(key);
        return Future<AdminApparatusQueueSnapshot>.sync(
          () => loader(apparatus: apparatus.id, orderId: orderId),
        ).whenComplete(() => _adminPendingDetailReads.remove(key));
      });
      AdminApparatusQueueSnapshot snapshot;
      try {
        snapshot = await future;
      } catch (_) {
        if (identical(_adminDetailReads[key], future)) {
          _adminDetailReads.remove(key);
        }
        rethrow;
      }
      if (!mounted ||
          account != _adminPageAccount ||
          _selectedApparatus?.id != apparatus.id ||
          window.request.search != _adminPageSearch ||
          !window.sequenceRows.containsKey(orderId)) {
        return null;
      }
      final baseline = window.pages.first;
      final valid = snapshot.epoch == baseline.epoch &&
          !_retiredSnapshotEpochs.contains(snapshot.epoch) &&
          snapshot.revision != null &&
          snapshot.revision! >= baseline.revision! &&
          snapshot.maps.length == 1 &&
          snapshot.maps.single.map.id == orderId &&
          snapshot.scope.isNotEmpty;
      if (valid) {
        // Bound full detail retention separately from summary page caches.
        while (_adminDetailReads.length > 8) {
          final victim = _adminDetailReads.keys.firstWhere((k) => k != key);
          _adminDetailReads.remove(victim);
        }
        return snapshot;
      }
      if (identical(_adminDetailReads[key], future)) {
        _adminDetailReads.remove(key);
      }
    }
    throw const MobileApiException(
        code: 'order_page_changed',
        message: 'Buyurtma yangilandi. Qayta oching.');
  }

  void _installAdminDetailAuthority(AdminApparatusQueueSnapshot snapshot) {
    // This full, scoped detail never replaces a summary wire baseline.
    _canonicalQueueSnapshot = snapshot;
    _sheetQueueSnapshot.value = snapshot;
    for (final e in snapshot.queueActionControls.entries) {
      _queueActionControlsByApparatus
          .putIfAbsent(e.key, () => {})
          .addAll(e.value);
    }
    for (final e in snapshot.queueStates.entries) {
      _queueStatesByApparatus.putIfAbsent(e.key, () => {}).addAll(e.value);
    }
    for (final order in snapshot.maps) {
      final id = order.map.id;
      _orderControlsByOrderId.remove(id);
      _stageOrderControls.removeWhere((c) => c.orderId == id);
      _earlyClosingOrderIds.remove(id);
    }
    _orderControlsByOrderId.addAll(snapshot.orderControls);
    _stageOrderControls.addAll(snapshot.stageOrderControls);
    _earlyClosingOrderIds.addAll(snapshot.earlyClosingOrderIds);
    _stageStatesByOrderId.addAll(snapshot.stageStates);
  }

  void _openAdminSequenceDetail(
      {required AdminApparatus apparatus, required ProductionMapSaved order}) {
    if (!_adminPaging || !_adminSequenceRows.containsKey(order.map.id)) {
      _showWatchOrderDetail(apparatus: apparatus, order: order);
      return;
    }
    if (_adminDetailOpening) return;
    _adminDetailOpening = true;
    try {
      _showWatchOrderDetail(
          apparatus: apparatus,
          order: order,
          initialPreview: _adminSequenceRows[order.map.id],
          initialControlConfirmed: true);
    } catch (_) {
      _adminDetailOpening = false;
      rethrow;
    }
  }

  Future<void> _openAdminSequenceActions(
          AdminApparatus apparatus, ProductionMapSaved order) =>
      _hydrateAdminSequence(apparatus, order, actions: true);

  Future<void> _hydrateAdminSequence(
      AdminApparatus apparatus, ProductionMapSaved order,
      {required bool actions}) async {
    if (_adminDetailOpening) return;
    _adminDetailOpening = true;
    try {
      final snapshot = await _readAdminSequenceDetail(apparatus, order.map.id);
      if (!mounted || snapshot == null) return;
      _installAdminDetailAuthority(snapshot);
      if (actions) {
        await _showOrderActions(snapshot.maps.single,
            apparatus: apparatus, hydrated: true);
      } else {
        _showWatchOrderDetail(
            apparatus: apparatus,
            order: snapshot.maps.single,
            initialQueueSnapshot: snapshot,
            initialControlConfirmed: true);
      }
    } catch (error) {
      if (mounted) {
        showAdminTopNotice(
            context,
            error is MobileApiException
                ? error.message
                : context.l10n.adminText('production.open_failed'),
            icon: Icons.warning_amber_rounded,
            tone: AdminTopNoticeTone.error);
      }
    } finally {
      _adminDetailOpening = false;
    }
  }
}
