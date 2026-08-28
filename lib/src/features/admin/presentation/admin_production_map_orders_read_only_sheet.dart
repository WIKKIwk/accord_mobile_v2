part of 'admin_production_map_orders_screen.dart';

const _queueActionUiTimeout = Duration(seconds: 20);
const _queueActionControlRefreshTimeout = Duration(seconds: 5);

class _MaterialAssignmentsSnapshot {
  const _MaterialAssignmentsSnapshot({
    required this.assignments,
    required this.startAssignments,
    required this.intakeCandidateAssignments,
    required this.requirements,
  });

  final List<AdminRawMaterialAssignment> assignments;
  final List<AdminRawMaterialAssignment> startAssignments;
  final List<AdminRawMaterialAssignment> intakeCandidateAssignments;
  final AdminRawMaterialStartRequirements? requirements;
}

class _ReadOnlyOrderDetailSheet extends StatefulWidget {
  const _ReadOnlyOrderDetailSheet({
    required this.order,
    this.apparatusCatalog = const [],
    this.baseMetraj,
    this.orderKg,
    this.customerName,
    this.apparatus,
    this.canManageQueue = false,
    this.workerMode = false,
    this.initialQueueStates = const {},
    this.queueStatesByApparatus = const {},
    this.stageStatesByOrderId = const {},
    this.queueActionControl,
    this.queuePolicy = ApparatusQueuePolicy.strictSequence,
    this.sequenceOrderIds = const [],
    this.visibleOrderIds = const [],
    this.onQueueAction,
    this.progressDriverUrlPicker,
    this.initialOrderControls = const {},
    this.initialOrderSwitchBatch,
    this.initialPauseRequestId = '',
    this.startPauseOnOpen = false,
    this.startWorkerHandoffOnOpen = false,
    this.startAstatkaOnOpen = false,
    this.startRollRemovalOnOpen = false,
    this.startResumeOnOpen = false,
  });

  final ProductionMapSaved order;
  final List<AdminApparatus> apparatusCatalog;
  final double? baseMetraj;
  final double? orderKg;
  final String? customerName;
  final AdminApparatus? apparatus;
  final bool canManageQueue;
  final bool workerMode;
  final Map<String, String> initialQueueStates;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final Map<String, Map<String, String>> stageStatesByOrderId;
  final AdminApparatusQueueOrderActionControl? queueActionControl;
  final ApparatusQueuePolicy queuePolicy;
  final List<String> sequenceOrderIds;
  final List<String> visibleOrderIds;
  final _ReadOnlyQueueActionCallback? onQueueAction;
  final Future<String?> Function(BuildContext context)? progressDriverUrlPicker;
  final Map<String, AdminOrderControlState> initialOrderControls;
  final AdminProgressBatch? initialOrderSwitchBatch;
  final String initialPauseRequestId;
  final bool startPauseOnOpen;
  final bool startWorkerHandoffOnOpen;
  final bool startAstatkaOnOpen;
  final bool startRollRemovalOnOpen;
  final bool startResumeOnOpen;

  @override
  State<_ReadOnlyOrderDetailSheet> createState() =>
      _ReadOnlyOrderDetailSheetState();
}

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
      _quickScanStatus = context.l10n.productionText('worker.scanner.prompt');
      _qolipRequirementsError = '';
      _materialsError = '';
      _inputProgressError = '';
    }
    _quickScanLocaleCode = localeCode;
    if (_quickScanStatus.isEmpty) {
      _quickScanStatus = context.l10n.productionText('worker.scanner.prompt');
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
      _quickScanStatus = context.l10n.productionText('worker.scanner.prompt');
      _materialIntakeMode = false;
      _seenQuickScanValues.clear();
      _startInputProgressBatch = null;
      _startInputOpeningWipBatch = null;
      _availableInputProgressBatches = const [];
      _availableOpeningWipBatches = const [];
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

  Future<void> _loadInteractionContractAndSections() async {
    if (!_queueActionContractSynchronized) {
      try {
        final refreshed = await _loadCurrentQueueActionControl();
        if (!mounted) return;
        if (refreshed?.isConsistentWith(
              _orderControlState,
              queueState: _queueStates[widget.order.map.id.trim()],
            ) ==
            true) {
          setState(() => _queueActionControl = refreshed);
        } else {
          debugPrint(
            'Invalid production interaction contract for '
            '${widget.order.map.id.trim()} at '
            '${widget.apparatus?.name.trim() ?? ''}',
          );
          setState(() => _queueActionControl = null);
          _showSheetNotice(
            context.l10n.productionText('worker.error.sync'),
          );
        }
      } catch (error) {
        if (!mounted) return;
        debugPrint('Production interaction contract refresh failed: $error');
        setState(() => _queueActionControl = null);
        _showSheetNotice(
          context.l10n.productionText('worker.error.sync'),
        );
      }
    }
    if (!mounted) return;
    await Future.wait([
      _loadMaterialAssignments(),
      _loadInputProgressBatches(),
      _loadQolipRequirements(),
    ]);
  }

  Future<_MaterialAssignmentsSnapshot> _fetchMaterialAssignments({
    required String orderId,
    required String apparatus,
    required List<String> materialBarcodes,
  }) async {
    final isMaterialTaminotchi =
        AppSession.instance.profile?.role == UserRole.materialTaminotchi;
    late final List<AdminRawMaterialAssignment> assignments;
    var startAssignments = const <AdminRawMaterialAssignment>[];
    var intakeCandidates = const <AdminRawMaterialAssignment>[];
    AdminRawMaterialStartRequirements? requirements;
    if (apparatus.isEmpty || isMaterialTaminotchi) {
      assignments = await MobileApi.instance.adminRawMaterialAssignments(
        orderId: orderId,
        apparatus: isMaterialTaminotchi ? '' : apparatus,
      );
    } else {
      final interaction = _queueActionControl?.interaction;
      if (_queueActionContractSynchronized &&
          interaction?.startMaterialsMode ==
              AdminQueueStartMaterialsMode.scanRequired) {
        requirements =
            await MobileApi.instance.adminRawMaterialStartRequirements(
          orderId: orderId,
          apparatus: apparatus,
          materialBarcodes: materialBarcodes,
        );
        assignments = requirements.assignments
            .where(
              (assignment) => assignment.apparatus.trim() == apparatus,
            )
            .toList(growable: false);
        startAssignments = requirements.startAssignments
            .where(
              (assignment) => assignment.apparatus.trim() == apparatus,
            )
            .toList(growable: false);
      } else {
        assignments = await MobileApi.instance.adminRawMaterialAssignments(
          orderId: orderId,
          apparatus: apparatus,
        );
        if (_queueActionContractSynchronized &&
            interaction?.materialIntakeAllowed == true) {
          intakeCandidates =
              await MobileApi.instance.adminRawMaterialIntakeCandidates(
            orderId: orderId,
            apparatus: apparatus,
          );
        }
      }
    }
    return _MaterialAssignmentsSnapshot(
      assignments: assignments,
      startAssignments: startAssignments,
      intakeCandidateAssignments: intakeCandidates,
      requirements: requirements,
    );
  }

  void _applyMaterialAssignmentsSnapshot(
    _MaterialAssignmentsSnapshot snapshot,
  ) {
    final eligibleBarcodes = snapshot.requirements == null
        ? null
        : snapshot.startAssignments
            .map((assignment) => _materialBarcodeKey(assignment.barcode))
            .toSet();
    setState(() {
      _materialAssignments = snapshot.assignments;
      _startAssignments = snapshot.startAssignments;
      _intakeCandidateAssignments = snapshot.intakeCandidateAssignments;
      _materialStartRequirements = snapshot.requirements;
      if (eligibleBarcodes != null) {
        _scannedMaterialBarcodes.removeWhere(
          (barcode) => !eligibleBarcodes.contains(barcode),
        );
      }
      _materialsLoading = false;
      _materialsError = '';
    });
  }

  bool _materialContextIsCurrent(String orderId, String apparatus) {
    return mounted &&
        widget.order.map.id.trim() == orderId &&
        (widget.apparatus?.id.trim() ?? '') == apparatus;
  }

  Future<bool> _loadMaterialAssignments({bool showLoading = true}) async {
    final loadGeneration = ++_materialLoadGeneration;
    final orderId = widget.order.map.id.trim();
    final apparatus = widget.apparatus?.id.trim() ?? '';
    if (mounted) {
      setState(() {
        if (showLoading) {
          _materialsLoading = true;
        }
        _materialsError = '';
      });
    }
    try {
      final snapshot = await _fetchMaterialAssignments(
        orderId: orderId,
        apparatus: apparatus,
        materialBarcodes: _scannedMaterialBarcodes.toList(growable: false),
      );
      if (!mounted ||
          loadGeneration != _materialLoadGeneration ||
          widget.order.map.id.trim() != orderId ||
          (widget.apparatus?.id.trim() ?? '') != apparatus) {
        return false;
      }
      _applyMaterialAssignmentsSnapshot(snapshot);
      return true;
    } catch (error) {
      if (!mounted || loadGeneration != _materialLoadGeneration) {
        return false;
      }
      setState(() {
        _materialAssignments = const [];
        _startAssignments = const [];
        _intakeCandidateAssignments = const [];
        _materialStartRequirements = null;
        _materialsLoading = false;
        _materialsError = _readOnlyQueueActionErrorText(error, context.l10n);
      });
      return false;
    }
  }

  List<AdminRawMaterialAssignment> _startMaterialAssignments() {
    if (_materialStartRequirements == null) {
      // Training materials are attached to the training order even when the
      // backend intentionally hides the normal start-material gate.
      return _isTrainingOrder ? _materialAssignments : const [];
    }
    return _startAssignments;
  }

  Future<void> _unlinkMaterialAssignment(
    AdminRawMaterialAssignment assignment,
  ) async {
    if (!_allowMaterialUnlink ||
        !_rawMaterialAssignmentCanBeUnlinked(assignment) ||
        _unlinkingMaterialBarcode.isNotEmpty) {
      return;
    }
    final confirmed = await showM3ConfirmDialog(
          context: context,
          title: context.l10n.productionText('worker.material.unlink.title'),
          message: context.l10n.productionText(
            'worker.material.unlink.message',
          ),
          cancelLabel: context.l10n.productionText('worker.action.cancel'),
          confirmLabel: context.l10n.productionText(
            'worker.material.unlink.confirm',
          ),
          destructive: true,
          verticalActions: true,
          confirmButtonKey:
              const ValueKey('production-material-confirm-unlink'),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    final barcode = _materialBarcodeKey(assignment.barcode);
    setState(() => _unlinkingMaterialBarcode = barcode);
    try {
      await MobileApi.instance.adminUnlinkRawMaterialAssignment(
        orderId: assignment.orderId,
        barcode: assignment.barcode,
      );
      await _loadMaterialAssignments(showLoading: false);
      if (mounted) {
        _showSheetNotice(
          context.l10n.productionText('worker.material.unlink.success'),
        );
      }
    } on MobileApiException catch (error) {
      if (mounted) {
        _showSheetNotice(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showSheetNotice(
          context.l10n.productionText('worker.material.unlink.failed'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _unlinkingMaterialBarcode = '');
      }
    }
  }

  Future<void> _loadQolipRequirements() async {
    final apparatus = widget.apparatus?.id.trim() ?? '';
    final orderId = widget.order.map.id.trim();
    if (!_queueActionContractSynchronized ||
        _queueActionControl?.interaction?.qolipMode !=
            AdminQueueQolipMode.scanRequired) {
      return;
    }
    if (mounted) {
      setState(() {
        _qolipRequirementsLoading = true;
        _qolipRequirementsError = '';
      });
    }
    try {
      final validation =
          await MobileApi.instance.adminProductionMapQolipRequirements(
        apparatus: apparatus,
        orderId: orderId,
      );
      if (!mounted ||
          widget.apparatus?.id.trim() != apparatus ||
          widget.order.map.id.trim() != orderId) {
        return;
      }
      setState(() {
        _replaceRequiredQolips(validation.requiredQolips);
        _qolipRequirementsLoading = false;
        _qolipRequirementsError = '';
      });
    } catch (error) {
      if (!mounted ||
          widget.apparatus?.id.trim() != apparatus ||
          widget.order.map.id.trim() != orderId) {
        return;
      }
      setState(() {
        _requiredQolips.clear();
        _qolipRequirementsLoading = false;
        _qolipRequirementsError = _readOnlyQueueActionErrorText(
          error,
          context.l10n,
        );
      });
    }
  }

  void _replaceRequiredQolips(
    Iterable<AdminProductionMapRequiredQolip> qolips,
  ) {
    _requiredQolips
      ..clear()
      ..addEntries(
        qolips.where((qolip) => qolip.qolipCode.trim().isNotEmpty).map(
              (qolip) => MapEntry(
                qolip.qolipCode.trim().toLowerCase(),
                qolip,
              ),
            ),
      );
  }

  bool get _allRequiredQolipsScanned => productionMapAllRequiredQolipsScanned(
        requiredQolipCodes:
            _requiredQolips.values.map((qolip) => qolip.qolipCode),
        scannedQolipCodes: _scannedQolipCodes.values,
      );

  bool get _bypassStartMaterialScan =>
      _queueActionControl?.interaction?.startMaterialsMode !=
      AdminQueueStartMaterialsMode.scanRequired;

  bool _completionNeedsFullReport(String action) {
    return action == 'complete' &&
        (_queueActionControl?.completeRequiresFullReport ?? true);
  }

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

  Future<AdminApparatusQueueOrderActionControl?>
      _loadCurrentQueueActionControl() async {
    final apparatus = widget.apparatus?.id.trim() ?? '';
    final orderId = widget.order.map.id.trim();
    if (apparatus.isEmpty || orderId.isEmpty) {
      return null;
    }
    final snapshot = await MobileApi.instance
        .adminProductionMapQueueSnapshot()
        .timeout(_queueActionControlRefreshTimeout);
    final control = snapshot.queueActionControls[apparatus]?[orderId];
    final nextQueueStates = snapshot.queueStates[apparatus];
    final nextStageStates = snapshot.stageStates[orderId];
    final nextOrderControl = snapshot.orderControlFor(orderId);
    if (mounted) {
      setState(() {
        _queueStates = Map<String, String>.from(nextQueueStates ?? const {});
        _stageStates = Map<String, String>.from(nextStageStates ?? const {});
        _orderControls = Map<String, AdminOrderControlState>.from(
          snapshot.orderControls,
        );
        _orderControlState = nextOrderControl;
      });
    }
    if (control?.isConsistentWith(
          nextOrderControl,
          queueState: snapshot.queueStates[apparatus]?[orderId],
        ) !=
        true) {
      return null;
    }
    return control;
  }

  Future<AdminProductionOrderFreezeDetails?>
      _loadAuthoritativeFreezeRequest() async {
    try {
      final control = await _loadCurrentQueueActionControl();
      if (!mounted) return null;
      final request = control?.freezeRequest;
      final apparatus = widget.apparatus?.id.trim() ?? '';
      final initialRequestId = widget.initialPauseRequestId.trim();
      final valid = control != null &&
          control.state.trim() == 'in_progress' &&
          request != null &&
          request.status.trim() == 'pending' &&
          request.requestId.trim().isNotEmpty &&
          request.targetSessionId.trim().isNotEmpty &&
          request.targetApparatus.trim() == apparatus &&
          (initialRequestId.isEmpty ||
              request.requestId.trim() == initialRequestId);
      if (!valid) {
        _showSheetNotice(
          context.l10n.productionText(
            'worker.freeze.safe_stop.metadata_missing',
          ),
        );
        return null;
      }
      setState(() => _queueActionControl = control);
      return request;
    } catch (_) {
      if (mounted) {
        _showSheetNotice(
          context.l10n.productionText(
            'worker.freeze.safe_stop.metadata_missing',
          ),
        );
      }
      return null;
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
    bool workerHandoff = false,
    bool removeRollFromApparatus = false,
    bool freezeWithIssue = false,
    String issueNote = '',
    String freezeRequestId = '',
  }) async {
    final l10n = context.l10n;
    if (!_queueActionContractSynchronized ||
        _queueActionControl?.allows(action) != true) {
      return false;
    }
    AdminApparatusQueueOrderActionControl? latestControl;
    try {
      latestControl = await _loadCurrentQueueActionControl();
    } catch (error) {
      if (mounted) {
        setState(() => _queueActionControl = null);
        _showSheetNotice(l10n.productionText('worker.error.sync'));
      }
      return false;
    }
    if (!mounted) {
      return false;
    }
    final latestQueueState = _queueStates[widget.order.map.id.trim()];
    if (latestControl?.isConsistentWith(
              _orderControlState,
              queueState: latestQueueState,
            ) !=
            true ||
        latestControl?.allows(action) != true) {
      setState(() => _queueActionControl = latestControl);
      _showSheetNotice(l10n.productionText('worker.error.sync'));
      return false;
    }
    setState(() => _queueActionControl = latestControl);
    if (action == 'start' &&
        !_bypassStartMaterialScan &&
        !await _loadMaterialAssignments(showLoading: false)) {
      if (mounted) {
        _showSheetNotice(
          _materialsError.isEmpty
              ? l10n.productionText('worker.error.rule_failed')
              : _materialsError,
        );
      }
      return false;
    }
    final prepared = _prepareReadOnlyQueueAction(
      action: action,
      apparatus: widget.apparatus,
      onQueueAction: widget.onQueueAction,
      actionInFlight: _actionInFlight,
      materialAssignments: _startMaterialAssignments(),
      materialRequirements: _materialStartRequirements,
      materialsLoading: _materialsLoading,
      materialsError: _materialsError,
      queueActionControl: _queueActionControl,
      scannedMaterialBarcodes: _scannedMaterialBarcodes,
      startInputProgressBatch: _startInputProgressBatch,
      startInputOpeningWipBatch: _startInputOpeningWipBatch,
      qolipScanned: _allRequiredQolipsScanned,
      l10n: l10n,
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
    setState(() {
      _actionInFlight = true;
      _lastQueueActionPrintFailed = false;
    });
    try {
      final states = await prepared
          .onQueueAction(
            _readOnlyQueueActionRequest(
              prepared: prepared,
              order: widget.order,
              action: action,
              progressInput: progressInput,
              uom: uom,
              qrPayload: qrPayload,
              progressBatchId: progressBatchId,
              customerName: widget.customerName?.trim().isNotEmpty == true
                  ? widget.customerName!.trim()
                  : widget.order.map.customerName.trim(),
              driverUrl: driverUrl,
              printTransport: printTransport,
              printer: printer,
              printMode: printMode,
              completionRequestNote: completionRequestNote,
              qolipCodes: qolipCodes,
              workerHandoff: workerHandoff,
              removeRollFromApparatus: removeRollFromApparatus,
              freezeWithIssue: freezeWithIssue,
              issueNote: issueNote,
              freezeRequestId: freezeRequestId,
            ),
          )
          .timeout(_queueActionUiTimeout);
      AdminApparatusQueueOrderActionControl? nextActionControl;
      if (states != null) {
        try {
          nextActionControl = await _loadCurrentQueueActionControl();
        } catch (_) {
          nextActionControl = null;
        }
      }
      if (!mounted) {
        return false;
      }
      setState(() {
        _actionInFlight = false;
        if (states != null) {
          _queueStates = states.states;
          if (states.orderControl != null) {
            _orderControlState = states.orderControl!;
            _orderControls[widget.order.map.id.trim()] = states.orderControl!;
          }
          _queueActionControl = nextActionControl;
        }
        if (_queueActionShouldClearStartInputProgress(
          action: action,
          result: states,
        )) {
          _startInputProgressBatch = null;
          _startInputOpeningWipBatch = null;
        }
        if (action == 'start' && states != null) {
          _scannedQolipCodes.clear();
          _requiredQolips.clear();
          _qolipsExpanded = false;
        }
      });
      if (_queueActionShouldReloadMaterials(action: action, result: states)) {
        unawaited(_loadMaterialAssignments());
      }
      if (states != null && nextActionControl == null && mounted) {
        _showSheetNotice(
          context.l10n.productionText('worker.error.sync'),
        );
      }
      if (states != null) {
        unawaited(_loadInputProgressBatches());
      }
      if (states?.completionRequest != null) {
        return false;
      }
      final printJobs = states == null
          ? const <UsbRpsPrintRequest>[]
          : states.printJobs.isNotEmpty
              ? states.printJobs
              : states.printJob == null
                  ? const <UsbRpsPrintRequest>[]
                  : [states.printJob!];
      if (states != null && printTransport.isLocal && printJobs.isNotEmpty) {
        try {
          for (final printJob in printJobs) {
            await PrintService.printRps(
              printJob,
              printerProfile: offlinePrinter,
              bluetoothPrinter: bluetoothPrinter,
              transport: printTransport,
            );
          }
        } catch (_) {
          if (mounted) {
            _lastQueueActionPrintFailed = true;
            _showSheetNotice(
              context.l10n.productionText(
                'worker.notice.action_print_failed',
              ),
            );
          }
        }
      }
      return states != null;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      final requirementsChanged =
          error is MobileApiException && error.code == 'qolip_scan_incomplete';
      setState(() {
        _actionInFlight = false;
        if (action == 'start' && _queueActionShouldClearQolipScan(error)) {
          _scannedQolipCodes.clear();
          if (requirementsChanged) {
            _requiredQolips.clear();
          }
          _qolipsExpanded = false;
        }
      });
      if (requirementsChanged) {
        unawaited(_loadQolipRequirements());
      }
      _showSheetNotice(
        error is TimeoutException
            ? context.l10n.productionText('worker.notice.action_sent')
            : _readOnlyQueueActionErrorText(error, context.l10n),
      );
      return false;
    } finally {
      if (mounted && _actionInFlight) {
        setState(() => _actionInFlight = false);
      }
    }
  }

  List<String>? _qolipCodesForQueueAction(
    String action,
    _PreparedReadOnlyQueueAction prepared,
  ) {
    if (action != 'start' ||
        _queueActionControl?.interaction?.qolipMode !=
            AdminQueueQolipMode.scanRequired) {
      return const [];
    }
    if (_scannedQolipCodes.isNotEmpty) {
      if (_allRequiredQolipsScanned) {
        return _scannedQolipCodes.values.toList(growable: false);
      }
      _showSheetNotice(
        context.l10n.productionText(
          'worker.error.scan_molds_count',
          values: {
            'scanned': _scannedQolipCodes.length,
            'required': _requiredQolips.length,
          },
        ),
      );
      return null;
    }
    _showSheetNotice(
      context.l10n.productionText('worker.error.scan_embedded_mold'),
    );
    return null;
  }

  Future<void> _handleQuickScan(String rawValue) async {
    final normalized = rawMaterialBarcodeFromQr(rawValue).trim();
    final scanKey = normalized.toUpperCase();
    if (normalized.isEmpty || !_seenQuickScanValues.add(scanKey)) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _quickScanActiveCount += 1;
      _quickScanStatus = context.l10n.productionText(
        'worker.scanner.checking',
      );
    });

    try {
      if (_materialIntakeMode) {
        await _receiveAdditionalMaterialFromQuickScan(normalized);
        return;
      }
      final orderId = widget.order.map.id.trim();
      final station = widget.apparatus?.id.trim() ?? '';
      if (_queueActionControl?.interaction?.openingWipMode ==
          AdminQueuePreviousWipMode.scanRequired) {
        _acceptOpeningWipQr(
          orderId: orderId,
          apparatus: station,
          qrPayload: rawValue.trim(),
        );
        return;
      }
      final assignments = _materialStartRequirements == null
          ? (_isTrainingOrder
              ? _materialAssignments
              : const <AdminRawMaterialAssignment>[])
          : _startAssignments;
      final material = _materialAssignmentForScannedBarcode(
        assignments: assignments,
        barcode: normalized,
      );
      if (material != null) {
        final key = _materialBarcodeKey(material.barcode);
        final alreadyScanned = _scannedMaterialBarcodes.contains(key);
        if (mounted) {
          setState(() {
            if (!alreadyScanned) {
              _scannedMaterialBarcodes.add(key);
            }
            _materialStartRequirements = _materialStartRequirements
                ?.withLocalScannedBarcodes(_scannedMaterialBarcodes);
            final complete = _materialStartRequirements?.scanSatisfied == true;
            _quickScanStatus = complete
                ? context.l10n.productionText(
                    'worker.notice.materials_confirmed',
                  )
                : context.l10n.productionText(
                    'worker.notice.material_confirmed_item',
                    values: {
                      'item': material.itemName.trim().isEmpty
                          ? material.itemCode
                          : material.itemName,
                    },
                  );
          });
        }
        return;
      }

      Object? scanError;
      if (_queueActionControl?.interaction?.qolipMode ==
          AdminQueueQolipMode.scanRequired) {
        final requiredQolip = _requiredQolips[normalized.toLowerCase()];
        if (requiredQolip != null) {
          final validatedCode = requiredQolip.qolipCode.trim();
          if (mounted) {
            final key = validatedCode.trim().toLowerCase();
            final alreadyScanned = _scannedQolipCodes.containsKey(key);
            setState(() {
              _scannedQolipCodes[key] = validatedCode.trim();
              _quickScanStatus = alreadyScanned
                  ? context.l10n.productionText(
                      'worker.mold.already_scanned',
                      values: {
                        'scanned': _scannedQolipCodes.length,
                        'required': _requiredQolips.length,
                      },
                    )
                  : context.l10n.productionText(
                      'worker.mold.added',
                      values: {
                        'scanned': _scannedQolipCodes.length,
                        'required': _requiredQolips.length,
                      },
                    );
            });
          }
          return;
        }
        scanError = MobileApiException(
          code: 'qolip_code_mismatch',
          message: context.l10n.productionText('worker.error.machine_flow'),
        );
        // The same QR may be a progress QR on a later production stage.
      }

      final previousStage = _queueActionControl?.previousStage.trim();
      if (previousStage != null && previousStage.isNotEmpty) {
        final batch = _inputProgressBatchForScannedQr(
          batches: _availableInputProgressBatches,
          qrPayload: normalized,
        );
        if (batch != null && _acceptProgressBatch(batch)) {
          return;
        }
        scanError ??= MobileApiException(
          code: 'progress_qr_not_found',
          message: context.l10n.productionText(
            'worker.error.previous_stage_qr',
          ),
        );
      }

      if (mounted) {
        setState(() {
          _quickScanStatus = scanError == null
              ? context.l10n.productionText('worker.error.machine_flow')
              : _readOnlyQueueActionErrorText(scanError, context.l10n);
        });
      }
    } catch (error) {
      if (_quickScanErrorAllowsRetry(error)) {
        _seenQuickScanValues.remove(scanKey);
      }
      if (mounted) {
        setState(() {
          _quickScanStatus = _readOnlyQueueActionErrorText(
            error,
            context.l10n,
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _quickScanActiveCount =
              _quickScanActiveCount > 0 ? _quickScanActiveCount - 1 : 0;
        });
      }
    }
  }

  bool _quickScanErrorAllowsRetry(Object error) {
    return error is TimeoutException || error is http.ClientException;
  }

  bool _acceptOpeningWipQr({
    required String orderId,
    required String apparatus,
    required String qrPayload,
  }) {
    final match = _matchingOpeningWipBatch(
      batches: _availableOpeningWipBatches,
      qrPayload: qrPayload,
    );
    if (!_materialContextIsCurrent(orderId, apparatus)) {
      return false;
    }
    if (match == null) {
      setState(() {
        _startInputOpeningWipBatch = null;
        _inputProgressLoading = false;
        _inputProgressError = '';
        _quickScanStatus = context.l10n.productionText(
          'worker.opening_wip.qr_mismatch',
        );
      });
      return false;
    }
    setState(() {
      _startInputOpeningWipBatch = match;
      _startInputProgressBatch = null;
      _inputProgressLoading = false;
      _inputProgressError = '';
      _quickScanStatus = context.l10n.productionText(
        'worker.opening_wip.confirmed',
      );
    });
    return true;
  }

  bool _acceptProgressBatch(
    AdminProgressBatch batch,
  ) {
    if (!mounted) {
      return false;
    }
    final match = _matchingInputProgressBatch(
      batches: _availableInputProgressBatches,
      batch: batch,
    );
    if (match == null || match.wipStatus.trim().toLowerCase() != 'waiting') {
      setState(() {
        _startInputProgressBatch = null;
        _inputProgressLoading = false;
        _inputProgressError = '';
        _quickScanStatus = context.l10n.productionText(
          'worker.error.previous_stage_qr',
        );
      });
      return false;
    }
    setState(() {
      _startInputProgressBatch = match;
      _inputProgressLoading = false;
      _inputProgressError = '';
      _quickScanStatus = context.l10n.productionText(
        'worker.progress.previous.confirmed',
      );
    });
    return true;
  }

  Future<bool> _confirmAndSwitchToScannedOrder({
    required AdminProgressBatch batch,
    required String station,
  }) async {
    final targetOrderId = batch.orderId.trim();
    if (targetOrderId.isEmpty) {
      return false;
    }
    final snapshot = await MobileApi.instance
        .adminProductionMapQueueSnapshot()
        .timeout(_queueActionControlRefreshTimeout);
    if (!mounted) return false;
    AdminApparatusQueueOrderActionControl? targetControl;
    String? targetQueueState;
    targetControl = snapshot.queueActionControls[station]?[targetOrderId];
    targetQueueState = snapshot.queueStates[station]?[targetOrderId];
    final targetOrderControl = snapshot.orderControlFor(targetOrderId);
    if (targetControl?.isConsistentWith(
              targetOrderControl,
              queueState: targetQueueState,
            ) !=
            true ||
        targetControl?.allows('start') != true) {
      _showSheetNotice(context.l10n.productionText('worker.error.sync'));
      return false;
    }
    final currentInteraction = _queueActionControl?.interaction;
    final operation = widget.apparatus?.operation.trim() ?? '';
    final usesTimelineAstatka = operation == 'laminate' || operation == 'cut';
    final confirmed = await showM3ConfirmDialog(
          context: context,
          title: context.l10n.productionText('worker.order.switch.title'),
          message:
              currentInteraction?.mode == AdminQueueInteractionMode.inProgress
                  ? context.l10n.productionText(
                      'worker.order.switch.complete_current',
                    )
                  : usesTimelineAstatka
                      ? context.l10n.productionText(
                          'worker.order.switch.report_current',
                        )
                      : context.l10n.productionText(
                          'worker.order.switch.stop_current',
                        ),
          cancelLabel: context.l10n.productionText('worker.action.no'),
          confirmLabel: context.l10n.productionText(
            'worker.order.switch.confirm',
          ),
          confirmButtonKey: const ValueKey('production-switch-order-confirm'),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return false;
    }
    if (_queueActionControl?.allows('complete') == true) {
      final outcome = await _runProgressAction(
        'complete',
        fullCompletionReportRequired: true,
      );
      if (outcome != _ProgressActionOutcome.completed || !mounted) {
        return false;
      }
    } else if (usesTimelineAstatka &&
        (currentInteraction?.mode == AdminQueueInteractionMode.paused ||
            currentInteraction?.mode == AdminQueueInteractionMode.completed)) {
      final outcome = await _runAstatkaReport();
      if (outcome != _ProgressActionOutcome.completed || !mounted) {
        return false;
      }
    }
    setState(() {
      _quickScanActiveCount += 1;
      _quickScanStatus = context.l10n.productionText(
        'worker.order.switch.starting',
      );
    });
    try {
      await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: station,
        orderId: targetOrderId,
        action: 'start',
        qrPayload: batch.qrPayload,
        progressBatchId: batch.batchId,
        uom: batch.uom.trim().isEmpty ? 'm' : batch.uom.trim(),
      );
      if (mounted) {
        setState(() {
          _quickScanStatus = context.l10n.productionText(
            'worker.order.switch.started_with_id',
            values: {'order': targetOrderId},
          );
          _startInputProgressBatch = null;
          _startInputOpeningWipBatch = null;
        });
        _showSheetNotice(
          context.l10n.productionText('worker.order.switch.started'),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        setState(
          () => _quickScanStatus = _readOnlyQueueActionErrorText(
            error,
            context.l10n,
          ),
        );
        _showSheetNotice(_readOnlyQueueActionErrorText(error, context.l10n));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _quickScanActiveCount =
              _quickScanActiveCount > 0 ? _quickScanActiveCount - 1 : 0;
        });
      }
    }
  }

  Future<void> _runInitialPauseFlow() async {
    final outcome = await _runProgressAction(
      _orderControlState == AdminOrderControlState.freezeRequested
          ? 'detach_roll'
          : 'pause',
    );
    if (!mounted) return;
    if (outcome == _ProgressActionOutcome.completed) {
      Navigator.of(context).pop(true);
    } else if (outcome == _ProgressActionOutcome.cancelled) {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _runInitialAstatkaFlow() async {
    final outcome = await _runAstatkaReport();
    if (!mounted) return;
    if (outcome == _ProgressActionOutcome.completed ||
        outcome == _ProgressActionOutcome.cancelled) {
      Navigator.of(context).pop(outcome == _ProgressActionOutcome.completed);
    }
  }

  Future<_ProgressActionOutcome> _runAstatkaReport() async {
    if (!mounted) return _ProgressActionOutcome.cancelled;
    final input = await _showProgressQtyDialogForApparatus(
      context,
      action: 'astatka',
      apparatus: widget.apparatus,
      order: widget.order,
      astatkaReport: true,
    );
    if (!mounted || input == null) {
      return _ProgressActionOutcome.cancelled;
    }
    setState(() => _actionInFlight = true);
    try {
      final apparatusId = widget.apparatus?.id ?? '';
      if (widget.apparatus?.operation.trim() == 'cut') {
        await MobileApi.instance.adminRezkaAstatkaReport(
          apparatus: apparatusId,
          orderId: widget.order.map.id,
          totalWaste: input.totalWaste,
          finishedGoodsMeter: input.meterQty,
          finishedGoodsKg: input.kgQty,
          bobinaKg: input.bobinaKg,
          rezkaBosmaWaste: input.rezkaBosmaWaste,
          rezkaLaminationWaste: input.rezkaLaminationWaste,
          rezkaEdgeWaste: input.rezkaEdgeWaste,
          description: input.description,
        );
      } else {
        await MobileApi.instance.adminLaminatsiyaAstatkaReport(
          apparatus: apparatusId,
          orderId: widget.order.map.id,
          finishedGoodsMeter: input.meterQty,
          finishedGoodsKg: input.kgQty,
          bobinaKg: input.bobinaKg,
          laminationPrintLeftoverRolls: input.laminationPrintLeftoverRolls,
          laminationFilmLeftoverRolls: input.laminationFilmLeftoverRolls,
          totalWaste: input.totalWaste,
          description: input.description,
        );
      }
      if (mounted) {
        setState(() => _actionInFlight = false);
        _showSheetNotice(
          context.l10n.productionText('worker.notice.astatka_recorded'),
        );
      }
      return _ProgressActionOutcome.completed;
    } catch (error) {
      if (mounted) {
        setState(() => _actionInFlight = false);
        _showSheetNotice(_readOnlyQueueActionErrorText(error, context.l10n));
      }
      return _ProgressActionOutcome.failed;
    }
  }

  Future<void> _runInitialWorkerHandoffFlow() async {
    final outcome = await _runProgressAction(
      'pause',
      workerHandoff: true,
    );
    if (!mounted) return;
    if (outcome == _ProgressActionOutcome.completed ||
        outcome == _ProgressActionOutcome.cancelled) {
      Navigator.of(context).pop(outcome == _ProgressActionOutcome.completed);
    }
  }

  Future<void> _runInitialRollRemovalFlow() async {
    final outcome = await _runProgressAction(
      'detach_roll',
      removeRollFromApparatus: true,
    );
    if (!mounted) return;
    if (outcome == _ProgressActionOutcome.completed ||
        outcome == _ProgressActionOutcome.cancelled) {
      Navigator.of(context).pop(outcome == _ProgressActionOutcome.completed);
    }
  }

  Future<void> _runInitialResumeFlow() async {
    final completed = await _runQueueAction('resume');
    if (mounted) Navigator.of(context).pop(completed);
  }

  Future<void> _runInitialOrderSwitchFlow() async {
    final batch = widget.initialOrderSwitchBatch;
    final station = widget.apparatus?.id.trim() ?? '';
    if (batch == null || station.isEmpty) {
      return;
    }
    final switched = await _confirmAndSwitchToScannedOrder(
      batch: batch,
      station: station,
    );
    if (switched && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<_ProgressActionOutcome> _runProgressAction(
    String action, {
    bool? fullCompletionReportRequired,
    bool workerHandoff = false,
    bool removeRollFromApparatus = false,
  }) async {
    if (_orderControlState == AdminOrderControlState.frozen) {
      return _ProgressActionOutcome.failed;
    }
    final freezeRequestSafeStop =
        _orderControlState == AdminOrderControlState.freezeRequested;
    final freezeRequest =
        freezeRequestSafeStop ? await _loadAuthoritativeFreezeRequest() : null;
    if (freezeRequestSafeStop && freezeRequest == null) {
      return _ProgressActionOutcome.failed;
    }
    final scope = returnedPaintWorkerDraftScope(
      actorRef: AppSession.instance.profile?.ref ?? '',
      orderId: widget.order.map.id,
      apparatus: widget.apparatus?.id ?? '',
    );
    if (_returnedPaintDraft == null || _returnedPaintDraftScope != scope) {
      _returnedPaintDraft = await ReturnedPaintDraftStore.instance.load(
        scope: scope,
      );
      _returnedPaintDraftScope = scope;
    }
    if (!mounted) return _ProgressActionOutcome.cancelled;
    final rezkaOutputKadrCounts =
        _queueActionControl?.rezkaOutputKadrCounts ?? const <int>[];
    final requiresRezkaOutputs = widget.apparatus?.operation.trim() == 'cut' &&
        !workerHandoff &&
        !removeRollFromApparatus &&
        const {'pause', 'detach_roll', 'roll_complete', 'complete'}
            .contains(action.trim().toLowerCase());
    if (requiresRezkaOutputs && rezkaOutputKadrCounts.isEmpty) {
      _showSheetNotice(context.l10n.productionText('worker.error.sync'));
      return _ProgressActionOutcome.failed;
    }
    final input = await _showProgressQtyDialogForApparatus(
      context,
      action: action,
      apparatus: widget.apparatus,
      order: widget.order,
      returnedPaintDraft: _returnedPaintDraft,
      fullCompletionReportRequired:
          fullCompletionReportRequired ?? _completionNeedsFullReport(action),
      rezkaTotalWasteOnlyCompletionRequired:
          _queueActionControl?.completeRequiresRezkaTotalWasteOnly ?? false,
      workerHandoff: workerHandoff,
      removeRollFromApparatus: removeRollFromApparatus,
      freezeRequestSafeStop: freezeRequestSafeStop,
      rezkaOutputKadrCounts: rezkaOutputKadrCounts,
    );
    if (!mounted || input == null) {
      return _ProgressActionOutcome.cancelled;
    }
    final isTrainingOrder = widget.order.map.id.trim().startsWith('training-');
    if (input.isIssue && freezeRequestSafeStop && !isTrainingOrder) {
      final completed = await _runQueueAction(
        action,
        progressInput: input,
        freezeRequestId: freezeRequest!.requestId,
      );
      if (completed && mounted) {
        _showSheetNotice(
          context.l10n.productionText(
            'worker.freeze.safe_stop.issue_success',
          ),
        );
      }
      return completed
          ? _ProgressActionOutcome.completed
          : _ProgressActionOutcome.failed;
    }
    if (input.isIssue && !isTrainingOrder) {
      final completed = await _runQueueAction(
        'freeze',
        freezeWithIssue: true,
        issueNote: input.description,
      );
      return completed
          ? _ProgressActionOutcome.completed
          : _ProgressActionOutcome.failed;
    }
    if ((workerHandoff || removeRollFromApparatus) && !isTrainingOrder) {
      final completed = await _runQueueAction(
        action,
        progressInput: input,
        uom: 'm',
        workerHandoff: workerHandoff,
        removeRollFromApparatus: removeRollFromApparatus,
        freezeRequestId: freezeRequest?.requestId ?? '',
      );
      return completed
          ? _ProgressActionOutcome.completed
          : _ProgressActionOutcome.failed;
    }
    final hasHealthyRezkaFrame = input.rezkaFrames.isEmpty ||
        input.rezkaFrames.any((frame) => !frame.isIssue);
    if ((action == 'roll_complete' || action == 'complete') &&
        !hasHealthyRezkaFrame &&
        !isTrainingOrder) {
      final completed = await _runQueueAction(
        action,
        progressInput: input,
        uom: 'm',
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
      workerHandoff: workerHandoff,
      removeRollFromApparatus: removeRollFromApparatus,
      freezeRequestId: freezeRequest?.requestId ?? '',
    );
    if (mounted &&
        completed &&
        freezeRequestSafeStop &&
        !_lastQueueActionPrintFailed) {
      _showSheetNotice(
        context.l10n.productionText(
          'worker.freeze.safe_stop.healthy_success',
        ),
      );
    }
    if (completed && action == 'complete') {
      await ReturnedPaintDraftStore.instance.clear(scope);
      _returnedPaintDraft = null;
      _returnedPaintDraftScope = '';
    }
    return completed
        ? _ProgressActionOutcome.completed
        : _ProgressActionOutcome.failed;
  }

  Future<void> _toggleMaterialIntakeMode() async {
    if (_materialIntakeMode) {
      setState(() {
        _materialIntakeMode = false;
        _quickScanStatus = context.l10n.productionText(
          'worker.scanner.prompt',
        );
      });
      return;
    }
    setState(() => _intakeCandidatesExpanded = true);
    if (!await _loadMaterialAssignments(showLoading: false) || !mounted) {
      return;
    }
    if (_intakeCandidateAssignments.isEmpty) {
      setState(() {
        _quickScanStatus = context.l10n.productionText(
          'worker.error.no_pending_material',
        );
      });
      _showSheetNotice(
        context.l10n.productionText('worker.error.no_pending_material'),
      );
      return;
    }
    setState(() {
      _materialIntakeMode = true;
      _intakeCandidatesExpanded = true;
      _quickScanStatus = context.l10n.productionText(
        'worker.scanner.additional_material_prompt',
      );
    });
  }

  Future<void> _receiveAdditionalMaterialFromQuickScan(String barcode) async {
    final orderId = widget.order.map.id.trim();
    final apparatus = widget.apparatus?.id.trim() ?? '';
    if (orderId.isEmpty || apparatus.isEmpty) {
      _showSheetNotice(
        context.l10n.productionText('worker.error.order_machine_missing'),
      );
      return;
    }
    if (mounted) {
      setState(() {
        _materialIntakeActiveCount += 1;
        _quickScanStatus = context.l10n.productionText(
          'worker.scanner.receiving_material',
        );
      });
    }
    try {
      final assignment =
          await MobileApi.instance.adminReceiveRawMaterialForActiveOrder(
        orderId: orderId,
        apparatus: apparatus,
        barcode: barcode,
      );
      if (!mounted) return;
      await _loadMaterialAssignments();
      if (!mounted) return;
      final qty = assignment.receivedQty;
      final uom = assignment.stockUom.trim();
      final quantityLabel =
          qty > 0 && uom.isNotEmpty ? ' (${formatRawQuantity(qty)} $uom)' : '';
      final hasRemainingCandidates = _intakeCandidateAssignments.isNotEmpty;
      setState(() {
        _intakeCandidatesExpanded = true;
        _materialIntakeMode =
            hasRemainingCandidates || _materialIntakeActiveCount > 1;
        _quickScanStatus = hasRemainingCandidates
            ? context.l10n.productionText(
                'worker.notice.material_received',
                values: {'qty': quantityLabel},
              )
            : context.l10n.productionText(
                'worker.notice.all_materials_received',
              );
      });
      _showSheetNotice(
        context.l10n.productionText(
          'worker.notice.material_received_short',
          values: {'qty': quantityLabel},
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _quickScanStatus = _readOnlyQueueActionErrorText(
            error,
            context.l10n,
          );
        });
        _showSheetNotice(_readOnlyQueueActionErrorText(error, context.l10n));
      }
    } finally {
      if (mounted) {
        setState(() {
          _materialIntakeActiveCount = _materialIntakeActiveCount > 0
              ? _materialIntakeActiveCount - 1
              : 0;
        });
      }
    }
  }

  Future<void> _loadInputProgressBatches() async {
    final station = widget.apparatus?.id.trim() ?? '';
    if (station.isEmpty) {
      return;
    }
    final interaction = _queueActionControl?.interaction;
    final openingWipRequired =
        interaction?.openingWipMode == AdminQueuePreviousWipMode.scanRequired;
    final previousWipRequired =
        interaction?.previousWipMode == AdminQueuePreviousWipMode.scanRequired;
    final previousStage = _queueActionControl?.previousStage.trim() ?? '';
    if (!_queueActionContractSynchronized ||
        (!openingWipRequired &&
            (!previousWipRequired || previousStage.isEmpty))) {
      return;
    }
    setState(() {
      _inputProgressLoading = true;
      _inputProgressError = '';
    });
    try {
      if (openingWipRequired) {
        final batches = await MobileApi.instance.adminOpeningWipCandidates(
          apparatus: station,
          orderId: widget.order.map.id.trim(),
        );
        if (!mounted) return;
        setState(() {
          _availableOpeningWipBatches = batches;
          _availableInputProgressBatches = const [];
          _inputProgressLoading = false;
          _inputProgressError = '';
          final currentBatch = _startInputOpeningWipBatch;
          _startInputOpeningWipBatch = currentBatch == null
              ? null
              : _matchingOpeningWipBatch(
                  batches: batches,
                  batchId: currentBatch.batchId,
                  qrPayload: currentBatch.qrPayload,
                );
        });
        return;
      }
      final batches = await _fetchInputProgressBatches(previousStage);
      if (!mounted) {
        return;
      }
      setState(() {
        _availableInputProgressBatches = batches;
        _availableOpeningWipBatches = const [];
        _inputProgressLoading = false;
        _inputProgressError = '';
        final currentBatch = _startInputProgressBatch;
        final matchingCurrentBatch = currentBatch == null
            ? null
            : _matchingInputProgressBatch(
                batches: batches,
                batch: currentBatch,
              );
        _startInputProgressBatch = matchingCurrentBatch;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _availableInputProgressBatches = const [];
        _availableOpeningWipBatches = const [];
        _inputProgressLoading = false;
        _inputProgressError = context.l10n.productionText(
          'worker.wip.load_failed',
        );
      });
    }
  }

  Future<List<AdminProgressBatch>> _fetchInputProgressBatches(
    String previousStage,
  ) async {
    final station = widget.apparatus?.id.trim() ?? '';
    final batches = await MobileApi.instance.adminWipBatches(
      status: 'waiting',
      apparatus: previousStage,
      nextApparatus: station,
      orderId: widget.order.map.id.trim(),
      limit: 250,
    );
    return batches;
  }

  void _showMapApparatusWipHistory(ProductionMapNode node) {
    final apparatusId = _orderMapNodeStationId(node);
    if (node.kind != 'apparatus' || apparatusId.isEmpty) return;

    final apparatus = _canonicalApparatusForId(
      widget.apparatusCatalog,
      apparatusId,
    );
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => _WorkerWipHistorySheet(
          order: widget.order,
          apparatus: apparatus,
          apparatusCatalog: widget.apparatusCatalog,
          sourceApparatusId: apparatusId,
          apparatusTitle: node.title,
        ),
      ),
    );
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

  void _showSheetNotice(String message) {
    showAdminTopNotice(
      context,
      message,
      anchorKey: _noticeAnchorKey,
    );
  }
}
