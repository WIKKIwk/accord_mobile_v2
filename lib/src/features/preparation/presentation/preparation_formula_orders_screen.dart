part of 'preparation_screen.dart';

String _formulaPageError(Object error) => preparationFormulaErrorMessage(error);

const _sharedFormulaWarning =
    'Formula mahsulot va homashyo turi uchun umumiy. O‘zgarishlar shu mahsulotli boshqa buyurtmalarda ham ko‘rinadi.';

class PreparationFormulaOrdersScreen extends StatefulWidget {
  const PreparationFormulaOrdersScreen({super.key});
  @override
  State<PreparationFormulaOrdersScreen> createState() =>
      _PreparationFormulaOrdersScreenState();
}

class _PreparationFormulaOrdersScreenState
    extends State<PreparationFormulaOrdersScreen> {
  List<PreparationFormulaSet> _sets = [];
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _error;
  bool _loading = true;
  bool _renaming = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_renaming) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sets = await MobileApi.instance.preparationFormulaSets();
      if (mounted) setState(() => _sets = sets);
    } catch (error) {
      if (mounted) setState(() => _error = _formulaPageError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(PreparationFormulaSet formulaSet) async {
    if (_renaming) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _PreparationFormulaSetDetails(formulaSet: formulaSet)));
    if (mounted) await _load();
  }

  Future<void> _actions(PreparationFormulaSet formulaSet) async {
    if (_loading || _renaming) return;
    final action = await showSpringBottomSheet<String>(
      context: context,
      builder: (_) => AppActionSheet<String>(
        title: formulaSet.id,
        actions: const [
          AppActionSheetAction(
            title: 'Nomini o‘zgartirish',
            icon: Icons.edit_outlined,
            value: 'rename',
          ),
        ],
      ),
    );
    if (!mounted || action != 'rename') return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _PreparationInputDialog(
        title: 'Komplekt nomini o‘zgartirish',
        label: 'Komplekt nomi',
        initialValue: formulaSet.name,
      ),
    );
    if (!mounted || name == null || name == formulaSet.name || _renaming) return;
    setState(() => _renaming = true);
    try {
      final savedName = await MobileApi.instance.preparationRenameFormulaSet(
        setId: formulaSet.id,
        name: name,
      );
      if (!mounted) return;
      setState(() => _sets = [
            for (final item in _sets)
              if (item.id == formulaSet.id) item.renamed(savedName) else item,
          ]);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: UrduAwareText('Komplekt nomi o‘zgartirildi')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_formulaPageError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _renaming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sets = _sets
        .where((item) => '${item.id} ${item.name} ${item.productTitle} ${item.productCode} ${item.orderCodes.join(' ')}'
            .toLowerCase()
            .contains(_query.trim().toLowerCase()))
        .toList();
    return AppShell(
      title: 'Formulalar',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      profileActionListenable: _searchFocus,
      showProfileActionResolver: () => !_searchFocus.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _search,
        focusNode: _searchFocus,
        hintText: 'Kod, nom yoki buyurtmani qidirish',
        onChanged: (query) => setState(() => _query = query),
        onClear: () {
          _search.clear();
          setState(() => _query = '');
        },
      ),
      contentPadding: EdgeInsets.zero,
      bottom: const PreparationDock(showPrimaryFab: false),
      child: Column(children: [
        if (_renaming) const LinearProgressIndicator(),
        Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator())
                : AppRefreshIndicator(
                    onRefresh: _load,
                    allowRefreshOnShortContent: true,
                    child: ListView(
                        physics: const TopRefreshScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 136),
                        children: [
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(children: [
                                  Text(_error!),
                                  TextButton(
                                      onPressed: _load,
                                      child:
                                          const UrduAwareText('Qayta urinish')),
                                ])),
                          if (_error == null && sets.isEmpty)
                            Padding(
                                padding: const EdgeInsets.all(16),
                                child: UrduAwareText(_query.trim().isEmpty
                                    ? 'Saqlangan formulalar yo‘q.'
                                    : 'Formula komplekti topilmadi.')),
                          M3SegmentSpacedColumn(children: [
                            for (var i = 0; i < sets.length; i++)
                              AdminCatalogListRow(
                                key: ValueKey(
                                    'preparation-formula-set-${sets[i].id}'),
                                slot: M3SegmentedListGeometry
                                    .standaloneListSlotForIndex(i, sets.length),
                                icon: Icons.functions_rounded,
                                title: sets[i].name,
                                subtitle: sets[i].orderCodes.isEmpty
                                    ? '${sets[i].id}\nMos buyurtma yo‘q'
                                    : sets[i].id,
                                subtitleMaxLines:
                                    sets[i].orderCodes.isEmpty ? 2 : 1,
                                value:
                                    '${sets[i].formulas.length} ta formula',
                                onTap: _renaming ? null : () => _open(sets[i]),
                                onLongPress: _renaming ? null : () => _actions(sets[i]),
                              ),
                          ]),
                        ]),
                  )),
      ]),
    );
  }
}

class _PreparationFormulaSetDetails extends StatefulWidget {
  const _PreparationFormulaSetDetails({required this.formulaSet});
  final PreparationFormulaSet formulaSet;
  @override
  State<_PreparationFormulaSetDetails> createState() =>
      _PreparationFormulaSetDetailsState();
}

class _PreparationFormulaSetDetailsState
    extends State<_PreparationFormulaSetDetails> {
  late List<PreparationScopedFormula> _formulas = widget.formulaSet.formulas;
  bool _busy = false;
  String? _error;

  Future<void> _reload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sets = await MobileApi.instance.preparationFormulaSets();
      if (mounted) {
        setState(() => _formulas = sets
                .where((item) => item.id == widget.formulaSet.id)
                .firstOrNull
                ?.formulas ??
            []);
      }
    } catch (error) {
      if (mounted) setState(() => _error = _formulaPageError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _actions(PreparationScopedFormula entry) async {
    if (_busy) return;
    final action = await showPreparationFormulaDetails(
      context,
      formula: entry.formula,
      materialName: entry.materialName,
      sharesComplete: preparationFormulaSharesComplete(_formulas
          .where((f) => f.materialId == entry.materialId && f.variantId == entry.variantId).map((f) => f.formula).toList()),
    );
    if (!mounted || action == null) return;
    if (action == 'shares') {
      final updated = await showPreparationFormulaSharesEditor(context,
        productCode: widget.formulaSet.productCode,
        materialId: entry.materialId, materialName: entry.materialName,
        formulas: _formulas.where((f) => f.materialId == entry.materialId && f.variantId == entry.variantId)
            .map((f) => f.formula).toList(), savedOnly: true, variantId: entry.variantId,
      );
      if (mounted && updated != null) await _reload();
      return;
    }
    if (action == 'edit') {
      await Navigator.of(context).push(PreparationOrderFormulaScreen.route(
        orderId: widget.formulaSet.id,
        orderCode: widget.formulaSet.id,
        productCode: widget.formulaSet.productCode,
        productTitle: widget.formulaSet.name,
        materialId: entry.materialId,
        materialName: entry.materialName,
        initialFormulaName: entry.formula.name,
        manageSavedFormula: true,
        variantId: entry.variantId,
        variantName: entry.variantName,
      ));
      if (mounted) await _reload();
      return;
    }
    final confirmed = await showM3ConfirmDialog(
        context: context,
        title: 'Formulani o‘chirish',
        message:
            '«${entry.formula.name}» formulasi o‘chirilsinmi? $_sharedFormulaWarning',
        cancelLabel: 'Bekor qilish',
        confirmLabel: 'O‘chirish',
        destructive: true);
    if (!mounted || confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      await MobileApi.instance.preparationDeleteFormula(
          widget.formulaSet.productCode, entry.formula.name,
          materialId: entry.materialId, savedOnly: true, variantId: entry.variantId);
      if (!mounted) return;
      setState(() => _formulas = _formulas
          .where((f) =>
              f.materialId != entry.materialId ||
              f.variantId != entry.variantId ||
              f.formula.name != entry.formula.name)
          .toList());
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: UrduAwareText('Formula o‘chirildi')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_formulaPageError(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: widget.formulaSet.id,
        subtitle: widget.formulaSet.name,
        nativeTopBar: true,
        contentPadding: EdgeInsets.zero,
        bottom: const PreparationDock(showPrimaryFab: false),
        child: AppRefreshIndicator(
          onRefresh: _reload,
          allowRefreshOnShortContent: true,
          child: ListView(
              physics: const TopRefreshScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 136),
              children: [
                if (_busy) const LinearProgressIndicator(),
                const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(_sharedFormulaWarning)),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.all(12), child: Text(_error!)),
                if (_formulas.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: UrduAwareText('Bu komplektda formula qolmadi.')),
                M3SegmentSpacedColumn(children: [
                  for (final (index, entry) in _formulas.indexed)
                    AdminCatalogListRow(
                      key: ValueKey(
                          'preparation-order-formula-${entry.materialId}-${entry.variantId.isEmpty ? '' : '${entry.variantId}-'}${entry.formula.name}'),
                      slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                          index, _formulas.length),
                      icon: Icons.functions_rounded,
                      title: [entry.variantName, entry.materialName, entry.formula.name]
                          .where((part) => part.isNotEmpty).join(' • '),
                      subtitle: [
                        entry.formula.sharePercent == null
                            ? 'Shnek ulushi belgilanmagan'
                            : 'Shnek ulushi: ${preparationDisplay(entry.formula.sharePercent!)}%',
                        if (entry.materialId.isEmpty)
                          'Eski formula — homashyo turi belgilanmagan',
                        for (final line in entry.formula.lines)
                          '${line.name} • ${preparationDisplay(line.percent)}%',
                      ].join('\n'),
                      subtitleMaxLines: entry.formula.lines.length + 1 +
                          (entry.materialId.isEmpty ? 1 : 0),
                      onTap: _busy ? null : () => _actions(entry),
                    ),
                ]),
              ]),
        ),
      );
}
