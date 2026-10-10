part of 'admin_production_map_orders_screen.dart';

extension _OrderDetailSync on _ReadOnlyOrderDetailSheetState {
  bool _sameDetailControl(AdminPrintPreflightControlState incoming) {
    final control = _queueActionControl;
    return control != null &&
        control.serverContractSignature.isNotEmpty &&
        control.serverContractSignature ==
            incoming.control.serverContractSignature &&
        _queueStates[incoming.orderId] == incoming.queueState &&
        _orderControlState == incoming.orderControl &&
        mapEquals(_stageStates, incoming.stageStates);
  }

  bool _liveAllowsDetailControl(AdminPrintPreflightControlState incoming) {
    if (incoming.apparatus != widget.apparatus?.id.trim() ||
        incoming.orderId != widget.order.map.id.trim() ||
        incoming.revision < 0 || incoming.epoch.isEmpty ||
        _retiredDetailEpochs.contains(incoming.epoch) ||
        !incoming.control.isConsistentWith(incoming.orderControl,
            queueState: incoming.queueState)) return false;
    final accepted = _acceptedDetailControl;
    if (accepted != null && accepted.epoch == incoming.epoch &&
        incoming.revision < accepted.revision &&
        !_sameDetailControl(incoming)) return false;
    final live = widget.currentQueueSnapshot?.call();
    if (accepted != null && accepted.epoch != incoming.epoch &&
        live?.epoch != incoming.epoch) return false;
    if (_pendingDetailRevision != null &&
        (incoming.epoch != _pendingDetailEpoch ||
            incoming.revision < _pendingDetailRevision!)) return false;
    if (live == null || live.epoch.isEmpty) return true;
    if (live.epoch != incoming.epoch) return false;
    if ((live.revision ?? -1) <= incoming.revision) return true;
    final control =
        live.queueActionControls[incoming.apparatus]?[incoming.orderId];
    return control != null &&
        control.serverContractSignature.isNotEmpty &&
        control.serverContractSignature ==
            incoming.control.serverContractSignature &&
        live.queueStates[incoming.apparatus]?[incoming.orderId] ==
            incoming.queueState &&
        live.orderControlFor(incoming.orderId) == incoming.orderControl &&
        mapEquals(live.stageStates[incoming.orderId] ?? const {},
            incoming.stageStates);
  }

  AdminPrintPreflightControlState? _canonicalDetailControl() {
    final snapshot = widget.queueSnapshotListenable?.value;
    final apparatus = widget.apparatus?.id.trim() ?? '';
    final orderId = widget.order.map.id.trim();
    if (snapshot == null ||
        snapshot.revision == null ||
        snapshot.epoch.isEmpty ||
        (_pendingDetailRevision != null &&
            (snapshot.epoch != _pendingDetailEpoch ||
                snapshot.revision! < _pendingDetailRevision!))) return null;
    final accepted = _acceptedDetailControl;
    if (accepted != null && accepted.epoch == snapshot.epoch &&
        snapshot.revision! < accepted.revision) return null;
    final control = snapshot.queueActionControls[apparatus]?[orderId];
    final queueState = snapshot.queueStates[apparatus]?[orderId];
    final orderControl = snapshot.orderControlFor(orderId);
    if (control == null ||
        queueState == null ||
        !control.isConsistentWith(orderControl, queueState: queueState))
      return null;
    return AdminPrintPreflightControlState(
      apparatus: apparatus,
      orderId: orderId,
      revision: snapshot.revision!,
      epoch: snapshot.epoch,
      control: control,
      queueState: queueState,
      stageStates: snapshot.stageStates[orderId] ?? const {},
      orderControl: orderControl,
    );
  }

  void _applyDetailControl(AdminPrintPreflightControlState control) {
    final accepted = _acceptedDetailControl;
    if (accepted != null && accepted.epoch == control.epoch &&
        accepted.revision > control.revision && _sameDetailControl(control)) {
      // Identical controls can validate an older section read, but must never
      // move this sheet's revision back behind an acknowledged mutation.
      control = accepted;
    }
    _acceptedDetailControl = control;
    _queueActionControl = control.control;
    _queueStates = Map<String, String>.from(_queueStates)
      ..[control.orderId] = control.queueState;
    _stageStates = Map<String, String>.from(control.stageStates);
    _orderControls = Map<String, AdminOrderControlState>.from(_orderControls)
      ..[control.orderId] = control.orderControl;
    _orderControlState = control.orderControl;
    _scanBootstrapRevision = control.revision;
    _scanBootstrapEpoch = control.epoch;
  }

  bool _installCanonicalDetailSnapshot() {
    return _installDetailControl(_canonicalDetailControl());
  }

  bool _installDetailControl(AdminPrintPreflightControlState? control) {
    if (!mounted || _detailReadScope != currentSessionReadScope()) return false;
    if (control == null || !_liveAllowsDetailControl(control)) return false;
    setState(() => _applyDetailControl(control));
    _pendingDetailRevision = null;
    _detailRecoveryAttempt = 0;
    if (!_detailSectionsNeedReload) {
      _detailRecoveryTimer?.cancel();
      _detailRecoveryTimer = null;
    }
    return true;
  }

  void _onCanonicalDetailSnapshot() {
    if (!mounted ||
        !widget.workerMode ||
        _isTrainingOrder ||
        _detailReadScope != currentSessionReadScope()) return;
    final snapshot = widget.queueSnapshotListenable?.value;
    final accepted = _acceptedDetailControl;
    if (snapshot != null && accepted != null &&
        snapshot.epoch != accepted.epoch) {
      // Only a canonical snapshot can establish a new server epoch.
      _retiredDetailEpochs.add(accepted.epoch);
      _acceptedDetailControl = null;
      _pendingDetailRevision = null;
      _actionControlGeneration++;
      _scanBootstrapGeneration++;
    }
    final control = _canonicalDetailControl();
    if (control == null) {
      final live = widget.currentQueueSnapshot?.call();
      if (_pendingDetailRevision == null && accepted != null &&
          _queueActionContractSynchronized && live?.epoch == accepted.epoch &&
          (live?.revision ?? -1) < accepted.revision) {
        // A scoped ACK/read is ahead of the global stream. Do not discard it
        // while the parent recovers missing delta history in the background.
        return;
      }
      setState(() => _queueActionControl = null);
      _scheduleDetailRecovery();
      return;
    }
    final changed = !_sameDetailControl(control);
    final waitingForAction = _pendingDetailRevision != null;
    if (!_installCanonicalDetailSnapshot() || !changed || _queueActionBusy)
      return;
    if (_detailRefreshInFlight) {
      _actionControlGeneration++;
      _refreshDetailSections();
    } else if (_actionControlLoads > 0) {
      // A read for the preceding interaction must not replace the new one.
      _scanBootstrapGeneration++;
      _materialLoadGeneration++;
      _detailSectionsNeedReload = true;
      _scheduleDetailRecovery();
    } else {
      _refreshDetailSections();
    }
    if (waitingForAction) dismissAdminTopNotice();
  }

  void _refreshDetailSections() {
    unawaited(_loadMaterialAssignments());
    unawaited(_loadInputProgressBatches());
    if (_queueActionControl?.interaction?.qolipMode ==
        AdminQueueQolipMode.scanRequired) {
      unawaited(_loadQolipRequirements());
    }
  }

  void _scheduleDetailRecovery({Object? error, Duration? delay}) {
    if (!mounted ||
        !widget.workerMode ||
        !_detailForeground ||
        _queueActionBusy ||
        widget.apparatus == null ||
        _detailReadScope != currentSessionReadScope() ||
        _detailRecoveryTimer != null) return;
    if (error is MobileApiException &&
        (error.statusCode == 401 ||
            error.statusCode == 403 ||
            const {
              'unauthorized',
              'forbidden',
              'order_not_available',
              'training_order_scan_bootstrap_unsupported',
            }.contains(error.code))) return;
    final seconds = 1 << _detailRecoveryAttempt.clamp(0, 3);
    _detailRecoveryAttempt++;
    _detailRecoveryTimer = Timer(delay ?? Duration(seconds: seconds), () {
      _detailRecoveryTimer = null;
      if (!mounted ||
          !_detailForeground ||
          _queueActionBusy ||
          _detailReadScope != currentSessionReadScope()) return;
      if (_actionControlLoads > 0 || _detailRefreshInFlight) {
        _scheduleDetailRecovery();
      } else if (_pendingDetailRevision != null) {
        unawaited(_refreshQueueActionControlAfterWrite());
      } else {
        unawaited(_loadInteractionContractAndSections());
      }
    });
  }
}
