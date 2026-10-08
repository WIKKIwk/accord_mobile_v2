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
    final live = widget.currentQueueSnapshot?.call();
    if (_pendingDetailRevision != null &&
        incoming.epoch == _pendingDetailEpoch &&
        incoming.revision < _pendingDetailRevision!) return false;
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
    if (!mounted || _detailReadScope != currentSessionReadScope()) return false;
    final control = _canonicalDetailControl();
    if (control == null) return false;
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
    final control = _canonicalDetailControl();
    if (control == null) {
      setState(() => _queueActionControl = null);
      _scheduleDetailRecovery();
      return;
    }
    final changed = !_sameDetailControl(control);
    final waitingForAction = _pendingDetailRevision != null;
    if (!_installCanonicalDetailSnapshot() || !changed || _actionInFlight)
      return;
    if (_actionControlLoads > 0) {
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
        _actionInFlight ||
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
          _actionInFlight ||
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
