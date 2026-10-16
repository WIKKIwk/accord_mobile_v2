part of 'admin_production_map_orders_screen.dart';

extension _AdminProductionMapOrdersRePause
    on _AdminProductionMapOrdersScreenState {
  AdminResumePauseControl? _workerRePauseControl(
      AdminApparatus apparatus,
      ProductionMapSaved order,
      AdminApparatusQueueOrderActionControl? control) {
    if (!widget.workerMode ||
        order.map.id.startsWith('training-') ||
        _queueSnapshotNeedsReconcile ||
        _queueSnapshotContractError ||
        control?.state != 'in_progress' ||
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
        control?.rePause?.belongsTo(AppSession.instance.profile) != true) {
      return null;
    }
    return control!.rePause;
  }

  Future<void> _runWorkerRePause(AdminApparatus apparatus,
      ProductionMapSaved order, AdminResumePauseControl checkpoint) async {
    final key = '${apparatus.id.trim()}|${order.map.id.trim()}';
    if (!_beginQueueAction(key)) return;
    final scope = currentSessionReadScope();
    var success = false;
    try {
      await MobileApi.instance.adminRePauseResumedWork(
          apparatus: apparatus.id,
          orderId: order.map.id,
          resumeId: checkpoint.resumeId);
      success = true;
    } catch (_) {
      // A timeout may follow a committed write. Reconcile with reads only.
    } finally {
      if (mounted && scope == currentSessionReadScope()) {
        setState(() {
          _queueSnapshotNeedsReconcile = true;
          _queueSnapshotGeneration++;
          _queueActionControlsByApparatus[apparatus.id]?.remove(order.map.id);
        });
        _sheetQueueSnapshot.value = null;
        showAdminTopNotice(
            context,
            context.l10n.productionText(
                success ? 'worker.re_pause.success' : 'worker.re_pause.failed'),
            tone: success
                ? AdminTopNoticeTone.success
                : AdminTopNoticeTone.error);
        unawaited(_refreshQueueSnapshot());
      }
      _endQueueAction(key);
    }
  }
}

class _WorkerRePauseButton extends StatelessWidget {
  const _WorkerRePauseButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          key: const ValueKey('worker-re-pause'),
          onPressed: onPressed,
          icon: const Icon(Icons.pause_circle_outline),
          label: Text(context.l10n.productionText('worker.re_pause.action')),
        ),
      );
}
