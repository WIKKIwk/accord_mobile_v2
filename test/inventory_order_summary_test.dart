import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:accord_mobile_v2/src/features/material_taminotchi/presentation/widgets/raw_material_list_assignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('omitted summary differs from confirmed unassigned', () {
    expect(InventoryAsset.fromJson({}).orderAssignmentKnown, isFalse);
    final asset = InventoryAsset.fromJson({'order_assignment': null});
    expect(asset.orderAssignmentKnown, isTrue);
    expect(rawMaterialListAssignmentForAsset(asset), isNull);
  });
  test('compact frozen summary preserves list label through stock mutations',
      () {
    final asset = InventoryAsset.fromJson({
      'order_assignment': {
        'order_id': 'zakaz-42',
        'order_label': '0042 · Product',
        'order_control': 'frozen',
      },
    });
    final moved = asset.copyWith(status: 'in_use');
    final summary = rawMaterialListAssignmentForAsset(moved)!;
    expect(summary.orderLabel, '0042 · Product');
    expect(summary.isFrozen, isTrue);
    expect(moved.orderAssignmentKnown, isTrue);
    expect(moved.copyWith(orderAssignmentKnown: true).orderAssignment, isNull);
  });
  test('invalid metadata cannot be mistaken for an unassigned material', () {
    expect(() => InventoryAsset.fromJson({'order_assignment': false}),
        throwsFormatException);
    expect(
        () => InventoryAsset.fromJson({
              'order_assignment': {'order_id': ''}
            }),
        throwsFormatException);
  });
}
