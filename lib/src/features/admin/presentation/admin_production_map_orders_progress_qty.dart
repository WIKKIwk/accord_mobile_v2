part of 'admin_production_map_orders_screen.dart';

class _ProgressQtyInput {
  const _ProgressQtyInput({
    this.meterQty,
    this.kgQty,
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
    this.isCompletionRequest = false,
  });

  final double? meterQty;
  final double? kgQty;
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
  final bool isCompletionRequest;
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
    ),
  );
}

Future<_ProgressQtyInput?> _showProgressQtyDialogForApparatus(
  BuildContext context, {
  required String action,
  required AdminApparatus? apparatus,
  required ProductionMapSaved order,
  ReturnedPaintDraft? returnedPaintDraft,
}) {
  final title = apparatus?.name ?? '';
  return _showProgressQtyDialog(
    context,
    action,
    order: order,
    apparatus: title,
    isBosma: productionMapIsPechatApparatus(title),
    isLaminatsiya: productionMapIsLaminatsiyaApparatus(title),
    isRezka: productionMapIsRezkaApparatus(title),
    returnedPaintDraft: returnedPaintDraft,
  );
}

Widget _progressQtySectionLabel(BuildContext context, String label) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  return Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 8),
    child: Text(
      label,
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
  });

  final String action;
  final ProductionMapSaved order;
  final String apparatus;
  final bool isBosma;
  final bool isLaminatsiya;
  final bool isRezka;
  final ReturnedPaintDraft returnedPaintDraft;

  @override
  State<_ProgressQtyDialog> createState() => _ProgressQtyDialogState();
}

class _ProgressQtyDialogState extends State<_ProgressQtyDialog> {
  final _meterController = TextEditingController();
  final _kgController = TextEditingController();
  final _printLeftoverController = TextEditingController();
  final _filmLeftoverController = TextEditingController();
  final _rezkaBosmaWasteController = TextEditingController();
  final _rezkaLaminationWasteController = TextEditingController();
  final _rezkaEdgeWasteController = TextEditingController();
  final _wasteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _completionError = '';

  ReturnedPaintDraft get _returnedPaintDraft => widget.returnedPaintDraft;

  List<ReturnedPaintItemInput> get _returnedPaintItems =>
      _isComplete ? returnedPaintItemsFromDraft(_returnedPaintDraft) : const [];

  bool get _isComplete => widget.action == 'complete';

  @override
  void dispose() {
    _descriptionController.dispose();
    _wasteController.dispose();
    _rezkaEdgeWasteController.dispose();
    _rezkaLaminationWasteController.dispose();
    _rezkaBosmaWasteController.dispose();
    _filmLeftoverController.dispose();
    _printLeftoverController.dispose();
    _kgController.dispose();
    _meterController.dispose();
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
    String suffix = '',
  }) {
    return TextFormField(
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
        if (trimmed.isEmpty) {
          return _isComplete ? null : error;
        }
        final qty = _parseQty(trimmed);
        if (qty == null || !qty.isFinite || qty < 0) {
          return 'To‘g‘ri raqam kiriting';
        }
        if (!_isComplete && qty == 0) {
          return '0 dan katta raqam kiriting';
        }
        return null;
      },
    );
  }

  void _submit() {
    setState(() => _completionError = '');
    final formValid = _formKey.currentState?.validate() ?? false;

    final meterQty = _parseQty(_meterController.text);
    final kgQty = _parseQty(_kgController.text);
    if (_isComplete &&
        widget.isBosma &&
        returnedPaintDraftHasInvalidValues(_returnedPaintDraft)) {
      setState(() {
        _completionError =
            'Qaytarilgan bo‘yoq qiymatlarini to‘g‘ri raqamda kiriting.';
      });
      return;
    }
    final returnedPaintItems = _returnedPaintItems;
    final rawReturnInkKg =
        _isComplete ? returnedPaintAstatkaTotal(returnedPaintItems) : null;
    final returnInkKg =
        rawReturnInkKg != null && rawReturnInkKg.isFinite && rawReturnInkKg > 0
            ? rawReturnInkKg
            : null;
    final returnedPaintImageId =
        _isComplete ? (_returnedPaintDraft.image?.imageId.trim() ?? '') : '';
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
    if (_isComplete && widget.isBosma && !returnedPaintValid) {
      setState(() {
        _completionError = returnedPaintFieldCount > 0
            ? 'Har bir tabda kamida 3 ta maydon to‘ldiring. '
                'Rasxot: $rasxotFieldCount/3, '
                'Astatka: $astatkaFieldCount/3.'
            : 'Kamida 3 ta qaytarilgan bo‘yoq maydonini to‘ldiring yoki '
                'rasm yuklang.';
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
    final hasMeter = meterQty != null && meterQty.isFinite && meterQty > 0;
    final hasKg = kgQty != null && kgQty.isFinite && kgQty > 0;
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
    final bosmaMetricsReady =
        hasWaste && hasMeter && hasKg && (!_isComplete || returnedPaintValid);
    final laminatsiyaMetricsReady = _isComplete
        ? (hasPrintLeftover || hasFilmLeftover) && hasWaste && hasMeter && hasKg
        : hasFilmLeftover && hasWaste && hasMeter && hasKg;
    final rezkaMetricsReady = hasRezkaBosmaWaste &&
        hasRezkaLaminationWaste &&
        hasRezkaEdgeWaste &&
        hasMeter &&
        hasKg;
    if (!widget.isBosma &&
        !widget.isLaminatsiya &&
        !widget.isRezka &&
        hasMeter &&
        hasKg) {
      Navigator.of(context).pop(_ProgressQtyInput(
        meterQty: meterQty,
        kgQty: kgQty,
        returnedPaintItems: returnedPaintItems,
        returnedPaintImageId: returnedPaintImageId,
      ));
      return;
    }
    if (widget.isBosma && bosmaMetricsReady) {
      Navigator.of(context).pop(
        _ProgressQtyInput(
          finishedGoodsMeter: meterQty,
          finishedGoodsKg: kgQty,
          returnInkKg: _isComplete ? returnInkKg : null,
          totalWaste: totalWaste,
          returnedPaintItems: returnedPaintItems,
          returnedPaintImageId: returnedPaintImageId,
        ),
      );
      return;
    }
    if (widget.isRezka && rezkaMetricsReady) {
      Navigator.of(context).pop(
        _ProgressQtyInput(
          meterQty: meterQty,
          kgQty: kgQty,
          rezkaBosmaWaste: rezkaBosmaWaste,
          rezkaLaminationWaste: rezkaLaminationWaste,
          rezkaEdgeWaste: rezkaEdgeWaste,
          returnedPaintItems: returnedPaintItems,
          returnedPaintImageId: returnedPaintImageId,
        ),
      );
      return;
    }
    if (widget.isLaminatsiya && laminatsiyaMetricsReady) {
      Navigator.of(context).pop(
        _ProgressQtyInput(
          finishedGoodsMeter: meterQty,
          finishedGoodsKg: kgQty,
          laminationPrintLeftoverRolls: _isComplete ? printLeftoverRolls : null,
          laminationFilmLeftoverRolls: filmLeftoverRolls,
          totalWaste: totalWaste,
          returnedPaintItems: returnedPaintItems,
          returnedPaintImageId: returnedPaintImageId,
        ),
      );
      return;
    }
    if (_isComplete) {
      if (!formValid) return;
      final description = _descriptionController.text.trim();
      if (description.isNotEmpty) {
        Navigator.of(context).pop(
          _completionRequestInput(
            meterQty: meterQty,
            kgQty: kgQty,
            returnInkKg: returnInkKg,
            printLeftoverRolls: printLeftoverRolls,
            filmLeftoverRolls: filmLeftoverRolls,
            rezkaBosmaWaste: rezkaBosmaWaste,
            rezkaLaminationWaste: rezkaLaminationWaste,
            rezkaEdgeWaste: rezkaEdgeWaste,
            totalWaste: totalWaste,
            description: description,
          ),
        );
        return;
      }
      setState(() {
        _completionError =
            '0 yoki to‘liq bo‘lmagan hisobot uchun sababini yozing.';
      });
      return;
    }
  }

  _ProgressQtyInput _completionRequestInput({
    required double? meterQty,
    required double? kgQty,
    required double? returnInkKg,
    required double? printLeftoverRolls,
    required double? filmLeftoverRolls,
    required double? rezkaBosmaWaste,
    required double? rezkaLaminationWaste,
    required double? rezkaEdgeWaste,
    required double? totalWaste,
    required String description,
  }) {
    if (widget.isBosma) {
      return _ProgressQtyInput(
        finishedGoodsMeter: meterQty,
        finishedGoodsKg: kgQty,
        returnInkKg: returnInkKg,
        totalWaste: totalWaste,
        description: description,
        returnedPaintItems: _returnedPaintItems,
        returnedPaintImageId: _returnedPaintDraft.image?.imageId.trim() ?? '',
        isCompletionRequest: true,
      );
    }
    if (widget.isLaminatsiya) {
      return _ProgressQtyInput(
        finishedGoodsMeter: meterQty,
        finishedGoodsKg: kgQty,
        laminationPrintLeftoverRolls: printLeftoverRolls,
        laminationFilmLeftoverRolls: filmLeftoverRolls,
        totalWaste: totalWaste,
        description: description,
        returnedPaintItems: _returnedPaintItems,
        returnedPaintImageId: _returnedPaintDraft.image?.imageId.trim() ?? '',
        isCompletionRequest: true,
      );
    }
    if (widget.isRezka) {
      return _ProgressQtyInput(
        meterQty: meterQty,
        kgQty: kgQty,
        rezkaBosmaWaste: rezkaBosmaWaste,
        rezkaLaminationWaste: rezkaLaminationWaste,
        rezkaEdgeWaste: rezkaEdgeWaste,
        description: description,
        returnedPaintItems: _returnedPaintItems,
        returnedPaintImageId: _returnedPaintDraft.image?.imageId.trim() ?? '',
        isCompletionRequest: true,
      );
    }
    return _ProgressQtyInput(
      meterQty: meterQty,
      kgQty: kgQty,
      description: description,
      returnedPaintItems: _returnedPaintItems,
      returnedPaintImageId: _returnedPaintDraft.image?.imageId.trim() ?? '',
      isCompletionRequest: true,
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
    final title =
        widget.action == 'pause' ? 'Pauza miqdori' : 'Tugatish miqdori';
    final subtitle = _isComplete
        ? '0 yoki to‘liq bo‘lmagan hisobot uchun izoh yozing'
        : 'Joriy miqdorni kiriting';

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
                        _isComplete
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
                        if (_isComplete && isLaminatsiya) ...[
                          _progressQtySectionLabel(
                              context, 'Ortiqcha rulonlar'),
                          _qtyField(
                            controller: _printLeftoverController,
                            label: 'Bosmadan ortgan rulon',
                            error: 'Bosmadan ortgan rulonni kiriting',
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (isLaminatsiya) ...[
                          if (!_isComplete)
                            _progressQtySectionLabel(
                              context,
                              'Ortiqcha rulonlar',
                            ),
                          _qtyField(
                            controller: _filmLeftoverController,
                            label: 'Plyonkadan ortgan rulon',
                            error: 'Plyonkadan ortgan rulonni kiriting',
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (isRezka) ...[
                          _progressQtySectionLabel(context, 'Chiqindilar'),
                          _qtyField(
                            controller: _rezkaBosmaWasteController,
                            label: 'Bosmachining chiqindisi',
                            error: 'Bosmachining chiqindisini kiriting',
                            suffix: 'kg',
                          ),
                          const SizedBox(height: 10),
                          _qtyField(
                            controller: _rezkaLaminationWasteController,
                            label: 'Laminatsiya chiqindisi',
                            error: 'Laminatsiya chiqindisini kiriting',
                            suffix: 'kg',
                          ),
                          const SizedBox(height: 10),
                          _qtyField(
                            controller: _rezkaEdgeWasteController,
                            label: 'Tayyor mahsulot chetidan chiqqan chiqindi',
                            error:
                                'Tayyor mahsulot chetidan chiqqan chiqindini kiriting',
                            suffix: 'kg',
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (hasDetailedMetrics &&
                            !(isBosma && _isComplete)) ...[
                          _progressQtySectionLabel(context, 'Chiqindi'),
                          _qtyField(
                            controller: _wasteController,
                            label: 'Jami chiqindi',
                            error: 'Jami chiqindi kg kiriting',
                            suffix: 'kg',
                          ),
                          const SizedBox(height: 10),
                        ],
                        _progressQtySectionLabel(
                          context,
                          hasDetailedMetrics ? 'Tayyor mahsulot' : 'Miqdor',
                        ),
                        _qtyField(
                          controller: _meterController,
                          label: 'Metraj',
                          error: hasDetailedMetrics
                              ? 'Tayyor mahsulot metr kiriting'
                              : 'Metraj kiriting',
                          suffix: 'metr',
                        ),
                        const SizedBox(height: 10),
                        _qtyField(
                          controller: _kgController,
                          label: 'Og\'irlik',
                          error: hasDetailedMetrics
                              ? 'Tayyor mahsulot kg kiriting'
                              : 'Kg kiriting',
                          suffix: 'kg',
                        ),
                        if (_isComplete && isBosma) ...[
                          const SizedBox(height: 10),
                          _progressQtySectionLabel(
                            context,
                            'Qaytim va chiqindi',
                          ),
                          _qtyField(
                            controller: _wasteController,
                            label: 'Jami chiqindi',
                            error: 'Jami chiqindi kg kiriting',
                            suffix: 'kg',
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
                            child: const Row(
                              children: [
                                Expanded(
                                  child: Text("Qaytarilgan bo'yoq"),
                                ),
                                Icon(Icons.arrow_forward_rounded),
                              ],
                            ),
                          ),
                        ],
                        if (_isComplete) ...[
                          const SizedBox(height: 6),
                          _progressQtySectionLabel(context, 'Izoh'),
                          TextFormField(
                            controller: _descriptionController,
                            minLines: 3,
                            maxLines: 4,
                            decoration: appSurfaceInputDecoration(
                              context,
                              labelText: '0 yoki noodatiy tugatish sababi',
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
                      child: const Text('Bekor qilish'),
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
                      child: const Text('Tasdiqlash'),
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
