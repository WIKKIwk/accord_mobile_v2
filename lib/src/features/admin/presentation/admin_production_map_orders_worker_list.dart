part of 'admin_production_map_orders_screen.dart';

extension _WorkerCompactOrders on _AdminProductionMapOrdersScreenState {
  List<ProductionMapSaved> _ordersInQueueSnapshot(
          AdminApparatusQueueSnapshot snapshot) =>
      _productionMapZakazOrders(widget.workerMode && snapshot.isWorkerList
          ? snapshot.workerListRows.values
              .map((row) => row.toPresentationOrder())
              .toList(growable: false)
          : snapshot.maps);

  Future<AdminApparatusQueueSnapshot?> _readWorkerListDetail(
      AdminApparatus apparatus, String orderId) async {
    final scope = currentSessionReadScope();
    final account = _adminPageAccount;
    final generation = _workerQueueWindowGeneration;
    final key = jsonEncode([account, 'worker-detail', apparatus.id, orderId]);
    final loader = widget.orderDetailLoader ??
        MobileApi.instance.workerProductionOrderDetail;
    for (var attempt = 0; attempt < 2; attempt++) {
      // Only unfinished reads are shared across reopen/actions. A completed
      // read must not certify a new action after an intervening queue event.
      if (!_adminPendingDetailReads.contains(key)) {
        _adminDetailReads.remove(key);
      }
      final future = _adminDetailReads.putIfAbsent(key, () {
        _adminPendingDetailReads.add(key);
        return Future<AdminApparatusQueueSnapshot>.sync(
                () => loader(apparatus: apparatus.id, orderId: orderId))
            .whenComplete(() => _adminPendingDetailReads.remove(key));
      });
      AdminApparatusQueueSnapshot detail;
      try {
        detail = await future;
      } catch (_) {
        if (identical(_adminDetailReads[key], future)) {
          _adminDetailReads.remove(key);
        }
        rethrow;
      }
      if (!mounted ||
          scope != currentSessionReadScope() ||
          account != _adminPageAccount ||
          generation != _workerQueueWindowGeneration) {
        return null;
      }
      final baseline = _canonicalQueueSnapshot;
      if (!detail.isWorkerList &&
          detail.maps.length == 1 &&
          detail.maps.single.map.id == orderId &&
          !isWorkerListPresentationOrder(detail.maps.single) &&
          detail.epoch.isNotEmpty &&
          detail.revision != null &&
          !_retiredSnapshotEpochs.contains(detail.epoch) &&
          (baseline == null ||
              (baseline.epoch == detail.epoch &&
                  detail.revision! >= (baseline.revision ?? -1)))) {
        while (_adminDetailReads.length > 8) {
          _adminDetailReads.remove(
              _adminDetailReads.keys.firstWhere((value) => value != key));
        }
        _workerPreparedDetail = detail;
        _workerPreparedDetailScope = scope;
        return detail;
      }
      if (identical(_adminDetailReads[key], future)) {
        _adminDetailReads.remove(key);
      }
    }
    throw const MobileApiException(
        code: 'order_page_changed',
        message: 'Buyurtma yangilandi. Qayta oching.');
  }

  Future<({double? base, double? kg})> _workerScopedDetailMetrics(
      AdminApparatusQueueSnapshot detail, ProductionMapSaved saved) {
    final templates = detail.calculationTemplates.values.toList();
    final key = jsonEncode([
      _adminPageAccount,
      'worker-metrics',
      saved.map.toJson(),
      for (final template in templates) template.toJson()
    ]);
    final future = _adminOrderDetailMetrics.putIfAbsent(
        key,
        () async => (
              base:
                  await _productionMapBaseMetrajForOrder(saved.map, templates),
              kg: _productionMapOrderKg(saved.map, templates),
            ));
    while (_adminOrderDetailMetrics.length > 8) {
      _adminOrderDetailMetrics.remove(
          _adminOrderDetailMetrics.keys.firstWhere((value) => value != key));
    }
    return future;
  }

  void _installWorkerDetailControls(AdminApparatusQueueSnapshot snapshot) {
    // Full detail authority is separate from the compact list/cache baseline.
    for (final entry in snapshot.queueActionControls.entries) {
      _queueActionControlsByApparatus[entry.key] = {
        ...?_queueActionControlsByApparatus[entry.key],
        ...entry.value,
      };
    }
    for (final entry in snapshot.queueStates.entries) {
      _queueStatesByApparatus[entry.key] = {
        ...?_queueStatesByApparatus[entry.key],
        ...entry.value,
      };
    }
    for (final order in snapshot.maps) {
      _orderControlsByOrderId.remove(order.map.id);
    }
    _orderControlsByOrderId.addAll(snapshot.orderControls);
    _stageStatesByOrderId.addAll(snapshot.stageStates);
  }

  Future<void> _hydrateWorkerActions(
      AdminApparatus apparatus, ProductionMapSaved order) async {
    if (_adminDetailOpening) return;
    _adminDetailOpening = true;
    try {
      final detail = await _readWorkerListDetail(apparatus, order.map.id);
      if (!mounted || detail == null) return;
      _installWorkerDetailControls(detail);
      // The read guard must not suppress a later menu choice that needs a
      // fresh scoped read after a queue event arrives while the menu is open.
      _adminDetailOpening = false;
      await _showWatchOrderLongPress(
          apparatus: apparatus, order: detail.maps.single);
    } catch (error) {
      if (mounted) _showWorkerDetailError(error);
    } finally {
      _adminDetailOpening = false;
    }
  }

  void _showWorkerDetailError(Object error) {
    showAdminTopNotice(
        context,
        error is MobileApiException
            ? error.message
            : context.l10n.productionText('worker.error.sync'),
        icon: Icons.warning_amber_rounded,
        tone: AdminTopNoticeTone.error);
  }

  Future<void> _hydrateWorkerHistory(_WorkerCompletedOrderEntry entry,
      {bool reactivate = false}) async {
    final apparatus = entry.apparatus;
    if (apparatus == null || _adminDetailOpening) return;
    _adminDetailOpening = true;
    try {
      final detail = await _readWorkerListDetail(apparatus, entry.order.map.id);
      if (!mounted || detail == null) return;
      final full = _WorkerCompletedOrderEntry(
          order: detail.maps.single,
          apparatus: apparatus,
          apparatusId: entry.apparatusId,
          status: entry.status,
          issueNote: entry.issueNote);
      if (reactivate) {
        await _showCompletedOrderReactivation(full);
      } else {
        _showCompletedOrderDetail(full);
      }
    } catch (error) {
      if (mounted) _showWorkerDetailError(error);
    } finally {
      _adminDetailOpening = false;
    }
  }

  Future<void> _showCompactStageAstatkaPrompt() async {
    final snapshot = _canonicalQueueSnapshot;
    if (snapshot == null || !snapshot.isWorkerList) return;
    final scope = currentSessionReadScope();
    for (final apparatus in _apparatus) {
      if (!_isAssignedWatchApparatus(apparatus,
          assignedApparatus: AppSession.instance.profile?.assignedApparatus ??
              const <String>[])) {
        continue;
      }
      for (final entry
          in (snapshot.workerReportPrompts[apparatus.id] ?? const {}).entries) {
        final row = snapshot.workerListRows[entry.key];
        if (row == null || _isWorkerOrderFrozen(entry.key)) continue;
        final prompt = entry.value;
        final key = '${entry.key}:${apparatus.id}:${prompt.reportSessionId}';
        if (!_shownStageAstatkaSessions.add(key)) continue;
        _stageAstatkaPromptOpen = true;
        try {
          final confirmed = await showM3ConfirmDialog(
                  context: context,
                  title:
                      context.l10n.productionText('worker.stage.astatka.title'),
                  message: context.l10n.productionText(
                      'worker.stage.astatka.upstream_closed',
                      values: {
                        'source': prompt.upstreamTitle,
                        'target': apparatus.name,
                        'order': row.title
                      }),
                  cancelLabel:
                      context.l10n.productionText('worker.stage.astatka.later'),
                  confirmLabel: context.l10n
                      .productionText('worker.stage.astatka.submit')) ??
              false;
          if (!mounted || scope != currentSessionReadScope()) return;
          final current = _canonicalQueueSnapshot
              ?.workerReportPrompts[apparatus.id]?[entry.key];
          if (confirmed && current?.reportSessionId == prompt.reportSessionId) {
            _showWatchOrderDetail(
                apparatus: apparatus,
                order: row.toPresentationOrder(),
                expectedReportSessionId: prompt.reportSessionId,
                startAstatkaOnOpen: true);
          }
        } finally {
          _stageAstatkaPromptOpen = false;
        }
        return;
      }
    }
  }
}
