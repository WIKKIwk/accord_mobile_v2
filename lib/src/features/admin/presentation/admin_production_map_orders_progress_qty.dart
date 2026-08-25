part of 'admin_production_map_orders_screen.dart';

class _RezkaFrameInput {
  const _RezkaFrameInput({
    this.meterQty,
    this.kgQty,
    this.bobinaKg,
    this.diameter,
    this.issueNote = '',
  });

  final double? meterQty;
  final double? kgQty;
  final double? bobinaKg;
  final double? diameter;
  final String issueNote;

  bool get isIssue => issueNote.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        if (meterQty != null) 'produced_qty': meterQty,
        if (kgQty != null) 'gross_qty': kgQty,
        if (kgQty != null) 'finished_goods_kg': kgQty,
        if (meterQty != null) 'finished_goods_meter': meterQty,
        if (bobinaKg != null) 'bobina_kg': bobinaKg,
        if (diameter != null) 'diameter': diameter,
        if (issueNote.trim().isNotEmpty) 'issue_note': issueNote.trim(),
      };
}

class _RezkaFrameControllers {
  final meter = TextEditingController();
  final kg = TextEditingController();
  final bobina = TextEditingController();
  final diameter = TextEditingController();
  final issueNote = TextEditingController();

  void dispose() {
    issueNote.dispose();
    meter.dispose();
    kg.dispose();
    bobina.dispose();
    diameter.dispose();
  }
}

class _ProgressQtyInput {
  const _ProgressQtyInput({
    this.meterQty,
    this.kgQty,
    this.bobinaKg,
    this.diameter,
    this.returnInkKg,
    this.laminationPrintLeftoverRolls,
    this.laminationFilmLeftoverRolls,
    this.rezkaBosmaWaste,
    this.rezkaLaminationWaste,
    this.rezkaEdgeWaste,
    this.totalWaste,
    this.finishedGoodsKg,
    this.finishedGoodsMeter,
    this.returnedPaintItems = const [],
    this.returnedPaintImageId = '',
    this.description = '',
    this.isIssue = false,
    this.fullCompletionReportRequired = false,
    this.rezkaFrames = const [],
  });

  final double? meterQty;
  final double? kgQty;
  final double? bobinaKg;
  final double? diameter;
  final double? returnInkKg;
  final double? laminationPrintLeftoverRolls;
  final double? laminationFilmLeftoverRolls;
  final double? rezkaBosmaWaste;
  final double? rezkaLaminationWaste;
  final double? rezkaEdgeWaste;
  final double? totalWaste;
  final double? finishedGoodsKg;
  final double? finishedGoodsMeter;
  final List<ReturnedPaintItemInput> returnedPaintItems;
  final String returnedPaintImageId;
  final String description;
  final bool isIssue;
  final bool fullCompletionReportRequired;
  final List<_RezkaFrameInput> rezkaFrames;
}

Future<_ProgressQtyInput?> _showProgressQtyDialog(
  BuildContext context,
  String action, {
  required ProductionMapSaved order,
  required String apparatus,
  required bool isBosma,
  required bool isLaminatsiya,
  required bool isRezka,
  ReturnedPaintDraft? returnedPaintDraft,
  bool fullCompletionReportRequired = false,
  bool workerHandoff = false,
  bool removeRollFromApparatus = false,
  bool astatkaReport = false,
  bool freezeRequestSafeStop = false,
}) async {
  final draft = returnedPaintDraft ??
      await ReturnedPaintDraftStore.instance.load(
        scope: returnedPaintWorkerDraftScope(
          actorRef: AppSession.instance.profile?.ref ?? '',
          orderId: order.map.id,
          apparatus: apparatus,
        ),
      );
  if (!context.mounted) return null;
  return showDialog<_ProgressQtyInput>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => _ProgressQtyDialog(
      action: action,
      order: order,
      apparatus: apparatus,
      isBosma: isBosma,
      isLaminatsiya: isLaminatsiya,
      isRezka: isRezka,
      returnedPaintDraft: draft,
      fullCompletionReportRequired: fullCompletionReportRequired,
      workerHandoff: workerHandoff,
      removeRollFromApparatus: removeRollFromApparatus,
      astatkaReport: astatkaReport,
      freezeRequestSafeStop: freezeRequestSafeStop,
    ),
  );
}

Future<_ProgressQtyInput?> _showProgressQtyDialogForApparatus(
  BuildContext context, {
  required String action,
  required AdminApparatus? apparatus,
  required ProductionMapSaved order,
  ReturnedPaintDraft? returnedPaintDraft,
  bool fullCompletionReportRequired = false,
  bool workerHandoff = false,
  bool removeRollFromApparatus = false,
  bool astatkaReport = false,
  bool freezeRequestSafeStop = false,
}) {
  final apparatusId = apparatus?.id ?? '';
  final operation = apparatus?.operation.trim() ?? '';
  return _showProgressQtyDialog(
    context,
    action,
    order: order,
    apparatus: apparatusId,
    isBosma: operation == 'print',
    isLaminatsiya: operation == 'laminate',
    isRezka: operation == 'cut',
    returnedPaintDraft: returnedPaintDraft,
    fullCompletionReportRequired: fullCompletionReportRequired,
    workerHandoff: workerHandoff,
    removeRollFromApparatus: removeRollFromApparatus,
    astatkaReport: astatkaReport,
    freezeRequestSafeStop: freezeRequestSafeStop,
  );
}

Widget _progressQtySectionLabel(BuildContext context, String label) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  return Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: theme.textTheme.labelLarge?.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ProgressQtyDialog extends StatefulWidget {
  const _ProgressQtyDialog({
    required this.action,
    required this.order,
    required this.apparatus,
    required this.isBosma,
    required this.isLaminatsiya,
    required this.isRezka,
    required this.returnedPaintDraft,
    required this.fullCompletionReportRequired,
    required this.workerHandoff,
    required this.removeRollFromApparatus,
    required this.astatkaReport,
    required this.freezeRequestSafeStop,
  });

  final String action;
  final ProductionMapSaved order;
  final String apparatus;
  final bool isBosma;
  final bool isLaminatsiya;
  final bool isRezka;
  final ReturnedPaintDraft returnedPaintDraft;
  final bool fullCompletionReportRequired;
  final bool workerHandoff;
  final bool removeRollFromApparatus;
  final bool astatkaReport;
  final bool freezeRequestSafeStop;

  @override
  State<_ProgressQtyDialog> createState() => _ProgressQtyDialogState();
}

class _ProgressQtyDialogState extends State<_ProgressQtyDialog> {
  final _meterController = TextEditingController();
  final _kgController = TextEditingController();
  final _bobinaController = TextEditingController();
  final _diameterController = TextEditingController();
  final _printLeftoverController = TextEditingController();
  final _filmLeftoverController = TextEditingController();
  final _rezkaBosmaWasteController = TextEditingController();
  final _rezkaLaminationWasteController = TextEditingController();
  final _rezkaEdgeWasteController = TextEditingController();
  final _wasteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _completionError = '';
  late final List<_RezkaFrameControllers> _rezkaFrameControllers;
  final Set<int> _rezkaFrameIssuePrompted = <int>{};

  ReturnedPaintDraft get _returnedPaintDraft => widget.returnedPaintDraft;

  List<ReturnedPaintItemInput> get _returnedPaintItems =>
      _requiresFullCompletionReport
          ? returnedPaintItemsFromDraft(_returnedPaintDraft)
          : const [];

  bool get _isComplete => widget.action == 'complete';

  bool get _requiresFullCompletionReport =>
      _isComplete && widget.fullCompletionReportRequired;

  bool get _isWorkerHandoff => widget.workerHandoff;

  bool get _isAstatkaReport => widget.astatkaReport;

  bool get _isRollRemoval => widget.removeRollFromApparatus;

  bool get _isFreezeRequestSafeStop => widget.freezeRequestSafeStop;

  int get _rezkaFrameCount {
    final node = _rezkaNodeForStation(
      map: widget.order.map,
      station: widget.apparatus,
    );
    final count = node?.rezkaKadrCount ?? 0;
    return count > 0 ? count : 0;
  }

  bool get _isRezkaProgressLabelAction => const {
        'pause',
        'detach_roll',
        'roll_complete',
        'complete',
      }.contains(widget.action.trim().toLowerCase());

  bool get _showRezkaFrameInputs =>
      widget.isRezka &&
      !_isAstatkaReport &&
      !_isWorkerHandoff &&
      !_isRollRemoval &&
      _isRezkaProgressLabelAction &&
      _rezkaFrameCount > 0;

  @override
  void initState() {
    super.initState();
    _rezkaFrameControllers = [
      for (var index = 0; index < _rezkaFrameCount; index += 1)
        _RezkaFrameControllers(),
    ];
    for (final frame in _rezkaFrameControllers) {
      frame.meter.addListener(_onRezkaFrameInputChanged);
      frame.kg.addListener(_onRezkaFrameInputChanged);
      frame.bobina.addListener(_onRezkaFrameInputChanged);
      frame.diameter.addListener(_onRezkaFrameInputChanged);
      frame.issueNote.addListener(_onRezkaFrameInputChanged);
    }
  }

  void _onRezkaFrameInputChanged() {
    if (!mounted) {
      return;
    }
    for (var index = 0; index < _rezkaFrameControllers.length; index += 1) {
      final frame = _rezkaFrameControllers[index];
      if (_rezkaFrameMetricsComplete(frame)) {
        _rezkaFrameIssuePrompted.remove(index);
        if (frame.issueNote.text.trim().isNotEmpty) {
          frame.issueNote.clear();
        }
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _wasteController.dispose();
    _rezkaEdgeWasteController.dispose();
    _rezkaLaminationWasteController.dispose();
    _rezkaBosmaWasteController.dispose();
    _filmLeftoverController.dispose();
    _printLeftoverController.dispose();
    _diameterController.dispose();
    _bobinaController.dispose();
    _kgController.dispose();
    _meterController.dispose();
    for (final frame in _rezkaFrameControllers) {
      frame.dispose();
    }
    super.dispose();
  }

  double? _parseQty(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> _openReturnedPaintSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ReturnedPaintSheet(
        draft: _returnedPaintDraft,
        orderId: widget.order.map.id,
        apparatus: widget.apparatus,
        allowImageEditing: true,
      ),
    );
  }

  Widget _qtyField({
    required TextEditingController controller,
    required String label,
    required String error,
    Key? key,
    String suffix = '',
    bool? requiredField,
    bool positive = false,
    bool allowZero = false,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      decoration: appSurfaceInputDecoration(
        context,
        labelText: label,
        suffixText: suffix.isEmpty ? null : suffix,
      ),
      validator: (value) {
        final trimmed = (value ?? '').trim();
        final fieldMustBeFilled =
            requiredField ?? (!_isComplete || !_requiresFullCompletionReport);
        if (trimmed.isEmpty) {
          return fieldMustBeFilled ? error : null;
        }
        final qty = _parseQty(trimmed);
        if (qty == null || !qty.isFinite || qty < 0) {
          return context.l10n.productionText(
            'worker.progress.qty.invalid_number',
          );
        }
        if (!allowZero &&
            (positive || !_isComplete || !_requiresFullCompletionReport) &&
            qty == 0) {
          return context.l10n.productionText(
            'worker.progress.qty.positive_number',
          );
        }
        return null;
      },
    );
  }

  bool _hasPositiveQty(TextEditingController controller) {
    final qty = _parseQty(controller.text);
    return qty != null && qty.isFinite && qty > 0;
  }

  bool _rezkaFrameMetricsComplete(_RezkaFrameControllers frame) {
    final values = [
      _parseQty(frame.meter.text),
      _parseQty(frame.kg.text),
      _parseQty(frame.bobina.text),
      _parseQty(frame.diameter.text),
    ];
    return values.every(
      (value) => value != null && value.isFinite && value > 0,
    );
  }

  bool _rezkaFrameHasAnyMetric(_RezkaFrameControllers frame) {
    return [frame.meter, frame.kg, frame.bobina, frame.diameter].any(
      (controller) => controller.text.trim().isNotEmpty,
    );
  }

  bool _rezkaFrameIssueAllowed(
    int index,
    _RezkaFrameControllers frame,
  ) {
    return (widget.action == 'roll_complete' || widget.action == 'complete') &&
        widget.isRezka &&
        _rezkaFrameIssuePrompted.contains(index) &&
        !_rezkaFrameMetricsComplete(frame);
  }

  List<_RezkaFrameInput>? _readRezkaFrameInputs({
    String fallbackIssueNote = '',
  }) {
    if (!_showRezkaFrameInputs) {
      return const [];
    }
    final frames = <_RezkaFrameInput>[];
    for (var index = 0; index < _rezkaFrameControllers.length; index += 1) {
      final frame = _rezkaFrameControllers[index];
      final meter = _parseQty(frame.meter.text);
      final kg = _parseQty(frame.kg.text);
      final bobina = _parseQty(frame.bobina.text);
      final diameter = _parseQty(frame.diameter.text);
      final issueNote = frame.issueNote.text.trim().isEmpty
          ? fallbackIssueNote.trim()
          : frame.issueNote.text.trim();
      if (issueNote.isNotEmpty) {
        if (!_rezkaFrameIssueAllowed(index, frame)) {
          return null;
        }
        frames.add(_RezkaFrameInput(issueNote: issueNote));
        continue;
      }
      if (!_rezkaFrameMetricsComplete(frame)) {
        return null;
      }
      frames.add(
        _RezkaFrameInput(
          meterQty: meter,
          kgQty: kg,
          bobinaKg: bobina,
          diameter: diameter,
        ),
      );
    }
    return frames;
  }

  void _submit() {
    setState(() => _completionError = '');
    final description = _descriptionController.text.trim();
    final hasRawOutput = <TextEditingController>[
      _meterController,
      _kgController,
      _bobinaController,
      _diameterController,
      _printLeftoverController,
      _filmLeftoverController,
      _rezkaBosmaWasteController,
      _rezkaLaminationWasteController,
      _rezkaEdgeWasteController,
      _wasteController,
      for (final frame in _rezkaFrameControllers) ...[
        frame.meter,
        frame.kg,
        frame.bobina,
        frame.diameter,
      ],
    ].any((controller) => controller.text.trim().isNotEmpty);
    final frameIssueMode = _showRezkaFrameInputs &&
        !_isFreezeRequestSafeStop &&
        (widget.action == 'roll_complete' || widget.action == 'complete');
    if (frameIssueMode) {
      final incompleteFrameIndexes = [
        for (var index = 0; index < _rezkaFrameControllers.length; index += 1)
          if (!_rezkaFrameMetricsComplete(_rezkaFrameControllers[index])) index,
      ];
      final hasNewIncompleteFrame = incompleteFrameIndexes.any(
        (index) => !_rezkaFrameIssuePrompted.contains(index),
      );
      if (hasNewIncompleteFrame) {
        setState(() {
          _rezkaFrameIssuePrompted.addAll(incompleteFrameIndexes);
        });
        return;
      }
    }
    if (_isFreezeRequestSafeStop && !hasRawOutput) {
      if (description.isNotEmpty) {
        Navigator.of(context).pop(
          _ProgressQtyInput(description: description, isIssue: true),
        );
      } else {
        setState(() {
          _completionError = context.l10n.productionText(
            'worker.freeze.safe_stop.output_or_issue_required',
          );
        });
      }
      return;
    }
    if (_isComplete && description.isNotEmpty && !_showRezkaFrameInputs) {
      Navigator.of(context).pop(
        _ProgressQtyInput(description: description, isIssue: true),
      );
      return;
    }
    final formValid = _formKey.currentState?.validate() ?? false;

    final meterQty = _parseQty(_meterController.text);
    final kgQty = _parseQty(_kgController.text);
    final bobinaKg = _parseQty(_bobinaController.text);
    final diameter = _parseQty(_diameterController.text);
    if (_requiresFullCompletionReport &&
        widget.isBosma &&
        returnedPaintDraftHasInvalidValues(_returnedPaintDraft)) {
      setState(() {
        _completionError = context.l10n.productionText(
          'worker.progress.qty.returned_paint_invalid',
        );
      });
      return;
    }
    final returnedPaintItems = _returnedPaintItems;
    final rawReturnInkKg = _requiresFullCompletionReport
        ? returnedPaintAstatkaTotal(returnedPaintItems)
        : null;
    final returnInkKg =
        rawReturnInkKg != null && rawReturnInkKg.isFinite && rawReturnInkKg > 0
            ? rawReturnInkKg
            : null;
    final returnedPaintImageId = _requiresFullCompletionReport
        ? (_returnedPaintDraft.image?.imageId.trim() ?? '')
        : '';
    final returnedPaintFieldCount =
        returnedPaintFilledFieldCount(returnedPaintItems);
    final rasxotFieldCount = returnedPaintFilledFieldCountForUsage(
      returnedPaintItems,
      'rasxot',
    );
    final astatkaFieldCount = returnedPaintFilledFieldCountForUsage(
      returnedPaintItems,
      'astatka',
    );
    final returnedPaintValid = returnedPaintReportCanClose(
      items: returnedPaintItems,
      imageId: returnedPaintImageId,
    );
    if (_requiresFullCompletionReport &&
        widget.isBosma &&
        !returnedPaintValid) {
      setState(() {
        _completionError = returnedPaintFieldCount > 0
            ? context.l10n.productionText(
                'worker.progress.qty.returned_paint_min',
                values: {
                  'rasxot': rasxotFieldCount,
                  'astatka': astatkaFieldCount,
                },
              )
            : context.l10n.productionText(
                'worker.progress.qty.returned_paint_image',
              );
      });
      return;
    }
    final printLeftoverRolls = _parseQty(_printLeftoverController.text);
    final filmLeftoverRolls = _parseQty(_filmLeftoverController.text);
    final rezkaBosmaWaste = _parseQty(_rezkaBosmaWasteController.text);
    final rezkaLaminationWaste =
        _parseQty(_rezkaLaminationWasteController.text);
    final rezkaEdgeWaste = _parseQty(_rezkaEdgeWasteController.text);
    final totalWaste = _parseQty(_wasteController.text);
    final allFrameMetricsEmpty = _rezkaFrameControllers.every(
      (frame) => !_rezkaFrameHasAnyMetric(frame),
    );
    final frameIssueFallback =
        (widget.action == 'roll_complete' || widget.action == 'complete') &&
                widget.isRezka &&
                allFrameMetricsEmpty
            ? description
            : '';
    final rezkaFrameInputs = _readRezkaFrameInputs(
      fallbackIssueNote: frameIssueFallback,
    );
    if (_showRezkaFrameInputs && rezkaFrameInputs == null) {
      setState(() {
        _completionError = context.l10n.productionText(
          widget.action == 'roll_complete'
              ? 'worker.freeze.safe_stop.output_or_issue_required'
              : 'worker.progress.qty.completion_reason',
        );
      });
      return;
    }
    _RezkaFrameInput? firstRezkaFrame;
    for (final frame in rezkaFrameInputs ?? const <_RezkaFrameInput>[]) {
      if (!frame.isIssue) {
        firstRezkaFrame = frame;
        break;
      }
    }
    final effectiveMeterQty = firstRezkaFrame?.meterQty ?? meterQty;
    final effectiveKgQty = firstRezkaFrame?.kgQty ?? kgQty;
    final effectiveBobinaKg = firstRezkaFrame?.bobinaKg ?? bobinaKg;
    final effectiveDiameter = firstRezkaFrame?.diameter ?? diameter;
    final hasMeter = effectiveMeterQty != null &&
        effectiveMeterQty.isFinite &&
        effectiveMeterQty > 0;
    final hasKg =
        effectiveKgQty != null && effectiveKgQty.isFinite && effectiveKgQty > 0;
    final hasBobina = effectiveBobinaKg != null &&
        effectiveBobinaKg.isFinite &&
        effectiveBobinaKg > 0;
    final hasDiameter = effectiveDiameter != null &&
        effectiveDiameter.isFinite &&
        effectiveDiameter > 0;
    final hasRezkaFrameMetrics = rezkaFrameInputs != null &&
        rezkaFrameInputs.isNotEmpty &&
        rezkaFrameInputs.length == _rezkaFrameCount;
    final allRezkaFramesIssue = hasRezkaFrameMetrics &&
        rezkaFrameInputs.every((frame) => frame.isIssue);
    final hasPrintLeftover = printLeftoverRolls != null &&
        printLeftoverRolls.isFinite &&
        printLeftoverRolls > 0;
    final hasFilmLeftover = filmLeftoverRolls != null &&
        filmLeftoverRolls.isFinite &&
        filmLeftoverRolls > 0;
    final hasRezkaBosmaWaste = rezkaBosmaWaste != null &&
        rezkaBosmaWaste.isFinite &&
        rezkaBosmaWaste > 0;
    final hasRezkaLaminationWaste = rezkaLaminationWaste != null &&
        rezkaLaminationWaste.isFinite &&
        rezkaLaminationWaste > 0;
    final hasRezkaEdgeWaste =
        rezkaEdgeWaste != null && rezkaEdgeWaste.isFinite && rezkaEdgeWaste > 0;
    final hasWaste =
        totalWaste != null && totalWaste.isFinite && totalWaste > 0;
    if (_isAstatkaReport) {
      if (!formValid) return;
      if (widget.isRezka) {
        Navigator.of(context).pop(
          _ProgressQtyInput(
            meterQty: meterQty,
            kgQty: kgQty,
            bobinaKg: bobinaKg,
            totalWaste: totalWaste,
            rezkaBosmaWaste: rezkaBosmaWaste,
            rezkaLaminationWaste: rezkaLaminationWaste,
            rezkaEdgeWaste: rezkaEdgeWaste,
            description: _descriptionController.text.trim(),
          ),
        );
        return;
      }
      Navigator.of(context).pop(
        _ProgressQtyInput(
          meterQty: meterQty,
          kgQty: kgQty,
          bobinaKg: bobinaKg,
          laminationPrintLeftoverRolls: printLeftoverRolls,
          laminationFilmLeftoverRolls: filmLeftoverRolls,
          totalWaste: totalWaste,
          description: _descriptionController.text.trim(),
        ),
      );
      return;
    }
    if (_isWorkerHandoff) {
      if (!formValid) return;
      Navigator.of(context).pop(
        _ProgressQtyInput(
          bobinaKg: bobinaKg,
          laminationPrintLeftoverRolls: printLeftoverRolls,
          laminationFilmLeftoverRolls: filmLeftoverRolls,
          totalWaste: totalWaste,
          description: _descriptionController.text.trim(),
        ),
      );
      return;
    }
    if (_isRollRemoval) {
      if (!formValid || !hasMeter || !hasKg || !hasBobina) return;
      Navigator.of(context).pop(
        _ProgressQtyInput(
          finishedGoodsMeter: meterQty,
          finishedGoodsKg: kgQty,
          bobinaKg: bobinaKg,
          description: description,
        ),
      );
      return;
    }
    final bosmaMetricsReady = _requiresFullCompletionReport
        ? hasWaste && hasMeter && hasKg && hasBobina && returnedPaintValid
        : hasMeter && hasKg && hasBobina;
    final laminatsiyaMetricsReady = _requiresFullCompletionReport
        ? (hasPrintLeftover || hasFilmLeftover) &&
            hasWaste &&
            hasMeter &&
            hasKg &&
            hasBobina
        : hasMeter && hasKg && hasBobina;
    final hasRezkaWaste = hasWaste ||
        hasRezkaBosmaWaste ||
        hasRezkaLaminationWaste ||
        hasRezkaEdgeWaste;
    final rezkaMetricsReady = (_showRezkaFrameInputs
            ? hasRezkaFrameMetrics
            : hasMeter && hasKg && hasBobina && hasDiameter) &&
        (!_requiresFullCompletionReport ||
            hasRezkaWaste ||
            allRezkaFramesIssue);
    if (!widget.isBosma &&
        !widget.isLaminatsiya &&
        !widget.isRezka &&
        hasMeter &&
        hasKg &&
        hasBobina) {
      Navigator.of(context).pop(_ProgressQtyInput(
        meterQty: meterQty,
        kgQty: kgQty,
        bobinaKg: bobinaKg,
        returnedPaintItems: returnedPaintItems,
        returnedPaintImageId: returnedPaintImageId,
        description: description,
      ));
      return;
    }
    if (widget.isBosma && bosmaMetricsReady) {
      Navigator.of(context).pop(
        _ProgressQtyInput(
          finishedGoodsMeter: meterQty,
          finishedGoodsKg: kgQty,
          bobinaKg: bobinaKg,
          returnInkKg: _isComplete ? returnInkKg : null,
          totalWaste: _isComplete ? totalWaste : null,
          returnedPaintItems: returnedPaintItems,
          returnedPaintImageId: returnedPaintImageId,
          fullCompletionReportRequired: _requiresFullCompletionReport,
          description: description,
        ),
      );
      return;
    }
    if (widget.isRezka && rezkaMetricsReady) {
      Navigator.of(context).pop(
        _ProgressQtyInput(
          meterQty: effectiveMeterQty,
          kgQty: effectiveKgQty,
          bobinaKg: effectiveBobinaKg,
          diameter: effectiveDiameter,
          totalWaste: totalWaste,
          rezkaBosmaWaste: rezkaBosmaWaste,
          rezkaLaminationWaste: rezkaLaminationWaste,
          rezkaEdgeWaste: rezkaEdgeWaste,
          returnedPaintItems: returnedPaintItems,
          returnedPaintImageId: returnedPaintImageId,
          fullCompletionReportRequired: _requiresFullCompletionReport,
          rezkaFrames: rezkaFrameInputs ?? const [],
          description: description,
        ),
      );
      return;
    }
    if (widget.isLaminatsiya && laminatsiyaMetricsReady) {
      Navigator.of(context).pop(
        _ProgressQtyInput(
          finishedGoodsMeter: meterQty,
          finishedGoodsKg: kgQty,
          bobinaKg: bobinaKg,
          laminationPrintLeftoverRolls: _isComplete ? printLeftoverRolls : null,
          laminationFilmLeftoverRolls: _isComplete ? filmLeftoverRolls : null,
          totalWaste: _isComplete ? totalWaste : null,
          returnedPaintItems: returnedPaintItems,
          returnedPaintImageId: returnedPaintImageId,
          fullCompletionReportRequired: _requiresFullCompletionReport,
          description: description,
        ),
      );
      return;
    }
    if (_isFreezeRequestSafeStop) {
      setState(() {
        _completionError = context.l10n.productionText(
          'worker.freeze.safe_stop.output_incomplete',
        );
      });
      return;
    }
    if (_isComplete && !_requiresFullCompletionReport) {
      return;
    }
    if (_isComplete) {
      if (!formValid) return;
      setState(() {
        _completionError = context.l10n.productionText(
          'worker.progress.qty.completion_reason',
        );
      });
      return;
    }
  }

  Widget _rezkaFrameSection(
    BuildContext context,
    int index,
    _RezkaFrameControllers frame,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final requiredError = (String label) => context.l10n.productionText(
          'worker.daily.required_field',
          values: {'label': label},
        );
    final issueAllowed = _rezkaFrameIssueAllowed(index, frame);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.productionText(
              'worker.progress.qty.rezka_frame',
              values: {'index': index + 1},
            ),
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _qtyField(
            key: ValueKey<String>('rezka-frame-$index-meter'),
            controller: frame.meter,
            label: context.l10n.productionText(
              'worker.daily.field.length',
            ),
            error: requiredError(
              context.l10n.productionText('worker.daily.field.length'),
            ),
            suffix: context.l10n.productionText(
              'worker.progress.qty.unit.meter',
            ),
            requiredField: issueAllowed ? false : true,
            positive: true,
          ),
          const SizedBox(height: 10),
          _qtyField(
            key: ValueKey<String>('rezka-frame-$index-kg'),
            controller: frame.kg,
            label: context.l10n.productionText('worker.daily.field.weight'),
            error: requiredError(
              context.l10n.productionText('worker.daily.field.weight'),
            ),
            suffix: context.l10n.productionText('worker.progress.qty.unit.kg'),
            requiredField: issueAllowed ? false : true,
            positive: true,
          ),
          const SizedBox(height: 10),
          _qtyField(
            key: ValueKey<String>('rezka-frame-$index-bobina'),
            controller: frame.bobina,
            label: context.l10n.productionText('worker.daily.field.roll'),
            error: context.l10n.productionText(
              'worker.progress.qty.roll_required',
            ),
            suffix: context.l10n.productionText('worker.progress.qty.unit.kg'),
            requiredField: issueAllowed ? false : true,
            positive: true,
          ),
          const SizedBox(height: 10),
          _qtyField(
            key: ValueKey<String>('rezka-frame-$index-diameter'),
            controller: frame.diameter,
            label: context.l10n.productionText(
              'worker.daily.field.diameter',
            ),
            error: requiredError(
              context.l10n.productionText('worker.daily.field.diameter'),
            ),
            suffix: context.l10n.productionText('worker.progress.qty.unit.mm'),
            requiredField: issueAllowed ? false : true,
            positive: true,
          ),
          if (issueAllowed) ...[
            const SizedBox(height: 10),
            TextFormField(
              controller: frame.issueNote,
              minLines: 2,
              maxLines: 4,
              decoration: appSurfaceInputDecoration(
                context,
                labelText: context.l10n.productionText(
                  'worker.freeze.safe_stop.issue_note',
                ),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value?.trim().isNotEmpty == true ||
                    (_descriptionController.text.trim().isNotEmpty &&
                        _rezkaFrameControllers.every(
                          (candidate) => !_rezkaFrameHasAnyMetric(candidate),
                        ))) {
                  return null;
                }
                return context.l10n.productionText(
                  'worker.freeze.safe_stop.output_or_issue_required',
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isBosma = widget.isBosma;
    final isLaminatsiya = widget.isLaminatsiya;
    final isRezka = widget.isRezka;
    final hasDetailedMetrics = isBosma || isLaminatsiya;
    final showTotalWaste = hasDetailedMetrics &&
        (_requiresFullCompletionReport ||
            _isWorkerHandoff ||
            _isAstatkaReport) &&
        !isBosma;
    final title = _isFreezeRequestSafeStop
        ? context.l10n.productionText('worker.freeze.safe_stop.title')
        : _isAstatkaReport
            ? context.l10n.productionText('worker.finish.title')
            : _isWorkerHandoff
                ? context.l10n.productionText('worker.finish.title')
                : _isRollRemoval
                    ? context.l10n.productionText(
                        'worker.progress.qty.title.remove_roll',
                      )
                    : switch (widget.action) {
                        'pause' => context.l10n.productionText(
                            'worker.progress.qty.title.pause',
                          ),
                        'detach_roll' => context.l10n.productionText(
                            'worker.progress.qty.title.detach_roll',
                          ),
                        'roll_complete' => context.l10n.productionText(
                            'worker.progress.qty.title.roll_complete',
                          ),
                        _ => context.l10n.productionText(
                            'worker.progress.qty.title.complete',
                          ),
                      };
    final subtitle = _isFreezeRequestSafeStop
        ? context.l10n
            .productionText('worker.freeze.safe_stop.form_instruction')
        : _isAstatkaReport
            ? context.l10n.productionText(
                'worker.progress.qty.subtitle.astatka',
              )
            : _isWorkerHandoff
                ? context.l10n.productionText(
                    'worker.progress.qty.subtitle.handoff',
                  )
                : _isRollRemoval
                    ? context.l10n.productionText(
                        'worker.progress.qty.subtitle.remove_roll',
                      )
                    : _requiresFullCompletionReport
                        ? context.l10n.productionText(
                            'worker.progress.qty.subtitle.full_report',
                          )
                        : context.l10n.productionText(
                            'worker.progress.qty.subtitle.current',
                          );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          maxWidth: 480,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        _isComplete || widget.action == 'roll_complete'
                            ? Icons.check_circle_outline_rounded
                            : Icons.pause_circle_outline_rounded,
                        color: scheme.onPrimaryContainer,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_showRezkaFrameInputs) ...[
                          _progressQtySectionLabel(
                            context,
                            context.l10n.productionText(
                              'worker.progress.qty.standard',
                            ),
                          ),
                          _qtyField(
                            controller: _bobinaController,
                            label: context.l10n.productionText(
                              'worker.daily.field.roll',
                            ),
                            error: context.l10n.productionText(
                              'worker.progress.qty.roll_required',
                            ),
                            suffix: context.l10n.productionText(
                              'worker.progress.qty.unit.kg',
                            ),
                            requiredField: true,
                            positive: true,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if ((_requiresFullCompletionReport ||
                                _isWorkerHandoff ||
                                _isAstatkaReport) &&
                            isLaminatsiya &&
                            !_isRollRemoval) ...[
                          _progressQtySectionLabel(
                            context,
                            context.l10n.productionText(
                              'worker.progress.qty.excess_rolls',
                            ),
                          ),
                          _qtyField(
                            controller: _printLeftoverController,
                            label: context.l10n.productionText(
                              'worker.daily.field.print_leftover',
                            ),
                            error: context.l10n.productionText(
                              'worker.daily.required_field',
                              values: {
                                'label': context.l10n.productionText(
                                  'worker.daily.field.print_leftover',
                                ),
                              },
                            ),
                            requiredField:
                                (_isWorkerHandoff || _isAstatkaReport)
                                    ? true
                                    : null,
                            allowZero: _isWorkerHandoff || _isAstatkaReport,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if ((_requiresFullCompletionReport ||
                                _isWorkerHandoff ||
                                _isAstatkaReport) &&
                            isLaminatsiya &&
                            !_isRollRemoval) ...[
                          _qtyField(
                            controller: _filmLeftoverController,
                            label: context.l10n.productionText(
                              'worker.daily.field.film_leftover',
                            ),
                            error: context.l10n.productionText(
                              'worker.daily.required_field',
                              values: {
                                'label': context.l10n.productionText(
                                  'worker.daily.field.film_leftover',
                                ),
                              },
                            ),
                            requiredField:
                                (_isWorkerHandoff || _isAstatkaReport)
                                    ? true
                                    : null,
                            allowZero: _isWorkerHandoff || _isAstatkaReport,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (isRezka &&
                            (_requiresFullCompletionReport ||
                                _isAstatkaReport)) ...[
                          _progressQtySectionLabel(
                            context,
                            context.l10n.productionText(
                              'worker.progress.qty.waste',
                            ),
                          ),
                          _qtyField(
                            controller: _wasteController,
                            label: context.l10n.productionText(
                              'worker.daily.field.total_waste',
                            ),
                            error: context.l10n.productionText(
                              'worker.daily.required_field',
                              values: {
                                'label': context.l10n.productionText(
                                  'worker.daily.field.total_waste',
                                ),
                              },
                            ),
                            suffix: context.l10n.productionText(
                              'worker.progress.qty.unit.kg',
                            ),
                            requiredField: _isAstatkaReport ? true : false,
                            positive: !_isAstatkaReport,
                            allowZero: _isAstatkaReport,
                          ),
                          const SizedBox(height: 10),
                          _qtyField(
                            controller: _rezkaBosmaWasteController,
                            label: context.l10n.productionText(
                              'worker.daily.field.print_waste',
                            ),
                            error: context.l10n.productionText(
                              'worker.daily.required_field',
                              values: {
                                'label': context.l10n.productionText(
                                  'worker.daily.field.print_waste',
                                ),
                              },
                            ),
                            suffix: context.l10n.productionText(
                              'worker.progress.qty.unit.kg',
                            ),
                            requiredField: _isAstatkaReport ? true : false,
                            positive: !_isAstatkaReport,
                            allowZero: _isAstatkaReport,
                          ),
                          const SizedBox(height: 10),
                          _qtyField(
                            controller: _rezkaLaminationWasteController,
                            label: context.l10n.productionText(
                              'worker.daily.field.lamination_waste',
                            ),
                            error: context.l10n.productionText(
                              'worker.daily.required_field',
                              values: {
                                'label': context.l10n.productionText(
                                  'worker.daily.field.lamination_waste',
                                ),
                              },
                            ),
                            suffix: context.l10n.productionText(
                              'worker.progress.qty.unit.kg',
                            ),
                            requiredField: _isAstatkaReport ? true : false,
                            positive: !_isAstatkaReport,
                            allowZero: _isAstatkaReport,
                          ),
                          const SizedBox(height: 10),
                          _qtyField(
                            controller: _rezkaEdgeWasteController,
                            label: context.l10n.productionText(
                              'worker.daily.field.edge_waste',
                            ),
                            error: context.l10n.productionText(
                              'worker.daily.required_field',
                              values: {
                                'label': context.l10n.productionText(
                                  'worker.daily.field.edge_waste',
                                ),
                              },
                            ),
                            suffix: context.l10n.productionText(
                              'worker.progress.qty.unit.kg',
                            ),
                            requiredField: _isAstatkaReport ? true : false,
                            positive: !_isAstatkaReport,
                            allowZero: _isAstatkaReport,
                          ),
                          const SizedBox(height: 10),
                          if (!_isAstatkaReport)
                            FormField<void>(
                              validator: (_) {
                                final hasWaste = [
                                  _wasteController,
                                  _rezkaBosmaWasteController,
                                  _rezkaLaminationWasteController,
                                  _rezkaEdgeWasteController,
                                ].any(_hasPositiveQty);
                                return hasWaste
                                    ? null
                                    : context.l10n.productionText(
                                        'worker.progress.qty.waste_required',
                                      );
                              },
                              builder: (field) {
                                if (!field.hasError) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    field.errorText!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                        if (showTotalWaste) ...[
                          _progressQtySectionLabel(
                            context,
                            context.l10n.productionText(
                              'worker.progress.qty.waste',
                            ),
                          ),
                          _qtyField(
                            controller: _wasteController,
                            label: context.l10n.productionText(
                              'worker.daily.field.total_waste',
                            ),
                            error: context.l10n.productionText(
                              'worker.daily.required_field',
                              values: {
                                'label': context.l10n.productionText(
                                  'worker.daily.field.total_waste',
                                ),
                              },
                            ),
                            suffix: context.l10n.productionText(
                              'worker.progress.qty.unit.kg',
                            ),
                            requiredField:
                                (_isWorkerHandoff || _isAstatkaReport)
                                    ? true
                                    : null,
                            allowZero: _isWorkerHandoff || _isAstatkaReport,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_showRezkaFrameInputs) ...[
                          _progressQtySectionLabel(
                            context,
                            context.l10n.productionText(
                              'worker.progress.qty.rezka_frames',
                              values: {'count': _rezkaFrameCount},
                            ),
                          ),
                          for (var index = 0;
                              index < _rezkaFrameControllers.length;
                              index += 1)
                            _rezkaFrameSection(
                              context,
                              index,
                              _rezkaFrameControllers[index],
                            ),
                        ],
                        if (!_isWorkerHandoff && !_showRezkaFrameInputs) ...[
                          _progressQtySectionLabel(
                            context,
                            hasDetailedMetrics
                                ? context.l10n.productionText(
                                    'worker.progress.qty.finished_goods',
                                  )
                                : context.l10n.productionText(
                                    'worker.daily.field.quantity',
                                  ),
                          ),
                          _qtyField(
                            controller: _meterController,
                            label: context.l10n.productionText(
                              'worker.daily.field.length',
                            ),
                            error: context.l10n.productionText(
                              'worker.daily.required_field',
                              values: {
                                'label': context.l10n.productionText(
                                  'worker.daily.field.length',
                                ),
                              },
                            ),
                            suffix: context.l10n.productionText(
                              'worker.progress.qty.unit.meter',
                            ),
                            requiredField:
                                isRezka || _isRollRemoval || _isAstatkaReport
                                    ? true
                                    : null,
                            positive:
                                isRezka || _isRollRemoval || _isAstatkaReport,
                          ),
                          const SizedBox(height: 10),
                          _qtyField(
                            controller: _kgController,
                            label: context.l10n.productionText(
                              'worker.daily.field.weight',
                            ),
                            error: context.l10n.productionText(
                              'worker.daily.required_field',
                              values: {
                                'label': context.l10n.productionText(
                                  'worker.daily.field.weight',
                                ),
                              },
                            ),
                            suffix: context.l10n.productionText(
                              'worker.progress.qty.unit.kg',
                            ),
                            requiredField:
                                isRezka || _isRollRemoval || _isAstatkaReport
                                    ? true
                                    : null,
                            positive:
                                isRezka || _isRollRemoval || _isAstatkaReport,
                          ),
                          if (isRezka) ...[
                            const SizedBox(height: 10),
                            _qtyField(
                              controller: _diameterController,
                              label: context.l10n.productionText(
                                'worker.daily.field.diameter',
                              ),
                              error: context.l10n.productionText(
                                'worker.daily.required_field',
                                values: {
                                  'label': context.l10n.productionText(
                                    'worker.daily.field.diameter',
                                  ),
                                },
                              ),
                              suffix: context.l10n.productionText(
                                'worker.progress.qty.unit.mm',
                              ),
                              requiredField: true,
                              positive: true,
                            ),
                          ],
                        ],
                        if (_requiresFullCompletionReport && isBosma) ...[
                          const SizedBox(height: 10),
                          _progressQtySectionLabel(
                            context,
                            context.l10n.productionText(
                              'worker.progress.qty.returned_paint_and_waste',
                            ),
                          ),
                          _qtyField(
                            controller: _wasteController,
                            label: context.l10n.productionText(
                              'worker.daily.field.total_waste',
                            ),
                            error: context.l10n.productionText(
                              'worker.daily.required_field',
                              values: {
                                'label': context.l10n.productionText(
                                  'worker.daily.field.total_waste',
                                ),
                              },
                            ),
                            suffix: context.l10n.productionText(
                              'worker.progress.qty.unit.kg',
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _openReturnedPaintSheet,
                            style: OutlinedButton.styleFrom(
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                              side: BorderSide(
                                color: scheme.primary,
                                width: 1.2,
                              ),
                              minimumSize: const Size.fromHeight(52),
                              alignment: Alignment.centerLeft,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    context.l10n.productionText(
                                      'worker.daily.field.returned_ink',
                                    ),
                                  ),
                                ),
                                Icon(Icons.arrow_forward_rounded),
                              ],
                            ),
                          ),
                        ],
                        if (_isComplete ||
                            (widget.action == 'roll_complete' && isRezka) ||
                            _isAstatkaReport ||
                            _isFreezeRequestSafeStop) ...[
                          const SizedBox(height: 6),
                          _progressQtySectionLabel(
                            context,
                            context.l10n.productionText(
                              'worker.progress.qty.note',
                            ),
                          ),
                          TextFormField(
                            controller: _descriptionController,
                            minLines: 3,
                            maxLines: 4,
                            decoration: appSurfaceInputDecoration(
                              context,
                              labelText: _isAstatkaReport
                                  ? context.l10n.productionText(
                                      'worker.progress.qty.optional_note',
                                    )
                                  : (_isFreezeRequestSafeStop ||
                                          (widget.action == 'roll_complete' &&
                                              isRezka))
                                      ? context.l10n.productionText(
                                          'worker.freeze.safe_stop.issue_note',
                                        )
                                      : context.l10n.productionText(
                                          'worker.progress.qty.reason',
                                        ),
                              alignLabelWithHint: true,
                            ),
                            onChanged: (_) {
                              if (_completionError.isNotEmpty) {
                                setState(() => _completionError = '');
                              }
                            },
                          ),
                          if (_completionError.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.errorContainer
                                    .withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 18,
                                      color: scheme.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _completionError,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: scheme.onErrorContainer,
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        context.l10n.productionText('worker.action.cancel'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        context.l10n.productionText('worker.action.confirm'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
