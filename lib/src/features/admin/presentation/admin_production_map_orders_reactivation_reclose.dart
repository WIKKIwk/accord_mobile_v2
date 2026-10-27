part of 'admin_production_map_orders_screen.dart';

AdminReactivationRecloseControl? _unstartedWorkerRecloseControl({
  required ProductionMapSaved order,
  required String apparatusId,
  required bool canManageQueue,
  required AdminApparatusQueueOrderActionControl? control,
  required AdminOrderControlState orderControlState,
  required String? queueState,
}) {
  final profile = AppSession.instance.profile;
  if (!canManageQueue ||
      order.map.id.startsWith('training-') ||
      profile?.assignedApparatus.any((id) => id.trim() == apparatusId) != true ||
      control?.state != 'paused' ||
      orderControlState != AdminOrderControlState.active ||
      control?.isConsistentWith(orderControlState, queueState: queueState) !=
          true ||
      control?.reclose?.stageNodeId != control?.stageNodeId ||
      control?.reclose?.belongsTo(profile) != true) {
    return null;
  }
  return control!.reclose;
}

extension _AdminProductionMapOrdersReclose
    on _AdminProductionMapOrdersScreenState {
  AdminReactivationRecloseControl? _workerRecloseControl(
      AdminApparatus apparatus,
      ProductionMapSaved order,
      AdminApparatusQueueOrderActionControl? control) {
    if (!widget.workerMode ||
        _queueSnapshotNeedsReconcile ||
        _queueSnapshotContractError) {
      return null;
    }
    return _unstartedWorkerRecloseControl(
      order: order,
      apparatusId: apparatus.id.trim(),
      canManageQueue: true,
      control: control,
      orderControlState: _orderControlsByOrderId[order.map.id] ??
          AdminOrderControlState.active,
      queueState: _queueStatesForApparatus(apparatus,
          queueStatesByApparatus: _queueStatesByApparatus)[order.map.id],
    );
  }

  Future<bool> _runWorkerReclose(
      AdminApparatus apparatus,
      ProductionMapSaved order,
      AdminReactivationRecloseControl checkpoint) async {
    final apparatusId = apparatus.id.trim();
    final orderId = order.map.id.trim();
    final key = '$apparatusId|$orderId';
    if (!_beginQueueAction(key)) return false;
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
    return success;
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
