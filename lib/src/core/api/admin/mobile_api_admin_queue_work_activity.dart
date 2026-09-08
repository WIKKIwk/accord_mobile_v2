part of '../mobile_api.dart';

/// Compact, server-owned session projection. No display-name or global-order
/// fallback: unknown ownership must never look like the current worker's job.
class AdminQueueWorkActivity {
  const AdminQueueWorkActivity({
    required this.workerRole,
    required this.workerRef,
    required this.state,
  });

  final String workerRole;
  final String workerRef;
  final String state;

  static AdminQueueWorkActivity? tryFromJson(Object? raw) {
    if (raw is! Map ||
        raw['worker_role'] is! String ||
        raw['worker_ref'] is! String ||
        raw['state'] is! String) {
      return null;
    }
    final role = (raw['worker_role'] as String).trim();
    final ref = (raw['worker_ref'] as String).trim();
    final state = (raw['state'] as String).trim();
    if (role.isEmpty ||
        ref.isEmpty ||
        (state != 'in_progress' && state != 'paused')) {
      return null;
    }
    return AdminQueueWorkActivity(
        workerRole: role, workerRef: ref, state: state);
  }

  bool belongsTo({required String role, required String ref}) =>
      workerRole.isNotEmpty &&
      workerRef.isNotEmpty &&
      workerRole == role.trim() &&
      workerRef == ref.trim();

  @override
  bool operator ==(Object other) =>
      other is AdminQueueWorkActivity &&
      workerRole == other.workerRole &&
      workerRef == other.workerRef &&
      state == other.state;

  @override
  int get hashCode => Object.hash(workerRole, workerRef, state);
}
