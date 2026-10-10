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
    try {
      final result = await MobileApi.instance
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
      await Future.wait([
        if (materials == null) _loadMaterialAssignments(readIsCurrent: current),
        if (qolips == null) _loadQolipRequirements(readIsCurrent: current),
        _loadInputProgressBatches(readIsCurrent: current),
      ]);
      if (contextCurrent() && !current()) {
        throw const MobileApiException(
          code: 'order_scan_bootstrap_stale',
          message: 'Order state changed while scan requirements loaded',
        );
      }
      if (current()) _detailRecoveryAttempt = 0;
      return true;
    } catch (error) {
      if (!mounted || !contextCurrent()) return true;
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
      if (context.mounted) {
        _showSheetNotice(context.l10n.productionText('worker.error.sync'));
      }
      _scheduleDetailRecovery(error: error);
      return true;
    } finally {
      if (mounted) _setScanBootstrapState(() => _actionControlLoads--);
    }
  }
}
