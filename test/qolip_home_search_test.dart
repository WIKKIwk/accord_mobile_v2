import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_home_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('qolip home search counts matching container children in a cell', () {
    final items = const [
      QolipLocationEntry(
        id: '1',
        block: 'A blok',
        warehouse: 'Qolip ombor',
        itemCode: 'ITEM-001',
        itemName: 'Kross model',
        qolipCode: 'Q-001',
        size: 40,
        quantity: 1,
        rowLetter: 'A',
        columnNumber: 1,
        locationLabel: 'A1',
      ),
      QolipLocationEntry(
        id: '2',
        block: 'A blok',
        warehouse: 'Qolip ombor',
        itemCode: 'ITEM-001',
        itemName: 'Kross model',
        qolipCode: 'Q-002',
        size: 41,
        quantity: 1,
        rowLetter: 'A',
        columnNumber: 1,
        locationLabel: 'A1',
      ),
      QolipLocationEntry(
        id: '3',
        block: 'A blok',
        warehouse: 'Qolip ombor',
        itemCode: 'ITEM-002',
        itemName: 'Botinka model',
        qolipCode: 'Q-003',
        size: 42,
        quantity: 1,
        rowLetter: 'A',
        columnNumber: 1,
        locationLabel: 'A1',
      ),
    ];

    expect(qolipContainerSearchMatchCount(items, 'kross'), 2);
    expect(qolipContainerSearchMatchCount(items, 'botinka'), 1);
    expect(qolipContainerSearchMatchCount(items, 'loafer'), 0);
    expect(qolipContainerSearchMatchCount(items, ''), 0);
  });
}
