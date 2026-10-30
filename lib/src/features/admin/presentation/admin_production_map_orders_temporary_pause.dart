part of 'admin_production_map_orders_screen.dart';

AdminTemporaryPauseControl? _eligibleWorkerTemporaryPause({
  required bool workerMode,
  required bool synchronized,
  required AdminApparatus? apparatus,
  required ProductionMapSaved order,
  required AdminApparatusQueueOrderActionControl? control,
  required AdminOrderControlState orderControl,
  required String? queueState,
}) {
  final profile = AppSession.instance.profile;
  if (!workerMode ||
      !synchronized ||
      apparatus == null ||
      profile?.role != UserRole.aparatchi ||
      !AppSession.instance.can('apparatus.queue.manage') ||
      !_isAssignedWatchApparatus(apparatus,
          assignedApparatus: profile!.assignedApparatus) ||
      order.map.id.startsWith('training-') ||
      orderControl != AdminOrderControlState.active ||
      control?.state != 'in_progress' ||
      control?.isConsistentWith(orderControl, queueState: queueState) != true) {
    return null;
  }
  return control!.temporaryPause;
}

extension _AdminProductionMapOrdersTemporaryPause
    on _AdminProductionMapOrdersScreenState {
  AdminTemporaryPauseControl? _workerTemporaryPauseControl(
    AdminApparatus apparatus,
    ProductionMapSaved order,
    AdminApparatusQueueOrderActionControl? control,
  ) =>
      _eligibleWorkerTemporaryPause(
        workerMode: widget.workerMode,
        synchronized: !_queueSnapshotContractError &&
            _snapshotReadScope == currentSessionReadScope() &&
            (!_queueSnapshotNeedsReconcile ||
                _hasFreshWorkerTemporaryPauseDetail(apparatus, order, control)),
        apparatus: apparatus,
        order: order,
        control: control,
        orderControl: _orderControlsByOrderId[order.map.id] ??
            AdminOrderControlState.active,
        queueState: _queueStatesForApparatus(apparatus,
            queueStatesByApparatus: _queueStatesByApparatus)[order.map.id],
      );

  Future<bool> _runWorkerTemporaryPause(
    AdminApparatus apparatus,
    ProductionMapSaved order,
    AdminTemporaryPauseControl control,
  ) async {
    final apparatusId = apparatus.id.trim();
    final orderId = order.map.id.trim();
    final key = '$apparatusId|$orderId';
    if (!_beginQueueAction(key)) return false;
    final scope = currentSessionReadScope();
    final snapshotGeneration = _queueSnapshotGeneration;
    var success = false;
    try {
      await MobileApi.instance.adminTemporarilyPauseWork(
          apparatus: apparatusId, orderId: orderId, control: control);
      success = true;
    } catch (_) {
      // An uncertain response can follow a committed pause. Refresh only;
      // never replay the write or fall back to producing an output roll.
    } finally {
      try {
        if (mounted && scope == currentSessionReadScope()) {
          setState(() {
            if (success && snapshotGeneration == _queueSnapshotGeneration) {
              // The committed pause is already acknowledged. Paint it without
              // waiting for the canonical background read; permissions still
              // come exclusively from that read. A newer live state wins.
              _queueStatesByApparatus[apparatusId] =
                  Map<String, String>.from(
                      _queueStatesByApparatus[apparatusId] ?? const {})
                    ..[orderId] = 'paused';
            }
            _queueSnapshotNeedsReconcile = true;
            _queueSnapshotGeneration++;
            _queueActionControlsByApparatus[apparatusId] =
                Map<String, AdminApparatusQueueOrderActionControl>.from(
                    _queueActionControlsByApparatus[apparatusId] ?? const {})
                  ..remove(orderId);
          });
          _sheetQueueSnapshot.value = null;
          showAdminTopNotice(
            context,
            context.l10n.productionText(success
                ? 'worker.temporary_pause.success'
                : 'worker.temporary_pause.failed'),
            tone:
                success ? AdminTopNoticeTone.success : AdminTopNoticeTone.error,
          );
          unawaited(_refreshQueueSnapshot());
        }
      } finally {
        _endQueueAction(key);
      }
    }
    return success && mounted && scope == currentSessionReadScope();
  }
}

class _WorkerTemporaryPauseButton extends StatelessWidget {
  const _WorkerTemporaryPauseButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton.icon(
          key: const ValueKey('worker-temporary-pause'),
          onPressed: onPressed,
          icon: const Icon(Icons.pause_circle_outline),
          label: Text(
              context.l10n.productionText('worker.temporary_pause.action')),
        ),
      );
}

enum _WorkerOrderSwitchChoice { temporaryPause, complete }

class _WorkerTemporaryPauseSwitchSheet extends StatelessWidget {
  const _WorkerTemporaryPauseSwitchSheet({
    required this.canComplete,
    required this.apparatusLabel,
    required this.orderLabel,
  });
  final bool canComplete;
  final String apparatusLabel;
  final String orderLabel;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.l10n.productionText('worker.order.switch.title'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                context.l10n.productionText(
                  'worker.order.switch.current_order',
                  values: {'apparatus': apparatusLabel, 'order': orderLabel},
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(context.l10n
                  .productionText('worker.temporary_pause.switch_description')),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const ValueKey('production-switch-order-temporary-pause'),
                onPressed: () => Navigator.of(context)
                    .pop(_WorkerOrderSwitchChoice.temporaryPause),
                icon: const Icon(Icons.pause_circle_outline),
                label: Text(context.l10n
                    .productionText('worker.temporary_pause.action')),
              ),
              if (canComplete) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const ValueKey('production-switch-order-complete'),
                  onPressed: () => Navigator.of(context)
                      .pop(_WorkerOrderSwitchChoice.complete),
                  child: Text(context.l10n.productionText(
                      'worker.temporary_pause.switch_complete')),
                ),
              ],
            ],
          ),
        ),
      );
}
