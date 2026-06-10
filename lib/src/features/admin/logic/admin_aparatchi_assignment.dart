import '../../shared/models/app_models.dart';

AdminRoleAssignment? adminAssignmentForCustomerRef(
  List<AdminRoleAssignment> assignments,
  String ref,
) {
  final trimmed = ref.trim();
  for (final assignment in assignments) {
    if (assignment.principalRef.trim() != trimmed) {
      continue;
    }
    if (assignment.principalRole == UserRole.customer ||
        assignment.principalRole == UserRole.aparatchi) {
      return assignment;
    }
  }
  return null;
}

bool adminIsAparatchiAssignment(AdminRoleAssignment? assignment) {
  return assignment?.roleId.trim().toLowerCase() == 'aparatchi';
}

UserRole adminCustomerPrincipalRole(
  List<AdminRoleAssignment> assignments,
  String ref,
) {
  final assignment = adminAssignmentForCustomerRef(assignments, ref);
  if (adminIsAparatchiAssignment(assignment)) {
    return UserRole.aparatchi;
  }
  return assignment?.principalRole ?? UserRole.customer;
}

AdminRoleAssignment adminAparatchiAssignmentUpsert({
  required String principalRef,
  required List<String> assignedApparatus,
}) {
  return AdminRoleAssignment(
    principalRole: UserRole.aparatchi,
    principalRef: principalRef.trim(),
    roleId: 'aparatchi',
    assignedApparatus: assignedApparatus,
  );
}
