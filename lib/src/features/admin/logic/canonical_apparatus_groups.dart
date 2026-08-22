import '../../../core/localization/app_localizations.dart';
import '../../shared/models/app_models.dart';

const _canonicalApparatusOperationOrder = <String>[
  'print',
  'laminate',
  'cut',
  'package',
  'glue',
];

class CanonicalApparatusGroup {
  const CanonicalApparatusGroup({
    required this.operation,
    required this.apparatus,
  });

  final String operation;
  final List<AdminApparatus> apparatus;

  bool get isClassified =>
      _canonicalApparatusOperationOrder.contains(operation);
}

bool isCanonicalApparatusId(String value) {
  return canonicalApparatusIdIsValid(value);
}

List<CanonicalApparatusGroup> canonicalApparatusGroups(
  Iterable<AdminApparatus> source,
) {
  final grouped = <String, List<AdminApparatus>>{};
  for (final apparatus in source) {
    if (!apparatus.isActive) continue;
    final operation = apparatus.operation.trim().toLowerCase();
    final groupKey = _canonicalApparatusOperationOrder.contains(operation)
        ? operation
        : 'unclassified';
    grouped.putIfAbsent(groupKey, () => <AdminApparatus>[]).add(apparatus);
  }

  final groups = <CanonicalApparatusGroup>[];
  for (final operation in [
    ..._canonicalApparatusOperationOrder,
    'unclassified',
  ]) {
    final apparatus = grouped[operation];
    if (apparatus == null || apparatus.isEmpty) continue;
    apparatus.sort((left, right) {
      final order = left.sortOrder.compareTo(right.sortOrder);
      return order != 0
          ? order
          : left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    groups.add(
      CanonicalApparatusGroup(
        operation: operation,
        apparatus: List<AdminApparatus>.unmodifiable(apparatus),
      ),
    );
  }
  return List<CanonicalApparatusGroup>.unmodifiable(groups);
}

String canonicalApparatusGroupLabel(
  CanonicalApparatusGroup group,
  AppLocalizations l10n,
) {
  final key = switch (group.operation) {
    'print' => 'apparatus.group.print',
    'laminate' => 'apparatus.group.laminate',
    'cut' => 'apparatus.group.cut',
    'package' => 'apparatus.group.package',
    'glue' => 'apparatus.group.glue',
    _ => 'apparatus.group.unclassified',
  };
  return l10n.adminText(key);
}
