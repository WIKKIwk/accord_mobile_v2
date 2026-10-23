part of 'admin_production_map_orders_screen.dart';

List<_OrderWatermarkData> _summaryOrderWatermarks(AdminOrderListRow row,
        List<AdminApparatus> catalog, AppLocalizations l10n) =>
    [
      for (final mark in row.watermarks)
        _OrderWatermarkData(
            label: mark.kind == 'active'
                ? _canonicalApparatusWatermarkLabel(mark.apparatusId,
                    apparatusCatalog: catalog)
                : l10n.adminText(
                    mark.kind == 'waiting' && mark.apparatusId.isEmpty
                        ? 'orders.watermark.waiting_generic'
                        : 'orders.watermark.${mark.kind}',
                    values: mark.apparatusId.isEmpty
                        ? const {}
                        : {
                            'apparatus': _canonicalApparatusWatermarkLabel(
                                mark.apparatusId,
                                apparatusCatalog: catalog)
                          })),
    ];

extension _AdminOrdersListDetails on _AdminProductionMapOrdersScreenState {
  Map<String, AdminOrderListRow> get _adminOrdersRows =>
      !_adminPaging || _module != _OpenedOrderModule.orders
          ? const {}
          : {
              for (final page in _adminWindow('orders').pages) ...page.orderRows
            };
  Map<String, AdminPendingOrderListRow> get _adminPendingRows =>
      !_adminPaging || _module != _OpenedOrderModule.orders
          ? const {}
          : {
              for (final page in _adminWindow('orders').pages)
                for (final id in page.pendingIds) id: page.pendingRows[id]!
            };

  Future<AdminApparatusQueueSnapshot?> _readOrdersListDetail(String id) async {
    final account = _adminPageAccount;
    final readScope = currentSessionReadScope();
    final window = _adminWindow('orders');
    final loader = widget.orderDetailLoader ??
        MobileApi.instance.adminProductionOrderDetail;
    final key = jsonEncode([account, 'orders', id]);
    for (var attempt = 0; attempt < 2; attempt++) {
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
                () => loader(apparatus: '', orderId: id))
            .whenComplete(() => _adminPendingDetailReads.remove(key));
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
          _module != _OpenedOrderModule.orders ||
          account != _adminPageAccount ||
          readScope != currentSessionReadScope() ||
          window.request.search != _adminPageSearch ||
          !window.pages.any((page) => page.orderRows.containsKey(id))) {
        return null;
      }
      final page = window.pages.first;
      if (snapshot.epoch == page.epoch &&
          !_retiredSnapshotEpochs.contains(snapshot.epoch) &&
          snapshot.revision != null &&
          snapshot.revision! >= page.revision! &&
          snapshot.scope.isNotEmpty &&
          snapshot.maps.length == 1 &&
          snapshot.maps.single.map.id == id) {
        while (_adminDetailReads.length > 8) {
          _adminDetailReads
              .remove(_adminDetailReads.keys.firstWhere((k) => k != key));
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

  Future<void> _showOrdersListDetail(ProductionMapSaved order) async {
    if (_adminDetailOpening) return;
    _adminDetailOpening = true;
    final id = order.map.id;
    final row = _adminOrdersRows[id]!;
    final account = _adminPageAccount;
    final search = _adminPageSearch;
    final scope = currentSessionReadScope();
    bool current() =>
        mounted &&
        _module == _OpenedOrderModule.orders &&
        account == _adminPageAccount &&
        search == _adminPageSearch &&
        scope == currentSessionReadScope();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: false,
        enableDrag: false,
        shape: _orderDetailSheetShape,
        clipBehavior: Clip.antiAlias,
        sheetAnimationStyle: AppMotion.sheetEaseOut,
        builder: (_) => _AdminInitialDetailHost(
            isCurrent: current,
            load: () => _readOrdersListDetail(id),
            onReady: _installAdminDetailAuthority,
            builder: (snapshot, error, retry) => _AdminHydratedDetailHost(
                  initialSnapshot: snapshot,
                  isCurrent: current,
                  currentCursor: () {
                    final pages = _adminWindow('orders').pages;
                    if (!pages.any((p) => p.orderRows.containsKey(id))) {
                      return null;
                    }
                    return (
                      epoch: pages.first.epoch,
                      revision: pages.first.revision!
                    );
                  },
                  load: () => _readOrdersListDetail(id),
                    builder: (detail, authority, _) {
                    final saved = detail?.maps.single ?? order;
                    final templates =
                        detail?.calculationTemplates.values.toList() ??
                            const <CalculateOrderTemplate>[];
                    Future<({double? base, double? kg})>? metrics;
                    if (detail != null) {
                      final key = jsonEncode([
                        account,
                        saved.map.toJson(),
                        for (final template in templates) template.toJson()
                      ]);
                      metrics = _adminOrderDetailMetrics.putIfAbsent(
                          key,
                          () async => (
                                base: await _productionMapBaseMetrajForOrder(
                                    saved.map, templates),
                                kg: _productionMapOrderKg(saved.map, templates)
                              ));
                      while (_adminOrderDetailMetrics.length > 8) {
                        _adminOrderDetailMetrics.remove(_adminOrderDetailMetrics
                            .keys
                            .firstWhere((k) => k != key));
                      }
                    }
                    return FutureBuilder<({double? base, double? kg})>(
                        future: metrics,
                        builder: (context, result) => _ReadOnlyOrderDetailSheet(
                              order: saved,
                              detailPending: detail == null,
                              detailError: error,
                              onRetryDetail: retry,
                              initialControlConfirmed: true,
                              currentQueueSnapshot: () => authority.value,
                              queueSnapshotListenable: authority,
                              apparatusCatalog: _apparatus,
                              baseMetraj:
                                  result.data?.base ?? saved.map.baseLength,
                              orderKg: result.data?.kg ??
                                  _productionMapOrderKg(saved.map, templates),
                              customerName: detail == null
                                  ? row.customerName
                                  : detail.orderCustomers[id] ??
                                      saved.map.customerName,
                              queueStatesByApparatus:
                                  detail?.queueStates ?? const {},
                              stageStatesByOrderId:
                                  detail?.stageStates ?? const {},
                              queueActionControlsByApparatus:
                                  detail?.queueActionControls ?? const {},
                              initialOrderControls:
                                  detail?.orderControls ?? const {},
                              progressDriverUrlPicker:
                                  widget.progressDriverUrlPicker,
                              allowWipQrReprint: !widget.supplyViewerMode,
                            ));
                  },
                )),
      );
    } finally {
      _adminDetailOpening = false;
    }
  }

  Future<void> _openOrdersListActions(ProductionMapSaved order) async {
    if (_adminDetailOpening) return;
    _adminDetailOpening = true;
    try {
      final snapshot = await _readOrdersListDetail(order.map.id);
      if (!mounted || snapshot == null) return;
      _installAdminDetailAuthority(snapshot);
      await _showOrderActions(snapshot.maps.single, hydrated: true);
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

  Future<void> _showPendingOrderRow(AdminPendingOrderListRow row) async {
    if (_adminDetailOpening) return;
    _adminDetailOpening = true;
    final scope = currentSessionReadScope();
    final account = _adminPageAccount;
    final search = _adminPageSearch;
    try {
      final order = await MobileApi.instance.pendingOrderDetail(row.id);
      if (!mounted ||
          account != _adminPageAccount ||
          search != _adminPageSearch ||
          scope != currentSessionReadScope() ||
          !_adminPendingRows.containsKey(row.id)) {
        return;
      }
      await _showPendingOrder(order);
    } catch (error) {
      if (mounted && scope == currentSessionReadScope()) {
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
