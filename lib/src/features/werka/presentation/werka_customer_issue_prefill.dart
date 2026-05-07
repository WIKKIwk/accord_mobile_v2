class WerkaCustomerIssuePrefillArgs {
  const WerkaCustomerIssuePrefillArgs({
    this.customerRef = '',
    this.customerName = '',
    required this.itemCode,
    required this.itemName,
    required this.qty,
    required this.uom,
    this.warehouse = '',
    this.sourceStockEntryName = '',
    this.sourceBarcode = '',
  });

  final String customerRef;
  final String customerName;
  final String itemCode;
  final String itemName;
  final double qty;
  final String uom;
  final String warehouse;
  final String sourceStockEntryName;
  final String sourceBarcode;

  bool get hasCustomer => customerRef.trim().isNotEmpty;

  bool get hasSource =>
      sourceStockEntryName.trim().isNotEmpty || sourceBarcode.trim().isNotEmpty;
}
