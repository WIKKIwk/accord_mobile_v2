part of 'admin_production_map_orders_screen.dart';

extension _QolipTasksScreen on _AdminProductionMapOrdersScreenState {
  Widget _buildQolipTasks(double bottomPadding) {
    final apparatus = _apparatus
        .where((item) => widget.materialTasksMode ||
            (item.isPechat && item.capabilities.contains('tooling')))
        .toList();
    final selected = apparatus
            .where((item) => item.id == _selectedApparatus?.id)
            .firstOrNull ??
        apparatus.firstOrNull;
    return _QolipTasksPage(
      materialMode: widget.materialTasksMode,
      apparatus: apparatus,
      selected: selected,
      orders: selected == null ? const [] : _ordersForApparatus(selected),
      customers: _customerByMapId,
      searchQuery: _searchQuery,
      bottomPadding: bottomPadding,
      onShowOrder: _showOrderDetail,
      onSelect: (item) {
        _userChangedSequenceApparatus = true;
        unawaited(AdminSequenceApparatusStore.instance.saveApparatus(item));
        _updateScreenState(() => _selectedApparatus = item);
      },
    );
  }
}

class _QolipTasksPage extends StatefulWidget {
  const _QolipTasksPage(
      {this.materialMode = false,
      required this.apparatus,
      required this.selected,
      required this.orders,
      required this.customers,
      required this.searchQuery,
      required this.bottomPadding,
      required this.onShowOrder,
      required this.onSelect});

  final bool materialMode;
  final List<AdminApparatus> apparatus;
  final AdminApparatus? selected;
  final List<ProductionMapSaved> orders;
  final Map<String, String> customers;
  final String searchQuery;
  final double bottomPadding;
  final Future<void> Function(ProductionMapSaved) onShowOrder;
  final ValueChanged<AdminApparatus> onSelect;

  @override
  State<_QolipTasksPage> createState() => _QolipTasksPageState();
}

class _QolipTasksPageState extends State<_QolipTasksPage>
    with WidgetsBindingObserver {
  int _limit = 10;
  int _generation = 0;
  bool _apparatusExpanded = false;
  bool _limitExpanded = false;
  bool _loading = true;
  bool _refreshing = false;
  bool _foreground = true;
  bool _adding = false;
  Object? _error;
  Map<String, QolipProduct?> _products = {};
  Map<String, List<GScaleOrderMaterialTask>> _materials = {};
  Timer? _timer;

  List<ProductionMapSaved> get _window => widget.orders.take(_limit).toList();

  String _identity(_QolipTasksPage page) => jsonEncode([
        page.materialMode,
        page.selected?.id,
        for (final order in page.orders.take(_limit))
          [order.map.id, order.map.productCode],
      ]);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!widget.materialMode) QolipDataRevision.locations.addListener(_dataChanged);
    unawaited(_load());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_foreground && !_refreshing && !_adding) unawaited(_load());
    });
  }

  @override
  void didUpdateWidget(covariant _QolipTasksPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_identity(oldWidget) != _identity(widget)) {
      _loading = true;
      unawaited(_load());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) unawaited(_load());
  }

  void _dataChanged() => unawaited(_load());

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    if (!widget.materialMode) QolipDataRevision.locations.removeListener(_dataChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _refreshing = true;
    try {
      final ids = _window.map((order) => order.map.id).toList();
      final materials = widget.materialMode
          ? await MobileApi.instance.gscaleMaterialTasks(ids)
          : <String, List<GScaleOrderMaterialTask>>{};
      final products = widget.materialMode
          ? <String, QolipProduct?>{}
          : await MobileApi.instance.qolipOrderProducts(ids);
      if (!mounted || generation != _generation) return;
      setState(() {
        _products = products;
        _materials = materials;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    } finally {
      if (generation == _generation) _refreshing = false;
    }
  }

  Future<void> _showMaterialDetail(ProductionMapSaved order) async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      await widget.onShowOrder(order);
      if (mounted) await _load();
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _showMaterialActions(ProductionMapSaved order) async {
    if (_adding) return;
    setState(() => _adding = true);
    bool? receive;
    try {
      receive = await showModalBottomSheet<bool>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              key: const ValueKey('material-task-receive'),
              leading: const Icon(Icons.scale_outlined),
              title: const Text('Kirim qilish'),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
    if (mounted && receive == true) await _add(order);
  }

  Future<void> _add(ProductionMapSaved order) async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      if (widget.materialMode) {
        await _openMaterialOrderReceipt(context, order);
        if (mounted) await _load();
        return;
      }
      // Re-read the exact order identity before opening a writable form.
      final products =
          await MobileApi.instance.qolipOrderProducts([order.map.id]);
      final product = products[order.map.id];
      if (!mounted) return;
      if (product == null || product.itemGroup.trim().isEmpty) {
        throw StateError('missing_product');
      }
      if (!product.hasQolipSpec) {
        await showQolipProductSpecSheet(context,
            initialProduct: product, lockProduct: true);
        // Keep the existing sheet open after save so its QR print action is available.
      }
      if (!mounted) return;
      QolipDataRevision.notifyLocationsChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
        widget.materialMode ? 'Material vazifalari yuklanmadi' : context.l10n.qolipText(error is StateError
            ? 'tasks.product_missing'
            : 'tasks.load_failed'),
      )));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final window = _window;
    final missing = window
        .where((order) => widget.materialMode
            ? (_materials[order.map.id] ?? const []).any((item) => !item.assigned)
            : _products[order.map.id]?.hasQolipSpec != true)
        .toList();
    // The queue window is chosen before QR and text filters are applied.
    final visible = _filterOrdersBySearch(missing, query: widget.searchQuery);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AdminExpandableFilterChip<String>(
            label: l10n.productionText('worker.queue.filter.apparatus'),
            emptyLabel: l10n.productionText('worker.queue.filter.unselected'),
            icon: Icons.precision_manufacturing_rounded,
            selectedValue: widget.selected?.id,
            options: [
              for (final item in widget.apparatus)
                AdminFilterChipOption(value: item.id, label: item.name)
            ],
            expanded: _apparatusExpanded,
            onToggle: () =>
                setState(() => _apparatusExpanded = !_apparatusExpanded),
            onSelect: (id) {
              setState(() => _apparatusExpanded = false);
              widget.onSelect(
                  widget.apparatus.firstWhere((item) => item.id == id));
            },
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 6),
          AdminExpandableFilterChip<int>(
            chipKey: ValueKey('${widget.materialMode ? 'material' : 'qolip'}-tasks-limit'),
            optionKeyPrefix: '${widget.materialMode ? 'material' : 'qolip'}-tasks-limit',
            label: l10n.qolipText('tasks.check'),
            emptyLabel: '',
            icon: Icons.format_list_numbered_rounded,
            selectedValue: _limit,
            options: [
              for (final count in [5, 10, 20, 50])
                AdminFilterChipOption(
                    value: count,
                    label:
                        l10n.qolipText('tasks.count', values: {'count': count}))
            ],
            expanded: _limitExpanded,
            onToggle: () => setState(() => _limitExpanded = !_limitExpanded),
            onSelect: (count) {
              setState(() {
                _limit = count;
                _limitExpanded = false;
                _loading = true;
              });
              unawaited(_load());
            },
            padding: EdgeInsets.zero,
          ),
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                  widget.materialMode
                    ? 'Tekshirilgan: ${window.length} • Homashyo kutilmoqda: ${missing.length}'
                    : l10n.qolipText('tasks.summary', values: {
                    'count': window.length,
                    'missing': missing.length,
                  }),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ]),
      ),
      Expanded(
          child: _loading
              ? const Center(child: AppLoadingIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(4, 4, 4, widget.bottomPadding),
                    children: [
                      if (_error != null)
                        AppRetryState(
                            onRetry: _load,
                            message: widget.materialMode ? 'Material vazifalari yuklanmadi' : l10n.qolipText('tasks.load_failed'))
                      else if (visible.isEmpty)
                        Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              widget.materialMode && window.isNotEmpty && missing.isEmpty
                                  ? 'Tanlangan orderlarda sizning materiallaringiz bo‘yicha kutilayotgan homashyo yo‘q.'
                                  : l10n.qolipText(window.isEmpty
                                  ? 'tasks.no_orders'
                                  : missing.isEmpty
                                      ? 'tasks.ready'
                                      : 'products.search_empty'),
                              textAlign: TextAlign.center,
                            ))
                      else
                        for (var i = 0; i < visible.length; i++) ...[
                          if (i > 0)
                            const SizedBox(height: M3SegmentedListGeometry.gap),
                          _SequenceOrderRow(
                            key: ValueKey('${widget.materialMode ? 'material' : 'qolip'}-task-${visible[i].map.id}'),
                            slot: M3SegmentedListGeometry
                                .standaloneListSlotForIndex(i, visible.length),
                            order: visible[i],
                            index: window.indexOf(visible[i]),
                            readOnly: true,
                            customerName:
                                widget.customers[visible[i].map.id] ?? '',
                            statusLabel: widget.materialMode
                                ? ((_materials[visible[i].map.id] ?? const [])
                                        .any((item) => item.assigned)
                                    ? 'Qisman'
                                    : null)
                                : l10n.qolipText('tasks.attach'),
                            onTap: _adding
                                ? null
                                : () => widget.materialMode
                                    ? _showMaterialDetail(visible[i])
                                    : _add(visible[i]),
                            onLongPress: widget.materialMode && !_adding
                                ? () => _showMaterialActions(visible[i])
                                : null,
                          ),
                        ],
                    ],
                  ))),
    ]);
  }
}
