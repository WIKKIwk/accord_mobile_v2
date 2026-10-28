part of 'preparation_screen.dart';

class PreparationFormulaCatalogScreen extends StatefulWidget {
  const PreparationFormulaCatalogScreen({super.key});

  @override
  State<PreparationFormulaCatalogScreen> createState() =>
      _PreparationFormulaCatalogScreenState();
}

class _PreparationFormulaCatalogScreenState
    extends State<PreparationFormulaCatalogScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late final _scope = currentSessionReadScope();
  bool get _sameScope => _scope == currentSessionReadScope();
  List<PreparationFormulaSet> _sets = const [];
  bool _loading = true, _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppSession.instance.revision.addListener(_sessionChanged);
    _load();
  }

  void _sessionChanged() {
    if (!mounted || _sameScope) return;
    setState(() {
      _sets = const [];
      _loading = false;
      _error = 'Akkaunt o‘zgargan. Sahifani qayta oching';
    });
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_busy || !_sameScope) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sets = await MobileApi.instance.preparationFormulaSets();
      if (mounted && _sameScope) setState(() => _sets = sets);
    } catch (error) {
      if (mounted && _sameScope) {
        setState(() => _error = preparationFormulaErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(
      PreparationFormulaSet set, PreparationScopedFormula entry) async {
    if (_busy || _loading || !_sameScope) return;
    setState(() => _busy = true);
    var changed = false;
    try {
      final formulas = set.formulas
          .where((f) =>
              f.materialId == entry.materialId &&
              f.variantId == entry.variantId)
          .map((f) => f.formula)
          .toList();
      final action = await showPreparationFormulaDetails(context,
          formula: entry.formula,
          materialName: entry.materialName,
          sharesComplete: preparationFormulaSharesComplete(formulas));
      if (!mounted || !_sameScope || action == null) return;
      if (action == 'shares') {
        final updated = await showPreparationFormulaSharesEditor(context,
            productCode: set.productCode,
            materialId: entry.materialId,
            materialName: entry.materialName,
            formulas: formulas,
            savedOnly: true,
            variantId: entry.variantId);
        changed = updated != null;
      } else if (action == 'edit') {
        await Navigator.of(context).push(PreparationOrderFormulaScreen.route(
            orderId: set.id,
            orderCode: set.id,
            productCode: set.productCode,
            productTitle: set.productTitle,
            materialId: entry.materialId,
            materialName: entry.materialName,
            initialFormulaName: entry.formula.name,
            manageSavedFormula: true,
            variantId: entry.variantId,
            variantName: entry.variantName));
        changed = true;
      } else if (action == 'delete') {
        final confirmed = await showM3ConfirmDialog(
            context: context,
            title: 'Formulani o‘chirish',
            message:
                '«${entry.formula.name}» formulasi o‘chirilsinmi? $_sharedFormulaWarning',
            cancelLabel: 'Bekor qilish',
            confirmLabel: 'O‘chirish',
            destructive: true);
        if (!mounted || !_sameScope || confirmed != true) return;
        await MobileApi.instance.preparationDeleteFormula(
            set.productCode, entry.formula.name,
            materialId: entry.materialId,
            savedOnly: true,
            variantId: entry.variantId);
        changed = true;
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(preparationFormulaErrorMessage(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (changed) await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final entries = [
      for (final set in _sets)
        for (final entry in set.formulas)
          if ([
            entry.formula.name,
            entry.formula.code,
            entry.variantName,
            entry.materialName,
            set.name,
            set.productTitle,
            set.productCode,
            ...set.orderCodes
          ].join(' ').toLowerCase().contains(query))
            (set, entry),
    ];
    return AppShell(
      title: 'Formulalar',
      subtitle: '',
      nativeTopBar: true,
      contentPadding: EdgeInsets.zero,
      drawer: const PreparationDrawer(
          selectedRouteName: AppRoutes.preparationFormulas),
      bottom: const PreparationDock(showPrimaryFab: false),
      titleWidget: AdminCatalogSearchField(
          controller: _search,
          focusNode: _searchFocus,
          hintText: 'Formula nomi, kodi yoki buyurtmani qidirish',
          onChanged: (_) => setState(() {}),
          onClear: () => setState(_search.clear)),
      child: _loading
          ? const Center(child: AppLoadingIndicator())
          : AppRefreshIndicator(
              onRefresh: _load,
              allowRefreshOnShortContent: true,
              child: ListView.builder(
                physics: const TopRefreshScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 136),
                itemCount: entries.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            UrduAwareText(
                                'Barcha buyurtmalarning formulalari: ${entries.length} ta'),
                            if (_error != null) ...[
                              Text(_error!),
                              TextButton(
                                  onPressed: _load,
                                  child: const UrduAwareText('Qayta urinish')),
                            ] else if (entries.isEmpty)
                              UrduAwareText(query.isEmpty
                                  ? 'Saqlangan formulalar yo‘q.'
                                  : 'Formula topilmadi.'),
                          ]),
                    );
                  }
                  final (set, entry) = entries[index - 1];
                  final formula = entry.formula;
                  return AdminCatalogListRow(
                    key: ValueKey(
                        'preparation-catalog-formula-${formula.code.isNotEmpty ? formula.code : '${set.id}-${entry.materialId}-${entry.variantId}-${formula.name}'}'),
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                        index - 1, entries.length),
                    icon: Icons.functions_rounded,
                    title: [entry.variantName, formula.name]
                        .where((v) => v.isNotEmpty)
                        .join(' • '),
                    subtitle: [
                      if (formula.code.isNotEmpty) formula.code,
                      set.productTitle,
                      if (entry.materialName.isNotEmpty) entry.materialName,
                      if (set.orderCodes.isNotEmpty)
                        'Buyurtmalar: ${set.orderCodes.join(', ')}',
                    ].join('\n'),
                    subtitleMaxLines: 4,
                    onTap: _busy ? null : () => _open(set, entry),
                  );
                },
              ),
            ),
    );
  }
}
