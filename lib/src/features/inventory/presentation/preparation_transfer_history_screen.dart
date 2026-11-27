part of 'inventory_movements_screen.dart';

class PreparationTransferHistoryScreen extends StatefulWidget {
  const PreparationTransferHistoryScreen({super.key});

  @override
  State<PreparationTransferHistoryScreen> createState() =>
      _PreparationTransferHistoryScreenState();
}

class _PreparationTransferHistoryScreenState
    extends State<PreparationTransferHistoryScreen> {
  static const _pageSize = 100;
  // The inventory endpoint caps the offset at this value.
  static const _lastOffset = 100000;
  final _scope = currentSessionReadScope();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _pages = <InventoryViewLease<InventoryTransfer>>[];
  late final InventoryViewLease<InventoryLocation> _locations;
  String _warehouseId = '';
  bool _warehouseFilterExpanded = false;

  bool get _current =>
      mounted &&
      _scope == currentSessionReadScope() &&
      AppRouter.canOpenRoute(AppRoutes.preparationTransferHistory);

  @override
  void initState() {
    super.initState();
    AppSession.instance.revision.addListener(_viewChanged);
    _locations = InventoryViewStore.instance.locations()
      ..addListener(_viewChanged);
    _addPage();
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_viewChanged);
    _locations.dispose();
    for (final page in _pages) {
      page.dispose();
    }
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _viewChanged() {
    if (mounted) setState(() {});
  }

  void _addPage() {
    _pages.add(InventoryViewStore.instance.transfers(
      limit: _pageSize,
      offset: _pages.length * _pageSize,
    )..addListener(_viewChanged));
  }

  Future<void> _refresh() async {
    if (!_current) return;
    await Future.wait([
      _locations.refresh().onError((_, __) {}),
      for (final page in _pages) page.refresh().onError((_, __) {}),
    ]);
  }

  @override
  Widget build(BuildContext context) => AppShell(
        title: localizeUrduUiText('Transfer tarixi'),
        subtitle: '',
        nativeTopBar: true,
        contentPadding: EdgeInsets.zero,
        drawer: const PreparationDrawer(
          selectedRouteName: AppRoutes.preparationTransferHistory,
        ),
        bottom: const PreparationDock(showPrimaryFab: false),
        child: _buildHistory(),
      );

  Widget _buildHistory() {
    if (!_current) {
      return const Center(
        child: UrduAwareText('Akkaunt o‘zgargan. Sahifani qayta oching'),
      );
    }
    final locations = _locations.rows;
    final firstPage = _pages.first;
    if (locations == null || firstPage.rows == null) {
      final error = _locations.error ?? firstPage.error;
      return error == null
          ? const Center(child: AppLoadingIndicator())
          : _InventoryErrorState(message: error, onRetry: _refresh);
    }

    final assigned = AppSession.instance.profile!.assignedWarehouses
        .map((name) => name.trim().toLowerCase())
        .toSet();
    final warehouses = locations
        .where((location) =>
            location.isWarehouse &&
            location.active &&
            assigned.contains(location.name.trim().toLowerCase()))
        .toList(growable: false);
    final warehouseId =
        warehouses.any((warehouse) => warehouse.warehouseId == _warehouseId)
            ? _warehouseId
            : '';
    final query = _search.text.trim().toLowerCase();
    final byId = {
      for (final page in _pages.reversed)
        for (final transfer in page.rows ?? const <InventoryTransfer>[])
          transfer.id: transfer,
    };
    final transfers = byId.values
        .where((transfer) =>
            _isPreparationTransferInHistory(transfer) &&
            (warehouseId.isEmpty ||
                transfer.sourceWarehouseId == warehouseId ||
                transfer.destinationWarehouseId == warehouseId) &&
            _matchesTransferSearch(transfer, query))
        .toList()
      ..sort((a, b) {
        final byDate = b.createdAtUnix.compareTo(a.createdAtUnix);
        return byDate == 0 ? b.id.compareTo(a.id) : byDate;
      });

    final lastPage = _pages.last;
    final loadMore = lastPage.rows?.length == _pageSize &&
        _pages.length * _pageSize <= _lastOffset;
    return _TransferList(
      transfers: transfers,
      emptyMessage: localizeUrduUiText('Transfer tarixida yozuv topilmadi'),
      header: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AdminCatalogSearchField(
              controller: _search,
              focusNode: _searchFocus,
              hintText: localizeUrduUiText('Mahsulot, kod yoki QR qidirish'),
              showLeading: false,
              onChanged: (_) => setState(() {}),
              onClear: () => setState(_search.clear),
            ),
          ),
          if (warehouses.isNotEmpty)
            AdminExpandableFilterChip<String>(
              chipKey: const ValueKey('preparation-transfer-history-warehouse'),
              label: 'Ombor',
              emptyLabel: 'Barcha omborlar',
              icon: Icons.warehouse_outlined,
              selectedValue: warehouseId.isEmpty ? null : warehouseId,
              expanded: _warehouseFilterExpanded,
              onToggle: () => setState(() {
                _warehouseFilterExpanded = !_warehouseFilterExpanded;
              }),
              onSelect: (value) => setState(() {
                _warehouseId = value;
                _warehouseFilterExpanded = false;
              }),
              options: [
                const AdminFilterChipOption(
                  value: '',
                  label: 'Barcha omborlar',
                ),
                for (final warehouse in warehouses)
                  AdminFilterChipOption(
                    value: warehouse.warehouseId,
                    label: warehouse.name,
                  ),
              ],
            ),
        ],
      ),
      footer: lastPage.loading
          ? const Center(child: AppLoadingIndicator())
          : lastPage.rows == null && lastPage.error != null
              ? _InventoryErrorState(
                  message: lastPage.error!,
                  onRetry: () => lastPage.refresh().onError((_, __) {}),
                )
              : loadMore
                  ? Center(
                      child: TextButton(
                        onPressed: () {
                          if (_current && identical(lastPage, _pages.last)) {
                            setState(_addPage);
                          }
                        },
                        child: const UrduAwareText('Yana yuklash'),
                      ),
                    )
                  : null,
      onTransferTap: (transfer) async {
        if (_current) {
          await _InventoryTransferDetailsSheet.show(context, transfer);
        }
      },
      onRefresh: _refresh,
    );
  }
}
