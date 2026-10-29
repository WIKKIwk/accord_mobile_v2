part of 'admin_production_map_orders_screen.dart';

extension _AdminProductionMapOrdersCancelStart
    on _AdminProductionMapOrdersScreenState {
  AdminCancelStartControl? _workerCancelStartControl(
      AdminApparatus apparatus,
      ProductionMapSaved order,
      AdminApparatusQueueOrderActionControl? control) {
    final profile = AppSession.instance.profile;
    final synchronized = !_queueSnapshotContractError &&
        _snapshotReadScope == currentSessionReadScope() &&
        (!_queueSnapshotNeedsReconcile ||
            _hasFreshWorkerTemporaryPauseDetail(apparatus, order, control));
    if (!widget.workerMode ||
        !synchronized ||
        !(apparatus.usesLaminationWorkflow || apparatus.operation == 'cut') ||
        profile?.role != UserRole.aparatchi ||
        !AppSession.instance.can('apparatus.queue.manage') ||
        !_isAssignedWatchApparatus(apparatus,
            assignedApparatus: profile!.assignedApparatus) ||
        order.map.id.startsWith('training-') ||
        control?.state != 'in_progress' ||
        control?.cancelStart?.workerRef != profile.ref ||
        control?.isConsistentWith(
                _orderControlsByOrderId[order.map.id] ??
                    AdminOrderControlState.active,
                queueState: _queueStatesForApparatus(apparatus,
                    queueStatesByApparatus:
                        _queueStatesByApparatus)[order.map.id]) !=
            true) {
      return null;
    }
    return control!.cancelStart;
  }

  Future<void> _runWorkerCancelStart(AdminApparatus apparatus,
      ProductionMapSaved order, AdminCancelStartControl control) async {
    final machine = apparatus.id.trim();
    final orderId = order.map.id.trim();
    final key = '$machine|$orderId';
    if (!_beginQueueAction(key)) {
      return;
    }
    final scope = currentSessionReadScope();
    var attempted = false, success = false;
    var generation = _queueSnapshotGeneration;
    try {
      final confirmed = await showM3ConfirmDialog(
          context: context,
          title: context.l10n.productionText('worker.cancel_start.title'),
          message: context.l10n.productionText('worker.cancel_start.message'),
          cancelLabel: context.l10n.productionText('worker.cancel_start.back'),
          confirmLabel:
              context.l10n.productionText('worker.cancel_start.confirm'),
          verticalActions: true,
          confirmButtonKey: const ValueKey('worker-cancel-start-confirm'),
          cancelButtonKey: const ValueKey('worker-cancel-start-back'));
      if (confirmed != true || !mounted || scope != currentSessionReadScope()) {
        return;
      }
      final current = _workerCancelStartControl(
          apparatus,
          order,
          _queueActionControlForApparatus(
              apparatus: apparatus, orderId: orderId));
      if (current?.token != control.token ||
          current?.sessionId != control.sessionId) {
        return;
      }
      generation = _queueSnapshotGeneration;
      attempted = true;
      await MobileApi.instance.adminCancelStartedWork(
          apparatus: machine, orderId: orderId, control: control);
      success = true;
    } catch (_) {
      // An uncertain response may follow a commit. Reconcile the authoritative
      // state; never issue a second action or invent a successful rollback.
    } finally {
      if (attempted && mounted && scope == currentSessionReadScope()) {
        // This extension belongs to the State's own library.
        // ignore: invalid_use_of_protected_member
        setState(() {
          if (success && generation == _queueSnapshotGeneration) {
            _queueStatesByApparatus[machine] = Map<String, String>.from(
                _queueStatesByApparatus[machine] ?? const {})
              ..[orderId] = control.previousState;
          }
          _queueSnapshotNeedsReconcile = true;
          _queueSnapshotGeneration++;
          _queueActionControlsByApparatus[machine] =
              Map<String, AdminApparatusQueueOrderActionControl>.from(
                  _queueActionControlsByApparatus[machine] ?? const {})
                ..remove(orderId);
        });
        _sheetQueueSnapshot.value = null;
        showAdminTopNotice(
            context,
            context.l10n.productionText(success
                ? 'worker.cancel_start.success'
                : 'worker.cancel_start.failed'),
            tone: success
                ? AdminTopNoticeTone.success
                : AdminTopNoticeTone.error);
        unawaited(_refreshQueueSnapshot());
      }
      _endQueueAction(key);
    }
  }
}

class _WorkerCancelStartButton extends StatelessWidget {
  const _WorkerCancelStartButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
          key: const ValueKey('worker-cancel-start'),
          onPressed: onPressed,
          icon: const Icon(Icons.undo_rounded),
          label:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.l10n.productionText('worker.cancel_start.action')),
            Text(context.l10n.productionText('worker.cancel_start.subtitle'),
                style: Theme.of(context).textTheme.bodySmall),
          ])));
}
