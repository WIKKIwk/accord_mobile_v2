part of 'preparation_screen.dart';

String _formulaPageError(Object error) => preparationFormulaErrorMessage(error);

const _sharedFormulaWarning =
    'Katalogdagi o‘zgarishlar formula keyingi safar buyurtmaga biriktirilganda olinadi.';

class PreparationFormulaOrdersScreen extends StatefulWidget {
  const PreparationFormulaOrdersScreen({
    super.key,
    this.initialSaved = false,
    this.library,
  });
  final bool initialSaved;
  final PreparationFormulaLibraryStore? library;
  @override
  State<PreparationFormulaOrdersScreen> createState() =>
      _PreparationFormulaOrdersScreenState();
}

class _PreparationFormulaOrdersScreenState
    extends State<PreparationFormulaOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
      length: 2, initialIndex: widget.initialSaved ? 1 : 0, vsync: this);
  late final _library =
      widget.library ?? PreparationFormulaLibraryStore.instance;
  final _scope = currentSessionReadScope();
  bool get _sameScope =>
      AppSession.instance.isLoggedIn && _scope == currentSessionReadScope();
  bool get _saved => _tabs.index == 1;
  late bool _lastTab = widget.initialSaved;
  List<PreparationFormulaSet> get _sets =>
      _sameScope ? _library.sets : const [];
  List<PreparationFormulaCatalogEntry> get _recipes =>
      _sameScope ? _library.recipes : const [];
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? get _error => !_sameScope
      ? 'Akkaunt o‘zgargan. Sahifani qayta oching'
      : _library.error == null
          ? null
          : _formulaPageError(_library.error!);
  bool get _loading => _error == null && !_library.hasList(_saved);
  bool _renaming = false;
  @override
  void initState() {
    super.initState();
    _library.attach();
    _library.addListener(_libraryChanged);
    _tabs.addListener(_tabChanged);
    unawaited(_library.ensure(_saved));
  }

  void _libraryChanged() => setState(() {});

  void _tabChanged() {
    if (_lastTab == _saved) return;
    _lastTab = _saved;
    _search.clear();
    setState(() => _query = '');
    unawaited(_library.ensure(_saved));
  }

  @override
  void dispose() {
    _library.removeListener(_libraryChanged);
    _library.detach();
    _tabs.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() =>
      _renaming || !_sameScope ? Future.value() : _library.refresh(_saved);

  Future<void> _open(PreparationFormulaSet formulaSet) async {
    if (_renaming || !_sameScope) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => _PreparationFormulaSetDetails(
              formulaSet: formulaSet,
              library: _library,
            )));
  }

  int _recipeCount(PreparationFormulaSet formulaSet) =>
      _library.recipesFor(formulaSet.productCode).length +
      formulaSet.formulas.where((entry) => entry.variantId.isEmpty).length;

  Future<void> _actions(PreparationFormulaSet formulaSet) async {
    if (_loading || _renaming || !_sameScope) return;
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
    if (!mounted || !_sameScope || action != 'rename') return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => PreparationInputDialog(
        title: 'Komplekt nomini o‘zgartirish',
        label: 'Komplekt nomi',
        initialValue: formulaSet.name,
      ),
    );
    if (!mounted ||
        !_sameScope ||
        name == null ||
        name == formulaSet.name ||
        _renaming) return;
    setState(() => _renaming = true);
    try {
      final savedName = await MobileApi.instance.preparationRenameFormulaSet(
        setId: formulaSet.id,
        name: name,
      );
      if (!mounted || !_sameScope) return;
      _library.renamedSet(formulaSet.id, savedName);
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

  Future<void> _openRecipe(PreparationFormulaCatalogEntry entry) async {
    if (_renaming || _loading || !_sameScope) return;
    setState(() => _renaming = true);
    var changed = false;
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
        onChanged: () => changed = true,
      ));
    } finally {
      if (mounted) {
        setState(() => _renaming = false);
        if (changed && _sameScope) await _library.afterEdit(saved: true);
      }
    }
  }

  Future<void> _rename(PreparationFormulaCatalogEntry entry) async {
    if (_renaming || _loading || !_sameScope) return;
    setState(() => _renaming = true);
    final renamed = await _renameCatalogRecipe(context, entry);
    if (!mounted) return;
    setState(() => _renaming = false);
    if (renamed && _sameScope) await _library.afterEdit(saved: true);
  }

  @override
  Widget build(BuildContext context) {
    final sets = _sets
        .where((item) =>
            '${item.id} ${item.name} ${item.productTitle} ${item.productCode} ${item.orderCodes.join(' ')}'
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
        hintText: _saved
            ? 'Formula nomi, kodi yoki buyurtmani qidirish'
            : 'Mahsulot yoki buyurtmani qidirish',
        onBack: () {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          } else {
            navigator.pushReplacementNamed(AppRoutes.preparation);
          }
        },
        onChanged: (query) => setState(() => _query = query),
        onClear: () {
          _search.clear();
          setState(() => _query = '');
        },
      ),
      contentPadding: EdgeInsets.zero,
      bottom: const PreparationDock(showPrimaryFab: false),
      child: Column(children: [
        IgnorePointer(
          ignoring: _renaming || !_sameScope,
          child: AdminSurfaceTabBar(controller: _tabs, tabs: const [
            Tab(child: UrduAwareText('Mahsulot bo‘yicha')),
            Tab(child: UrduAwareText('Saqlangan formulalar')),
          ]),
        ),
        if (_renaming && !_saved) const LinearProgressIndicator(),
        Expanded(
            child: _loading
                ? const Center(child: AppLoadingIndicator())
                : _saved
                    ? _savedRecipeList()
                    : AppRefreshIndicator(
                        onRefresh: _load,
                        allowRefreshOnShortContent: true,
                        child: ListView(
                            key: const PageStorageKey(
                                'preparation-formula-sets'),
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
                                          child: const UrduAwareText(
                                              'Qayta urinish')),
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
                                        .standaloneListSlotForIndex(
                                            i, sets.length),
                                    icon: Icons.functions_rounded,
                                    title: sets[i].name,
                                    subtitle: sets[i].orderCodes.isEmpty
                                        ? '${sets[i].id}\nMos buyurtma yo‘q'
                                        : sets[i].id,
                                    subtitleMaxLines:
                                        sets[i].orderCodes.isEmpty ? 2 : 1,
                                    value:
                                        '${_recipeCount(sets[i])} ta formula',
                                    onTap:
                                        _renaming ? null : () => _open(sets[i]),
                                    onLongPress: _renaming
                                        ? null
                                        : () => _actions(sets[i]),
                                  ),
                              ]),
                            ]),
                      )),
      ]),
    );
  }

  Widget _savedRecipeList() {
    final query = _search.text.trim().toLowerCase();
    final setNames = {for (final set in _sets) set.productCode: set.name};
    final entries = [
      for (final entry in _recipes)
        if ([
          entry.name,
          entry.code,
          entry.materialName,
          setNames[entry.productCode] ?? entry.setName,
          entry.productTitle,
          entry.productCode,
          ...entry.orderCodes
        ].join(' ').toLowerCase().contains(query))
          entry,
    ];
    return AppRefreshIndicator(
      onRefresh: _load,
      allowRefreshOnShortContent: true,
      child: ListView.builder(
        key: const PageStorageKey('preparation-saved-formulas'),
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
              onTap: _renaming ? null : () => _openRecipe(entry),
              onLongPress: _renaming ? null : () => _rename(entry),
            ),
          );
        },
      ),
    );
  }
}

class _PreparationFormulaSetDetails extends StatefulWidget {
  const _PreparationFormulaSetDetails({
    required this.formulaSet,
    required this.library,
  });
  final PreparationFormulaSet formulaSet;
  final PreparationFormulaLibraryStore library;
  @override
  State<_PreparationFormulaSetDetails> createState() =>
      _PreparationFormulaSetDetailsState();
}

class _PreparationFormulaSetDetailsState
    extends State<_PreparationFormulaSetDetails> {
  final _scope = currentSessionReadScope();
  bool get _sameScope =>
      AppSession.instance.isLoggedIn && _scope == currentSessionReadScope();
  PreparationFormulaLibraryStore get _library => widget.library;
  PreparationFormulaSet? get _currentSet =>
      _library.sets.where((set) => set.id == widget.formulaSet.id).firstOrNull;
  List<PreparationScopedFormula> get _formulas =>
      _sameScope ? _currentSet?.formulas ?? const [] : const [];
  List<PreparationFormulaCatalogEntry> get _recipes => _sameScope
      ? _library.recipesFor(widget.formulaSet.productCode)
      : const [];
  bool _busy = false;
  String? get _error =>
      _library.error == null ? null : _formulaPageError(_library.error!);
  Future<void> _reload() =>
      _sameScope && !_busy ? _library.refresh(false) : Future.value();

  Future<void> _openRecipe(PreparationFormulaCatalogEntry entry) async {
    if (_busy || !_sameScope) return;
    setState(() => _busy = true);
    var changed = false;
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
        onChanged: () => changed = true,
      ));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (changed && _sameScope) await _library.afterEdit(saved: false);
      }
    }
  }

  Future<void> _renameRecipe(PreparationFormulaCatalogEntry entry) async {
    if (_busy || !_sameScope) return;
    setState(() => _busy = true);
    final renamed = await _renameCatalogRecipe(context, entry);
    if (!mounted) return;
    setState(() => _busy = false);
    if (renamed && _sameScope) await _library.afterEdit(saved: false);
  }

  Future<void> _actions(PreparationScopedFormula entry) async {
    if (_busy || !_sameScope) return;
    final action = await showPreparationFormulaDetails(
      context,
      formula: entry.formula,
      materialName: entry.materialName,
      sharesComplete: preparationFormulaSharesComplete(_formulas
          .where((f) =>
              f.materialId == entry.materialId &&
              f.variantId == entry.variantId)
          .map((f) => f.formula)
          .toList()),
    );
    if (!mounted || !_sameScope || action == null) return;
    if (action == 'shares') {
      final updated = await showPreparationFormulaSharesEditor(
        context,
        productCode: widget.formulaSet.productCode,
        materialId: entry.materialId,
        materialName: entry.materialName,
        formulas: _formulas
            .where((f) =>
                f.materialId == entry.materialId &&
                f.variantId == entry.variantId)
            .map((f) => f.formula)
            .toList(),
        savedOnly: true,
        variantId: entry.variantId,
      );
      if (mounted && _sameScope && updated != null) {
        await _library.afterEdit(saved: false);
      }
      return;
    }
    if (action == 'edit') {
      var changed = false;
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
        onChanged: () => changed = true,
      ));
      if (mounted && _sameScope && changed) {
        await _library.afterEdit(saved: false);
      }
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
    if (!mounted || !_sameScope || confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      await MobileApi.instance.preparationDeleteFormula(
          widget.formulaSet.productCode, entry.formula.name,
          materialId: entry.materialId,
          savedOnly: true,
          variantId: entry.variantId);
      if (!mounted || !_sameScope) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: UrduAwareText('Formula o‘chirildi')));
      _library.removedFormula(widget.formulaSet.id, entry);
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
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _library,
        builder: (context, _) => _buildDetails(context),
      );

  Widget _buildDetails(BuildContext context) {
    if (!_sameScope || !_library.hasList(false)) {
      return AppShell(
        title: 'Formulalar',
        subtitle: '',
        child: Center(
          child: UrduAwareText(
            _error ?? 'Akkaunt o‘zgargan. Sahifani qayta oching',
          ),
        ),
      );
    }
    final formulas = _formulas;
    final recipes = _recipes;
    final legacyFormulas =
        formulas.where((entry) => entry.variantId.isEmpty).toList();
    final rowCount = recipes.length + legacyFormulas.length;
    return AppShell(
      title: _currentSet?.name ?? widget.formulaSet.name,
      subtitle: widget.formulaSet.id,
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
              if (rowCount == 0)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: UrduAwareText('Bu komplektda formula qolmadi.')),
              M3SegmentSpacedColumn(children: [
                for (final (index, entry) in recipes.indexed)
                  AdminCatalogListRow(
                    key: ValueKey('preparation-product-recipe-${entry.id}'),
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                        index, rowCount),
                    icon: Icons.functions_rounded,
                    title: entry.name,
                    subtitle: [entry.code, entry.materialName]
                        .where((part) => part.isNotEmpty)
                        .join(' • '),
                    onTap: _busy ? null : () => _openRecipe(entry),
                    onLongPress: _busy ? null : () => _renameRecipe(entry),
                  ),
                for (final (index, entry) in legacyFormulas.indexed)
                  AdminCatalogListRow(
                    key: ValueKey(
                        'preparation-order-formula-${entry.materialId}-${entry.variantId.isEmpty ? '' : '${entry.variantId}-'}${entry.formula.name}'),
                    slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                        recipes.length + index, rowCount),
                    icon: Icons.functions_rounded,
                    title: [
                      entry.variantName,
                      entry.materialName,
                      entry.formula.name
                    ].where((part) => part.isNotEmpty).join(' • '),
                    subtitle: [
                      entry.formula.sharePercent == null
                          ? 'Shnek ulushi belgilanmagan'
                          : 'Shnek ulushi: ${preparationDisplay(entry.formula.sharePercent!)}%',
                      if (entry.materialId.isEmpty)
                        'Eski formula — homashyo turi belgilanmagan',
                      for (final line in entry.formula.lines)
                        '${line.name} • ${preparationDisplay(line.percent)}%',
                    ].join('\n'),
                    subtitleMaxLines: entry.formula.lines.length +
                        1 +
                        (entry.materialId.isEmpty ? 1 : 0),
                    onTap: _busy ? null : () => _actions(entry),
                  ),
              ]),
            ]),
      ),
    );
  }
}
