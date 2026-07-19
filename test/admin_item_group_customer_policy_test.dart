import 'package:accord_mobile_v2/src/features/admin/models/admin_item_group_tree_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finished-goods customer rule follows exact parent path', () {
    const groups = [
      AdminItemGroupTreeEntry(
        name: 'All Item Groups',
        itemGroupName: 'All Item Groups',
        parentItemGroup: '',
        isGroup: true,
      ),
      AdminItemGroupTreeEntry(
        name: 'Tayyor mahsulot',
        itemGroupName: 'Tayyor mahsulot',
        parentItemGroup: 'All Item Groups',
        isGroup: true,
      ),
      AdminItemGroupTreeEntry(
        name: 'Paketlar',
        itemGroupName: 'Paketlar',
        parentItemGroup: 'Tayyor mahsulot',
        isGroup: false,
      ),
      AdminItemGroupTreeEntry(
        name: 'Yarim tayyor mahsulot',
        itemGroupName: 'Yarim tayyor mahsulot',
        parentItemGroup: 'All Item Groups',
        isGroup: false,
      ),
    ];

    expect(adminItemGroupRequiresCustomer('Tayyor mahsulot', groups), isTrue);
    expect(adminItemGroupRequiresCustomer('Paketlar', groups), isTrue);
    expect(
      adminItemGroupRequiresCustomer('Yarim tayyor mahsulot', groups),
      isFalse,
    );
  });

  test('customer rule terminates safely on cyclic group data', () {
    const groups = [
      AdminItemGroupTreeEntry(
        name: 'A',
        itemGroupName: 'A',
        parentItemGroup: 'B',
        isGroup: true,
      ),
      AdminItemGroupTreeEntry(
        name: 'B',
        itemGroupName: 'B',
        parentItemGroup: 'A',
        isGroup: true,
      ),
    ];

    expect(adminItemGroupRequiresCustomer('A', groups), isFalse);
  });
}
