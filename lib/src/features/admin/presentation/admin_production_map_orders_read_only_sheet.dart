part of 'admin_production_map_orders_screen.dart';

const _queueActionUiTimeout = Duration(seconds: 20);
const _queueActionControlRefreshTimeout = Duration(seconds: 5);

class _ReadOnlyOrderDetailSheetState extends State<_ReadOnlyOrderDetailSheet> {
  final GlobalKey _noticeAnchorKey = GlobalKey();
  late Map<String, String> _queueStates;
  late Map<String, String> _stageStates;
  AdminApparatusQueueOrderActionControl? _queueActionControl;
  late AdminOrderControlState _orderControlState;
  late Map<String, AdminOrderControlState> _orderControls;
  List<AdminRawMaterialAssignment> _materialAssignments = const [];
  List<AdminRawMaterialAssignment> _startAssignments = const [];
  List<AdminRawMaterialAssignment> _intakeCandidateAssignments = const [];
  AdminRawMaterialStartRequirements? _materialStartRequirements;
  List<AdminProgressBatch> _availableInputProgressBatches = const [];
  List<AdminOpeningWipBatch> _availableOpeningWipBatches = const [];
  final Set<String> _scannedMaterialBarcodes = {};
  final Map<String, String> _scannedQolipCodes = {};
  final Map<String, AdminProductionMapRequiredQolip> _requiredQolips = {};
  bool _qolipRequirementsLoading = false;
  String _qolipRequirementsError = '';
  String _quickScanStatus = '';
  String _quickScanLocaleCode = '';
  final Set<String> _seenQuickScanValues = <String>{};
  int _quickScanActiveCount = 0;
  int _materialIntakeActiveCount = 0;
  int _materialLoadGeneration = 0;
  AdminProgressBatch? _startInputProgressBatch;
  AdminOpeningWipBatch? _startInputOpeningWipBatch;
  bool _actionInFlight = false;
  bool _lastQueueActionPrintFailed = false;
  bool _materialIntakeMode = false;
  bool _materialsLoading = true;
  String _materialsError = '';
  bool _inputProgressLoading = false;
  String _inputProgressError = '';
  bool _startMaterialsExpanded = false;
  bool _intakeCandidatesExpanded = false;
  bool _materialsExpanded = false;
  bool _qolipsExpanded = false;
  bool _mapExpanded = false;
  bool _summaryExpanded = false;
  ReturnedPaintDraft? _returnedPaintDraft;
  String _returnedPaintDraftScope = '';
  String _unlinkingMaterialBarcode = '';

  bool get _quickScanInFlight => _quickScanActiveCount > 0;

  bool get _materialIntakeInFlight => _materialIntakeActiveCount > 0;

  bool get _isTrainingOrder =>
      widget.order.map.id.trim().startsWith('training-');

  bool get _queueActionContractSynchronized =>
      _queueActionControl?.isConsistentWith(
        _orderControlState,
        queueState: _queueStates[widget.order.map.id.trim()],
      ) ==
      true;

  bool get _allowMaterialUnlink =>
      AppSession.instance.profile?.role == UserRole.materialTaminotchi;

  @override
  void initState() {
    super.initState();
    _queueStates = Map<String, String>.from(widget.initialQueueStates);
    _stageStates = Map<String, String>.from(
      widget.stageStatesByOrderId[widget.order.map.id.trim()] ?? const {},
    );
    _queueActionControl = widget.queueActionControl;
    _orderControls =
        Map<String, AdminOrderControlState>.from(widget.initialOrderControls);
    _orderControlState = adminProductionMapOrderControlFor(
      _orderControls,
      widget.order.map.id.trim(),
    );
    unawaited(_loadInteractionContractAndSections());
    if (widget.startPauseOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runInitialPauseFlow());
      });
    } else if (widget.startAstatkaOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runInitialAstatkaFlow());
      });
    } else if (widget.startWorkerHandoffOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runInitialWorkerHandoffFlow());
      });
    } else if (widget.startRollRemovalOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runInitialRollRemovalFlow());
      });
    } else if (widget.startResumeOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runInitialResumeFlow());
      });
    } else if (widget.initialOrderSwitchBatch != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_runInitialOrderSwitchFlow());
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeCode = context.l10n.locale.languageCode;
    if (_quickScanLocaleCode.isNotEmpty && _quickScanLocaleCode != localeCode) {
      _quickScanStatus = _defaultQuickScanStatus();
      _qolipRequirementsError = '';
      _materialsError = '';
      _inputProgressError = '';
    }
    _quickScanLocaleCode = localeCode;
    if (_quickScanStatus.isEmpty) {
      _quickScanStatus = _defaultQuickScanStatus();
    }
  }

  @override
  void dispose() {
    dismissAdminTopNotice();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ReadOnlyOrderDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldStation = oldWidget.apparatus?.id.trim() ?? '';
    final station = widget.apparatus?.id.trim() ?? '';
    if (!_actionInFlight) {
      _queueActionControl = widget.queueActionControl;
    }
    _stageStates = Map<String, String>.from(
      widget.stageStatesByOrderId[widget.order.map.id.trim()] ?? const {},
    );
    if (oldWidget.order.map.id.trim() != widget.order.map.id.trim() ||
        oldStation != station) {
      _scannedMaterialBarcodes.clear();
      _scannedQolipCodes.clear();
      _requiredQolips.clear();
      _qolipRequirementsLoading = false;
      _qolipRequirementsError = '';
      _materialsExpanded = false;
      _startMaterialsExpanded = false;
      _intakeCandidatesExpanded = false;
      _qolipsExpanded = false;
      _materialIntakeMode = false;
      _seenQuickScanValues.clear();
      _startInputProgressBatch = null;
      _startInputOpeningWipBatch = null;
      _availableInputProgressBatches = const [];
      _availableOpeningWipBatches = const [];
      _quickScanStatus = _defaultQuickScanStatus();
      _inputProgressError = '';
      _inputProgressLoading = false;
      _returnedPaintDraft = null;
      _returnedPaintDraftScope = '';
      _unlinkingMaterialBarcode = '';
      _materialStartRequirements = null;
      _intakeCandidateAssignments = const [];
      _materialsError = '';
      _materialsLoading = true;
      unawaited(_loadInteractionContractAndSections());
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

  bool get _allRequiredQolipsScanned => productionMapAllRequiredQolipsScanned(
        requiredQolipCodes:
            _requiredQolips.values.map((qolip) => qolip.qolipCode),
        scannedQolipCodes: _scannedQolipCodes.values,
      );

  bool get _bypassStartMaterialScan =>
      _queueActionControl?.interaction?.startMaterialsMode !=
      AdminQueueStartMaterialsMode.scanRequired;

  String get _qolipRequirementsStatusText {
    if (_qolipRequirementsLoading) {
      return context.l10n.productionText('worker.mold.requirements.loading');
    }
    if (_qolipRequirementsError.isNotEmpty) {
      return _qolipRequirementsError;
    }
    if (_requiredQolips.isEmpty) {
      return context.l10n.productionText('worker.mold.requirements.empty');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.order.map;
    final steps = _linearProductionMapNodes(map);
    final uiState = _readOnlyOrderDetailUiState(
      order: widget.order,
      apparatus: widget.apparatus,
      queueActionControl: _queueActionControl,
      orderControlState: _orderControlState,
      queueState: _queueStates[widget.order.map.id.trim()],
      materialAssignments: _materialAssignments,
      startMaterialAssignments: _startAssignments,
      intakeCandidateAssignments: _intakeCandidateAssignments,
      materialRequirements: _materialStartRequirements,
      scannedMaterialBarcodes: _scannedMaterialBarcodes,
      canManageQueue: widget.canManageQueue,
      startInputProgressBatch: _startInputProgressBatch,
      startInputOpeningWipBatch: _startInputOpeningWipBatch,
    );
    final requiresQolipScan = uiState.qolipScanRequired;
    final qolipScanAllowsStart =
        !requiresQolipScan || _allRequiredQolipsScanned;
    final materialStartUnavailableReason = _materialStartUnavailableReason(
      materialRequirements: _materialStartRequirements,
      materialsLoading: _materialsLoading,
      materialsError: _materialsError,
      materialScanRequired: uiState.showStartMaterials,
      l10n: context.l10n,
    );
    final materialStartBlockingText = uiState.showStart &&
            !_materialsLoading &&
            materialStartUnavailableReason != null
        ? materialStartUnavailableReason
        : '';
    final materialStartReady = !uiState.showStartMaterials ||
        (!_materialsLoading &&
            materialStartUnavailableReason == null &&
            _materialStartRequirements?.scanSatisfied == true);
    final startMaterialScanPending = uiState.showStart &&
        uiState.showStartMaterials &&
        !_materialsLoading &&
        _materialsError.isEmpty &&
        materialStartUnavailableReason == null &&
        uiState.materialRequiredCount > uiState.materialScannedCount;
    final qolipScanPending = uiState.showStart &&
        requiresQolipScan &&
        !_qolipRequirementsLoading &&
        _qolipRequirementsError.isEmpty &&
        _requiredQolips.isNotEmpty &&
        !_allRequiredQolipsScanned;
    final inputWipScanPending = uiState.showStart &&
        uiState.previousProgressRequired &&
        !uiState.previousProgressReady &&
        !_inputProgressLoading &&
        _inputProgressError.isEmpty &&
        (uiState.openingWipRequired
            ? _availableOpeningWipBatches.isNotEmpty
            : _availableInputProgressBatches.isNotEmpty);
    final materialIntakeScanActive =
        _materialIntakeMode && uiState.materialIntakeAllowed;
    final showQuickScanner = startMaterialScanPending ||
        qolipScanPending ||
        inputWipScanPending ||
        materialIntakeScanActive;
    return PopScope(
      canPop: false,
      child: _ReadOnlyOrderDetailContent(
        noticeAnchorKey: _noticeAnchorKey,
        onClose: () => Navigator.of(context).pop(),
        map: map,
        workerMode: widget.workerMode,
        apparatusCatalog: widget.apparatusCatalog,
        baseMetraj: widget.baseMetraj,
        orderKg: widget.orderKg,
        customerName: widget.customerName,
        steps: steps,
        uiState: uiState,
        showContractWarning: widget.workerMode && widget.canManageQueue,
        pauseLabel: widget.workerMode
            ? context.l10n.productionText(
                _queueActionControl?.interaction?.mode ==
                        AdminQueueInteractionMode.freezeRequested
                    ? 'worker.freeze.safe_stop.action'
                    : 'worker.action.detach_roll',
              )
            : context.l10n.productionText('worker.action.pause'),
        queueStates: _queueStates,
        queueStatesByApparatus: widget.queueStatesByApparatus,
        stageStates: _stageStates,
        materialsLoading: _materialsLoading,
        materialsError: _materialsError,
        materialStartReady: materialStartReady,
        materialStartBlockingText: materialStartBlockingText,
        actionInFlight: _actionInFlight,
        materialIntakeInFlight: _materialIntakeInFlight,
        materialIntakeMode: _materialIntakeMode,
        intakeCandidatesExpanded: _intakeCandidatesExpanded,
        onToggleIntakeCandidatesExpanded: () {
          setState(() {
            _intakeCandidatesExpanded = !_intakeCandidatesExpanded;
          });
        },
        previousProgressBatch: _startInputProgressBatch,
        openingWipBatch: _startInputOpeningWipBatch,
        openingWipBatches: _availableOpeningWipBatches,
        inputProgressBatches: _availableInputProgressBatches,
        inputProgressLoading: _inputProgressLoading,
        inputProgressError: _inputProgressError,
        quickScanStatus: _quickScanStatus,
        quickScanInFlight: _quickScanInFlight,
        showQuickScanner: showQuickScanner,
        allowConcurrentQuickScanner: widget.workerMode,
        onQuickScan: _handleQuickScan,
        requiresQolipScan: requiresQolipScan,
        qolipScanned: qolipScanAllowsStart,
        qolipCodes: _scannedQolipCodes.values.toList(growable: false),
        requiredQolips: _requiredQolips.values.toList(growable: false),
        qolipRequirementsStatusText: _qolipRequirementsStatusText,
        startMaterialsExpanded: _startMaterialsExpanded,
        onToggleStartMaterialsExpanded: () {
          setState(() => _startMaterialsExpanded = !_startMaterialsExpanded);
        },
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
        onTapMapApparatus: _showMapApparatusWipHistory,
        summaryExpanded: _summaryExpanded,
        onToggleSummaryExpanded: () {
          setState(() => _summaryExpanded = !_summaryExpanded);
        },
        onMaterialIntake: _toggleMaterialIntakeMode,
        onStart: () => unawaited(_runQueueAction('start')),
        onPause: () => unawaited(_runProgressAction('pause')),
        onRollComplete: () => unawaited(_runProgressAction('roll_complete')),
        onComplete: () => unawaited(_runProgressAction('complete')),
        onResume: () => unawaited(_runQueueAction('resume')),
        orderControlState: _orderControlState,
        allowMaterialUnlink: _allowMaterialUnlink,
        onUnlinkMaterial: _unlinkMaterialAssignment,
        unlinkingMaterialBarcode: _unlinkingMaterialBarcode,
      ),
    );
  }
}
