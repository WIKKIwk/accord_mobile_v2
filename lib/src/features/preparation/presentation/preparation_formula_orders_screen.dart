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
  List<PreparationFormulaOrder> _orders = [];
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  String? _error;
  bool _loading = true;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await MobileApi.instance.preparationFormulaOrders();
      if (mounted) setState(() => _orders = orders);
    } catch (error) {
      if (mounted) setState(() => _error = _formulaPageError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(PreparationFormulaOrder order) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _PreparationFormulaOrderDetails(order: order)));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders
        .where((order) => '${order.code} ${order.title} ${order.productCode}'
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
        hintText: 'Buyurtma yoki mahsulotni qidirish',
        onChanged: (query) => setState(() => _query = query),
        onClear: () {
          _search.clear();
          setState(() => _query = '');
        },
      ),
      contentPadding: EdgeInsets.zero,
      bottom: const PreparationDock(showPrimaryFab: false),
      child: Column(children: [
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
                                      child: const Text('Qayta urinish')),
                                ])),
                          if (_error == null && orders.isEmpty)
                            Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(_query.trim().isEmpty
                                    ? 'Saqlangan formulalar yo‘q.'
                                    : 'Formula topilmadi.')),
                          M3SegmentSpacedColumn(children: [
                            for (var i = 0; i < orders.length; i++)
                              AdminSummaryCard(
                                key: ValueKey(
                                    'preparation-formula-order-${orders[i].id}'),
                                slot: _slotFor(i, orders.length),
                                cornerRadius:
                                    M3SegmentedListGeometry.cornerLarge,
                                title: orders[i].code.isEmpty
                                    ? orders[i].title
                                    : orders[i].code,
                                subtitle: !orders[i].hasOrder
                                    ? 'Mos buyurtma yo‘q'
                                    : orders[i].code.isEmpty
                                        ? null
                                        : orders[i].title,
                                value:
                                    '${orders[i].formulas.length} ta formula',
                                onTap: () => _open(orders[i]),
                                elevation: 0,
                              ),
                          ]),
                        ]),
                  )),
      ]),
    );
  }
}

class _PreparationFormulaOrderDetails extends StatefulWidget {
  const _PreparationFormulaOrderDetails({required this.order});
  final PreparationFormulaOrder order;
  @override
  State<_PreparationFormulaOrderDetails> createState() =>
      _PreparationFormulaOrderDetailsState();
}

class _PreparationFormulaOrderDetailsState
    extends State<_PreparationFormulaOrderDetails> {
  late List<PreparationScopedFormula> _formulas = widget.order.formulas;
  bool _busy = false;
  String? _error;

  Future<void> _reload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final orders = await MobileApi.instance.preparationFormulaOrders();
      if (mounted) {
        setState(() => _formulas = orders
                .where((o) => o.id == widget.order.id)
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
    final action = await showSpringBottomSheet<String>(
      context: context,
      builder: (_) => AppActionSheet<String>(
        title: entry.formula.name,
        actions: const [
          AppActionSheetAction(
            title: 'Tahrirlash',
            icon: Icons.edit_outlined,
            value: 'edit',
          ),
          AppActionSheetAction(
            title: 'O‘chirish',
            icon: Icons.delete_outline_rounded,
            value: 'delete',
            destructive: true,
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'edit') {
      await Navigator.of(context).push(PreparationOrderFormulaScreen.route(
        orderId: widget.order.id,
        orderCode: widget.order.code,
        productCode: widget.order.productCode,
        productTitle: widget.order.title,
        materialId: entry.materialId,
        materialName: entry.materialName,
        initialFormulaName: entry.formula.name,
        manageSavedFormula: true,
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
          widget.order.productCode, entry.formula.name,
          materialId: entry.materialId, savedOnly: true);
      if (!mounted) return;
      setState(() => _formulas = _formulas
          .where((f) =>
              f.materialId != entry.materialId ||
              f.formula.name != entry.formula.name)
          .toList());
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Formula o‘chirildi')));
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
        title: widget.order.code.isEmpty ? 'Formulalar' : widget.order.code,
        subtitle: widget.order.title,
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
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(widget.order.hasOrder
                          ? 'Bu buyurtmada formula qolmadi.'
                          : 'Bu mahsulotda formula qolmadi.')),
                M3SegmentSpacedColumn(children: [
                  for (var i = 0; i < _formulas.length; i++)
                    M3SegmentFilledSurface(
                      key: ValueKey(
                          'preparation-order-formula-${_formulas[i].materialId}-${_formulas[i].formula.name}'),
                      slot: _slotFor(i, _formulas.length),
                      cornerRadius: M3SegmentedListGeometry.cornerLarge,
                      onTap: _busy ? null : () => _actions(_formulas[i]),
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: Text(
                                          _formulas[i].materialName.isEmpty
                                              ? _formulas[i].formula.name
                                              : '${_formulas[i].materialName} • ${_formulas[i].formula.name}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium)),
                                  IconButton(
                                      tooltip: 'Formula amallari',
                                      onPressed: _busy
                                          ? null
                                          : () => _actions(_formulas[i]),
                                      icon: const Icon(Icons.more_vert))
                                ]),
                                if (_formulas[i].materialId.isEmpty)
                                  const Text(
                                      'Eski formula — homashyo turi belgilanmagan'),
                                for (final line in _formulas[i].formula.lines)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(children: [
                                        Expanded(child: Text(line.name)),
                                        const SizedBox(width: 12),
                                        Text(
                                            '${preparationDisplay(line.percent)}%'),
                                      ])),
                              ])),
                    ),
                ]),
              ]),
        ),
      );
}
