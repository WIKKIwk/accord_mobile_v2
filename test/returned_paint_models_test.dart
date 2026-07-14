import 'package:accord_mobile_v2/src/features/boyoqchi/models/returned_paint_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returned paint keeps rasxot and astatka values separate', () {
    final request = ReturnedPaintRequest.fromJson(const {
      'id': 'returned-paint-1',
      'order_id': 'order-1',
      'order_code': '1212',
      'order_name': 'Estello',
      'apparatus': '7 ta rangli bosma',
      'sender_role': 'aparatchi',
      'sender_ref': 'worker-1',
      'sender_display_name': 'Bosmachi',
      'created_at_unix': 100,
      'items': [
        {
          'usage': 'rasxot',
          'category': 'colors',
          'name': 'Oq',
          'values': {'Mix': 3},
        },
        {
          'usage': 'astatka',
          'category': 'colors',
          'name': 'Oq',
          'values': {'Mix': 1.5},
        },
      ],
    });

    expect(request.items[0].usage, 'rasxot');
    expect(request.items[0].values['Mix'], 3);
    expect(request.items[1].usage, 'astatka');
    expect(request.items[1].values['Mix'], 1.5);
  });

  test('astatka values become the aggregate return ink amount', () {
    const items = [
      ReturnedPaintItemInput(
        usage: 'rasxot',
        category: 'colors',
        name: 'Oq',
        values: {'Mix': 9, 'Oq': 3},
      ),
      ReturnedPaintItemInput(
        usage: 'astatka',
        category: 'colors',
        name: 'Oq',
        values: {'Mix': 1.25, 'Oq': 0.75},
      ),
      ReturnedPaintItemInput(
        usage: 'astatka',
        category: 'solvents',
        name: 'Spirtlar',
        values: {'Etil': 0.5},
      ),
    ];

    expect(returnedPaintAstatkaTotal(items), 2.5);
    expect(returnedPaintAstatkaTotal(const []), isNull);
  });
}
