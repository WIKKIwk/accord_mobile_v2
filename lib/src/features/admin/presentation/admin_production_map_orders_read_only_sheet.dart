part of 'admin_production_map_orders_screen.dart';

class _ReadOnlyOrderDetailSheet extends StatefulWidget {
  const _ReadOnlyOrderDetailSheet({
    required this.order,
    this.apparatus,
    this.canManageQueue = false,
    this.initialQueueStates = const {},
    this.queueStatesByApparatus = const {},
    this.queuePolicy = ApparatusQueuePolicy.strictSequence,
    this.sequenceOrderIds = const [],
    this.visibleOrderIds = const [],
    this.onQueueAction,
    this.progressDriverUrlPicker,
  });

  final ProductionMapSaved order;
  final AdminWarehouse? apparatus;
  final bool canManageQueue;
  final Map<String, String> initialQueueStates;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final ApparatusQueuePolicy queuePolicy;
  final List<String> sequenceOrderIds;
  final List<String> visibleOrderIds;
  final _ReadOnlyQueueActionCallback? onQueueAction;
  final Future<String?> Function(BuildContext context)? progressDriverUrlPicker;

  @override
  State<_ReadOnlyOrderDetailSheet> createState() =>
      _ReadOnlyOrderDetailSheetState();
}

class _ReadOnlyOrderDetailSheetState extends State<_ReadOnlyOrderDetailSheet> {
  final GlobalKey _noticeAnchorKey = GlobalKey();
  late Map<String, String> _queueStates;
  List<AdminRawMaterialAssignment> _materialAssignments = const [];
  List<AdminProgressBatch> _availableInputProgressBatches = const [];
  final Set<String> _scannedMaterialBarcodes = {};
  String _scannedQolipCode = '';
  AdminProgressBatch? _startInputProgressBatch;
  bool _actionInFlight = false;
  bool _materialsLoading = true;
  String _materialsError = '';
  bool _inputProgressLoading = false;
  String _inputProgressError = '';
  bool _mapExpanded = false;

  @override
  void initState() {
    super.initState();
    _queueStates = Map<String, String>.from(widget.initialQueueStates);
    unawaited(_loadMaterialAssignments());
    unawaited(_loadInputProgressBatches());
  }

  @override
  void didUpdateWidget(covariant _ReadOnlyOrderDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldStation = oldWidget.apparatus?.warehouse.trim() ?? '';
    final station = widget.apparatus?.warehouse.trim() ?? '';
    if (oldWidget.order.map.id.trim() != widget.order.map.id.trim() ||
        oldStation != station) {
      _scannedMaterialBarcodes.clear();
      _scannedQolipCode = '';
      _startInputProgressBatch = null;
      _availableInputProgressBatches = const [];
      _inputProgressError = '';
      _inputProgressLoading = false;
      unawaited(_loadInputProgressBatches());
    }
    if (_actionInFlight) {
      return;
    }
    if (station.isEmpty) {
      return;
    }
    final nextStates = _queueStatesForStation(
      station,
      widget.queueStatesByApparatus,
    );
    if (!mapEquals(_queueStates, nextStates)) {
      setState(() => _queueStates = Map<String, String>.from(nextStates));
    }
  }

  Future<void> _loadMaterialAssignments() async {
    setState(() {
      _materialsLoading = true;
      _materialsError = '';
    });
    try {
      final assignments =
          await MobileApi.instance.adminRawMaterialAssignments();
      if (!mounted) {
        return;
      }
      setState(() {
        _materialAssignments = assignments;
        _materialsLoading = false;
        _materialsError = '';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _materialAssignments = const [];
        _materialsLoading = false;
        _materialsError = '';
      });
    }
  }

  Future<void> _runQueueAction(
    String action, {
    _ProgressQtyInput? progressInput,
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
    String driverUrl = '',
    String completionRequestNote = '',
  }) async {
    final prepared = _prepareReadOnlyQueueAction(
      action: action,
      apparatus: widget.apparatus,
      onQueueAction: widget.onQueueAction,
      actionInFlight: _actionInFlight,
      materialAssignments: _materialAssignments,
      scannedMaterialBarcodes: _scannedMaterialBarcodes,
      startInputProgressBatch: _startInputProgressBatch,
      order: widget.order,
    );
    if (prepared == null) {
      return;
    }
    if (prepared.blockReason != null) {
      _showSheetNotice(prepared.blockReason!);
      return;
    }
    final qolipCode = await _qolipCodeForQueueAction(action, prepared);
    if (!mounted || qolipCode == null) {
      return;
    }
    setState(() => _actionInFlight = true);
    try {
      final states = await prepared.onQueueAction(
        _readOnlyQueueActionRequest(
          prepared: prepared,
          order: widget.order,
          action: action,
          progressInput: progressInput,
          uom: uom,
          qrPayload: qrPayload,
          progressBatchId: progressBatchId,
          driverUrl: driverUrl,
          completionRequestNote: completionRequestNote,
          qolipCode: qolipCode,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _actionInFlight = false;
        if (states != null) {
          _queueStates = states.states;
        }
        if (_queueActionShouldClearStartInputProgress(
          action: action,
          result: states,
        )) {
          _startInputProgressBatch = null;
        }
        if (action == 'start' && states != null) {
          _scannedQolipCode = '';
        }
      });
      if (_queueActionShouldReloadMaterials(action: action, result: states)) {
        unawaited(_loadMaterialAssignments());
      }
      if (states != null) {
        unawaited(_loadInputProgressBatches());
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _actionInFlight = false);
      _showSheetNotice(_readOnlyQueueActionErrorText(error));
    }
  }

  Future<String?> _qolipCodeForQueueAction(
    String action,
    _PreparedReadOnlyQueueAction prepared,
  ) async {
    if (action != 'start' ||
        !_apparatusRequiresQolipScan(prepared.apparatus.warehouse)) {
      return '';
    }
    if (_scannedQolipCode.trim().isNotEmpty) {
      return _scannedQolipCode.trim();
    }
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const QolipRawQrScanScreen()),
    );
    if (!mounted || code == null || code.trim().isEmpty) {
      return null;
    }
    setState(() => _scannedQolipCode = code.trim());
    return code.trim();
  }

  Future<void> _runProgressAction(String action) async {
    final input = await _showProgressQtyDialogForApparatus(
      context,
      action: action,
      apparatus: widget.apparatus,
    );
    if (!mounted || input == null) {
      return;
    }
    if (input.isCompletionRequest) {
      await _runQueueAction(
        action,
        completionRequestNote: input.description,
      );
      return;
    }
    final driverUrl = await _pickProgressDriverUrl(
      context,
      widget.progressDriverUrlPicker,
    );
    if (!mounted || driverUrl == null) {
      return;
    }
    await _runQueueAction(
      action,
      progressInput: input,
      uom: 'm',
      driverUrl: driverUrl,
    );
  }

  Future<void> _scanMaterial() async {
    final orderId = widget.order.map.id.trim();
    final materialAssignments = _stationMaterialAssignments(
      assignments: _materialAssignments,
      orderId: orderId,
      station: widget.apparatus?.warehouse.trim() ?? '',
    );
    if (materialAssignments.isEmpty) {
      return;
    }
    final scan = await _scanMaterialAssignmentFromDialog(
      context: context,
      assignments: materialAssignments,
    );
    if (!mounted || scan == null) {
      return;
    }
    final match = scan.assignment;
    if (match == null) {
      _showSheetNotice('Bu homashyo zakazga mos emas');
      return;
    }
    setState(() {
      _scannedMaterialBarcodes.add(_materialBarcodeKey(match.barcode));
    });
    if (_materialScanCompleted(
      assignments: materialAssignments,
      scannedBarcodes: _scannedMaterialBarcodes,
      orderId: orderId,
    )) {
      _showSheetNotice('Homashyolar tasdiqlandi');
    }
  }

  Future<void> _scanStartInputProgressQr(String previousStage) async {
    try {
      final batch = await _scanProgressBatchFromQrDialog(context);
      if (!mounted) {
        return;
      }
      if (batch == null) {
        return;
      }
      if (!_progressBatchMatchesPreviousStage(
        batch: batch,
        orderId: widget.order.map.id.trim(),
        previousStage: previousStage,
      )) {
        _showSheetNotice('Bu QR oldingi bosqich mahsulotiga mos emas');
        return;
      }
      final latest = await _fetchInputProgressBatches(previousStage);
      if (!mounted) {
        return;
      }
      final match = _matchingInputProgressBatch(
        batches: latest,
        batch: batch,
      );
      if (match == null) {
        _showSheetNotice(
          'Bu QR ushbu orderning ${widget.apparatus?.warehouse.trim() ?? ''} WIP listida topilmadi',
        );
        setState(() {
          _availableInputProgressBatches = latest;
          _inputProgressLoading = false;
          _inputProgressError = '';
        });
        return;
      }
      setState(() {
        _availableInputProgressBatches = latest;
        _startInputProgressBatch = match;
        _inputProgressLoading = false;
        _inputProgressError = '';
      });
      _showSheetNotice('Oldingi bosqich QR tasdiqlandi');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSheetNotice(_progressQrLookupErrorText(error));
    }
  }

  Future<void> _loadInputProgressBatches() async {
    final station = widget.apparatus?.warehouse.trim() ?? '';
    if (station.isEmpty) {
      return;
    }
    final previousStage = productionMapPreviousWorkStageStation(
        map: widget.order.map, station: station);
    if (previousStage == null) {
      return;
    }
    setState(() {
      _inputProgressLoading = true;
      _inputProgressError = '';
    });
    try {
      final batches = await _fetchInputProgressBatches(previousStage);
      if (!mounted) {
        return;
      }
      setState(() {
        _availableInputProgressBatches = batches;
        _inputProgressLoading = false;
        _inputProgressError = '';
        if (_startInputProgressBatch != null &&
            _matchingInputProgressBatch(
                  batches: batches,
                  batch: _startInputProgressBatch!,
                ) ==
                null) {
          _startInputProgressBatch = null;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _availableInputProgressBatches = const [];
        _inputProgressLoading = false;
        _inputProgressError = 'WIP ro‘yxati yuklanmadi';
      });
    }
  }

  Future<List<AdminProgressBatch>> _fetchInputProgressBatches(
    String previousStage,
  ) async {
    final station = widget.apparatus?.warehouse.trim() ?? '';
    final batches = await MobileApi.instance.adminWipBatches(
      status: 'all',
      apparatus: previousStage,
      nextApparatus: station,
      orderId: widget.order.map.id.trim(),
      limit: 250,
    );
    return [
      for (final batch in batches)
        if (_progressBatchMatchesPreviousStage(
              batch: batch,
              orderId: widget.order.map.id.trim(),
              previousStage: previousStage,
            ) &&
            _progressBatchCanFeedStation(batch: batch, station: station))
          batch,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.order.map;
    final steps = _linearProductionMapNodes(map);
    final uiState = _readOnlyOrderDetailUiState(
      order: widget.order,
      apparatus: widget.apparatus,
      queueStates: _queueStates,
      queueStatesByApparatus: widget.queueStatesByApparatus,
      materialAssignments: _materialAssignments,
      scannedMaterialBarcodes: _scannedMaterialBarcodes,
      canManageQueue: widget.canManageQueue,
      sequenceOrderIds: widget.sequenceOrderIds,
      visibleOrderIds: widget.visibleOrderIds,
      queuePolicy: widget.queuePolicy,
      startInputProgressBatch: _startInputProgressBatch,
    );

    return _ReadOnlyOrderDetailContent(
      noticeAnchorKey: _noticeAnchorKey,
      map: map,
      steps: steps,
      uiState: uiState,
      queueStates: _queueStates,
      queueStatesByApparatus: widget.queueStatesByApparatus,
      materialsLoading: _materialsLoading,
      materialsError: _materialsError,
      actionInFlight: _actionInFlight,
      previousProgressBatch: _startInputProgressBatch,
      inputProgressBatches: _availableInputProgressBatches,
      inputProgressLoading: _inputProgressLoading,
      inputProgressError: _inputProgressError,
      mapExpanded: _mapExpanded,
      onToggleMapExpanded: () {
        setState(() => _mapExpanded = !_mapExpanded);
      },
      onScan: () => unawaited(_scanMaterial()),
      onProgressScan: uiState.previousStage == null
          ? null
          : () => unawaited(_scanStartInputProgressQr(uiState.previousStage!)),
      onStart: () => unawaited(_runQueueAction('start')),
      onPause: () => unawaited(_runProgressAction('pause')),
      onComplete: () => unawaited(_runProgressAction('complete')),
      onResume: () => unawaited(_runQueueAction('resume')),
    );
  }

  void _showSheetNotice(String message) {
    showAdminTopNotice(
      context,
      message,
      anchorKey: _noticeAnchorKey,
    );
  }
}
