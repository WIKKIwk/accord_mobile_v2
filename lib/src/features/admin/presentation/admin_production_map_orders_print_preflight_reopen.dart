part of 'admin_production_map_orders_screen.dart';

extension _AdminProductionMapOrdersPrintPreflightReopen
    on _AdminProductionMapOrdersScreenState {
  AdminPrintPreflightHold? _reopenablePrintPreflight(
    AdminApparatus apparatus,
    ProductionMapSaved order,
  ) {
    final orderId = order.map.id.trim();
    final orderControl =
        _orderControlsByOrderId[orderId] ?? AdminOrderControlState.active;
    if (_queueSnapshotNeedsReconcile ||
        _queueSnapshotContractError ||
        _queueActionsInFlight.contains('${apparatus.id.trim()}|$orderId') ||
        orderId.startsWith('training-') ||
        apparatus.operation.trim().toLowerCase() != 'print' ||
        orderControl != AdminOrderControlState.active ||
        _earlyClosingOrderIds.contains(orderId) ||
        widget.supplyViewerMode ||
        (!widget.workerMode && widget.readOnly) ||
        !const [
          'admin.access',
          'production.map.manage',
          'apparatus.queue.manage'
        ].any(AppSession.instance.can) ||
        (widget.workerMode &&
            !_isAssignedWatchApparatus(apparatus,
                assignedApparatus:
                    AppSession.instance.profile?.assignedApparatus ??
                        const []))) {
      return null;
    }
    final control =
        _queueActionControlForApparatus(apparatus: apparatus, orderId: orderId);
    final queueState = _queueStatesForApparatus(apparatus,
        queueStatesByApparatus: _queueStatesByApparatus)[orderId];
    final hold = control?.printPreflight;
    if (control?.state != 'print_preflight' ||
        control?.isConsistentWith(orderControl, queueState: queueState) !=
            true ||
        hold?.isPassed != true ||
        hold?.orderId != orderId ||
        hold?.apparatus != apparatus.id.trim()) {
      return null;
    }
    return hold;
  }

  AdminApparatus? _printPreflightReopenApparatus(ProductionMapSaved order) {
    final selected = _selectedApparatus;
    if (selected != null &&
        _reopenablePrintPreflight(selected, order) != null) {
      return selected;
    }
    final candidates = _apparatus
        .where(
            (apparatus) => _reopenablePrintPreflight(apparatus, order) != null)
        .toList(growable: false);
    return candidates.length == 1 ? candidates.single : null;
  }

  Future<void> _showPrintPreflightReopenActions(
    AdminApparatus apparatus,
    ProductionMapSaved order,
  ) async {
    final chosen = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PrintPreflightReopenTile(
            onTap: () => Navigator.pop(sheetContext, true),
          ),
        ],
      ),
    );
    if (mounted && chosen == true) {
      await _confirmPrintPreflightReopen(apparatus, order);
    }
  }

  Future<void> _confirmPrintPreflightReopen(
    AdminApparatus apparatus,
    ProductionMapSaved order,
  ) async {
    final hold = _reopenablePrintPreflight(apparatus, order);
    if (hold == null) return;
    final scope = currentSessionReadScope();
    final confirmed = await showM3ConfirmDialog(
      context: context,
      title:
          context.l10n.productionText('worker.print_preflight.reopen.action'),
      message:
          context.l10n.productionText('worker.print_preflight.reopen.message'),
      cancelLabel:
          context.l10n.productionText('worker.print_preflight.reopen.cancel'),
      confirmLabel:
          context.l10n.productionText('worker.print_preflight.reopen.confirm'),
      confirmButtonKey: const ValueKey('print-preflight-reopen-confirm'),
      cancelButtonKey: const ValueKey('print-preflight-reopen-cancel'),
    );
    if (!mounted || confirmed != true || scope != currentSessionReadScope()) {
      return;
    }
    if (_reopenablePrintPreflight(apparatus, order)?.holdId != hold.holdId) {
      unawaited(_refreshQueueSnapshot());
      return;
    }
    final key = '${apparatus.id.trim()}|${order.map.id.trim()}';
    if (!_beginQueueAction(key)) return;
    var success = false;
    try {
      final response = await MobileApi.instance
          .adminPrintPreflight(
            apparatus: apparatus.id.trim(),
            orderId: order.map.id.trim(),
            holdId: hold.holdId,
            action: 'reopen',
          )
          .timeout(const Duration(seconds: 20));
      success = response.hold.holdId == hold.holdId &&
          response.hold.orderId == hold.orderId &&
          response.hold.apparatus == hold.apparatus &&
          response.hold.isRunning;
    } catch (_) {
      // A response can be lost after commit; recover with reads only.
    } finally {
      try {
        if (mounted && scope == currentSessionReadScope()) {
          _updateScreenState(() {
            _queueSnapshotNeedsReconcile = true;
            _queueSnapshotGeneration++;
            _queueActionControlsByApparatus[apparatus.id.trim()] =
                Map<String, AdminApparatusQueueOrderActionControl>.from(
                    _queueActionControlsByApparatus[apparatus.id.trim()] ??
                        const {})
                  ..remove(order.map.id.trim());
          });
          _sheetQueueSnapshot.value = null;
          if (!success) {
            showAdminTopNotice(
                context,
                context.l10n.productionText(
                    'worker.print_preflight.reopen.unconfirmed'),
                tone: AdminTopNoticeTone.error);
          }
          await _refreshQueueSnapshot();
        }
      } finally {
        _endQueueAction(key);
      }
    }
  }
}

class _PrintPreflightReopenTile extends StatelessWidget {
  const _PrintPreflightReopenTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        key: const ValueKey('print-preflight-reopen-action'),
        leading: const Icon(Icons.colorize_rounded),
        title: Text(context.l10n
            .productionText('worker.print_preflight.reopen.action')),
        onTap: onTap,
      );
}
