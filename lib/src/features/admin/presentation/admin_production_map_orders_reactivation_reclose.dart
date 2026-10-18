part of 'admin_production_map_orders_screen.dart';

extension _AdminProductionMapOrdersReclose
    on _AdminProductionMapOrdersScreenState {
  AdminReactivationRecloseControl? _workerRecloseControl(
      AdminApparatus apparatus,
      ProductionMapSaved order,
      AdminApparatusQueueOrderActionControl? control) {
    if (!widget.workerMode ||
        order.map.id.startsWith('training-') ||
        _queueSnapshotNeedsReconcile ||
        _queueSnapshotContractError ||
        control?.state != 'paused' ||
        (_orderControlsByOrderId[order.map.id] ??
                AdminOrderControlState.active) !=
            AdminOrderControlState.active ||
        control?.isConsistentWith(
              _orderControlsByOrderId[order.map.id] ??
                  AdminOrderControlState.active,
              queueState: _queueStatesForApparatus(apparatus,
                  queueStatesByApparatus:
                      _queueStatesByApparatus)[order.map.id],
            ) !=
            true ||
        control?.reclose?.stageNodeId != control?.stageNodeId ||
        control?.reclose?.belongsTo(AppSession.instance.profile) != true) {
      return null;
    }
    return control!.reclose;
  }

  Future<void> _runWorkerReclose(
      AdminApparatus apparatus,
      ProductionMapSaved order,
      AdminReactivationRecloseControl checkpoint) async {
    final apparatusId = apparatus.id.trim();
    final orderId = order.map.id.trim();
    final key = '$apparatusId|$orderId';
    if (!_beginQueueAction(key)) return;
    final scope = currentSessionReadScope();
    var success = false;
    try {
      await MobileApi.instance.adminRecloseReactivatedWork(
          apparatus: apparatusId, orderId: orderId, control: checkpoint);
      success = true;
    } catch (_) {
      // A timeout may follow a committed write. Reconcile with reads only.
    } finally {
      try {
        if (mounted && scope == currentSessionReadScope()) {
          setState(() {
            _queueSnapshotNeedsReconcile = true;
            _queueSnapshotGeneration++;
            // Snapshot maps are immutable; invalidate only the local copy.
            _queueActionControlsByApparatus[apparatusId] =
                Map<String, AdminApparatusQueueOrderActionControl>.from(
                    _queueActionControlsByApparatus[apparatusId] ?? const {})
                  ..remove(orderId);
          });
          _sheetQueueSnapshot.value = null;
          showAdminTopNotice(
              context,
              context.l10n.productionText(
                  success ? 'worker.reclose.success' : 'worker.reclose.failed'),
              tone: success
                  ? AdminTopNoticeTone.success
                  : AdminTopNoticeTone.error);
          unawaited(_refreshQueueSnapshot());
          unawaited(_refreshWorkerCompletedOrders());
        }
      } finally {
        _endQueueAction(key);
      }
    }
  }
}

class _WorkerRecloseButton extends StatelessWidget {
  const _WorkerRecloseButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          key: const ValueKey('worker-reclose'),
          onPressed: onPressed,
          icon: const Icon(Icons.check_circle_outline),
          label: Text(context.l10n.productionText('worker.reclose.action')),
        ),
      );
}
