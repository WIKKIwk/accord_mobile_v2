import '../../../core/localization/app_localizations.dart';
import '../../shared/models/app_models.dart';

const _canonicalApparatusGroupOrder = <String>[
  'print',
  'laminate',
  'extrusion_lamination',
  'cut',
  'package',
  'glue',
];

class CanonicalApparatusGroup {
  const CanonicalApparatusGroup({
    required this.operation,
    required this.apparatus,
    String? key,
  }) : key = key ?? operation;

  /// Display family; multiple families may share the same production operation.
  final String key;
  final String operation;
  final List<AdminApparatus> apparatus;

  bool get isClassified => _canonicalApparatusGroupOrder.contains(key);
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
    final family = operation == 'laminate' &&
            apparatus.technology.trim().toLowerCase() == 'extrusion_lamination'
        ? 'extrusion_lamination'
        : operation;
    final groupKey = _canonicalApparatusGroupOrder.contains(family)
        ? family
        : 'unclassified';
    grouped.putIfAbsent(groupKey, () => <AdminApparatus>[]).add(apparatus);
  }

  final groups = <CanonicalApparatusGroup>[];
  for (final groupKey in [
    ..._canonicalApparatusGroupOrder,
    'unclassified',
  ]) {
    final apparatus = grouped[groupKey];
    if (apparatus == null || apparatus.isEmpty) continue;
    apparatus.sort((left, right) {
      final order = left.sortOrder.compareTo(right.sortOrder);
      return order != 0
          ? order
          : left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    groups.add(
      CanonicalApparatusGroup(
        key: groupKey,
        operation: groupKey == 'extrusion_lamination' ? 'laminate' : groupKey,
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
  final key = switch (group.key) {
    'print' => 'apparatus.group.print',
    'laminate' => 'apparatus.group.laminate',
    'extrusion_lamination' => 'apparatus.option.extruder_laminatsiya',
    'cut' => 'apparatus.group.cut',
    'package' => 'apparatus.group.package',
    'glue' => 'apparatus.group.glue',
    _ => 'apparatus.group.unclassified',
  };
  return l10n.adminText(key);
}
