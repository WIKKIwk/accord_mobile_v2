part of 'admin_production_map_orders_screen.dart';

extension _OrderDetailScanBootstrap on _ReadOnlyOrderDetailSheetState {
  bool _liveAllowsScanControl(int? revision, String epoch) {
    final live = widget.currentQueueSnapshot?.call();
    return revision == null ||
        live == null ||
        live.epoch.isEmpty ||
        (live.epoch == epoch && (live.revision ?? -1) <= revision);
  }

  /// Returns true when the aggregate owns this load, including failures. Only
  /// a positively unsupported route may fall through to the legacy readers.
  Future<bool> _loadScanBootstrap(int generation) async {
    final interaction = _queueActionControl?.interaction;
    if (!widget.workerMode ||
        widget.apparatus == null ||
        _isTrainingOrder ||
        widget.startPauseOnOpen ||
        widget.currentQueueSnapshot == null ||
        (!_usesScanBootstrap &&
            interaction?.startMaterialsMode !=
                AdminQueueStartMaterialsMode.scanRequired &&
            interaction?.qolipMode != AdminQueueQolipMode.scanRequired)) {
      return false;
    }
    if (await TestModeController.instance.isEnabled()) return false;
    if (!mounted || generation != _scanBootstrapGeneration) return true;
    // A failed authoritative read must retry this same scoped endpoint rather
    // than losing the initial interaction hint and falling through to broader
    // legacy readers on the next click.
    _usesScanBootstrap = true;
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
            _liveAllowsScanControl(
              acceptedControl.revision,
              acceptedControl.epoch,
            ));
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
      if (result == null) return false;
      final control = result.controlState;
      // A scoped read does not fill global delta history. Use the live cursor
      // solely to reject delayed controls, never to advance or replace it.
      if (!_liveAllowsScanControl(control.revision, control.epoch)) {
        throw const MobileApiException(
          code: 'order_scan_bootstrap_stale',
          message: 'Order state changed while scan requirements loaded',
        );
      }
      acceptedControl = control;
      _setScanBootstrapState(() {
        _queueActionControl = control.control;
        _queueStates = Map<String, String>.from(_queueStates)
          ..[orderId] = control.queueState;
        _stageStates = Map<String, String>.from(control.stageStates);
        _orderControls = Map<String, AdminOrderControlState>.from(
          _orderControls,
        )..[orderId] = control.orderControl;
        _orderControlState = control.orderControl;
        _scanBootstrapRevision = control.revision;
        _scanBootstrapEpoch = control.epoch;
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
      return true;
    } finally {
      if (mounted) _setScanBootstrapState(() => _actionControlLoads--);
    }
  }
}
