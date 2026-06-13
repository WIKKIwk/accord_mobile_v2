import 'package:accord_mobile_v2/src/features/admin/presentation/calculate_product_picker_loader.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads assigned customer items when customer is selected', () async {
    var detailCalls = 0;
    var allCalls = 0;

    final result = await loadCalculateProductPickerPage(
      customerRef: 'CUST-001',
      query: 'cust',
      offset: 1,
      limit: 1,
      customerDetail: (customerRef) async {
        detailCalls++;
        expect(customerRef, 'CUST-001');
        return const AdminCustomerDetail(
          ref: 'CUST-001',
          name: 'Customer',
          phone: '',
          code: '',
          codeLocked: false,
          codeRetryAfterSec: 0,
          assignedItems: [
            SupplierItem(
              code: 'ITEM-1',
              name: 'Customer first',
              uom: 'Kg',
              warehouse: '',
            ),
            SupplierItem(
              code: 'ITEM-2',
              name: 'Customer second',
              uom: 'Kg',
              warehouse: '',
            ),
            SupplierItem(
              code: 'NOPE',
              name: 'Other item',
              uom: 'Kg',
              warehouse: '',
            ),
          ],
        );
      },
      allItems: ({query = '', group = '', limit = 80, offset = 0}) async {
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

    expect(result.single.code, 'ITEM-2');
    expect(detailCalls, 1);
    expect(allCalls, 0);
  });

  test(
    'returns empty customer item page when offset is past filtered items',
    () async {
      final result = await loadCalculateProductPickerPage(
        customerRef: 'CUST-001',
        query: 'missing',
        offset: 0,
        limit: 20,
        customerDetail: (_) async {
          return const AdminCustomerDetail(
            ref: 'CUST-001',
            name: 'Customer',
            phone: '',
            code: '',
            codeLocked: false,
            codeRetryAfterSec: 0,
            assignedItems: [
              SupplierItem(
                code: 'ITEM-CUST',
                name: 'Customer item',
                uom: 'Kg',
                warehouse: '',
              ),
            ],
          );
        },
        allItems: ({query = '', group = '', limit = 80, offset = 0}) async {
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

      expect(result, isEmpty);
    },
  );

  test('loads all items when customer is not selected', () async {
    var detailCalls = 0;
    var allCalls = 0;

    final result = await loadCalculateProductPickerPage(
      customerRef: '',
      query: 'cpp',
      offset: 0,
      limit: 80,
      customerDetail: (_) async {
        detailCalls++;
        throw StateError('customer detail should not load');
      },
      allItems: ({query = '', group = '', limit = 80, offset = 0}) async {
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
    expect(detailCalls, 0);
    expect(allCalls, 1);
  });
}
