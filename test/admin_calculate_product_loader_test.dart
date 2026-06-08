import 'package:erpnext_stock_mobile/src/features/admin/presentation/calculate_product_picker_loader.dart';
import 'package:erpnext_stock_mobile/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads customer items when customer is selected', () async {
    var customerCalls = 0;
    var allCalls = 0;

    final result = await loadCalculateProductPickerPage(
      customerRef: 'CUST-001',
      query: 'cpp',
      offset: 10,
      limit: 20,
      customerItems: ({
        required customerRef,
        query = '',
        limit = 100,
        offset = 0,
      }) async {
        customerCalls++;
        expect(customerRef, 'CUST-001');
        expect(query, 'cpp');
        expect(offset, 10);
        expect(limit, 20);
        return const [
          SupplierItem(
            code: 'ITEM-CUST',
            name: 'Customer item',
            uom: 'Kg',
            warehouse: '',
          ),
        ];
      },
      allItems: ({
        query = '',
        group = '',
        limit = 80,
        offset = 0,
      }) async {
        allCalls++;
        return const <SupplierItem>[];
      },
    );

    expect(result.single.code, 'ITEM-CUST');
    expect(customerCalls, 1);
    expect(allCalls, 0);
  });

  test('loads all items when customer is not selected', () async {
    var customerCalls = 0;
    var allCalls = 0;

    final result = await loadCalculateProductPickerPage(
      customerRef: '',
      query: 'cpp',
      offset: 0,
      limit: 80,
      customerItems: ({
        required customerRef,
        query = '',
        limit = 100,
        offset = 0,
      }) async {
        customerCalls++;
        return const <SupplierItem>[];
      },
      allItems: ({
        query = '',
        group = '',
        limit = 80,
        offset = 0,
      }) async {
        allCalls++;
        expect(query, 'cpp');
        expect(offset, 0);
        expect(limit, 80);
        return const [
          SupplierItem(
            code: 'ITEM-ALL',
            name: 'All item',
            uom: 'Kg',
            warehouse: '',
          ),
        ];
      },
    );

    expect(result.single.code, 'ITEM-ALL');
    expect(customerCalls, 0);
    expect(allCalls, 1);
  });
}
