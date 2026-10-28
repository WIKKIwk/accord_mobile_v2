import 'package:accord_mobile_v2/src/features/admin/presentation/calculate_product_picker_loader.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const items = [
    SupplierItem(
        code: 'A',
        name: 'A',
        uom: 'kg',
        warehouse: '',
        itemGroup: 'Tayyor mahsulot'),
    SupplierItem(
        code: 'COMBO-1',
        name: 'A+B',
        uom: 'kg',
        warehouse: '',
        itemGroup: 'Kombo'),
  ];
  Future<List<SupplierItem>> load(
          {String query = '',
          String group = '',
          int limit = 0,
          int offset = 0}) async =>
      items;
  Future<AdminCustomerDetail> customer(String ref) async =>
      AdminCustomerDetail.fromJson({
        'ref': ref,
        'assigned_items': [
          for (final item in items)
            {
              'code': item.code,
              'name': item.name,
              'item_group': item.itemGroup,
            }
        ]
      });
  for (final customerRef in ['', 'C1']) {
    test(
        'combo is selectable as a catalog parent but not a child, customer=$customerRef',
        () async {
      Future<List<SupplierItem>> page(bool include) =>
          loadCalculateProductPickerPage(
              customerRef: customerRef,
              query: '',
              offset: 0,
              limit: 80,
              customerDetail: customer,
              allItems: load,
              includeCombos: include);
      expect((await page(false)).map((p) => p.code), ['A']);
      expect((await page(true)).map((p) => p.code), ['A', 'COMBO-1']);
    });
  }
}
