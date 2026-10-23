part of 'admin_production_map_orders_screen.dart';

/// Display data only. Never used by scanners, writes or contract validation.
class _WorkerDetailPresentation {
  _WorkerDetailPresentation({
    required this.scope,
    required this.uiState,
    required this.pauseLabel,
    required List<AdminProductionMapRequiredQolip> requiredQolips,
    required List<String> qolipCodes,
    required this.qolipScanned,
    required this.qolipRequirementsLoaded,
    required this.qolipRequirementsStatusText,
  })  : requiredQolips = List.unmodifiable(requiredQolips),
        qolipCodes = List.unmodifiable(qolipCodes);

  final Object scope;
  final _ReadOnlyOrderDetailUiState uiState;
  final String pauseLabel;
  final List<AdminProductionMapRequiredQolip> requiredQolips;
  final List<String> qolipCodes;
  final bool qolipScanned;
  final bool qolipRequirementsLoaded;
  final String qolipRequirementsStatusText;
}

extension _WorkerOrderPresentation on _ReadOnlyOrderDetailSheetState {
  _WorkerDetailPresentation? _workerPresentationFor(
      _ReadOnlyOrderDetailUiState current, String pauseLabel) {
    final epoch = widget.currentQueueEpoch?.call() ??
        widget.currentQueueSnapshot?.call()?.epoch ??
        _acceptedDetailControl?.epoch ??
        '';
    final scope = (
      currentSessionReadScope(),
      widget.order.map.id.trim(),
      widget.apparatus?.id.trim(),
      epoch,
    );
    final eligible = widget.workerMode &&
        !widget.detailPending &&
        !_workerPresentationDenied &&
        _detailReadScope == currentSessionReadScope() &&
        widget.canManageQueue &&
        widget.workerPresentationAllowed?.call() != false &&
        _effectiveOrderControlState == AdminOrderControlState.active &&
        (_acceptedDetailControl == null ||
            epoch.isEmpty ||
            _acceptedDetailControl!.epoch == epoch);
    if (!eligible || _lastWorkerPresentation?.scope != scope) {
      _lastWorkerPresentation = null;
    }
    if (eligible && current.contractSynchronized) {
      _lastWorkerPresentation = _WorkerDetailPresentation(
        scope: scope,
        uiState: current,
        pauseLabel: pauseLabel,
        requiredQolips: _visibleRequiredQolips,
        qolipCodes: _scannedQolipCodes.values.toList(growable: false),
        qolipScanned: !current.qolipScanRequired || _allRequiredQolipsScanned,
        qolipRequirementsLoaded: _qolipRequirementsLoaded &&
            !_qolipRequirementsLoading &&
            _qolipRequirementsError.isEmpty,
        qolipRequirementsStatusText: _qolipRequirementsStatusText,
      );
    }
    return _lastWorkerPresentation;
  }
}
