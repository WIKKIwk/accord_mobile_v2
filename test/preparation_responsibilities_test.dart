import 'package:accord_mobile_v2/src/features/preparation/models/preparation_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('snapshot parses responsibilities when present', () {
    final snapshot = PreparationSnapshot.fromJson({
      'warehouses': ['W'],
      'materials': [],
      'orders': [],
      'history': [],
      'responsibilities': [
        {'material_id': 'builtin-pet', 'material_name': 'PET'},
        {'material_id': 'builtin-pe', 'material_name': 'PE'},
      ],
    });
    expect(snapshot.responsibilities.length, 2);
    expect(snapshot.responsibilities.first.materialId, 'builtin-pet');
    expect(snapshot.responsibilities.first.materialName, 'PET');
  });

  test('snapshot defaults responsibilities to empty for old backends', () {
    final snapshot = PreparationSnapshot.fromJson({
      'warehouses': <String>[],
      'materials': [],
      'orders': [],
      'history': [],
    });
    expect(snapshot.responsibilities, isEmpty);
  });

  test('responsibility trims whitespace', () {
    final item = PreparationResponsibility.fromJson({
      'material_id': '  builtin-pet ',
      'material_name': ' PET ',
    });
    expect(item.materialId, 'builtin-pet');
    expect(item.materialName, 'PET');
    expect(item.toJson(), {
      'material_id': 'builtin-pet',
      'material_name': 'PET',
    });
  });
}
