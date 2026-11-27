part of 'preparation_screen.dart';

class _PreparationWarehouseRolls extends StatefulWidget {
  const _PreparationWarehouseRolls({
    super.key,
    required this.warehouseId,
    required this.query,
  });

  final String warehouseId;
  final String query;

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
                  title: roll.itemName,
                  subtitle: roll.paddonCode != null
                      ? 'Paddonda · ${roll.paddonCode}'
                      : roll.isPreparationReceiptWithoutQr
                          ? 'QR kodisiz kirim'
                          : roll.identifier,
                  icon: Icons.inventory_2_outlined,
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
