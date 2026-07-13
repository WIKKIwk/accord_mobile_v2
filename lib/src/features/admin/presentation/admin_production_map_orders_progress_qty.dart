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
  final String description;
  final bool isCompletionRequest;
}

Future<_ProgressQtyInput?> _showProgressQtyDialog(
  BuildContext context,
  String action, {
  required bool isBosma,
  required bool isLaminatsiya,
  required bool isRezka,
}) {
  return showDialog<_ProgressQtyInput>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => _ProgressQtyDialog(
      action: action,
      isBosma: isBosma,
      isLaminatsiya: isLaminatsiya,
      isRezka: isRezka,
    ),
  );
}

Future<_ProgressQtyInput?> _showProgressQtyDialogForApparatus(
  BuildContext context, {
  required String action,
  required AdminWarehouse? apparatus,
}) {
  final title = apparatus?.warehouse ?? '';
  return _showProgressQtyDialog(
    context,
    action,
    isBosma: productionMapPechatColorCount(title) != null,
    isLaminatsiya: productionMapIsLaminatsiyaApparatus(title),
    isRezka: productionMapIsRezkaApparatus(title),
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

class _ReturnedPaintOption {
  const _ReturnedPaintOption({
    required this.label,
    required this.color,
    required this.foreground,
    this.fieldLabels,
  });

  final String label;
  final Color color;
  final Color foreground;
  final List<String>? fieldLabels;
}

const _returnedPaintColors = <_ReturnedPaintOption>[
  _ReturnedPaintOption(
    label: 'Oq',
    color: Color(0xFFF8F7F2),
    foreground: Color(0xFF332C26),
  ),
  _ReturnedPaintOption(
    label: 'Sariq',
    color: Color(0xFFFFD54F),
    foreground: Color(0xFF3B2A00),
  ),
  _ReturnedPaintOption(
    label: 'Qizil',
    color: Color(0xFFE53935),
    foreground: Colors.white,
  ),
  _ReturnedPaintOption(
    label: 'Ko‘k',
    color: Color(0xFF1E88E5),
    foreground: Colors.white,
  ),
  _ReturnedPaintOption(
    label: 'Tilla',
    color: Color(0xFFD4A72C),
    foreground: Color(0xFF332100),
  ),
  _ReturnedPaintOption(
    label: 'Kumush',
    color: Color(0xFFC7CDD3),
    foreground: Color(0xFF273038),
  ),
  _ReturnedPaintOption(
    label: 'Qora',
    color: Color(0xFF202124),
    foreground: Colors.white,
  ),
  _ReturnedPaintOption(
    label: 'Varnish',
    color: Color(0xFF5A321F),
    foreground: Colors.white,
  ),
];

const _returnedPaintLacquers = <_ReturnedPaintOption>[
  _ReturnedPaintOption(
    label: 'Lak',
    color: Color(0xFFB7BCC2),
    foreground: Color(0xFF273038),
    fieldLabels: <String>['OPV lak', 'MAT lak'],
  ),
];

const _returnedPaintSolvents = <_ReturnedPaintOption>[
  _ReturnedPaintOption(
    label: 'Spirtlar',
    color: Color(0xFFE4B77A),
    foreground: Color(0xFF3E2815),
    fieldLabels: <String>[
      'Aralashmalar',
      'Etil',
      'Metoxil',
      'Rasvavitel',
      'Izopropel',
    ],
  ),
];

class _ReturnedPaintSheet extends StatefulWidget {
  const _ReturnedPaintSheet();

  @override
  State<_ReturnedPaintSheet> createState() => _ReturnedPaintSheetState();
}

class _ReturnedPaintSheetState extends State<_ReturnedPaintSheet>
    with TickerProviderStateMixin {
  late final TabController _usageController;
  String? _selectedPaint;
  int? _selectedUsageIndex;
  List<String>? _selectedFieldLabels;
  final Map<String, List<bool>> _filledFieldsByPaint = {};
  final Map<String, List<TextEditingController>> _fieldControllersByPaint = {};

  @override
  void initState() {
    super.initState();
    _usageController = TabController(length: 2, vsync: this);
  }

  static const _fieldLabels = <String>[
    'Mix',
    'Oq',
    'Qora',
    'Sariq',
    'Qizil',
    'Ko‘k',
    'Varnish',
    'Spirt',
    'Pantone+',
  ];

  Color _fieldBorderColor(String label) {
    return switch (label) {
      'Mix' => const Color(0xFF8A6A4A),
      'Oq' => const Color(0xFFB9B6AD),
      'Qora' => const Color(0xFF202124),
      'Sariq' => const Color(0xFFE0B52D),
      'Qizil' => const Color(0xFFE53935),
      'Ko‘k' => const Color(0xFF1E88E5),
      'Varnish' => const Color(0xFF5A321F),
      'Spirt' => const Color(0xFF6AAED6),
      'Pantone+' => const Color(0xFF8E6BBE),
      _ => Theme.of(context).colorScheme.outlineVariant,
    };
  }

  InputDecoration _paintFieldDecoration(
    BuildContext context,
    String label,
  ) {
    final base = appSurfaceInputDecoration(context, labelText: label);
    final color = _fieldBorderColor(label);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: 1.2),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: 1.8),
    );
    return base.copyWith(
      border: border,
      enabledBorder: border,
      focusedBorder: focusedBorder,
    );
  }

  List<String> _fieldsForOption(_ReturnedPaintOption option) =>
      option.fieldLabels ?? _fieldLabels;

  String _paintStateKey(String paint, int usageIndex) =>
      '${usageIndex == 0 ? 'rasxot' : 'astatka'}:$paint';

  List<TextEditingController> _controllersForPaint(
    String paint,
    List<String> fieldLabels,
    int usageIndex,
  ) {
    final stateKey = _paintStateKey(paint, usageIndex);
    final existing = _fieldControllersByPaint[stateKey];
    if (existing != null && existing.length == fieldLabels.length) {
      return existing;
    }
    final controllers = [
      for (var index = 0; index < fieldLabels.length; index++)
        TextEditingController(),
    ];
    _fieldControllersByPaint[stateKey] = controllers;
    return controllers;
  }

  @override
  void dispose() {
    _usageController.dispose();
    for (final controllers in _fieldControllersByPaint.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  Widget? _completionIndicator(
    _ReturnedPaintOption option,
    int usageIndex,
  ) {
    final fields =
        _filledFieldsByPaint[_paintStateKey(option.label, usageIndex)];
    if (fields == null || fields.every((filled) => !filled)) {
      return null;
    }
    if (fields.length == _fieldsForOption(option).length &&
        fields.every((filled) => filled)) {
      return Icon(
        Icons.check_rounded,
        size: 17,
        color: option.foreground,
      );
    }
    return Icon(
      Icons.star_rounded,
      size: 16,
      color: option.foreground,
    );
  }

  void _updateFieldValue({
    required String paint,
    required int index,
    required String value,
    required int usageIndex,
  }) {
    final stateKey = _paintStateKey(paint, usageIndex);
    final fields = List<bool>.from(
      _filledFieldsByPaint[stateKey] ??
          List<bool>.filled(
              _selectedFieldLabels?.length ?? _fieldLabels.length, false),
    );
    fields[index] = value.trim().isNotEmpty;
    setState(() => _filledFieldsByPaint[stateKey] = fields);
  }

  Widget _paintFields(
    BuildContext context,
    String paint,
    List<String> fieldLabels,
    int usageIndex,
  ) {
    final controllers = _controllersForPaint(paint, fieldLabels, usageIndex);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: [
        for (var index = 0; index < fieldLabels.length; index++)
          TextFormField(
            controller: controllers[index],
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: _paintFieldDecoration(context, fieldLabels[index]),
            onChanged: (value) => _updateFieldValue(
              paint: paint,
              index: index,
              value: value,
              usageIndex: usageIndex,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    Widget category(
      String title,
      List<_ReturnedPaintOption> options,
      int usageIndex,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _progressQtySectionLabel(context, title),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
            children: [
              for (final option in options)
                Tooltip(
                  message: option.label,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final radius = BorderRadius.circular(
                        constraints.maxHeight / 2,
                      );
                      return Material(
                        color: option.color,
                        elevation: 7,
                        shadowColor: Colors.black45,
                        borderRadius: radius,
                        child: InkWell(
                          borderRadius: radius,
                          onTap: () {
                            setState(() {
                              _selectedPaint = option.label;
                              _selectedUsageIndex = usageIndex;
                              _selectedFieldLabels =
                                  option.fieldLabels ?? _fieldLabels;
                            });
                          },
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: radius,
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    option.label,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: option.foreground,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                if (_completionIndicator(option, usageIndex)
                                    case final indicator?)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: indicator,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      );
    }

    Widget palettePage(int usageIndex) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          category('Ranglar', _returnedPaintColors, usageIndex),
          category('Laklar', _returnedPaintLacquers, usageIndex),
          category(
            'Erituvchilar / spirtli suyuqliklar',
            _returnedPaintSolvents,
            usageIndex,
          ),
        ],
      );
    }

    return AnimatedPadding(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (_selectedPaint != null)
                    IconButton(
                      tooltip: 'Orqaga',
                      onPressed: () {
                        setState(() {
                          _selectedPaint = null;
                          _selectedUsageIndex = null;
                          _selectedFieldLabels = null;
                        });
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  Expanded(
                    child: Text(
                      'Qaytarilgan bo‘yoq',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_selectedPaint == null) ...[
                AdminSurfaceTabBar(
                  controller: _usageController,
                  tabs: const [
                    Tab(height: 38, text: 'Rasxot'),
                    Tab(height: 38, text: 'Astatka'),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                reverseDuration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: _selectedPaint == null
                    ? SizedBox(
                        key: const ValueKey('returned-paint-palette'),
                        height: 640,
                        child: TabBarView(
                          controller: _usageController,
                          children: [palettePage(0), palettePage(1)],
                        ),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('returned-paint-fields'),
                        child: _paintFields(
                          context,
                          _selectedPaint!,
                          _selectedFieldLabels ?? _fieldLabels,
                          _selectedUsageIndex ?? _usageController.index,
                        ),
                      ),
              ),
              Divider(color: scheme.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressQtyDialog extends StatefulWidget {
  const _ProgressQtyDialog({
    required this.action,
    required this.isBosma,
    required this.isLaminatsiya,
    required this.isRezka,
  });

  final String action;
  final bool isBosma;
  final bool isLaminatsiya;
  final bool isRezka;

  @override
  State<_ProgressQtyDialog> createState() => _ProgressQtyDialogState();
}

class _ProgressQtyDialogState extends State<_ProgressQtyDialog> {
  final _meterController = TextEditingController();
  final _kgController = TextEditingController();
  final _returnInkController = TextEditingController();
  final _printLeftoverController = TextEditingController();
  final _filmLeftoverController = TextEditingController();
  final _rezkaBosmaWasteController = TextEditingController();
  final _rezkaLaminationWasteController = TextEditingController();
  final _rezkaEdgeWasteController = TextEditingController();
  final _wasteController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _completionError = '';

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
    _returnInkController.dispose();
    _kgController.dispose();
    _meterController.dispose();
    super.dispose();
  }

  double? _parseQty(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _openReturnedPaintSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _ReturnedPaintSheet(),
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
    final returnInkKg = _parseQty(_returnInkController.text);
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
    final bosmaMetricsReady = hasWaste && hasMeter && hasKg;
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
      Navigator.of(context)
          .pop(_ProgressQtyInput(meterQty: meterQty, kgQty: kgQty));
      return;
    }
    if (widget.isBosma && bosmaMetricsReady) {
      Navigator.of(context).pop(
        _ProgressQtyInput(
          finishedGoodsMeter: meterQty,
          finishedGoodsKg: kgQty,
          returnInkKg: _isComplete ? returnInkKg : null,
          totalWaste: totalWaste,
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
        isCompletionRequest: true,
      );
    }
    return _ProgressQtyInput(
      meterQty: meterQty,
      kgQty: kgQty,
      description: description,
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
