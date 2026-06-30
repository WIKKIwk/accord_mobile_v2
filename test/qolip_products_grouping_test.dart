import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('qolip products are grouped by container item', () {
    final groups = groupQolipProductsByContainer(const [
      QolipProduct(
        code: 'ITEM-002',
        name: 'Botinka',
        itemGroup: 'Tayyor mahsulot',
        qolipCode: 'Q-B-02',
        qolipSize: 42,
        hasQolipSpec: true,
      ),
      QolipProduct(
        code: 'ITEM-001',
        name: 'Kross',
        itemGroup: 'Tayyor mahsulot',
        qolipCode: 'Q-A-02',
        qolipSize: 41,
        hasQolipSpec: true,
      ),
      QolipProduct(
        code: 'ITEM-001',
        name: 'Kross',
        itemGroup: 'Tayyor mahsulot',
        qolipCode: 'Q-A-01',
        qolipSize: 40,
        hasQolipSpec: true,
      ),
    ]);

    expect(groups.map((group) => group.name), ['Botinka', 'Kross']);
    expect(groups[1].children.map((child) => child.qolipCode), [
      'Q-A-01',
      'Q-A-02',
    ]);
  });

  test('qolip grouping ignores products without child code', () {
    final groups = groupQolipProductsByContainer(const [
      QolipProduct(
        code: 'ITEM-001',
        name: 'Kross',
        itemGroup: 'Tayyor mahsulot',
      ),
    ]);

    expect(groups, isEmpty);
  });
}
