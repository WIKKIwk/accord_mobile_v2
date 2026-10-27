part of 'admin_production_map_orders_screen.dart';

extension _OrderDetailScanBootstrap on _ReadOnlyOrderDetailSheetState {
  bool _liveAllowsScanControl(int? revision, String epoch) {
    final live = widget.currentQueueSnapshot?.call();
    if (revision == null || live == null || live.epoch.isEmpty) return true;
    if (live.epoch != epoch) return false;
    if ((live.revision ?? -1) <= revision) return true;
    final control = _queueActionControl;
    if (control == null) return false;
    return _liveAllowsDetailControl(AdminPrintPreflightControlState(
      apparatus: widget.apparatus?.id.trim() ?? '',
      orderId: widget.order.map.id.trim(), revision: revision,
      epoch: epoch, control: control,
      queueState: _queueStates[widget.order.map.id.trim()] ?? '',
      stageStates: _stageStates, orderControl: _orderControlState,
    ));
  }

  /// Returns true when the aggregate owns this load, including failures. Only
  /// a positively unsupported route may fall through to the legacy readers.
  Future<bool> _loadScanBootstrap(int generation) async {
    if (!widget.workerMode ||
        widget.apparatus == null ||
        _isTrainingOrder ||
        widget.startPauseOnOpen ||
        _scanBootstrapUnsupported ||
        widget.currentQueueSnapshot == null) {
      return false;
    }
    if (await TestModeController.instance.isEnabled()) return false;
    if (!mounted || generation != _scanBootstrapGeneration) return true;
    if (_detailReadScope != currentSessionReadScope()) return true;
    final orderId = widget.order.map.id.trim();
    final apparatus = widget.apparatus!.id.trim();
    final scope = currentSessionReadScope();
    final actionGeneration = _actionControlGeneration;
    AdminPrintPreflightControlState? incomingControl;
    AdminPrintPreflightControlState? acceptedControl;
    bool contextCurrent() =>
        _materialContextIsCurrent(orderId, apparatus) &&
        generation == _scanBootstrapGeneration &&
        actionGeneration == _actionControlGeneration &&
        scope == currentSessionReadScope();
    bool current() =>
        contextCurrent() &&
        (acceptedControl == null ||
            _liveAllowsDetailControl(acceptedControl));
    _setScanBootstrapState(() {
      _actionControlLoads++;
      _materialsLoading = true;
      _materialsError = '';
      _qolipRequirementsLoading = true;
      _qolipRequirementsLoaded = false;
      _qolipRequirementsError = '';
    });
    var materialGeneration = _materialLoadGeneration;
    var qolipGeneration = _qolipRequirementsGeneration;
    try {
      final prepared = _pendingFabPreparedScan;
      _pendingFabPreparedScan = null;
      if (prepared != null && (prepared.readScope != scope ||
          prepared.qrPayload.trim() != widget.initialScanQrPayload.trim() ||
          prepared.bootstrap.controlState.apparatus != apparatus ||
          prepared.bootstrap.controlState.orderId != orderId)) {
        throw const MobileApiException(
            code: 'order_scan_bootstrap_stale', message: '');
      }
      final result = prepared?.bootstrap ?? await MobileApi.instance
          .adminOrderScanBootstrap(
            apparatus: apparatus,
            orderId: orderId,
            materialBarcodes: _scannedMaterialBarcodes.toList(growable: false),
          )
          .timeout(_queueActionControlRefreshTimeout);
      if (!current()) return true;
      if (result == null) {
        _scanBootstrapUnsupported = true;
        return false;
      }
      final control = result.controlState;
      incomingControl = control;
      // A scoped read never fills global delta history or advances its cursor.
      // A newer revision is harmless only when the target state is unchanged.
      if (!_liveAllowsDetailControl(control)) {
        throw const MobileApiException(
          code: 'order_scan_bootstrap_stale',
          message: 'Order state changed while scan requirements loaded',
        );
      }
      acceptedControl = control;
      _setScanBootstrapState(() {
        _applyDetailControl(control);
        _initialFabBootstrapAccepted = prepared != null;
        _qolipRequirementsLoading = false;
      });
      final needsMaterials = control.control.interaction?.startMaterialsMode ==
          AdminQueueStartMaterialsMode.scanRequired;
      final materials = needsMaterials ? result.materials : null;
      if (materials != null) {
        ++_materialLoadGeneration;
        _applyMaterialAssignmentsSnapshot(
          _MaterialAssignmentsSnapshot(
            assignments: materials.assignments
                .where((row) => row.apparatus == apparatus)
                .toList(),
            startAssignments: materials.startAssignments
                .where((row) => row.apparatus == apparatus)
                .toList(),
            intakeCandidateAssignments: const [],
            requirements: materials,
          ),
        );
      }
      final needsQolips = control.control.interaction?.qolipMode ==
          AdminQueueQolipMode.scanRequired;
      final qolips = needsQolips ? result.qolips : null;
      if (qolips != null) {
        _setScanBootstrapState(() {
          _replaceRequiredQolips(qolips.requiredQolips);
          _qolipRequirementsLoaded = true;
          _qolipRequirementsError = '';
        });
      }
      // Each missing/failed/incomplete section keeps its independent reader.
      // Candidate lists and authoritative QR lookups keep existing behavior.
      final sectionReads = [
        if (materials == null) _loadMaterialAssignments(
          readIsCurrent: current,
          preparedAssignments: result.materialAssignments,
        ),
        if (qolips == null) _loadQolipRequirements(readIsCurrent: current),
        _loadInputProgressBatches(
          readIsCurrent: current,
          preparedBatches: result.inputProgressBatches,
        ),
      ];
      materialGeneration = _materialLoadGeneration;
      qolipGeneration = _qolipRequirementsGeneration;
      await Future.wait(sectionReads);
      if (contextCurrent() && !current()) {
        throw const MobileApiException(
          code: 'order_scan_bootstrap_stale',
          message: 'Order state changed while scan requirements loaded',
        );
      }
      if (current()) _detailRecoveryNeeded = false;
      return true;
    } catch (error) {
      if (!mounted || !contextCurrent()) return true;
      final canonical = _canonicalDetailControl();
      if (error is MobileApiException &&
          error.code == 'order_scan_bootstrap_stale' &&
          incomingControl != null && canonical != null &&
          canonical.epoch == incomingControl.epoch &&
          canonical.revision > incomingControl.revision &&
          _queueActionContractSynchronized &&
          _sameDetailControl(canonical) &&
          _liveAllowsDetailControl(canonical)) {
        // An old successful GET cannot withdraw newer canonical authority.
        // Its sections still need fresh readers, owned by the current state.
        _detailRecoveryNeeded = false;
        _setScanBootstrapState(() => _qolipRequirementsLoading = false);
        _refreshDetailSections();
        return true;
      }
      _setScanBootstrapState(() {
        _queueActionControl = null;
        _materialStartRequirements = null;
        _materialAssignments = const [];
        _startAssignments = const [];
        _intakeCandidateAssignments = const [];
        _materialsLoading = false;
        _materialsError = _readOnlyQueueActionErrorText(error, context.l10n);
        _requiredQolips.clear();
        _qolipRequirementsLoaded = false;
        _qolipRequirementsLoading = false;
        _qolipRequirementsError = _materialsError;
      });
      _markDetailRecoveryNeeded(error: error);
      return true;
    } finally {
      if (mounted) {
        _setScanBootstrapState(() {
          _actionControlLoads--;
          // A shared write can retire this bootstrap while its replacement
          // reads only the control. Do not leave the abandoned section flags
          // spinning, or clear flags now owned by a newer section/bootstrap.
          if (generation != _scanBootstrapGeneration ||
              !_materialContextIsCurrent(orderId, apparatus) ||
              scope != currentSessionReadScope() || contextCurrent()) return;
          if (materialGeneration == _materialLoadGeneration &&
              _materialsLoading) {
            _materialsLoading = false;
            _materialsError = '';
          }
          if (qolipGeneration == _qolipRequirementsGeneration &&
              _qolipRequirementsLoading) {
            _qolipRequirementsLoading = false;
            _qolipRequirementsError = '';
          }
          if (!_queueActionContractSynchronized) _detailRecoveryNeeded = true;
        });
      }
    }
  }
}
