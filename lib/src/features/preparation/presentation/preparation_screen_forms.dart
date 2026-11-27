part of 'preparation_screen.dart';

Future<T?> _pickPreparationItem<T>(BuildContext context,
        {required String title,
        required List<T> items,
        required String Function(T) label,
        required String Function(T) subtitle,
        String Function(T)? searchText}) =>
    showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: kM3PickerSheetAnimation,
        builder: (sheetContext) => M3AsyncPickerSheet<T>(
            title: title,
            hintText: 'Qidirish',
            pageSize: 50,
            loadPage: (query, offset, limit) async => items
                .where((item) => (searchText?.call(item) ??
                        '${label(item)} ${subtitle(item)}')
                    .toLowerCase()
                    .contains(query.trim().toLowerCase()))
                .skip(offset)
                .take(limit)
                .toList(),
            itemTitle: label,
            itemSubtitle: subtitle,
            onSelected: (item) => Navigator.of(sheetContext).pop(item)));

List<PreparationMaterial> _receivableSeriyo(List<PreparationMaterial> materials,
        String warehouse, List<String> materialWarehouses) =>
    materials
        .where((m) =>
            m.isSeriyo != false &&
            m.canReceiveIn(warehouse, materialWarehouses))
        .toList();

Future<PreparationMaterial?> _pickSeriyo(BuildContext context, String warehouse,
        List<PreparationMaterial> materials, List<String> materialWarehouses) =>
    _pickPreparationItem<PreparationMaterial>(
      context,
      title: 'Homashyo tanlang',
      items: _receivableSeriyo(materials, warehouse, materialWarehouses),
      label: (m) => m.name,
      subtitle: (m) =>
          'Mavjud: ${preparationDisplay(m.available(warehouse))} kg',
      searchText: (m) => '${m.name} ${m.code}',
    );

extension _PreparationForms on _PreparationScreenState {
  Future<String?> _input(
          {required String title,
          required String label,
          bool quantity = false}) =>
      showDialog<String>(
          context: context,
          builder: (_) => PreparationInputDialog(
              title: title, label: label, quantity: quantity));

  Future<void> _receive(PreparationMaterial material) async {
    final warehouse = _warehouse;
    if (_locked ||
        warehouse == null ||
        !_syncedAssignedWarehouses().contains(warehouse) ||
        !material.canReceiveIn(warehouse, _syncedMaterialWarehouses())) {
      return;
    }
    final kg = await _input(
        title: '${material.name} — kirim', label: 'Kirim (kg)', quantity: true);
    if (kg != null &&
        !_locked &&
        _warehouse == warehouse &&
        _syncedAssignedWarehouses().contains(warehouse)) {
      await _submit('receipts', {
        'item_code': material.code,
        'warehouse': warehouse,
        'kg': preparationDecimalText(preparationDecimal(kg))
      });
    }
  }
}

String _formatDateTime(dynamic raw) {
  if (raw == null) return '';
  final dt = DateTime.tryParse(raw.toString())?.toLocal();
  if (dt == null) return raw.toString();
  return dt.toString().split('.').first;
}

class PreparationWarehouseScreen extends StatefulWidget {
  const PreparationWarehouseScreen({
    super.key,
    required this.warehouses,
    required this.assignedWarehouses,
    required this.materialWarehouses,
    required this.initialWarehouse,
    required this.materials,
    required this.history,
    required this.locked,
    required this.onWarehouseSelected,
    required this.onReceive,
    required this.onReload,
    required this.freshMaterials,
    required this.freshHistory,
    required this.freshAssignedWarehouses,
    required this.freshMaterialWarehouses,
    this.freshManagedWarehouses,
    this.freshAssignedWarehouseIds,
    this.showPreparedRolls = false,
  });

  final List<String> warehouses;
  final List<String> assignedWarehouses;
  final List<String> materialWarehouses;
  final String? initialWarehouse;
  final List<PreparationMaterial> materials;
  final List<dynamic> history;
  final bool locked;
  final void Function(String warehouse) onWarehouseSelected;
  final Future<void> Function(PreparationMaterial material) onReceive;
  final Future<void> Function() onReload;
  final List<PreparationMaterial> Function() freshMaterials;
  final List<dynamic> Function() freshHistory;
  final List<String> Function() freshAssignedWarehouses;
  final List<String> Function() freshMaterialWarehouses;
  final List<String> Function()? freshManagedWarehouses;
  final Map<String, String> Function()? freshAssignedWarehouseIds;
  final bool showPreparedRolls;

  @override
  State<PreparationWarehouseScreen> createState() =>
      _PreparationWarehouseScreenState();
}

class _PreparationWarehouseScreenState
    extends State<PreparationWarehouseScreen> with SingleTickerProviderStateMixin {
  late String? _warehouse = widget.initialWarehouse;
  late List<PreparationMaterial> _materials = widget.materials;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  bool _filterExpanded = false;
  bool _managingWarehouse = false;
  late final TabController _stockTabs;
  final _scope = currentSessionReadScope();
  final _selectedReceipts = <String, String>{};
  int _selectionGeneration = 0;
  int _rollRefresh = 0;
  bool _resolvingRoll = false;

  void _clearRollSelection() {
    _selectionGeneration++;
    _selectedReceipts.clear();
    _resolvingRoll = false;
  }

  void _updateWarehouse(VoidCallback action) => setState(action);

  /// Faqat shu userga ulangan omborlar, jumladan yangi bola omborlar.
  List<String> get _warehouses => widget.freshAssignedWarehouses();

  List<String> get _managedWarehouses =>
      widget.freshManagedWarehouses?.call() ?? const [];

  List<String> get _materialWarehouses => widget.freshMaterialWarehouses();
  Map<String, String> get _warehouseIds =>
      widget.freshAssignedWarehouseIds?.call() ?? const {};
  bool get _hasStockViews => _warehouseIds.isNotEmpty;

  bool get _canReceiveSeriyo =>
      _hasStockViews || _materialWarehouses.contains(_warehouse);

  @override
  void initState() {
    super.initState();
    _stockTabs = TabController(
      length: 2,
      initialIndex: widget.showPreparedRolls ? 1 : 0,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _stockTabs.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<PreparationMaterial> get _filtered {
    final q = _query.trim().toLowerCase();
    final visible = _warehouse == null
        ? const <PreparationMaterial>[]
        : _materials.where((m) =>
            m.visibleIn(_warehouse) && (!_hasStockViews || m.isSeriyo == true));
    if (q.isEmpty) return visible.toList();
    return visible
        .where((m) => '${m.name} ${m.code}'.toLowerCase().contains(q))
        .toList();
  }

  void _selectWarehouse(String w) {
    setState(() {
      if (w != _warehouse) _clearRollSelection();
      _warehouse = w;
    });
    widget.onWarehouseSelected(w);
  }

  Future<void> _doKirim() async {
    final warehouse = _warehouse;
    if (warehouse == null ||
        widget.locked ||
        (_hasStockViews && !_warehouses.contains(warehouse))) {
      return;
    }
    if (!_canReceiveSeriyo) {
      await _openPreparationScaleReceipt(context, _warehouse);
      await widget.onReload();
      if (mounted) setState(() => _materials = widget.freshMaterials());
      return;
    }
    final material = await _pickSeriyo(context, warehouse, _materials, _materialWarehouses);
    if (material != null && mounted && _warehouse == warehouse) {
      await widget.onReceive(material);
      if (mounted) setState(() => _materials = widget.freshMaterials());
    }
  }

  Future<void> _createWarehouse() async {
    if (widget.locked || _managingWarehouse) return;
    final warehouses = _materialWarehouses;
    if (warehouses.isEmpty) return;
    final nameController = TextEditingController();
    var parent = _warehouse != null && warehouses.contains(_warehouse)
        ? _warehouse!
        : warehouses.first;
    try {
      final created = await showDialog<String>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const UrduAwareText('Bola ombor ochish'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  key: const ValueKey('preparation-warehouse-parent'),
                  initialValue: parent,
                  decoration: InputDecoration(
                    labelText: localizeUrduUiText('Ota ombor'),
                  ),
                  items: [
                    for (final w in warehouses)
                      DropdownMenuItem(value: w, child: Text(w)),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => parent = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('preparation-warehouse-name'),
                  controller: nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: localizeUrduUiText('Yangi ombor nomi'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const UrduAwareText('Bekor qilish'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;
                  Navigator.of(dialogContext).pop(name);
                },
                child: const UrduAwareText('Saqlash'),
              ),
            ],
          ),
        ),
      );
      if (created == null || created.trim().isEmpty || !mounted) return;
      setState(() => _managingWarehouse = true);
      final warehouse = await MobileApi.instance.preparationCreateWarehouse(
        name: created,
        parent: parent,
      );
      if (warehouse.isEmpty || !mounted) return;
      await widget.onReload();
      if (!mounted) return;
      setState(() {
        _warehouse = warehouse;
        _materials = widget.freshMaterials();
        _filterExpanded = false;
      });
      widget.onWarehouseSelected(warehouse);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: UrduAwareText('Ombor ochildi: $warehouse')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_warehouseErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _managingWarehouse = false);
      nameController.dispose();
    }
  }

  Future<void> _openDetail(PreparationMaterial material) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreparationMaterialDetailScreen(
          materialCode: material.code,
          warehouse: _warehouse!,
          materials: _materials,
          history: widget.freshHistory(),
          locked: widget.locked,
          onReceive: widget.onReceive,
          onReload: widget.onReload,
          freshMaterials: widget.freshMaterials,
          freshHistory: widget.freshHistory,
          freshMaterialWarehouses: widget.freshMaterialWarehouses,
          legacyWarehouseView: !_hasStockViews,
        ),
      ),
    );
    if (mounted) {
      setState(() => _materials = widget.freshMaterials());
      await widget.onReload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    final filtered =
        _warehouse == null ? const <PreparationMaterial>[] : _filtered;
    final warehouseId = _warehouseIds[_warehouse];
    final showPreparedRolls = _hasStockViews && _stockTabs.index == 1;
    final rollsView = showPreparedRolls && warehouseId != null
        ? _PreparationWarehouseRolls(
            key: ValueKey(warehouseId),
            warehouseId: warehouseId,
            query: _query.trim(),
            selected: _selectedReceipts.keys.toSet(),
            refreshRevision: _rollRefresh,
            onToggle: _toggleWarehouseRoll,

          )
        : null;

    return AppShell(
      title: 'Ombor',
      subtitle: '',
      nativeTopBar: true,
      automaticallyImplyNativeLeading: false,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      profileActionListenable: _searchFocusNode,
      showProfileActionResolver: () => !_searchFocusNode.hasFocus,
      titleWidget: AdminCatalogSearchField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        hintText: showPreparedRolls ? 'Ombordan rulon qidirish' : 'Ombordan seriyo qidirish',
        onBack: () {
          final nav = Navigator.of(context);
          if (nav.canPop()) {
            nav.pop();
          } else {
            nav.pushReplacementNamed(AppRoutes.preparation);
          }
        },
        onChanged: (v) => setState(() => _query = v),
        onClear: () {
          _searchController.clear();
          setState(() => _query = '');
        },
      ),
      contentPadding: EdgeInsets.zero,
      bottom: PreparationDock(
        primaryFabActions: _warehouses.isEmpty
            ? null
            : [
                if (showPreparedRolls && _warehouse != null &&
                    _selectedReceipts.isEmpty && !widget.locked &&
                    AppRouter.canOpenRoute(AppRoutes.gscaleMode))
                  AdminFabMenuAction(
                    title: 'Rulonni tortish',
                    icon: Icons.scale_outlined,
                    onTap: () async {
                      await _openPreparationScaleReceipt(context, _warehouse);
                      if (mounted) setState(() => _rollRefresh++);
                    },
                  ),
                if (showPreparedRolls && _selectedReceipts.isNotEmpty &&
                    !widget.locked && _scope == currentSessionReadScope()) ...[
                  AdminFabMenuAction(
                    title: 'Paddonga biriktirish',
                    icon: Icons.inventory_2_outlined,
                    onTap: _attachWarehouseRolls,
                  ),
                  AdminFabMenuAction(
                    title: 'Tanlovni bekor qilish',
                    icon: Icons.close_rounded,
                    onTap: () => setState(_clearRollSelection),
                  ),
                ],
                if (!showPreparedRolls &&
                    _warehouse != null &&
                    !widget.locked &&
                    !_managingWarehouse)
                  AdminFabMenuAction(
                    title: _canReceiveSeriyo ? 'Seriyo kirimi' : 'Rulonni tortish',
                    icon: _canReceiveSeriyo
                        ? Icons.add_circle_outline_rounded
                        : Icons.scale_outlined,
                    onTap: _doKirim,
                  ),
                if (!showPreparedRolls &&
                    !widget.locked &&
                    !_managingWarehouse &&
                    _materialWarehouses.isNotEmpty)
                  AdminFabMenuAction(
                    title: 'Ombor qo‘shish',
                    icon: Icons.warehouse_outlined,
                    onTap: _createWarehouse,
                  ),
              ],
      ),
      child: Column(
        children: [
          if (_hasStockViews)
            AdminSurfaceTabBar(
              controller: _stockTabs,
              onTap: (index) => setState(() { if (index == 0) _clearRollSelection(); }),
              tabs: const [
                Tab(
                  height: 52,
                  child: UrduAwareText(
                    'Seriyo',
                    textAlign: TextAlign.center,
                  ),
                ),
                Tab(height: 52, child: UrduAwareText('Tayyor rulonlar')),
              ],
            ),
          if (_warehouses.isNotEmpty)
            AdminExpandableFilterChip<String>(
              key: const ValueKey('preparation-warehouse-filter'),
              label: 'Ombor',
              emptyLabel: 'Tanlanmagan',
              icon: Icons.warehouse_outlined,
              selectedValue: _warehouse,
              options: [
                for (final w in _warehouses)
                  AdminFilterChipOption(
                    value: w,
                    label: w,
                    onLongPress: !widget.locked &&
                            !_managingWarehouse &&
                            _managedWarehouses.contains(w)
                        ? () => _warehouseActions(w)
                        : null,
                  ),
              ],
              expanded: _filterExpanded,
              onToggle: () => setState(
                () => _filterExpanded = !_filterExpanded,
              ),
              onSelect: (w) {
                _selectWarehouse(w);
                setState(() => _filterExpanded = false);
              },
              chipKey: const ValueKey('preparation-warehouse-filter-chip'),
              optionKeyPrefix: 'preparation-warehouse-filter-option',
            ),
          Expanded(
            child: rollsView ?? AppRefreshIndicator(
              onRefresh: () async {
                await widget.onReload();
                if (mounted) {
                  setState(() => _materials = widget.freshMaterials());
                }
              },
              allowRefreshOnShortContent: true,
              child: ListView(
                physics: const TopRefreshScrollPhysics(),
                padding: EdgeInsets.fromLTRB(4, 4, 4, bottomPadding),
                children: [
                  if (_warehouses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: UrduAwareText(
                        'Sizga ombor biriktirilmagan.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else if (_warehouse == null ||
                      (_hasStockViews && !_warehouses.contains(_warehouse)))
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: UrduAwareText(
                        'Yuqoridagi filtrdan ombor tanlang.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: UrduAwareText(
                        'Bu omborda hali kirim yo‘q.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    M3SegmentSpacedColumn(
                      padding: EdgeInsets.zero,
                      children: [
                        for (var index = 0; index < filtered.length; index++)
                          _PreparationWarehouseStockRow(
                            slot: M3SegmentedListGeometry
                                .standaloneListSlotForIndex(
                              index,
                              filtered.length,
                            ),
                            material: filtered[index],
                            warehouse: _warehouse!,
                            onTap: () => _openDetail(filtered[index]),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreparationWarehouseStockRow extends StatelessWidget {
  const _PreparationWarehouseStockRow({
    required this.slot,
    required this.material,
    required this.warehouse,
    this.onTap,
  });

  final M3SegmentVerticalSlot slot;
  final PreparationMaterial material;
  final String warehouse;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = material.name.trim().isEmpty ? material.code : material.name;
    final available = preparationDisplay(material.available(warehouse));
    final consumable = preparationDisplay(material.consumable(warehouse));

    return AdminSummaryCard(
      slot: slot,
      cornerRadius: M3SegmentedListGeometry.cornerRadiusForSlot(slot),
      backgroundColor: scheme.surfaceContainerLowest,
      fixedHeight: 61,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 10, 8),
      value: '$available kg',
      onTap: onTap,
      showChevron: onTap != null,
      leading: SizedBox.square(
        dimension: 30,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.inventory_2_rounded,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
      title: title,
      subtitle: material.consumableBalances == null
          ? 'Mavjud qoldiq'
          : available == consumable
              ? 'Sarfga tayyor'
              : 'Sarfga tayyor · $consumable kg',
      titleMaxLines: 1,
      subtitleMaxLines: 1,
      titleStyle: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      subtitleStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.05,
          ),
    );
  }
}

class PreparationMaterialDetailScreen extends StatefulWidget {
  const PreparationMaterialDetailScreen({
    super.key,
    required this.materialCode,
    required this.warehouse,
    required this.materials,
    required this.history,
    required this.locked,
    required this.onReceive,
    required this.onReload,
    required this.freshMaterials,
    required this.freshHistory,
    required this.freshMaterialWarehouses,
    this.legacyWarehouseView = true,
  });

  final String materialCode;
  final String warehouse;
  final List<PreparationMaterial> materials;
  final List<dynamic> history;
  final bool locked;
  final Future<void> Function(PreparationMaterial material) onReceive;
  final Future<void> Function() onReload;
  final List<PreparationMaterial> Function() freshMaterials;
  final List<dynamic> Function() freshHistory;
  final List<String> Function() freshMaterialWarehouses;
  final bool legacyWarehouseView;

  @override
  State<PreparationMaterialDetailScreen> createState() =>
      _PreparationMaterialDetailScreenState();
}

class _PreparationMaterialDetailScreenState
    extends State<PreparationMaterialDetailScreen> {
  late List<PreparationMaterial> _materials = widget.materials;
  late List<dynamic> _history = widget.history;

  PreparationMaterial? get _material {
    for (final m in _materials) {
      if (m.code == widget.materialCode) return m;
    }
    return null;
  }

  List<dynamic> get _receipts => _history
      .where((d) =>
          (d['kind'] == 'receipt' || d['kind'] == 'receipt_reversal') &&
          d['warehouse'] == widget.warehouse &&
          (d['item_code'] as String? ?? '') == widget.materialCode)
      .toList();

  List<Map<String, dynamic>> get _consumptions {
    final result = <Map<String, dynamic>>[];
    for (final d in _history) {
      if (d is! Map ||
          d['kind'] != 'consumption' ||
          d['warehouse'] != widget.warehouse) {
        continue;
      }
      final lines = d['lines'];
      if (lines is! List) continue;
      for (final l in lines) {
        if (l is Map &&
            (l['item_code'] as String? ?? '') == widget.materialCode) {
          result.add({
            'doc': Map<String, dynamic>.from(d),
            'line': Map<String, dynamic>.from(l),
          });
        }
      }
    }
    return result;
  }

  Future<void> _sync() async {
    if (!mounted) return;
    setState(() {
      _materials = widget.freshMaterials();
      _history = widget.freshHistory();
    });
  }

  bool get _canReceiveManually => _material?.canReceiveIn(
      widget.warehouse, widget.freshMaterialWarehouses()) == true;

  bool get _canOpenLegacyScale => widget.legacyWarehouseView &&
      !widget.freshMaterialWarehouses().contains(widget.warehouse);

  Future<void> _doKirim() async {
    final material = _material;
    if (material == null || widget.locked) return;
    if (_canOpenLegacyScale) {
      await _openPreparationScaleReceipt(context, widget.warehouse);
      await widget.onReload();
      await _sync();
      return;
    }
    if (!_canReceiveManually) return;
    await widget.onReceive(material);
    await _sync();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final material = _material;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 136.0;
    final receipts = _receipts;
    final consumptions = _consumptions;

    return AppShell(
      title: material?.name ?? 'Homashyo',
      subtitle: widget.warehouse,
      nativeTopBar: true,
      nativeTitleTextStyle: AppTheme.werkaNativeAppBarTitleStyle(context),
      contentPadding: EdgeInsets.zero,
      bottom: const PreparationDock(),
      child: AppRefreshIndicator(
        onRefresh: () async {
          await widget.onReload();
          await _sync();
        },
        allowRefreshOnShortContent: true,
        child: ListView(
          physics: const TopRefreshScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPadding),
          children: [
            const SizedBox(height: _adminHomePanelCardGap),
            if (material != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _adminHomePanelCardGap,
                ),
                child: AdminSummaryCard(
                  slot: M3SegmentVerticalSlot.top,
                  cornerRadius: M3SegmentedListGeometry.cornerLarge,
                  borderRadiusOverride: BorderRadius.circular(
                    M3SegmentedListGeometry.cornerLarge,
                  ),
                  backgroundColor: scheme.surfaceContainerLowest,
                  title: material.name,
                  subtitle: material.code,
                  value:
                      '${preparationDisplay(material.available(widget.warehouse))} kg',
                  leading: SizedBox.square(
                    dimension: 30,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        size: 16,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  showChevron: false,
                  titleMaxLines: 1,
                  subtitleMaxLines: 1,
                  titleStyle: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  subtitleStyle: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.05,
                  ),
                  elevation: 0,
                ),
              ),
            if (_canReceiveManually || _canOpenLegacyScale)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    _adminHomePanelCardGap, 12, _adminHomePanelCardGap, 0),
                child: FilledButton.icon(
                  key: const Key('preparation-detail-kirim'),
                  onPressed: material == null || widget.locked ? null : _doKirim,
                  icon: Icon(_canReceiveManually
                      ? Icons.add_circle_outline_rounded
                      : Icons.scale_outlined),
                  label: UrduAwareText(
                      _canReceiveManually ? 'Seriyo kirimi' : 'Rulonni tortish'),
                ),
              ),
            if (receipts.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: UrduAwareText(
                  'Kirimlar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              M3SegmentSpacedColumn(
                padding: const EdgeInsets.symmetric(
                  horizontal: _adminHomePanelCardGap,
                ),
                children: [
                  for (var i = 0; i < receipts.length; i++)
                    Builder(builder: (_) {
                      final doc = receipts[i];
                      final isReversal = doc['kind'] == 'receipt_reversal';
                      final reversed = doc['reversed'] == true;
                      final name =
                          doc['name']?.toString() ?? material?.name ?? '';
                      final reason = doc['reason']?.toString().trim() ?? '';
                      final subtitle = [
                        '${doc['warehouse']} • ${_formatDateTime(doc['created_at'])}',
                        if (isReversal && reason.isNotEmpty) 'Sabab: $reason',
                        if (!isReversal && reversed) 'Bekor qilingan',
                      ].join('\n');
                      return AdminSummaryCard(
                        slot: _slotFor(i, receipts.length),
                        cornerRadius:
                            M3SegmentedListGeometry.cornerRadiusForSlot(
                          _slotFor(i, receipts.length),
                        ),
                        backgroundColor: scheme.surfaceContainerLowest,
                        title: isReversal
                            ? 'Kirimni bekor qilish — $name'
                            : '+${preparationDisplay(doc['kg'] as String? ?? '0')} kg',
                        subtitle: subtitle,
                        value: isReversal
                            ? '-${preparationDisplay(doc['kg'] as String? ?? '0')} kg'
                            : '',
                        leading: Icon(
                          isReversal
                              ? Icons.undo_rounded
                              : reversed
                                  ? Icons.undo_outlined
                                  : Icons.check_circle_outline_rounded,
                          color: isReversal
                              ? scheme.error
                              : reversed
                                  ? scheme.outline
                                  : Colors.green,
                        ),
                        showChevron: false,
                        elevation: 0,
                      );
                    }),
                ],
              ),
            ],
            if (consumptions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: UrduAwareText(
                  'Chiqimlar',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              M3SegmentSpacedColumn(
                padding: const EdgeInsets.symmetric(
                  horizontal: _adminHomePanelCardGap,
                ),
                children: [
                  for (var i = 0; i < consumptions.length; i++)
                    Builder(builder: (_) {
                      final doc = consumptions[i]['doc']!;
                      final line = consumptions[i]['line']!;
                      return AdminSummaryCard(
                        slot: _slotFor(i, consumptions.length),
                        cornerRadius:
                            M3SegmentedListGeometry.cornerRadiusForSlot(
                          _slotFor(i, consumptions.length),
                        ),
                        backgroundColor: scheme.surfaceContainerLowest,
                        title:
                            '-${preparationDisplay(line['kg'] as String? ?? '0')} kg',
                        subtitle:
                            '${doc['order_code']} ${doc['order_title']} • ${preparationDisplay(line['percent'] as String? ?? '0')}% • ${_formatDateTime(doc['created_at'])}',
                        value: '',
                        leading: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: Colors.orange,
                        ),
                        showChevron: false,
                        elevation: 0,
                      );
                    }),
                ],
              ),
            ],
            if (receipts.isEmpty && consumptions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: UrduAwareText(
                  'Bu homashyo bo‘yicha hali kirim yoki chiqim yo‘q.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
