part of 'inventory_movements_screen.dart';

class _PreparationTransferHistoryTab extends StatefulWidget {
  const _PreparationTransferHistoryTab({
    super.key,
    required this.scope,
    required this.locations,
    required this.warehouseId,
    required this.onWarehouseSelected,
    required this.onRefreshLocations,
  });

  final String scope;
  final List<InventoryLocation> locations;
  final String warehouseId;
  final ValueChanged<String> onWarehouseSelected;
  final Future<void> Function() onRefreshLocations;

  @override
  State<_PreparationTransferHistoryTab> createState() =>
      _PreparationTransferHistoryTabState();
}

class _PreparationTransferHistoryTabState
    extends State<_PreparationTransferHistoryTab>
    with AutomaticKeepAliveClientMixin<_PreparationTransferHistoryTab> {
  static const _pageSize = 100;
  // The inventory endpoint caps the offset at this value.
  static const _lastOffset = 100000;
  final _pages = <InventoryViewLease<InventoryTransfer>>[];
  bool _warehouseFilterExpanded = false;

  bool get _current =>
      mounted &&
      widget.scope == currentSessionReadScope() &&
      AppRouter.canOpenRoute(AppRoutes.preparationTransfers);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AppSession.instance.revision.addListener(_viewChanged);
    if (_current) _addPage();
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_viewChanged);
    for (final page in _pages) {
      page.dispose();
    }
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

  Future<void> _refreshTransfers() async {
    if (!_current) return;
    await Future.wait([
      for (final page in _pages) page.refresh().onError((_, __) {}),
    ]);
  }

  Future<void> _refresh() async {
    if (!_current) return;
    await Future.wait([
      widget.onRefreshLocations().onError((_, __) {}),
      _refreshTransfers(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_current || _pages.isEmpty) {
      return const Center(
        child: UrduAwareText('Akkaunt o‘zgargan. Sahifani qayta oching'),
      );
    }
    final firstPage = _pages.first;
    if (firstPage.rows == null) {
      final error = firstPage.error;
      return error == null
          ? const Center(child: AppLoadingIndicator())
          : _InventoryErrorState(message: error, onRetry: _refresh);
    }

    final assigned = AppSession.instance.profile!.assignedWarehouses
        .map((name) => name.trim().toLowerCase())
        .toSet();
    final warehouses = widget.locations
        .where(
            (location) => assigned.contains(location.name.trim().toLowerCase()))
        .toList(growable: false);
    final warehouseId = warehouses
            .any((warehouse) => warehouse.warehouseId == widget.warehouseId)
        ? widget.warehouseId
        : '';
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
                transfer.destinationWarehouseId == warehouseId))
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
      rowGap: M3SegmentedListGeometry.gap,
      header: Column(
        children: [
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
              onSelect: (value) {
                setState(() => _warehouseFilterExpanded = false);
                widget.onWarehouseSelected(value);
              },
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
