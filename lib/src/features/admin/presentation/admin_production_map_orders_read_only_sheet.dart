part of 'admin_production_map_orders_screen.dart';

class _ReadOnlyOrderDetailSheet extends StatefulWidget {
  const _ReadOnlyOrderDetailSheet({
    required this.order,
    this.baseMetraj,
    this.orderKg,
    this.customerName,
    this.apparatus,
    this.canManageQueue = false,
    this.initialQueueStates = const {},
    this.queueStatesByApparatus = const {},
    this.queuePolicy = ApparatusQueuePolicy.strictSequence,
    this.sequenceOrderIds = const [],
    this.visibleOrderIds = const [],
    this.onQueueAction,
    this.progressDriverUrlPicker,
    this.initialOrderControls = const {},
    this.initialPauseRequestId = '',
    this.startPauseOnOpen = false,
  });

  final ProductionMapSaved order;
  final double? baseMetraj;
  final double? orderKg;
  final String? customerName;
  final AdminApparatus? apparatus;
  final bool canManageQueue;
  final Map<String, String> initialQueueStates;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final ApparatusQueuePolicy queuePolicy;
  final List<String> sequenceOrderIds;
  final List<String> visibleOrderIds;
  final _ReadOnlyQueueActionCallback? onQueueAction;
  final Future<String?> Function(BuildContext context)? progressDriverUrlPicker;
  final Map<String, AdminOrderControlState> initialOrderControls;
  final String initialPauseRequestId;
  final bool startPauseOnOpen;

  @override
  State<_ReadOnlyOrderDetailSheet> createState() =>
      _ReadOnlyOrderDetailSheetState();
}

class _ReadOnlyOrderDetailSheetState extends State<_ReadOnlyOrderDetailSheet> {
  final GlobalKey _noticeAnchorKey = GlobalKey();
  late Map<String, String> _queueStates;
  late AdminOrderControlState _orderControlState;
  late Map<String, AdminOrderControlState> _orderControls;
  StreamSubscription<AdminProductionMapLiveSnapshot>? _controlLiveSubscription;
  List<AdminRawMaterialAssignment> _materialAssignments = const [];
  List<AdminProgressBatch> _availableInputProgressBatches = const [];
  final Set<String> _scannedMaterialBarcodes = {};
  final Map<String, String> _scannedQolipCodes = {};
  String _quickScanStatus =
      'Qolip yoki homashyo QR kodini tirqishga olib keling';
  bool _quickScanInFlight = false;
  String _lastQuickScanValue = '';
  DateTime? _lastQuickScanAt;
  AdminProgressBatch? _startInputProgressBatch;
  bool _actionInFlight = false;
  bool _materialsLoading = true;
  String _materialsError = '';
  bool _inputProgressLoading = false;
  String _inputProgressError = '';
  bool _materialsExpanded = false;
  bool _qolipsExpanded = false;
  bool _mapExpanded = false;
  bool _summaryExpanded = false;
  ReturnedPaintDraft? _returnedPaintDraft;
  String _returnedPaintDraftScope = '';

  @override
  void initState() {
    super.initState();
    _queueStates = Map<String, String>.from(widget.initialQueueStates);
    _orderControls =
        Map<String, AdminOrderControlState>.from(widget.initialOrderControls);
    _orderControlState = _orderControls[widget.order.map.id.trim()] ??
        AdminOrderControlState.active;
    if (widget.canManageQueue) {
      _controlLiveSubscription =
          MobileApi.instance.adminProductionMapLiveEvents().listen(
                _applyOrderControlLiveSnapshot,
                onError: (_, __) {},
              );
    }
    unawaited(_loadMaterialAssignments());
    unawaited(_loadInputProgressBatches());
    if (widget.startPauseOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runInitialPauseFlow());
      });
    }
  }

  @override
  void dispose() {
    unawaited(_controlLiveSubscription?.cancel());
    super.dispose();
  }

  void _applyOrderControlLiveSnapshot(
    AdminProductionMapLiveSnapshot snapshot,
  ) {
    if (!mounted) return;
    final orderId = widget.order.map.id.trim();
    final station = widget.apparatus?.name.trim() ?? '';
    final nextControls =
        Map<String, AdminOrderControlState>.from(snapshot.orderControls);
    final nextControl = nextControls[orderId] ?? AdminOrderControlState.active;
    final nextStates = _queueStatesForStation(
      station,
      snapshot.queueStates,
    );
    if (nextControl == _orderControlState &&
        mapEquals(nextStates, _queueStates)) {
      return;
    }
    setState(() {
      _orderControlState = nextControl;
      _orderControls = nextControls;
      _queueStates = Map<String, String>.from(nextStates);
    });
  }

  @override
  void didUpdateWidget(covariant _ReadOnlyOrderDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldStation = oldWidget.apparatus?.name.trim() ?? '';
    final station = widget.apparatus?.name.trim() ?? '';
    if (oldWidget.order.map.id.trim() != widget.order.map.id.trim() ||
        oldStation != station) {
      _scannedMaterialBarcodes.clear();
      _scannedQolipCodes.clear();
      _materialsExpanded = false;
      _qolipsExpanded = false;
      _quickScanStatus = 'Qolip yoki homashyo QR kodini tirqishga olib keling';
      _lastQuickScanValue = '';
      _lastQuickScanAt = null;
      _startInputProgressBatch = null;
      _availableInputProgressBatches = const [];
      _inputProgressError = '';
      _inputProgressLoading = false;
      _returnedPaintDraft = null;
      _returnedPaintDraftScope = '';
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

  Future<bool> _runQueueAction(
    String action, {
    _ProgressQtyInput? progressInput,
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
    String driverUrl = '',
    PrintTransport printTransport = PrintTransport.wifi,
    String printer = '',
    String printMode = '',
    UsbPrinterProfile? offlinePrinter,
    BluetoothPrinterProfile? bluetoothPrinter,
    String completionRequestNote = '',
  }) async {
    if (_orderControlState == AdminOrderControlState.frozen) {
      _showSheetNotice('Buyurtma muzlatilgan');
      return false;
    }
    if (_orderControlState == AdminOrderControlState.freezeRequested &&
        action != 'pause') {
      _showSheetNotice('Buyurtmani muzlatish uchun pauza qiling');
      return false;
    }
    final prepared = _prepareReadOnlyQueueAction(
      action: action,
      apparatus: widget.apparatus,
      order: widget.order,
      onQueueAction: widget.onQueueAction,
      actionInFlight: _actionInFlight,
      materialAssignments: _materialAssignments,
      scannedMaterialBarcodes: _scannedMaterialBarcodes,
      startInputProgressBatch: _startInputProgressBatch,
      qolipScanned: _scannedQolipCodes.isNotEmpty,
    );
    if (prepared == null) {
      return false;
    }
    if (prepared.blockReason != null) {
      _showSheetNotice(prepared.blockReason!);
      return false;
    }
    final qolipCodes = _qolipCodesForQueueAction(action, prepared);
    if (!mounted || qolipCodes == null) {
      return false;
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
          printTransport: printTransport,
          printer: printer,
          printMode: printMode,
          completionRequestNote: completionRequestNote,
          qolipCodes: qolipCodes,
          freezeRequestId:
              action == 'pause' ? widget.initialPauseRequestId : '',
        ),
      );
      if (!mounted) {
        return false;
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
          _scannedQolipCodes.clear();
          _qolipsExpanded = false;
        }
        if (action == 'pause' &&
            states != null &&
            _orderControlState == AdminOrderControlState.freezeRequested) {
          _orderControlState = AdminOrderControlState.frozen;
          _orderControls[widget.order.map.id.trim()] =
              AdminOrderControlState.frozen;
        }
      });
      if (_queueActionShouldReloadMaterials(action: action, result: states)) {
        unawaited(_loadMaterialAssignments());
      }
      if (states != null) {
        unawaited(_loadInputProgressBatches());
      }
      if (states != null && printTransport.isLocal && states.printJob != null) {
        try {
          await PrintService.printRps(
            states.printJob!,
            printerProfile: offlinePrinter,
            bluetoothPrinter: bluetoothPrinter,
            transport: printTransport,
          );
        } catch (_) {
          if (mounted) {
            _showSheetNotice('Amal bajarildi, local printer chop etmadi');
          }
        }
      }
      return states != null;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _actionInFlight = false;
        if (action == 'start' && _queueActionShouldClearQolipScan(error)) {
          _scannedQolipCodes.clear();
          _qolipsExpanded = false;
        }
      });
      _showSheetNotice(_readOnlyQueueActionErrorText(error));
      return false;
    }
  }

  List<String>? _qolipCodesForQueueAction(
    String action,
    _PreparedReadOnlyQueueAction prepared,
  ) {
    if (action != 'start' ||
        !_apparatusRequiresQolipScan(prepared.apparatus.name)) {
      return const [];
    }
    if (_scannedQolipCodes.isNotEmpty) {
      return _scannedQolipCodes.values.toList(growable: false);
    }
    _showSheetNotice(
      'Avval yuqoridagi embedded scanner orqali qolip QR scan qiling',
    );
    return null;
  }

  Future<void> _scanQolip() async {
    final code = await showRawMaterialScanDialog(
      context,
      title: 'Qolip QR',
      manualLabel: 'Qolip kodi',
    );
    if (!mounted || code == null || code.trim().isEmpty) {
      return;
    }
    try {
      final validatedCode =
          await MobileApi.instance.adminValidateProductionMapQolip(
        apparatus: widget.apparatus?.name ?? '',
        orderId: widget.order.map.id,
        qolipCode: code,
      );
      if (!mounted) {
        return;
      }
      final key = validatedCode.trim().toLowerCase();
      final alreadyScanned = _scannedQolipCodes.containsKey(key);
      setState(() => _scannedQolipCodes[key] = validatedCode.trim());
      _showSheetNotice(
        alreadyScanned
            ? 'Bu qolip avval scan qilingan (${_scannedQolipCodes.length} ta)'
            : 'Qolip qo‘shildi (${_scannedQolipCodes.length} ta)',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSheetNotice(_readOnlyQueueActionErrorText(error));
    }
  }

  Future<void> _handleQuickScan(String rawValue) async {
    final normalized = rawMaterialBarcodeFromQr(rawValue).trim();
    if (normalized.isEmpty) {
      return;
    }
    final now = DateTime.now();
    if (_lastQuickScanValue == normalized &&
        _lastQuickScanAt != null &&
        now.difference(_lastQuickScanAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastQuickScanValue = normalized;
    _lastQuickScanAt = now;
    if (mounted) {
      setState(() {
        _quickScanInFlight = true;
        _quickScanStatus = 'QR tekshirilmoqda...';
      });
    }

    try {
      final orderId = widget.order.map.id.trim();
      final station = widget.apparatus?.name.trim() ?? '';
      final assignments = _stationMaterialAssignments(
        assignments: _materialAssignments,
        orderId: orderId,
        station: station,
      );
      final material = _materialAssignmentForScannedBarcode(
        assignments: assignments,
        barcode: normalized,
      );
      if (material != null) {
        final key = _materialBarcodeKey(material.barcode);
        final alreadyScanned = _scannedMaterialBarcodes.contains(key);
        if (!alreadyScanned && mounted) {
          setState(() => _scannedMaterialBarcodes.add(key));
        }
        if (mounted) {
          final complete = _materialScanCompleted(
            assignments: assignments,
            scannedBarcodes: _scannedMaterialBarcodes,
            orderId: orderId,
          );
          setState(() {
            _quickScanStatus = complete
                ? 'Barcha homashyolar tasdiqlandi'
                : '${material.itemName.trim().isEmpty ? material.itemCode : material.itemName} tasdiqlandi';
          });
        }
        return;
      }

      Object? scanError;
      if (_apparatusRequiresQolipScan(station)) {
        try {
          final validatedCode =
              await MobileApi.instance.adminValidateProductionMapQolip(
            apparatus: station,
            orderId: orderId,
            qolipCode: normalized,
          );
          if (mounted) {
            final key = validatedCode.trim().toLowerCase();
            final alreadyScanned = _scannedQolipCodes.containsKey(key);
            setState(() {
              _scannedQolipCodes[key] = validatedCode.trim();
              _quickScanStatus = alreadyScanned
                  ? 'Bu qolip avval scan qilingan (${_scannedQolipCodes.length} ta)'
                  : 'Qolip qo‘shildi (${_scannedQolipCodes.length} ta)';
            });
          }
          return;
        } catch (error) {
          scanError = error;
          // The same QR may be a progress QR on a later production stage.
        }
      }

      final previousStage = productionMapPreviousWorkStageStation(
        map: widget.order.map,
        station: station,
      );
      if (previousStage != null && _startInputProgressBatch == null) {
        try {
          final batch = await MobileApi.instance.adminProgressQrLookup(
            normalized,
          );
          final accepted = await _acceptProgressBatch(batch, previousStage);
          if (accepted) {
            return;
          }
          return;
        } catch (error) {
          scanError ??= error;
          // Unknown QR values are reported below and scanning continues.
        }
      }

      if (mounted) {
        setState(() {
          _quickScanStatus = scanError == null
              ? 'Bu QR ushbu order uchun mos emas'
              : _readOnlyQueueActionErrorText(scanError);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _quickScanInFlight = false);
      }
    }
  }

  Future<bool> _acceptProgressBatch(
    AdminProgressBatch batch,
    String previousStage,
  ) async {
    if (!_progressBatchMatchesPreviousStage(
      batch: batch,
      orderId: widget.order.map.id.trim(),
      previousStage: previousStage,
    )) {
      if (mounted) {
        setState(() => _quickScanStatus = 'Bu QR oldingi bosqichga mos emas');
      }
      return false;
    }
    final latest = await _fetchInputProgressBatches(previousStage);
    if (!mounted) {
      return false;
    }
    final match = _matchingInputProgressBatch(batches: latest, batch: batch);
    if (match == null) {
      setState(() {
        _availableInputProgressBatches = latest;
        _inputProgressLoading = false;
        _inputProgressError = '';
        _quickScanStatus = 'Bu WIP QR ushbu order ro‘yxatida topilmadi';
      });
      return false;
    }
    setState(() {
      _availableInputProgressBatches = latest;
      _startInputProgressBatch = match;
      _inputProgressLoading = false;
      _inputProgressError = '';
      _quickScanStatus = 'Oldingi bosqich QR tasdiqlandi';
    });
    return true;
  }

  Future<void> _runInitialPauseFlow() async {
    final outcome = await _runProgressAction('pause');
    if (!mounted) return;
    if (outcome == _ProgressActionOutcome.completed) {
      Navigator.of(context).pop(true);
    } else if (outcome == _ProgressActionOutcome.cancelled) {
      Navigator.of(context).pop(false);
    }
  }

  Future<_ProgressActionOutcome> _runProgressAction(String action) async {
    final scope = returnedPaintWorkerDraftScope(
      actorRef: AppSession.instance.profile?.ref ?? '',
      orderId: widget.order.map.id,
      apparatus: widget.apparatus?.name ?? '',
    );
    if (_returnedPaintDraft == null || _returnedPaintDraftScope != scope) {
      _returnedPaintDraft = await ReturnedPaintDraftStore.instance.load(
        scope: scope,
      );
      _returnedPaintDraftScope = scope;
    }
    if (!mounted) return _ProgressActionOutcome.cancelled;
    final input = await _showProgressQtyDialogForApparatus(
      context,
      action: action,
      apparatus: widget.apparatus,
      order: widget.order,
      returnedPaintDraft: _returnedPaintDraft,
    );
    if (!mounted || input == null) {
      return _ProgressActionOutcome.cancelled;
    }
    if (input.isCompletionRequest) {
      final completed = await _runQueueAction(
        action,
        progressInput: input,
        uom: 'm',
        completionRequestNote: input.description,
      );
      return completed
          ? _ProgressActionOutcome.completed
          : _ProgressActionOutcome.failed;
    }
    final printerOption = await _pickProgressPrinter(
      context,
      widget.progressDriverUrlPicker,
    );
    if (!mounted || printerOption == null) {
      return _ProgressActionOutcome.cancelled;
    }
    final completed = await _runQueueAction(
      action,
      progressInput: input,
      uom: 'm',
      driverUrl: printerOption.driverUrl,
      printTransport: printerOption.transport,
      printer: printerOption.printer,
      printMode: printerOption.printMode,
      offlinePrinter: printerOption.offlinePrinter,
      bluetoothPrinter: printerOption.bluetoothPrinter,
    );
    if (completed && action == 'complete') {
      await ReturnedPaintDraftStore.instance.clear(scope);
      _returnedPaintDraft = null;
      _returnedPaintDraftScope = '';
    }
    return completed
        ? _ProgressActionOutcome.completed
        : _ProgressActionOutcome.failed;
  }

  Future<void> _scanMaterial() async {
    final orderId = widget.order.map.id.trim();
    final materialAssignments = _stationMaterialAssignments(
      assignments: _materialAssignments,
      orderId: orderId,
      station: widget.apparatus?.name.trim() ?? '',
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
      final accepted = await _acceptProgressBatch(batch, previousStage);
      if (accepted && mounted) {
        _showSheetNotice('Oldingi bosqich QR tasdiqlandi');
      } else if (mounted) {
        _showSheetNotice(_quickScanStatus);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSheetNotice(_progressQrLookupErrorText(error));
    }
  }

  Future<void> _loadInputProgressBatches() async {
    final station = widget.apparatus?.name.trim() ?? '';
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
    final station = widget.apparatus?.name.trim() ?? '';
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
      orderControlState: _orderControlState,
      orderControlsByOrderId: _orderControls,
    );
    final requiresQolipScan = _apparatusRequiresQolipScan(uiState.station);
    final qolipScanAllowsStart =
        !requiresQolipScan || _scannedQolipCodes.isNotEmpty;

    return _ReadOnlyOrderDetailContent(
      noticeAnchorKey: _noticeAnchorKey,
      map: map,
      baseMetraj: widget.baseMetraj,
      orderKg: widget.orderKg,
      customerName: widget.customerName,
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
      quickScanStatus: _quickScanStatus,
      quickScanInFlight: _quickScanInFlight,
      showQuickScanner: uiState.showStart,
      onQuickScan: _handleQuickScan,
      requiresQolipScan: requiresQolipScan,
      qolipScanned: qolipScanAllowsStart,
      qolipCodes: _scannedQolipCodes.values.toList(growable: false),
      materialsExpanded: _materialsExpanded,
      onToggleMaterialsExpanded: () {
        setState(() => _materialsExpanded = !_materialsExpanded);
      },
      qolipsExpanded: _qolipsExpanded,
      onToggleQolipsExpanded: () {
        setState(() => _qolipsExpanded = !_qolipsExpanded);
      },
      mapExpanded: _mapExpanded,
      onToggleMapExpanded: () {
        setState(() => _mapExpanded = !_mapExpanded);
      },
      summaryExpanded: _summaryExpanded,
      onToggleSummaryExpanded: () {
        setState(() => _summaryExpanded = !_summaryExpanded);
      },
      onScan: () => unawaited(_scanMaterial()),
      onProgressScan: uiState.previousStage == null
          ? null
          : () => unawaited(_scanStartInputProgressQr(uiState.previousStage!)),
      onQolipScan: () => unawaited(_scanQolip()),
      onStart: () => unawaited(_runQueueAction('start')),
      onPause: () => unawaited(_runProgressAction('pause')),
      onComplete: () => unawaited(_runProgressAction('complete')),
      onResume: () => unawaited(_runQueueAction('resume')),
      orderControlState: _orderControlState,
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
