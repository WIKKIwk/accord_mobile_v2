import 'package:accord_mobile_v2/src/features/boyoqchi/models/returned_paint_models.dart';
import 'package:accord_mobile_v2/src/features/boyoqchi/presentation/widgets/returned_paint_sheet.dart';
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
      'calculation': {
        'rasxot_mix_total': '3',
        'astatka_mix_total': '1.5',
        'rasxot_alcohol': '0.9',
        'astatka_alcohol': '0.45',
        'final_used_alcohol': '0.45',
        'rasxot_pure_paint': '2.1',
        'astatka_pure_paint': '1.05',
        'final_used_paint': '1.05',
      },
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
    expect(request.items[0].values['Mix'], '3');
    expect(request.items[1].usage, 'astatka');
    expect(request.items[1].values['Mix'], '1.5');
    expect(request.calculation?.rasxotMixTotal, '3');
    expect(request.calculation?.finalUsedAlcohol, '0.45');
    expect(request.calculation?.finalUsedPaint, '1.05');
  });

  test('astatka values become the aggregate return ink amount', () {
    const items = [
      ReturnedPaintItemInput(
        usage: 'rasxot',
        category: 'colors',
        name: 'Oq',
        values: {'Mix': '9', 'Oq': '3'},
      ),
      ReturnedPaintItemInput(
        usage: 'astatka',
        category: 'colors',
        name: 'Oq',
        values: {'Mix': '1.25', 'Oq': '0.75'},
      ),
      ReturnedPaintItemInput(
        usage: 'astatka',
        category: 'solvents',
        name: 'Spirtlar',
        values: {'Etil': '0.5'},
      ),
    ];

    expect(returnedPaintAstatkaTotal(items), 2.5);
    expect(returnedPaintAstatkaTotal(const []), isNull);
  });

  test('image-only report keeps waiting status and image metadata', () {
    final request = ReturnedPaintRequest.fromJson(const {
      'id': 'returned-paint-waiting',
      'order_id': 'order-image',
      'order_code': '8963',
      'order_name': 'Rasmli order',
      'apparatus': '7 ta rangli bosma',
      'sender_role': 'aparatchi',
      'sender_ref': 'worker-image',
      'sender_display_name': 'Bosmachi',
      'created_at_unix': 100,
      'status': 'waiting_for_boyoqchi_input',
      'image': {
        'image_id': 'image-1',
        'image_name': 'qoldiq.jpg',
        'image_mime': 'image/jpeg',
        'image_size_bytes': 123,
        'image_url': '/v1/mobile/returned-paint/images/view?id=image-1',
      },
      'items': [],
    });

    expect(request.waitingForBoyoqchiInput, isTrue);
    expect(request.calculation, isNull);
    expect(request.image?.imageId, 'image-1');
    expect(request.image?.imageSizeBytes, 123);
  });

  test('close rule requires three fields in each tab or image-only input', () {
    const oneRasxotField = ReturnedPaintItemInput(
      usage: 'rasxot',
      category: 'colors',
      name: 'Oq',
      values: {'Mix': '10'},
    );
    const threeRasxotFields = ReturnedPaintItemInput(
      usage: 'rasxot',
      category: 'colors',
      name: 'Oq',
      values: {'Mix': '10', '1w Oq': '2', '7w Oq': '1'},
    );
    const threeAstatkaFields = ReturnedPaintItemInput(
      usage: 'astatka',
      category: 'colors',
      name: 'Oq',
      values: {'Mix': '5', '1w Oq': '1', '7w Oq': '1'},
    );

    expect(
      returnedPaintReportCanClose(items: const [], imageId: 'image-1'),
      isTrue,
    );
    expect(
      returnedPaintReportCanClose(
        items: const [threeRasxotFields, threeAstatkaFields],
        imageId: '',
      ),
      isTrue,
    );
    expect(
      returnedPaintReportCanClose(
        items: const [threeRasxotFields],
        imageId: '',
      ),
      isFalse,
    );
    expect(
      returnedPaintReportCanClose(
        items: const [oneRasxotField, threeAstatkaFields],
        imageId: 'image-1',
      ),
      isFalse,
    );
    expect(
      returnedPaintFilledFieldCountForUsage(
        const [threeRasxotFields, threeAstatkaFields],
        'rasxot',
      ),
      3,
    );
  });
}
