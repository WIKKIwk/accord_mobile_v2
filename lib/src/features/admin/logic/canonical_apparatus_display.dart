import '../../shared/models/app_models.dart';
import 'canonical_apparatus_groups.dart';

Set<String> canonicalApparatusIds(Iterable<String> values) {
  return {
    for (final value in values)
      if (isCanonicalApparatusId(value)) value.trim(),
  };
}

Map<String, String> canonicalApparatusNamesById(
  Iterable<AdminApparatus> apparatus,
) {
  return {
    for (final item in apparatus)
      if (item.id.trim().isNotEmpty && item.name.trim().isNotEmpty)
        item.id.trim(): item.name.trim(),
  };
}

String canonicalApparatusDisplayLabel(
  String apparatusId,
  Iterable<AdminApparatus> apparatus,
) {
  final id = apparatusId.trim();
  if (id.isEmpty) {
    return '';
  }
  return canonicalApparatusNamesById(apparatus)[id] ?? id;
}

List<String> canonicalApparatusDisplayLabels(
  Iterable<String> apparatusIds,
  Iterable<AdminApparatus> apparatus,
) {
  final namesById = canonicalApparatusNamesById(apparatus);
  final labels = <String>[
    for (final id in canonicalApparatusIds(apparatusIds)) namesById[id] ?? id,
  ]..sort();
  return labels;
}
