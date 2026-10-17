part of 'admin_production_map_orders_screen.dart';

Future<AdminApparatusQueueSnapshot?> _loadWorkerQrSnapshot({
  required String apparatus,
  required String orderId,
  required bool Function() isCurrent,
  AdminApparatusQueueSnapshot? Function()? currentSnapshot,
}) async {
  final apparatusId = apparatus.trim();
  for (var attempt = 0; attempt < 2; attempt++) {
    final snapshot = await MobileApi.instance
        .adminProductionMapQueueSnapshot(
          apparatus: apparatusId,
          orderId: orderId,
          fresh: true,
        )
        .timeout(_queueActionControlRefreshTimeout);
    if (!isCurrent()) return null;
    AdminPrintPreflightControlState? detail;
    final testMode = await TestModeController.instance.isEnabled();
    if (!isCurrent()) return null;
    if (!testMode && !orderId.startsWith('training-')) {
      // This endpoint rechecks the worker's assignment and capabilities.
      // Only a positively unsupported aggregate falls back to /sequence.
      final bootstrap = await MobileApi.instance
          .adminOrderScanBootstrap(
            apparatus: apparatusId,
            orderId: orderId,
            includeSections: false,
          )
          .timeout(_queueActionControlRefreshTimeout);
      if (!isCurrent()) return null;
      detail = bootstrap?.controlState;
    }
    final live = currentSnapshot?.call();
    final revision = detail?.revision ?? snapshot.revision;
    final epoch = detail?.epoch ?? snapshot.epoch;
    // Keep station occupancy and target permissions at the same revision.
    // A scoped read never changes the cursor of the filtered list stream.
    if ((detail != null &&
            (detail.apparatus != apparatusId ||
                detail.orderId != orderId ||
                detail.epoch != snapshot.epoch ||
                detail.revision != snapshot.revision)) ||
        (live != null &&
            live.epoch.isNotEmpty &&
            (epoch != live.epoch ||
                (revision ?? -1) < (live.revision ?? -1)))) {
      continue;
    }
    final control =
        detail?.control ?? snapshot.queueActionControls[apparatusId]?[orderId];
    final queueState =
        detail?.queueState ?? snapshot.queueStates[apparatusId]?[orderId];
    final orderControl =
        detail?.orderControl ?? snapshot.orderControlFor(orderId);
    if (control?.isConsistentWith(orderControl, queueState: queueState) !=
        true) {
      throw const MobileApiException(code: 'worker_qr_sync', message: '');
    }
    if (detail == null) return snapshot;
    return AdminApparatusQueueSnapshot(
      sequences: snapshot.sequences,
      sequenceVersions: snapshot.sequenceVersions,
      sequenceRevisions: snapshot.sequenceRevisions,
      visibleOrderIds: snapshot.visibleOrderIds,
      queueStates: {
        ...snapshot.queueStates,
        apparatusId: {
          ...?snapshot.queueStates[apparatusId],
          orderId: detail.queueState
        },
      },
      queuePolicies: snapshot.queuePolicies,
      orderControls: {...snapshot.orderControls, orderId: detail.orderControl},
      earlyClosingOrderIds: snapshot.earlyClosingOrderIds,
      queueActionControls: {
        ...snapshot.queueActionControls,
        apparatusId: {
          ...?snapshot.queueActionControls[apparatusId],
          orderId: detail.control
        },
      },
      stageStates: {...snapshot.stageStates, orderId: detail.stageStates},
      orderCustomers: snapshot.orderCustomers,
      orderStatuses: snapshot.orderStatuses,
      frozenOrdersByApparatus: snapshot.frozenOrdersByApparatus,
      maps: snapshot.maps,
      revision: detail.revision,
      epoch: detail.epoch,
    );
  }
  throw const MobileApiException(code: 'worker_qr_sync', message: '');
}
