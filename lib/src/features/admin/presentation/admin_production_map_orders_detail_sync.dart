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
    final previousMaterialsMode =
        _queueActionControl?.interaction?.startMaterialsMode;
    if (control.control.interaction?.startMaterialsMode ==
            AdminQueueStartMaterialsMode.scanRequired &&
        previousMaterialsMode != AdminQueueStartMaterialsMode.scanRequired) {
      // A colour outcome can reveal start requirements after the trial hid
      // them. Retire preceding display-only reads before publishing that mode.
      _materialLoadGeneration++;
      _materialStartRequirements = null;
      _materialsLoading = true;
      _materialsError = '';
    }
    _workerPresentationDenied = false;
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
    if (!_detailSectionsNeedReload) _detailRecoveryNeeded = false;
    return true;
  }

  void _onCanonicalDetailSnapshot() {
    final hydratedAdmin = widget.initialControlConfirmed &&
        (!widget.workerMode || widget.scopedWorkerDetail);
    if (!mounted ||
        (!widget.workerMode && !hydratedAdmin) ||
        (_isTrainingOrder && !hydratedAdmin) ||
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
      final apparatus = widget.apparatus?.id.trim() ?? '';
      final orderId = widget.order.map.id.trim();
      final omitted = live?.queueActionControls[apparatus]?[orderId] == null &&
          live?.queueStates[apparatus]?[orderId] == null;
      if (_pendingDetailRevision == null && accepted != null &&
          _queueActionContractSynchronized && live?.epoch == accepted.epoch &&
          ((live?.revision ?? -1) < accepted.revision ||
              (live?.revision == accepted.revision && omitted))) {
        // A bounded projection can omit an equally fresh scoped ACK/read.
        // It cannot invalidate that contract without a newer revision.
        return;
      }
      setState(() => _queueActionControl = null);
      if (hydratedAdmin) return;
      // A newer bounded projection can omit this order without removing it.
      // Disable actions, then re-read its scoped contract immediately.
      _markDetailRecoveryNeeded();
      _queueDetailRecoveryFromStream();
      return;
    }
    final changed = !_sameDetailControl(control);
    final recoveryNeeded = _detailRecoveryNeeded || _detailSectionsNeedReload;
    final waitingForAction = _pendingDetailRevision != null;
    if (!_installCanonicalDetailSnapshot() || _queueActionBusy) return;
    if (!changed) {
      if (recoveryNeeded && !hydratedAdmin) _queueDetailRecoveryFromStream();
      return;
    }
    if (_detailRefreshInFlight) {
      _actionControlGeneration++;
      _refreshDetailSections();
    } else if (_actionControlLoads > 0) {
      // A read for the preceding interaction must not replace the new one.
      _scanBootstrapGeneration++;
      _materialLoadGeneration++;
      _detailSectionsNeedReload = true;
      if (hydratedAdmin) {
        _refreshDetailSections();
      } else {
        _queueDetailRecoveryFromStream();
      }
    } else {
      _refreshDetailSections();
    }
    if (waitingForAction) dismissAdminTopNotice();
  }

  void _refreshDetailSections({bool refreshDisplayOnlyMaterials = true}) {
    if (refreshDisplayOnlyMaterials ||
        _queueActionControl?.interaction?.startMaterialsMode ==
            AdminQueueStartMaterialsMode.scanRequired ||
        _detailUiState.materialIntakeAllowed) {
      unawaited(_loadMaterialAssignments());
    }
    unawaited(_loadInputProgressBatches());
    if (_queueActionControl?.interaction?.qolipMode ==
        AdminQueueQolipMode.scanRequired) {
      unawaited(_loadQolipRequirements());
    }
  }

  void _markDetailRecoveryNeeded({Object? error}) {
    if (!mounted ||
        !widget.workerMode ||
        widget.apparatus == null ||
        _detailReadScope != currentSessionReadScope()) return;
    if (error is MobileApiException &&
        (error.statusCode == 401 ||
            error.statusCode == 403 ||
            const {
              'unauthorized',
              'forbidden',
              'order_not_available',
              'training_order_scan_bootstrap_unsupported',
            }.contains(error.code))) {
      _setScanBootstrapState(() {
        _lastWorkerPresentation = null;
        _workerPresentationDenied = true;
      });
      return;
    }
    // A failed HTTP read waits for a pushed revision or an explicit retry.
    _detailRecoveryNeeded = true;
  }

  Object? _currentDetailRecoveryCursor() {
    final snapshot = widget.queueSnapshotListenable?.value ??
        widget.currentQueueSnapshot?.call();
    if (snapshot == null || snapshot.epoch.isEmpty ||
        snapshot.revision == null) return null;
    return (snapshot.epoch, snapshot.revision);
  }

  void _queueDetailRecoveryFromStream() {
    final cursor = _currentDetailRecoveryCursor();
    if (cursor == null || cursor == _detailRecoveryCursor) return;
    _detailRecoveryEventCursor = cursor;
    _drainDetailRecoveryFromStream();
  }

  void _drainDetailRecoveryFromStream() {
    if (!mounted || !_detailForeground || _queueActionBusy ||
        _detailReadScope != currentSessionReadScope() ||
        _actionControlLoads > 0 || _detailRefreshInFlight ||
        _detailRecoveryEventCursor == null) return;
    final cursor = _detailRecoveryEventCursor;
    _detailRecoveryEventCursor = null;
    if (cursor == _detailRecoveryCursor) return;
    _detailRecoveryCursor = cursor;
    if (_pendingDetailRevision != null) {
      unawaited(_refreshQueueActionControlAfterWrite());
    } else {
      unawaited(_loadInteractionContractAndSections());
    }
  }
}
