part of 'inventory_movements_screen.dart';

class _PreparationHistoryTab extends StatefulWidget {
  const _PreparationHistoryTab({
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

  String get visibleWarehouseId =>
      warehouses.any((location) => location.warehouseId == warehouseId)
          ? warehouseId
          : '';

  Iterable<InventoryLocation> get warehouses {
    final assigned = AppSession.instance.profile?.assignedWarehouses
        .map((name) => name.trim().toLowerCase())
        .toSet();
    return locations.where(
      (location) =>
          assigned?.contains(location.name.trim().toLowerCase()) == true,
    );
  }

  @override
  State<_PreparationHistoryTab> createState() => _PreparationHistoryTabState();
}

class _PreparationHistoryTabState extends State<_PreparationHistoryTab>
    with AutomaticKeepAliveClientMixin<_PreparationHistoryTab> {
  List<PreparationHistoryEntry> _entries = const [];
  PreparationHistoryCursor? _nextCursor;
  InventoryViewLease<InventoryTransfer>? _transferView;
  List<InventoryTransfer>? _lastTransfers;
  Timer? _transferRefresh;
  int _request = 0;
  bool _loading = false;
  bool _failedAppend = false;
  bool _warehouseFilterExpanded = false;
  String? _error;

  bool get _current =>
      mounted &&
      widget.scope == currentSessionReadScope() &&
      AppRouter.canOpenRoute(AppRoutes.preparationTransfers);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AppSession.instance.revision.addListener(_sessionChanged);
    if (_current) {
      _transferView = InventoryViewStore.instance.transfers()
        ..addListener(_transfersChanged);
      _lastTransfers = _transferView?.rows;
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(_PreparationHistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibleWarehouseId != widget.visibleWarehouseId) {
      unawaited(_load(reset: true));
    }
  }

  @override
  void dispose() {
    AppSession.instance.revision.removeListener(_sessionChanged);
    _transferView?.dispose();
    _transferRefresh?.cancel();
    super.dispose();
  }

  void _sessionChanged() {
    if (mounted) setState(() {});
  }

  void _transfersChanged() {
    final view = _transferView;
    final rows = view?.rows;
    if (!_current || view?.trusted != true || rows == null) return;
    final previous = _lastTransfers;
    _lastTransfers = rows;
    if (previous == null || identical(previous, rows)) return;
    _transferRefresh?.cancel();
    _transferRefresh = Timer(const Duration(milliseconds: 150), () {
      unawaited(_load());
    });
  }

  Future<void> _load({bool append = false, bool reset = false}) async {
    if (!_current || (append && (_loading || _nextCursor == null))) return;
    _transferRefresh?.cancel();
    final request = ++_request;
    final warehouseId = widget.visibleWarehouseId;
    final preserveCount = !append && !reset ? _entries.length : 0;
    final entries = <String, PreparationHistoryEntry>{
      if (append)
        for (final entry in _entries) entry.key: entry,
    };
    var cursor = append ? _nextCursor : null;
    setState(() {
      if (reset) {
        _entries = const [];
        _nextCursor = null;
      }
      _loading = true;
      _error = null;
      _failedAppend = append;
    });

    try {
      do {
        final page = await MobileApi.instance.preparationHistory(
          warehouseId: warehouseId,
          cursor: cursor,
        );
        if (!_current || request != _request) return;
        for (final entry in page.entries) {
          entries.putIfAbsent(entry.key, () => entry);
        }
        cursor = page.nextCursor;
      } while (cursor != null && entries.length < preserveCount);

      setState(() {
        _entries = entries.values.toList(growable: false);
        _nextCursor = cursor;
        _loading = false;
      });
    } catch (error) {
      if (!_current || request != _request) return;
      setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    if (!_current) return;
    await Future.wait([
      widget.onRefreshLocations().onError((_, __) {}),
      _load(),
    ]);
  }

  Future<void> _receiptReversed() async {
    await Future.wait([
      _load(),
      InventoryViewStore.instance.reconcileAfterWrite().onError((_, __) {}),
    ]);
  }

  Widget _buildWarehouseFilter() {
    final warehouseId = widget.visibleWarehouseId;
    final warehouses = widget.warehouses.toList(growable: false);
    if (warehouses.isEmpty) return const SizedBox.shrink();
    return AdminExpandableFilterChip<String>(
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
        const AdminFilterChipOption(value: '', label: 'Barcha omborlar'),
        for (final warehouse in warehouses)
          AdminFilterChipOption(
            value: warehouse.warehouseId,
            label: warehouse.name,
          ),
      ],
    );
  }

  Widget _buildFooter() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: AppLoadingIndicator()),
      );
    }
    if (_error case final error?) {
      return _InventoryErrorState(
        message: error,
        onRetry: () => _load(append: _failedAppend),
      );
    }
    if (_nextCursor != null) {
      return Center(
        child: TextButton(
          onPressed: () => _load(append: true),
          child: const UrduAwareText('Yana yuklash'),
        ),
      );
    }
    if (_entries.isEmpty) {
      return _InventoryEmptyState(
        icon: Icons.history_rounded,
        message: localizeUrduUiText('Tarixda yozuv topilmadi'),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_current) {
      return const Center(
        child: UrduAwareText('Akkaunt o‘zgargan. Sahifani qayta oching'),
      );
    }
    return AppRefreshIndicator(
      onRefresh: _refresh,
      allowRefreshOnShortContent: true,
      child: ListView.separated(
        physics: const TopRefreshScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 116),
        itemCount: _entries.length + 2,
        separatorBuilder: (_, index) => SizedBox(
          height: index == 0 ? 8 : M3SegmentedListGeometry.gap,
        ),
        itemBuilder: (context, index) {
          if (index == 0) return _buildWarehouseFilter();
          if (index == _entries.length + 1) return _buildFooter();
          final entry = _entries[index - 1];
          final slot = M3SegmentedListGeometry.standaloneListSlotForIndex(
            index - 1,
            _entries.length,
          );
          final date = _inventoryTimestamp(entry.occurredAt);
          if (entry.transfer case final transfer?) {
            return _InventoryTransferListRow(
              key: ValueKey('inventory-transfer-${transfer.id}'),
              slot: slot,
              transfer: transfer,
              busy: false,
              historyTime: date,
              onTap: () {
                if (!_current) return;
                unawaited(_InventoryTransferDetailsSheet.show(
                  context,
                  transfer,
                  showHistoryDates: true,
                  preparationReceivedAt: entry.preparationReceivedAt,
                  preparationReceipts: entry.preparationReceipts,
                ));
              },
            );
          }
          return PreparationHistoryOperationCard(
            key: ValueKey(entry.key),
            operation: entry.operation!,
            date: date,
            slot: slot,
            onReversed: _receiptReversed,
          );
        },
      ),
    );
  }
}
