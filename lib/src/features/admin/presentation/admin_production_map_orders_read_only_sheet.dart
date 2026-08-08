part of 'admin_production_map_orders_screen.dart';

const _queueActionUiTimeout = Duration(seconds: 20);
const _queueActionControlRefreshTimeout = Duration(seconds: 5);

class _ReadOnlyOrderDetailSheet extends StatefulWidget {
  const _ReadOnlyOrderDetailSheet({
    required this.order,
    this.baseMetraj,
    this.orderKg,
    this.customerName,
    this.apparatus,
    this.canManageQueue = false,
    this.workerMode = false,
    this.initialQueueStates = const {},
    this.queueStatesByApparatus = const {},
    this.queueActionControl,
    this.queuePolicy = ApparatusQueuePolicy.strictSequence,
    this.sequenceOrderIds = const [],
    this.visibleOrderIds = const [],
    this.onQueueAction,
    this.progressDriverUrlPicker,
    this.initialOrderControls = const {},
    this.initialOrderSwitchBatch,
    this.initialOrderSwitchPreviousStage = '',
    this.initialPauseRequestId = '',
    this.startPauseOnOpen = false,
    this.startWorkerHandoffOnOpen = false,
    this.startAstatkaOnOpen = false,
    this.startRollRemovalOnOpen = false,
    this.startResumeOnOpen = false,
  });

  final ProductionMapSaved order;
  final double? baseMetraj;
  final double? orderKg;
  final String? customerName;
  final AdminApparatus? apparatus;
  final bool canManageQueue;
  final bool workerMode;
  final Map<String, String> initialQueueStates;
  final Map<String, Map<String, String>> queueStatesByApparatus;
  final AdminApparatusQueueOrderActionControl? queueActionControl;
  final ApparatusQueuePolicy queuePolicy;
  final List<String> sequenceOrderIds;
  final List<String> visibleOrderIds;
  final _ReadOnlyQueueActionCallback? onQueueAction;
  final Future<String?> Function(BuildContext context)? progressDriverUrlPicker;
  final Map<String, AdminOrderControlState> initialOrderControls;
  final AdminProgressBatch? initialOrderSwitchBatch;
  final String initialOrderSwitchPreviousStage;
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
  AdminApparatusQueueOrderActionControl? _queueActionControl;
  late AdminOrderControlState _orderControlState;
  late Map<String, AdminOrderControlState> _orderControls;
  List<AdminRawMaterialAssignment> _materialAssignments = const [];
  List<AdminRawMaterialAssignment> _startAssignments = const [];
  List<AdminRawMaterialAssignment> _intakeCandidateAssignments = const [];
  AdminRawMaterialStartRequirements? _materialStartRequirements;
  List<AdminProgressBatch> _availableInputProgressBatches = const [];
  final Set<String> _scannedMaterialBarcodes = {};
  final Map<String, String> _scannedQolipCodes = {};
  final Map<String, AdminProductionMapRequiredQolip> _requiredQolips = {};
  bool _qolipRequirementsLoading = false;
  String _qolipRequirementsError = '';
  String _quickScanStatus =
      'Qolip yoki homashyo QR kodini tirqishga olib keling';
  bool _quickScanInFlight = false;
  String _lastQuickScanValue = '';
  DateTime? _lastQuickScanAt;
  AdminProgressBatch? _startInputProgressBatch;
  bool _actionInFlight = false;
  bool _materialIntakeInFlight = false;
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

  bool get _allowMaterialUnlink =>
      AppSession.instance.profile?.role == UserRole.materialTaminotchi;

  @override
  void initState() {
    super.initState();
    _queueStates = Map<String, String>.from(widget.initialQueueStates);
    _queueActionControl = widget.queueActionControl;
    _orderControls =
        Map<String, AdminOrderControlState>.from(widget.initialOrderControls);
    _orderControlState = _orderControls[widget.order.map.id.trim()] ??
        AdminOrderControlState.active;
    unawaited(_loadMaterialAssignments());
    unawaited(_loadInputProgressBatches());
    unawaited(_loadQolipRequirements());
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
  void dispose() {
    dismissAdminTopNotice();
    super.dispose();
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
      _requiredQolips.clear();
      _qolipRequirementsLoading = false;
      _qolipRequirementsError = '';
      _materialsExpanded = false;
      _startMaterialsExpanded = false;
      _intakeCandidatesExpanded = false;
      _qolipsExpanded = false;
      _quickScanStatus = 'Qolip yoki homashyo QR kodini tirqishga olib keling';
      _materialIntakeMode = false;
      _lastQuickScanValue = '';
      _lastQuickScanAt = null;
      _startInputProgressBatch = null;
      _availableInputProgressBatches = const [];
      _inputProgressError = '';
      _inputProgressLoading = false;
      _returnedPaintDraft = null;
      _returnedPaintDraftScope = '';
      _unlinkingMaterialBarcode = '';
      _materialStartRequirements = null;
      _intakeCandidateAssignments = const [];
      _materialsError = '';
      _materialsLoading = true;
      unawaited(_loadMaterialAssignments());
      unawaited(_loadInputProgressBatches());
      unawaited(_loadQolipRequirements());
    }
    if (_actionInFlight) {
      return;
    }
    _queueActionControl = widget.queueActionControl;
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

  Future<bool> _loadMaterialAssignments({bool showLoading = true}) async {
    final orderId = widget.order.map.id.trim();
    final apparatus = widget.apparatus?.name.trim() ?? '';
    final isMaterialTaminotchi =
        AppSession.instance.profile?.role == UserRole.materialTaminotchi;
    if (showLoading && mounted) {
      setState(() {
        _materialsLoading = true;
        _materialsError = '';
      });
    }
    try {
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
        final queueState = apparatusQueueOrderStateFromRaw(
          _queueStates[orderId],
        );
        if (queueState == ApparatusQueueOrderState.pending) {
          requirements =
              await MobileApi.instance.adminRawMaterialStartRequirements(
            orderId: orderId,
            apparatus: apparatus,
            materialBarcodes: _scannedMaterialBarcodes.toList(growable: false),
          );
          assignments = requirements.assignments
              .where(
                (assignment) => productionMapWarehouseTitlesMatch(
                  assignment.apparatus,
                  apparatus,
                ),
              )
              .toList(growable: false);
          startAssignments = requirements.startAssignments
              .where(
                (assignment) => productionMapWarehouseTitlesMatch(
                  assignment.apparatus,
                  apparatus,
                ),
              )
              .toList(growable: false);
        } else {
          assignments = await MobileApi.instance.adminRawMaterialAssignments(
            orderId: orderId,
            apparatus: apparatus,
          );
          if (queueState == ApparatusQueueOrderState.inProgress ||
              queueState == ApparatusQueueOrderState.paused) {
            intakeCandidates =
                await MobileApi.instance.adminRawMaterialIntakeCandidates(
              orderId: orderId,
              apparatus: apparatus,
            );
          }
        }
      }
      if (!mounted ||
          widget.order.map.id.trim() != orderId ||
          (widget.apparatus?.name.trim() ?? '') != apparatus) {
        return false;
      }
      final eligibleBarcodes = requirements == null
          ? null
          : startAssignments
              .map((assignment) => _materialBarcodeKey(assignment.barcode))
              .toSet();
      setState(() {
        _materialAssignments = assignments;
        _startAssignments = startAssignments;
        _intakeCandidateAssignments = intakeCandidates;
        _materialStartRequirements = requirements;
        if (eligibleBarcodes != null) {
          _scannedMaterialBarcodes.removeWhere(
            (barcode) => !eligibleBarcodes.contains(barcode),
          );
        }
        _materialsLoading = false;
        _materialsError = '';
      });
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _materialAssignments = const [];
        _startAssignments = const [];
        _intakeCandidateAssignments = const [];
        _materialStartRequirements = null;
        _materialsLoading = false;
        _materialsError = error is MobileApiException
            ? error.message
            : 'Homashyo qoidasi yuklanmadi';
      });
      return false;
    }
  }

  List<AdminRawMaterialAssignment> _startMaterialAssignments() {
    if (_materialStartRequirements == null) return const [];
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
          title: 'Homashyoni uzish',
          message: 'Bu homashyoni zakazdan uzasizmi?',
          cancelLabel: 'Bekor qilish',
          confirmLabel: 'Uzish',
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
        _showSheetNotice('Homashyo zakazdan uzildi');
      }
    } on MobileApiException catch (error) {
      if (mounted) {
        _showSheetNotice(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showSheetNotice('Homashyoni zakazdan uzib bo‘lmaydi');
      }
    } finally {
      if (mounted) {
        setState(() => _unlinkingMaterialBarcode = '');
      }
    }
  }

  Future<void> _loadQolipRequirements() async {
    final apparatus = widget.apparatus?.name.trim() ?? '';
    final orderId = widget.order.map.id.trim();
    if (!_apparatusRequiresQolipScan(apparatus)) {
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
          widget.apparatus?.name.trim() != apparatus ||
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
          widget.apparatus?.name.trim() != apparatus ||
          widget.order.map.id.trim() != orderId) {
        return;
      }
      setState(() {
        _requiredQolips.clear();
        _qolipRequirementsLoading = false;
        _qolipRequirementsError = _readOnlyQueueActionErrorText(error);
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

  bool get _laminatsiyaWipMaterialScanCanBeSkipped {
    final station = widget.apparatus?.name.trim() ?? '';
    final previousStage = _queueActionControl?.previousStage.trim();
    return _laminatsiyaMaterialScanCanBeSkippedForWip(
      station: station,
      previousStage:
          previousStage == null || previousStage.isEmpty ? null : previousStage,
      inputProgressBatches: _availableInputProgressBatches,
    );
  }

  bool get _bypassStartMaterialScan => _laminatsiyaMaterialGateBypassed(
        station: widget.apparatus?.name.trim() ?? '',
        materialRequirements: _materialStartRequirements,
        skipStartMaterialScan: _laminatsiyaWipMaterialScanCanBeSkipped,
      );

  bool _completionNeedsFullReport(String action) {
    return action == 'complete' &&
        (_queueActionControl?.completeRequiresFullReport ?? true);
  }

  String get _qolipRequirementsStatusText {
    if (_qolipRequirementsLoading) {
      return 'Mahsulot qoliplari yuklanmoqda';
    }
    if (_qolipRequirementsError.isNotEmpty) {
      return _qolipRequirementsError;
    }
    if (_requiredQolips.isEmpty) {
      return 'Mahsulotga qolip biriktirilmagan';
    }
    return '';
  }

  Future<AdminApparatusQueueOrderActionControl?>
      _loadCurrentQueueActionControl() async {
    final apparatus = widget.apparatus?.name.trim() ?? '';
    final orderId = widget.order.map.id.trim();
    if (apparatus.isEmpty || orderId.isEmpty) {
      return null;
    }
    final snapshot = await MobileApi.instance
        .adminProductionMapQueueSnapshot()
        .timeout(_queueActionControlRefreshTimeout);
    for (final entry in snapshot.queueActionControls.entries) {
      if (productionMapQueueApparatusTitlesMatch(entry.key, apparatus)) {
        return entry.value[orderId];
      }
    }
    return null;
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
  }) async {
    if (action == 'start' &&
        !_bypassStartMaterialScan &&
        !await _loadMaterialAssignments(showLoading: false)) {
      if (mounted) {
        _showSheetNotice(
          _materialsError.isEmpty
              ? 'Homashyo qoidasi yuklanmadi'
              : _materialsError,
        );
      }
      return false;
    }
    final prepared = _prepareReadOnlyQueueAction(
      action: action,
      apparatus: widget.apparatus,
      order: widget.order,
      onQueueAction: widget.onQueueAction,
      actionInFlight: _actionInFlight,
      materialAssignments: _startAssignments,
      materialRequirements: _materialStartRequirements,
      materialsLoading: _materialsLoading,
      materialsError: _materialsError,
      scannedMaterialBarcodes: _scannedMaterialBarcodes,
      startInputProgressBatch: _startInputProgressBatch,
      qolipScanned: _allRequiredQolipsScanned,
      skipStartMaterialScan: _laminatsiyaWipMaterialScanCanBeSkipped,
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
              freezeRequestId:
                  action == 'pause' ? widget.initialPauseRequestId : '',
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
          if (nextActionControl != null) {
            _queueActionControl = nextActionControl;
          }
        }
        if (_queueActionShouldClearStartInputProgress(
          action: action,
          result: states,
        )) {
          _startInputProgressBatch = null;
        }
        if (action == 'start' && states != null) {
          _scannedQolipCodes.clear();
          _requiredQolips.clear();
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
            _showSheetNotice('Amal bajarildi, local printer chop etmadi');
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
            ? 'Amal serverga yuborildi. Holat avtomatik yangilanadi'
            : _readOnlyQueueActionErrorText(error),
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
        !_apparatusRequiresQolipScan(prepared.apparatus.name)) {
      return const [];
    }
    if (_scannedQolipCodes.isNotEmpty) {
      if (_allRequiredQolipsScanned) {
        return _scannedQolipCodes.values.toList(growable: false);
      }
      _showSheetNotice(
        'Barcha qoliplarni scan qiling '
        '(${_scannedQolipCodes.length}/${_requiredQolips.length} ta)',
      );
      return null;
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
      final validation =
          await MobileApi.instance.adminValidateProductionMapQolipDetails(
        apparatus: widget.apparatus?.name ?? '',
        orderId: widget.order.map.id,
        qolipCode: code,
      );
      final validatedCode = validation.qolipCode;
      if (!mounted) {
        return;
      }
      final key = validatedCode.trim().toLowerCase();
      final alreadyScanned = _scannedQolipCodes.containsKey(key);
      setState(() {
        _replaceRequiredQolips(validation.requiredQolips);
        _scannedQolipCodes[key] = validatedCode.trim();
      });
      final scannedCount = _scannedQolipCodes.length;
      final requiredCount = _requiredQolips.length;
      _showSheetNotice(
        alreadyScanned
            ? 'Bu qolip avval scan qilingan ($scannedCount/$requiredCount ta)'
            : 'Qolip qo‘shildi ($scannedCount/$requiredCount ta)',
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
    if (_materialIntakeMode) {
      await _receiveAdditionalMaterialFromQuickScan(normalized);
      return;
    }
    if (mounted) {
      setState(() {
        _quickScanInFlight = true;
        _quickScanStatus = 'QR tekshirilmoqda...';
      });
    }

    try {
      await _loadMaterialAssignments(showLoading: false);
      if (!mounted) return;
      final orderId = widget.order.map.id.trim();
      final station = widget.apparatus?.name.trim() ?? '';
      final assignments = _startMaterialAssignments();
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
        await _loadMaterialAssignments(showLoading: false);
        if (mounted) {
          final complete = _materialStartRequirements?.scanSatisfied == true;
          setState(() {
            _quickScanStatus = complete
                ? 'Ish boshlash uchun homashyolar tasdiqlandi'
                : '${material.itemName.trim().isEmpty ? material.itemCode : material.itemName} tasdiqlandi';
          });
        }
        return;
      }

      Object? scanError;
      if (_apparatusRequiresQolipScan(station)) {
        try {
          final validation =
              await MobileApi.instance.adminValidateProductionMapQolipDetails(
            apparatus: station,
            orderId: orderId,
            qolipCode: normalized,
          );
          final validatedCode = validation.qolipCode;
          if (mounted) {
            final key = validatedCode.trim().toLowerCase();
            final alreadyScanned = _scannedQolipCodes.containsKey(key);
            setState(() {
              _replaceRequiredQolips(validation.requiredQolips);
              _scannedQolipCodes[key] = validatedCode.trim();
              _quickScanStatus = alreadyScanned
                  ? 'Bu qolip avval scan qilingan '
                      '(${_scannedQolipCodes.length}/${_requiredQolips.length} ta)'
                  : 'Qolip qo‘shildi '
                      '(${_scannedQolipCodes.length}/${_requiredQolips.length} ta)';
            });
          }
          return;
        } catch (error) {
          scanError = error;
          // The same QR may be a progress QR on a later production stage.
        }
      }

      final previousStage = _queueActionControl?.previousStage.trim();
      if (previousStage != null && previousStage.isNotEmpty) {
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

  bool _progressBatchCanStartForStation({
    required AdminProgressBatch batch,
    required String previousStage,
    required String station,
  }) {
    final action = batch.action.trim().toLowerCase();
    final status = batch.status.trim().toLowerCase();
    return batch.orderId.trim().isNotEmpty &&
        batch.wipStatus.trim().toLowerCase() == 'waiting' &&
        productionMapWarehouseTitlesMatch(batch.apparatus, previousStage) &&
        (batch.nextApparatus.trim().isEmpty ||
            productionMapNextStageTitleMatchesApparatus(
              batch.nextApparatus,
              station,
            )) &&
        (action == 'pause' ||
            action == 'detach_roll' ||
            action == 'roll_complete' ||
            action == 'complete') &&
        (status == 'paused' ||
            status == 'roll_detached' ||
            status == 'completed' ||
            status == 'resumed');
  }

  Future<bool> _confirmAndSwitchToScannedOrder({
    required AdminProgressBatch batch,
    required String previousStage,
    required String station,
  }) async {
    if (!_progressBatchCanStartForStation(
      batch: batch,
      previousStage: previousStage,
      station: station,
    )) {
      if (mounted) {
        setState(() => _quickScanStatus = 'Bu WIP QR ushbu aparatga mos emas');
      }
      return false;
    }
    final currentOrderId = widget.order.map.id.trim();
    final targetOrderId = batch.orderId.trim();
    final currentState = apparatusQueueOrderStateFromRaw(
      _queueStates[currentOrderId],
    );
    final usesTimelineAstatka = productionMapApparatusUsesTimelineAstatka(
      widget.apparatus?.name ?? '',
    );
    final confirmed = await showM3ConfirmDialog(
          context: context,
          title: 'Boshqa order aniqlandi',
          message: currentState == ApparatusQueueOrderState.inProgress
              ? 'Bu QR boshqa orderga tegishli. Hozirgi ishni to‘liq tugatib, '
                  'yangi orderni boshlaysizmi?'
              : usesTimelineAstatka
                  ? 'Bu QR boshqa orderga tegishli. Hozirgi ish uchun astatka '
                      'qayd qilib, yangi orderni boshlaysizmi?'
                  : 'Bu QR boshqa orderga tegishli. Hozirgi ishni to‘xtatib, '
                      'yangi orderni boshlaysizmi?',
          cancelLabel: 'Yo‘q',
          confirmLabel: 'Ha, boshlash',
          confirmButtonKey: const ValueKey('production-switch-order-confirm'),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return false;
    }
    if (currentState == ApparatusQueueOrderState.inProgress) {
      final outcome = await _runProgressAction(
        'complete',
        fullCompletionReportRequired: true,
      );
      if (outcome != _ProgressActionOutcome.completed || !mounted) {
        return false;
      }
    } else if (usesTimelineAstatka &&
        (currentState == ApparatusQueueOrderState.paused ||
            currentState == ApparatusQueueOrderState.completed)) {
      final outcome = await _runAstatkaReport();
      if (outcome != _ProgressActionOutcome.completed || !mounted) {
        return false;
      }
    }
    setState(() {
      _quickScanInFlight = true;
      _quickScanStatus = 'Yangi order boshlanmoqda...';
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
          _quickScanStatus = 'Yangi order boshlandi: $targetOrderId';
          _startInputProgressBatch = null;
        });
        _showSheetNotice('Yangi order boshlandi');
      }
      return true;
    } catch (error) {
      if (mounted) {
        setState(() => _quickScanStatus = _readOnlyQueueActionErrorText(error));
        _showSheetNotice(_readOnlyQueueActionErrorText(error));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _quickScanInFlight = false);
      }
    }
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
      final apparatus = widget.apparatus?.name ?? '';
      if (productionMapIsRezkaApparatus(apparatus)) {
        await MobileApi.instance.adminRezkaAstatkaReport(
          apparatus: apparatus,
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
          apparatus: apparatus,
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
        _showSheetNotice('Order astatkasi qayd qilindi');
      }
      return _ProgressActionOutcome.completed;
    } catch (error) {
      if (mounted) {
        setState(() => _actionInFlight = false);
        _showSheetNotice(_readOnlyQueueActionErrorText(error));
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
    final previousStage = widget.initialOrderSwitchPreviousStage.trim();
    final station = widget.apparatus?.name.trim() ?? '';
    if (batch == null || previousStage.isEmpty || station.isEmpty) {
      return;
    }
    final switched = await _confirmAndSwitchToScannedOrder(
      batch: batch,
      previousStage: previousStage,
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
      fullCompletionReportRequired:
          fullCompletionReportRequired ?? _completionNeedsFullReport(action),
      workerHandoff: workerHandoff,
      removeRollFromApparatus: removeRollFromApparatus,
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
        workerHandoff: workerHandoff,
        removeRollFromApparatus: removeRollFromApparatus,
      );
      return completed
          ? _ProgressActionOutcome.completed
          : _ProgressActionOutcome.failed;
    }
    if (workerHandoff || removeRollFromApparatus) {
      final completed = await _runQueueAction(
        action,
        progressInput: input,
        uom: 'm',
        workerHandoff: workerHandoff,
        removeRollFromApparatus: removeRollFromApparatus,
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
    if (!await _loadMaterialAssignments(showLoading: false) || !mounted) {
      _showSheetNotice(
        _materialsError.isEmpty
            ? 'Homashyo qoidasi yuklanmadi'
            : _materialsError,
      );
      return;
    }
    final requirements = _materialStartRequirements;
    final materialAssignments = _startMaterialAssignments();
    if (requirements == null || materialAssignments.isEmpty) {
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
    await _loadMaterialAssignments(showLoading: false);
    if (mounted && _materialStartRequirements?.scanSatisfied == true) {
      _showSheetNotice('Ish boshlash uchun homashyolar tasdiqlandi');
    }
  }

  Future<void> _toggleMaterialIntakeMode() async {
    if (_materialIntakeMode) {
      setState(() {
        _materialIntakeMode = false;
        _quickScanStatus =
            'Qolip yoki homashyo QR kodini tirqishga olib keling';
      });
      return;
    }
    setState(() => _intakeCandidatesExpanded = true);
    if (!await _loadMaterialAssignments(showLoading: false) || !mounted) {
      return;
    }
    if (_intakeCandidateAssignments.isEmpty) {
      setState(() {
        _quickScanStatus = 'Hali qabul qilinmagan homashyo yo‘q';
      });
      _showSheetNotice('Hali qabul qilinmagan homashyo yo‘q');
      return;
    }
    setState(() {
      _materialIntakeMode = true;
      _intakeCandidatesExpanded = true;
      _quickScanStatus =
          'Qo‘shimcha homashyo QR kodini yuqoridagi tirqishga olib keling';
    });
  }

  Future<void> _receiveAdditionalMaterialFromQuickScan(String barcode) async {
    if (_materialIntakeInFlight) return;
    final orderId = widget.order.map.id.trim();
    final apparatus = widget.apparatus?.name.trim() ?? '';
    if (orderId.isEmpty || apparatus.isEmpty) {
      _showSheetNotice('Zakaz yoki aparat topilmadi');
      return;
    }
    if (mounted) {
      setState(() {
        _quickScanInFlight = true;
        _materialIntakeInFlight = true;
        _quickScanStatus = 'Qo‘shimcha homashyo qabul qilinmoqda...';
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
        _materialIntakeMode = hasRemainingCandidates;
        _quickScanStatus = hasRemainingCandidates
            ? 'Homashyo qabul qilindi$quantityLabel. Yana QR scan qiling'
            : 'Barcha kutilayotgan homashyolar qabul qilindi';
      });
      _showSheetNotice('Homashyo qabul qilindi$quantityLabel');
    } catch (error) {
      if (mounted) {
        setState(() {
          _quickScanStatus = _readOnlyQueueActionErrorText(error);
        });
        _showSheetNotice(_readOnlyQueueActionErrorText(error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _quickScanInFlight = false;
          _materialIntakeInFlight = false;
        });
      }
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
    final previousStage = _queueActionControl?.previousStage.trim();
    if (previousStage == null || previousStage.isEmpty) {
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
      queueActionControl: _queueActionControl,
      materialAssignments: _materialAssignments,
      startMaterialAssignments: _startAssignments,
      intakeCandidateAssignments: _intakeCandidateAssignments,
      materialRequirements: _materialStartRequirements,
      scannedMaterialBarcodes: _scannedMaterialBarcodes,
      canManageQueue: widget.canManageQueue,
      startInputProgressBatch: _startInputProgressBatch,
      skipStartMaterialScan: _laminatsiyaWipMaterialScanCanBeSkipped,
    );
    final requiresQolipScan = _apparatusRequiresQolipScan(uiState.station);
    final qolipScanAllowsStart =
        !requiresQolipScan || _allRequiredQolipsScanned;
    return _ReadOnlyOrderDetailContent(
      noticeAnchorKey: _noticeAnchorKey,
      map: map,
      baseMetraj: widget.baseMetraj,
      orderKg: widget.orderKg,
      customerName: widget.customerName,
      steps: steps,
      uiState: uiState,
      pauseLabel: widget.workerMode ? 'Rulonni yechish' : 'Pauza',
      queueStates: _queueStates,
      queueStatesByApparatus: widget.queueStatesByApparatus,
      materialsLoading: _materialsLoading,
      materialsError: _materialsError,
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
      inputProgressBatches: _availableInputProgressBatches,
      inputProgressLoading: _inputProgressLoading,
      inputProgressError: _inputProgressError,
      quickScanStatus: _quickScanStatus,
      quickScanInFlight: _quickScanInFlight,
      showQuickScanner: uiState.showStart ||
          (_materialIntakeMode && (uiState.showPause || uiState.showResume)),
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
      summaryExpanded: _summaryExpanded,
      onToggleSummaryExpanded: () {
        setState(() => _summaryExpanded = !_summaryExpanded);
      },
      onScan: () => unawaited(_scanMaterial()),
      onMaterialIntake: _toggleMaterialIntakeMode,
      onProgressScan: uiState.previousStage == null
          ? null
          : () => unawaited(_scanStartInputProgressQr(uiState.previousStage!)),
      onQolipScan: () => unawaited(_scanQolip()),
      onStart: () => unawaited(_runQueueAction('start')),
      onPause: () => unawaited(
        _runProgressAction(widget.workerMode ? 'detach_roll' : 'pause'),
      ),
      onRollComplete: () => unawaited(_runProgressAction('roll_complete')),
      onComplete: () => unawaited(_runProgressAction('complete')),
      onResume: () => unawaited(_runQueueAction('resume')),
      orderControlState: _orderControlState,
      allowMaterialUnlink: _allowMaterialUnlink,
      onUnlinkMaterial: _unlinkMaterialAssignment,
      unlinkingMaterialBarcode: _unlinkingMaterialBarcode,
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
