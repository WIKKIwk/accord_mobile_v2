part of 'preparation_screen.dart';

extension _WarehouseRollAttachment on _PreparationWarehouseScreenState {
  bool get _canPack =>
      mounted &&
      _scope == currentSessionReadScope() &&
      !widget.locked &&
      _stockTabs.index == 1 &&
      AppSession.instance.profile?.role == UserRole.tayyorlovMasteri &&
      AppSession.instance.can('preparation.access');

  Future<void> _toggleWarehouseRoll(InventoryAsset roll) async {
    if (!_canPack ||
        _resolvingRoll ||
        !roll.canSelectForPaddon ||
        roll.custodyWarehouseId != _warehouseIds[_warehouse]) return;
    if (_selectedReceipts.containsKey(roll.assetRef)) {
      _updateWarehouse(() => _selectedReceipts.remove(roll.assetRef));
      return;
    }
    if (_selectedReceipts.length >= preparationNoteSelectionLimit) return;
    final generation = _selectionGeneration;
    bool current() => _canPack && _selectionGeneration == generation;
    _updateWarehouse(() => _resolvingRoll = true);
    try {
      final barcode = roll.identifier.trim().toLowerCase();
      var offset = 0;
      while (current()) {
        final page = await MobileApi.instance.preparationProductionRolls(
          query: barcode,
          offset: offset,
        );
        if (!current()) return;
        final ownRoll = page.rolls
            .where((r) =>
                r.epc.trim().toLowerCase() == barcode &&
                r.receiptName.isNotEmpty)
            .firstOrNull;
        if (ownRoll != null) {
          _updateWarehouse(
              () => _selectedReceipts[roll.assetRef] = ownRoll.receiptName);
          return;
        }
        final next = page.nextOffset;
        if (!page.hasMore || next == null || next <= offset) break;
        offset = next;
      }
      if (current())
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: UrduAwareText(
                'Bu rulon sizning ishlab chiqarish jurnalingizda topilmadi.')));
    } catch (error) {
      if (current())
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (current()) _updateWarehouse(() => _resolvingRoll = false);
    }
  }

  Future<void> _attachWarehouseRolls() async {
    if (!_canPack || _selectedReceipts.isEmpty || _resolvingRoll) return;
    final generation = _selectionGeneration;
    bool current() => _canPack && _selectionGeneration == generation;
    final result = await showProductionPaddonPicker(context,
        receiptNames: _selectedReceipts.values.toList(),
        currentAccount: current);
    if (result != null && current()) {
      _updateWarehouse(() {
        _clearRollSelection();
        _rollRefresh++;
      });
    }
  }
}

class _PreparationWarehouseRolls extends StatefulWidget {
  const _PreparationWarehouseRolls({
    super.key,
    required this.warehouseId,
    required this.query,
    required this.selected,
    required this.refreshRevision,
    required this.onToggle,
  });

  final String warehouseId;
  final String query;
  final Set<String> selected;
  final int refreshRevision;
  final ValueChanged<InventoryAsset> onToggle;

  @override
  State<_PreparationWarehouseRolls> createState() =>
      _PreparationWarehouseRollsState();
}

class _PreparationWarehouseRollsState
    extends State<_PreparationWarehouseRolls> {
  static const _pageSize = 50;
  int _offset = 0;
  Timer? _searchDebounce;
  late InventoryViewLease<InventoryAsset> _view = _openView();

  InventoryViewLease<InventoryAsset> _openView() =>
      InventoryViewStore.instance.assets(
        warehouseId: widget.warehouseId,
        query: widget.query,
        assetKind: InventoryAssetKind.rawMaterial,
        stockUse: InventoryStockUse.preparedRoll,
        includePreparedPaddons: true,
        includeOrderAssignment: false,
        limit: _pageSize + 1,
        offset: _offset,
      );

  @override
  void didUpdateWidget(covariant _PreparationWarehouseRolls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshRevision != widget.refreshRevision)
      unawaited(_view.refresh());
    if (oldWidget.query == widget.query) return;
    _searchDebounce?.cancel();
    _searchDebounce =
        Timer(const Duration(milliseconds: 350), () => _setPage(0));
  }

  void _setPage(int offset) {
    _view.dispose();
    setState(() {
      _offset = offset;
      _view = _openView();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _view,
      builder: (context, _) {
        final rolls = _view.rows
                ?.where(
                    (roll) => roll.stockUse == InventoryStockUse.preparedRoll)
                .toList() ??
            const <InventoryAsset>[];
        final count = rolls.length > _pageSize ? _pageSize : rolls.length;
        if (_view.rows == null && _view.loading) {
          return const Center(child: AppLoadingIndicator());
        }
        return AppRefreshIndicator(
          onRefresh: _view.refresh,
          allowRefreshOnShortContent: true,
          child: ListView.builder(
            key: ValueKey(_offset),
            physics: const TopRefreshScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              4,
              4,
              4,
              MediaQuery.viewPaddingOf(context).bottom + 136,
            ),
            itemCount: count + 1,
            itemBuilder: (context, index) {
              if (index == count) {
                if (_view.error case final error?) {
                  return TextButton(
                      onPressed: _view.refresh, child: Text(error));
                }
                return Column(
                  children: [
                    if (count == 0)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child:
                            UrduAwareText('Bu omborda tayyor rulon topilmadi.'),
                      ),
                    if (_offset > 0 || rolls.length > _pageSize)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_offset > 0)
                            TextButton(
                              onPressed: () => _setPage(_offset - _pageSize),
                              child: const UrduAwareText('Oldingi'),
                            ),
                          if (rolls.length > _pageSize)
                            TextButton(
                              onPressed: () => _setPage(_offset + _pageSize),
                              child: const UrduAwareText('Keyingi'),
                            ),
                        ],
                      ),
                  ],
                );
              }
              final roll = rolls[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: AdminCatalogListRow(
                  slot: M3SegmentedListGeometry.standaloneListSlotForIndex(
                      index, count),
                  key: ValueKey('warehouse-roll-${roll.assetRef}'),
                  title: roll.itemName,
                  onTap: roll.canSelectForPaddon
                      ? () => widget.onToggle(roll)
                      : null,
                  onLongPress: roll.canSelectForPaddon
                      ? () => widget.onToggle(roll)
                      : null,
                  backgroundColor: widget.selected.contains(roll.assetRef)
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  subtitle: roll.paddonCode != null
                      ? 'Paddonda · ${roll.paddonCode}'
                      : roll.isPreparationReceiptWithoutQr
                          ? 'QR kodisiz kirim'
                          : roll.identifier,
                  icon: widget.selected.contains(roll.assetRef)
                      ? Icons.check_circle
                      : roll.canSelectForPaddon
                          ? Icons.radio_button_unchecked
                          : Icons.inventory_2_outlined,
                  value:
                      '${preparationDisplay(roll.qty.toString())} ${roll.uom}',
                ),
              );
            },
          ),
        );
      },
    );
  }
}
