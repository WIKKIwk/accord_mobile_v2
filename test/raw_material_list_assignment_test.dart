import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/material_taminotchi/presentation/widgets/raw_material_list_assignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('material linked to frozen order keeps the frozen assignment state', () {
    final assignments = rawMaterialListAssignmentsByBarcode(
      assignments: const [
        AdminRawMaterialAssignment(
          orderId: 'zakaz-frozen',
          apparatus: 'Pechat',
          barcode: 'RM-001',
          itemCode: 'INK-1',
          itemName: 'Kraska',
          itemGroup: 'Kraska',
        ),
      ],
      orders: const [],
      orderControlsByOrderId: const {
        'zakaz-frozen': AdminOrderControlState.frozen,
      },
    );

    expect(assignments['RM-001']?.isFrozen, isTrue);
    expect(assignments['RM-001']?.orderId, 'zakaz-frozen');
  });
}
