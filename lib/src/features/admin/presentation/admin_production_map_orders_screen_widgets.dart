part of 'admin_production_map_orders_screen.dart';

enum _OpenedOrderModule { orders, move, sequence, closed, audit }

enum _OrderLongPressAction {
  freeze,
  cancelFreeze,
  unfreeze,
  delete,
  editMap,
}

Future<void> showAdminProductionMapOrderReadOnlyDetail(
  BuildContext context, {
  required ProductionMapSaved order,
  required AdminApparatus apparatus,
  AdminApparatusQueueSnapshot? queueSnapshot,
}) async {
  final results = await Future.wait<Object>([
    queueSnapshot == null
        ? MobileApi.instance.adminProductionMapQueueSnapshot()
        : Future.value(queueSnapshot),
    MobileApi.instance.adminApparatus(),
  ]);
  final snapshot = results[0] as AdminApparatusQueueSnapshot;
  final apparatusCatalog = results[1] as List<AdminApparatus>;
  if (!context.mounted) {
    return;
  }
  final visibleOrderIds =
      snapshot.visibleOrderIds[apparatus.id.trim()] ?? const <String>[];
  final mapId = order.map.id.trim();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    shape: _orderDetailSheetShape,
    clipBehavior: Clip.antiAlias,
    builder: (context) => _ReadOnlyOrderDetailSheet(
      order: order,
      apparatus: apparatus,
      apparatusCatalog: apparatusCatalog,
      baseMetraj: order.map.baseLength,
      orderKg: order.map.orderKg,
      customerName: snapshot.orderCustomers[mapId] ?? order.map.customerName,
      initialQueueStates: _queueStatesForApparatus(
        apparatus,
        queueStatesByApparatus: snapshot.queueStates,
      ),
      queueStatesByApparatus: snapshot.queueStates,
      stageStatesByOrderId: snapshot.stageStates,
      queuePolicy: _queuePolicyForApparatus(
        apparatus,
        queuePoliciesByApparatus: snapshot.queuePolicies,
      ),
      sequenceOrderIds: _sequenceOrderIdsForApparatus(
        apparatus,
        sequenceByApparatus: snapshot.sequences,
      ),
      visibleOrderIds: visibleOrderIds,
      initialOrderControls: snapshot.orderControls,
    ),
  );
}

Future<bool> showProductionMapFreezePauseFlow(
  BuildContext context, {
  required String requestId,
  required String orderId,
  required String apparatus,
}) async {
  final normalizedRequestId = requestId.trim();
  final normalizedOrderId = orderId.trim();
  final normalizedApparatus = apparatus.trim();
  if (normalizedRequestId.isEmpty ||
      normalizedOrderId.isEmpty ||
      normalizedApparatus.isEmpty) {
    throw MobileApiException(
      code: 'order_freeze_request_invalid',
      message: context.l10n.adminText(
        'production.freeze_request_incomplete',
      ),
    );
  }
  final results = await Future.wait<Object>([
    MobileApi.instance.adminProductionMap(normalizedOrderId),
    MobileApi.instance.adminProductionMapQueueSnapshot(),
    MobileApi.instance.adminApparatus(),
  ]);
  if (!context.mounted) return false;
  final order = results[0] as ProductionMapSaved;
  final snapshot = results[1] as AdminApparatusQueueSnapshot;
  final apparatusCatalog = results[2] as List<AdminApparatus>;
  final target = _canonicalApparatusForId(
    apparatusCatalog,
    normalizedApparatus,
  );
  if (target == null) {
    throw MobileApiException(
      code: 'apparatus_projection_missing',
      message: context.l10n.adminText(
        'production.assignment.apparatus_missing',
      ),
    );
  }
  final visibleOrderIds =
      snapshot.visibleOrderIds[normalizedApparatus] ?? const <String>[];
  final queueActionControl =
      snapshot.queueActionControls[normalizedApparatus]?[normalizedOrderId];
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    shape: _orderDetailSheetShape,
    clipBehavior: Clip.antiAlias,
    builder: (context) => _ReadOnlyOrderDetailSheet(
      order: order,
      apparatus: target,
      apparatusCatalog: apparatusCatalog,
      workerMode: true,
      canManageQueue: true,
      initialQueueStates: _queueStatesForApparatus(
        target,
        queueStatesByApparatus: snapshot.queueStates,
      ),
      queueStatesByApparatus: snapshot.queueStates,
      stageStatesByOrderId: snapshot.stageStates,
      queueActionControl: queueActionControl,
      queuePolicy: _queuePolicyForApparatus(
        target,
        queuePoliciesByApparatus: snapshot.queuePolicies,
      ),
      sequenceOrderIds: _sequenceOrderIdsForApparatus(
        target,
        sequenceByApparatus: snapshot.sequences,
      ),
      visibleOrderIds: visibleOrderIds,
      onQueueAction: (request) => _submitAdminApparatusQueueAction(
        request,
        apparatusKey: request.apparatus.id.trim(),
      ),
      initialOrderControls: snapshot.orderControls,
      initialPauseRequestId: normalizedRequestId,
      startPauseOnOpen: true,
    ),
  );
  return result ?? false;
}

class AdminProductionMapOrdersScreen extends StatefulWidget {
  const AdminProductionMapOrdersScreen({
    super.key,
    this.readOnly = false,
    this.workerMode = false,
    this.supplyViewerMode = false,
    this.progressDriverUrlPicker,
    this.closedOrdersLoader,
    this.completionRequestsLoader,
  }) : assert(!(workerMode && supplyViewerMode));
  final bool readOnly;
  final bool workerMode;
  final bool supplyViewerMode;
  final Future<String?> Function(BuildContext context)? progressDriverUrlPicker;
  final Future<List<AdminClosedProductionOrder>> Function()? closedOrdersLoader;
  final Future<List<AdminCompletionRequestNotification>> Function()?
      completionRequestsLoader;

  @override
  State<AdminProductionMapOrdersScreen> createState() =>
      _AdminProductionMapOrdersScreenState();
}

class _QueueSnapshotWarningBanner extends StatelessWidget {
  const _QueueSnapshotWarningBanner({
    required this.message,
    required this.onRetry,
  });
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
        child: Row(
          children: [
            Icon(
              Icons.sync_problem_rounded,
              color: scheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => unawaited(onRetry()),
              child: Text(context.l10n.adminText('action.retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenedOrdersLoadErrorBody extends StatelessWidget {
  const _OpenedOrdersLoadErrorBody({
    required this.message,
    required this.bottomPadding,
    required this.onRefresh,
  });
  final String message;
  final double bottomPadding;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppRefreshIndicator(
      onRefresh: onRefresh,
      allowRefreshOnShortContent: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            physics: const TopRefreshScrollPhysics(),
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding),
            children: [
              SizedBox(height: constraints.maxHeight * 0.42),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
