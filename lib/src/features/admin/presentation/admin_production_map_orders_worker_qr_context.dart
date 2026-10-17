part of 'admin_production_map_orders_screen.dart';

/// One-use route data, never persisted or installed as a live-list cursor.
class _WorkerFabPreparedScan {
  const _WorkerFabPreparedScan(this.bootstrap, this.qrPayload, this.readScope);
  final AdminOrderScanBootstrap bootstrap;
  final String qrPayload;
  final String readScope;
}

extension _PreparedFabInput on _ReadOnlyOrderDetailSheetState {
  Future<bool> _acceptInitialFabScan(_WorkerFabPreparedScan prepared) async {
    final live = widget.currentQueueSnapshot?.call();
    if (live?.epoch == prepared.bootstrap.controlState.epoch &&
        (live?.revision ?? -1) > prepared.bootstrap.controlState.revision) {
      // WIP ownership can change without changing this target's controls.
      // Revalidate its proof once when live progressed during section reads.
      final actionGeneration = _actionControlGeneration;
      final loadGeneration = _scanBootstrapGeneration;
      try {
        final refreshed = await MobileApi.instance
            .adminOrderScanBootstrap(
              apparatus: prepared.bootstrap.controlState.apparatus,
              orderId: prepared.bootstrap.controlState.orderId,
              qrPayload: prepared.qrPayload,
              includeSections: false,
            )
            .timeout(_queueActionControlRefreshTimeout);
        if (!mounted ||
            prepared.readScope != currentSessionReadScope() ||
            actionGeneration != _actionControlGeneration ||
            loadGeneration != _scanBootstrapGeneration ||
            refreshed == null ||
            refreshed.validatedProgress == null ||
            !_sameDetailControl(refreshed.controlState) ||
            !_liveAllowsDetailControl(refreshed.controlState)) {
          return false;
        }
        _setScanBootstrapState(
            () => _applyDetailControl(refreshed.controlState));
        prepared = _WorkerFabPreparedScan(
            refreshed, prepared.qrPayload, prepared.readScope);
      } catch (_) {
        return false;
      }
    }
    return _acceptPreparedFabScan(prepared);
  }

  bool _acceptPreparedFabScan(_WorkerFabPreparedScan prepared) {
    final control = prepared.bootstrap.controlState;
    final batch = prepared.bootstrap.validatedProgress;
    final apparatus = widget.apparatus?.id.trim() ?? '';
    final live = widget.currentQueueSnapshot?.call();
    if (!mounted ||
        batch == null ||
        prepared.readScope != currentSessionReadScope() ||
        prepared.readScope != _detailReadScope ||
        prepared.qrPayload.trim() != widget.initialScanQrPayload.trim() ||
        control.apparatus != apparatus ||
        control.orderId != widget.order.map.id.trim() ||
        batch.orderId.trim() != control.orderId ||
        batch.qrPayload.trim().toUpperCase() !=
            prepared.qrPayload.trim().toUpperCase() ||
        batch.wipStatus != 'waiting' ||
        !_queueActionContractSynchronized ||
        (live != null &&
            live.epoch.isNotEmpty &&
            (live.epoch != control.epoch ||
                (live.revision ?? -1) > control.revision)) ||
        !_sameDetailControl(control) ||
        !_liveAllowsDetailControl(control) ||
        !(_queueActionControl?.allows('start') == true ||
            (_queueActionControl?.allows('resume') == true &&
                _queueActionControl?.interaction?.resumeInputRequired ==
                    true)) ||
        !_workerWipConsumerIds(
                _ScannedWorkerWip(progress: batch), widget.order.map,
                consumerStageNodeId: _queueActionControl?.stageNodeId ?? '')
            .contains(apparatus)) {
      return false;
    }
    // Only the exact server-validated input is marked scanned. Resource scan
    // tasks and the explicit Start POST keep their existing validation gates.
    _updateWipScanState(() {
      _availableInputProgressBatches = [
        batch,
        ..._availableInputProgressBatches
            .where((item) => item.batchId != batch.batchId)
      ];
      _seenQuickScanValues.add(
          rawMaterialBarcodeFromQr(prepared.qrPayload).trim().toUpperCase());
    });
    final accepted = _acceptProgressBatch(batch);
    _showQuickScanFeedback(accepted
        ? ProductionQuickScanFeedback.accepted
        : ProductionQuickScanFeedback.rejected);
    return accepted;
  }
}

Future<AdminOrderScanBootstrap?> _loadWorkerFabBootstrap({
  required String apparatus,
  required String orderId,
  required String qrPayload,
  required bool Function() isCurrent,
  AdminApparatusQueueSnapshot? Function()? currentSnapshot,
}) async {
  if (orderId.startsWith('training-') ||
      await TestModeController.instance.isEnabled()) {
    return null;
  }
  if (!isCurrent()) return null;
  for (var attempt = 0; attempt < 2; attempt++) {
    final result = await MobileApi.instance
        .adminOrderScanBootstrap(
          apparatus: apparatus,
          orderId: orderId,
          includeContext: true,
          qrPayload: qrPayload,
        )
        .timeout(_queueActionControlRefreshTimeout);
    if (!isCurrent()) return null;
    if (result == null) return null;
    final live = currentSnapshot?.call();
    if (live != null &&
        live.epoch.isNotEmpty &&
        (live.epoch != result.controlState.epoch ||
            (live.revision ?? -1) > result.controlState.revision)) {
      continue;
    }
    return result;
  }
  throw const MobileApiException(code: 'worker_qr_sync', message: '');
}

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
