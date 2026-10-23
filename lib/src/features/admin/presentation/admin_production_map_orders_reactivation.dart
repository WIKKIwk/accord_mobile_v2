part of 'admin_production_map_orders_screen.dart';

extension _AdminProductionMapOrdersReactivation
    on _AdminProductionMapOrdersScreenState {
  Future<void> _showCompletedOrderReactivation(
      _WorkerCompletedOrderEntry entry) async {
    if (isWorkerListPresentationOrder(entry.order)) {
      await _hydrateWorkerHistory(entry, reactivate: true);
      return;
    }
    final apparatus = entry.apparatus;
    if (!widget.workerMode ||
        apparatus?.operation.trim() != 'print' ||
        entry.isFrozen ||
        entry.hasFreezeIssue ||
        _isWorkerOrderFrozen(entry.order.map.id)) return;
    final key = '${apparatus!.id}|${entry.order.map.id}';
    if (!_beginQueueAction(key)) return;
    try {
      final scope = currentSessionReadScope();
      final attempted = await _showWorkerWorkReactivation(
        context: context,
        order: entry.order,
        apparatus: apparatus,
      );
      if (attempted && mounted && scope == currentSessionReadScope()) {
        _reconcileReactivatedWork();
      }
    } finally {
      _endQueueAction(key);
    }
  }

  void _reconcileReactivatedWork() {
    if (!mounted) return;
    setState(() {
      _queueSnapshotNeedsReconcile = true;
      _queueSnapshotGeneration++;
    });
    _sheetQueueSnapshot.value = null;
    unawaited(_refreshQueueSnapshot());
    unawaited(_refreshWorkerCompletedOrders());
  }
}

enum _WorkerReactivationChoice { reactivate, details }

/// Returns true only after attempting a write. Unknown write outcomes are
/// reconciled with reads by the caller; they are never automatically repeated.
Future<bool> _showWorkerWorkReactivation({
  required BuildContext context,
  required ProductionMapSaved order,
  required AdminApparatus apparatus,
  AdminProgressBatch? batch,
  Future<void> Function()? showDetails,
}) async {
  final scope = currentSessionReadScope();
  final l10n = context.l10n;
  final actionKey = batch == null
      ? 'worker.reactivate.order_action'
      : 'worker.reactivate.wip_action';
  AdminWorkReactivationPreview? preview;
  try {
    preview = await MobileApi.instance.adminWorkReactivationPreview(
      apparatus: apparatus.id,
      orderId: order.map.id,
      batchId: batch?.batchId ?? '',
    );
  } catch (_) {
    // An old server or an incomplete response must never enable this action.
  }
  if (!context.mounted || scope != currentSessionReadScope()) return false;
  final candidate = preview?.target;
  final matchingNodes = order.map.nodes
      .where((node) =>
          node.id == candidate?.stageNodeId &&
          node.kind == 'apparatus' &&
          node.apparatusId == apparatus.id)
      .toList(growable: false);
  // A stale local map cannot provide a reviewable occurrence label.
  final target = matchingNodes.length == 1 ? candidate : null;
  final reason = candidate != null && target == null
      ? 'stale_target'
      : preview == null
          ? 'unavailable'
          : preview.denialReason;
  final occurrences = productionMapLinearWorkStages(order.map)
      .where((stage) => stage.apparatusId == apparatus.id)
      .toList(growable: false);
  final occurrenceIndex =
      occurrences.indexWhere((stage) => stage.nodeId == target?.stageNodeId);
  final stageTitle = matchingNodes.length == 1
      ? '${_workerWipFirstNotEmpty([
              matchingNodes.single.title,
              apparatus.name
            ])}'
          '${occurrences.length > 1 && occurrenceIndex >= 0 ? ' (${occurrenceIndex + 1}/${occurrences.length})' : ''}'
      : '';
  final identity = [
    _workerWipFirstNotEmpty(
        [order.map.orderNumber, order.map.code, order.map.title, order.map.id]),
    apparatus.name,
    if (target != null)
      l10n.productionText('worker.reactivate.stage',
          values: {'stage': stageTitle}),
    if (batch != null)
      _workerWipFirstNotEmpty([batch.qrPayload, batch.batchId]),
  ].where((value) => value.trim().isNotEmpty).join('\n');
  final choice = await showModalBottomSheet<_WorkerReactivationChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(identity, style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (target == null) ...[
              Text(_workerReactivationDenial(l10n, reason)),
              const SizedBox(height: 16),
            ],
            FilledButton.icon(
              key: const ValueKey('worker-reactivate-completed-work'),
              onPressed: target == null
                  ? null
                  : () => Navigator.of(sheetContext)
                      .pop(_WorkerReactivationChoice.reactivate),
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(l10n.productionText(actionKey)),
            ),
            if (target == null &&
                (reason == 'final_stage_closed' || reason == 'order_closed'))
              TextButton.icon(
                key: const ValueKey('worker-reactivate-denial-details'),
                onPressed: () {
                  if (scope != currentSessionReadScope()) return;
                  unawaited(showDialog<void>(
                    context: sheetContext,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(l10n.productionText(actionKey)),
                      content: Text(_workerReactivationDenial(l10n, reason)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child:
                              Text(l10n.productionText('worker.action.close')),
                        ),
                      ],
                    ),
                  ));
                },
                icon: const Icon(Icons.info_outline),
                label: Text(
                    l10n.productionText('worker.reactivate.reason_details')),
              ),
            if (showDetails != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(sheetContext)
                    .pop(_WorkerReactivationChoice.details),
                icon: const Icon(Icons.info_outline),
                label: Text(l10n.productionText('worker.reactivate.details')),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || scope != currentSessionReadScope()) return false;
  if (choice == _WorkerReactivationChoice.details) {
    await showDetails?.call();
    return false;
  }
  if (choice != _WorkerReactivationChoice.reactivate || target == null) {
    return false;
  }
  final confirmed = await showM3ConfirmDialog(
    context: context,
    title: l10n.productionText(actionKey),
    message:
        '$identity\n\n${l10n.productionText(batch == null ? 'worker.reactivate.order_explanation' : 'worker.reactivate.wip_explanation')}',
    cancelLabel: l10n.productionText('worker.action.cancel'),
    confirmLabel: l10n.productionText('worker.reactivate.confirm'),
    confirmButtonKey: const ValueKey('worker-reactivate-confirm'),
    verticalActions: true,
  );
  if (confirmed != true ||
      !context.mounted ||
      scope != currentSessionReadScope()) return false;
  var succeeded = false;
  String failureReason = '';
  try {
    await MobileApi.instance.adminReactivateCompletedWork(target);
    succeeded = true;
  } catch (error) {
    if (error is MobileApiException) {
      failureReason = error.code.replaceFirst(RegExp(r'^reactivation_'), '');
    }
  }
  if (!context.mounted || scope != currentSessionReadScope()) return true;
  showAdminTopNotice(
    context,
    succeeded
        ? l10n.productionText('worker.reactivate.success')
        : '${_workerReactivationDenial(l10n, failureReason)}\n'
            '${l10n.productionText('worker.reactivate.unconfirmed')}',
    tone: succeeded ? AdminTopNoticeTone.success : AdminTopNoticeTone.error,
  );
  return true;
}

String _workerReactivationDenial(AppLocalizations l10n, String reason) {
  const reasons = {
    'apparatus_busy',
    'source_not_free',
    'final_stage_closed',
    'stale_target',
    'resource_unavailable',
    'order_closed',
    'unsupported_history',
  };
  return l10n.productionText(
      'worker.reactivate.reason.${reasons.contains(reason) ? reason : 'unavailable'}');
}
