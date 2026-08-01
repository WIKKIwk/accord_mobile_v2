import 'package:accord_mobile_v2/src/features/admin/logic/admin_aparatchi_assignment.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('material apparatus update preserves role and item-group scope', () {
    const assignment = AdminRoleAssignment(
      principalRole: UserRole.materialTaminotchi,
      principalRef: 'MAT-001',
      roleId: 'material_taminotchi',
      assignedApparatus: ['Pechat - A'],
      assignedItemGroups: ['Rulon', 'Kraska'],
    );

    final updated = adminMaterialTaminotchiAssignmentUpsert(
      assignment: assignment,
      assignedApparatus: const ['Laminatsiya - A'],
    );

    expect(updated.principalRole, UserRole.materialTaminotchi);
    expect(updated.principalRef, 'MAT-001');
    expect(updated.roleId, 'material_taminotchi');
    expect(updated.assignedApparatus, ['Laminatsiya - A']);
    expect(updated.assignedItemGroups, ['Rulon', 'Kraska']);
  });
}
