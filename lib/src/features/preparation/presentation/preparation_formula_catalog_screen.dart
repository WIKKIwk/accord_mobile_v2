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
  List<PreparationFormulaCatalogEntry> _formulas = const [];
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
      _formulas = const [];
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
      final formulas = await MobileApi.instance.preparationFormulaCatalog();
      if (mounted && _sameScope) setState(() => _formulas = formulas);
    } catch (error) {
      if (mounted && _sameScope) {
        setState(() => _error = preparationFormulaErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(PreparationFormulaCatalogEntry entry) async {
    if (_busy || _loading || !_sameScope) return;
    setState(() => _busy = true);
    try {
      await Navigator.of(context).push(PreparationOrderFormulaScreen.route(
        orderId: '',
        orderCode: '',
        productCode: entry.productCode,
        productTitle: entry.productTitle,
        materialId: entry.materialId,
        materialName: entry.materialName,
        manageSavedFormula: true,
        variantId: entry.id,
        variantName: entry.name,
        variantCode: entry.code,
        allowAddingFormula: entry.canCreate,
      ));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_sameScope) await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final entries = [
      for (final entry in _formulas)
        if ([
          entry.name,
          entry.code,
          entry.materialName,
          entry.setName,
          entry.productTitle,
          entry.productCode,
          ...entry.orderCodes
        ].join(' ').toLowerCase().contains(query))
          entry,
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
          showLeading: false,
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
                  final entry = entries[index - 1];
                  return Padding(
                    padding: EdgeInsets.only(
                      top: index == 1 ? 0 : M3SegmentedListGeometry.gap,
                    ),
                    child: AdminCatalogListRow(
                      key: ValueKey('preparation-catalog-formula-${entry.id}'),
                      slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                          index - 1, entries.length),
                      icon: Icons.functions_rounded,
                      title: entry.name,
                      subtitle: [
                        if (entry.code.isNotEmpty) entry.code,
                        entry.productTitle,
                        if (entry.materialName.isNotEmpty) entry.materialName,
                        if (entry.orderCodes.isNotEmpty)
                          'Buyurtmalar: ${entry.orderCodes.join(', ')}',
                      ].join(' • '),
                      onTap: _busy ? null : () => _open(entry),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
