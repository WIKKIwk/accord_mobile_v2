part of 'admin_warehouses_screen.dart';

List<_WarehouseDetailEntry> _warehouseRawStockDetails(
  AdminRawMaterialStockEntry stock,
  AppLocalizations l10n, {
  bool includeBarcode = true,
  bool includeReservation = true,
}) =>
    [
      _WarehouseDetailEntry(l10n.adminText('label.item_code'), stock.itemCode),
      if (includeBarcode)
        _WarehouseDetailEntry(l10n.adminText('label.barcode'), stock.barcode),
      _WarehouseDetailEntry(l10n.adminText('label.warehouse'), stock.warehouse),
      _WarehouseDetailEntry(l10n.adminText('label.quantity'),
          '${_formatQty(stock.qty)} ${stock.uom}'.trim()),
      if (stock.widthMm case final width?)
        _WarehouseDetailEntry(
            l10n.adminText('warehouse.roll_width'), '${_formatQty(width)} mm'),
      if (stock.micron case final micron?)
        _WarehouseDetailEntry(
            l10n.adminText('label.micron'), _formatQty(micron)),
      if (stock.lengthM case final length?)
        _WarehouseDetailEntry(
            l10n.adminText('warehouse.roll_length'), '${_formatQty(length)} m'),
      _WarehouseDetailEntry(l10n.adminText('label.status'),
          _warehouseStockStatusLabel(stock.status, l10n)),
      if (includeReservation && stock.reservedOrderId.trim().isNotEmpty)
        _WarehouseDetailEntry(
            l10n.adminText('calculate.order'), stock.reservedOrderId),
      if (stock.sourceReceiptId.trim().isNotEmpty)
        _WarehouseDetailEntry(
            l10n.adminText('label.receipt'), stock.sourceReceiptId),
    ];

class _WarehouseReservationOrderDetails extends StatefulWidget {
  const _WarehouseReservationOrderDetails({required this.orderId});

  final String orderId;

  @override
  State<_WarehouseReservationOrderDetails> createState() =>
      _WarehouseReservationOrderDetailsState();
}

class _WarehouseReservationOrderDetailsState
    extends State<_WarehouseReservationOrderDetails> {
  late Future<ProductionMapSaved> _orderFuture;

  @override
  void initState() {
    super.initState();
    _orderFuture = MobileApi.instance.adminProductionMap(widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<ProductionMapSaved>(
      future: _orderFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Center(child: AppLoadingIndicator(size: 24)),
          );
        }
        final order = snapshot.data?.map;
        if (order == null) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _orderFuture =
                    MobileApi.instance.adminProductionMap(widget.orderId);
              }),
              icon: const Icon(Icons.refresh_rounded),
              label:
                  Text(l10n.adminText('warehouse.reserved_order_load_failed')),
            ),
          );
        }
        return Column(
          children: [
            _WarehouseDetailLine(
              label: l10n.adminText('warehouse.reservation_reason'),
              value: l10n.adminText('warehouse.reservation_for_order', values: {
                'order': order.title.trim().isEmpty ? order.id : order.title,
              }),
            ),
            if (order.customerName.trim().isNotEmpty)
              _WarehouseDetailLine(
                label: l10n.adminText('label.customer'),
                value: order.customerName,
              ),
          ],
        );
      },
    );
  }
}
