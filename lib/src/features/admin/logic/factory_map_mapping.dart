import '../../../core/api/mobile_api.dart';
import '../../shared/models/app_models.dart';

// Verified against the GLB geometry (2026-09-04): node:33 is the overhead
// arrow billboard (7-vertex arrow silhouette) floating above the node:39
// apparatus body. Neighbouring floating parts (node:32 roof canopy, node:34
// corner fins, node:38 corner plates, node:90/91 text signs, node:36/37
// machine panels) are intentionally NOT merged: they stay separately
// tappable so nothing foreign is ever grouped into an apparatus.
const Map<String, String> _apparatusAttachmentBaseMap = {
  'node:33': 'node:39',
};

// Extruder and Rezka each have eight coincident copies, not eight separate
// machines (verified against the source GLB world transforms).
// Preserve their node:7 / node:20 placements for these known taps only.
// Do not generalize this to other legacy node bindings or future instances.
const Set<String> _extruderCoincidentInstances = {
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
};

String canonicalFactoryMapObjectId(String objectId) {
  final trimmed = objectId.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final match = RegExp(r'^(.*):instance:(\d+)$').firstMatch(trimmed);
  if (match != null) {
    final base = match.group(1)?.trim() ?? '';
    final instance = match.group(2)?.trim() ?? '';
    if ((base == 'node:7' || base == 'node:20') &&
        _extruderCoincidentInstances.contains(instance)) {
      return base;
    }
    final canonicalBase = _apparatusAttachmentBaseMap[base] ?? base;
    return '$canonicalBase:instance:$instance';
  }
  return _apparatusAttachmentBaseMap[trimmed] ?? trimmed;
}

AdminApparatus? resolveFactoryMapApparatus(
  Iterable<AdminApparatus> apparatus,
  String objectId,
) {
  final owners = factoryMapObjectOwners(apparatus, objectId);
  return owners.length == 1 ? owners.single : null;
}

List<AdminApparatus> factoryMapObjectOwners(
  Iterable<AdminApparatus> apparatus,
  String objectId,
) {
  final target = canonicalFactoryMapObjectId(objectId);
  if (target.isEmpty) return const [];
  return apparatus
      .where((item) =>
          canonicalFactoryMapObjectId(item.factoryMapObjectId) == target)
      .toList();
}

/// Free apparatus for the map attach sheet: active items with no map
/// object attached. One apparatus id binds to exactly one unique map
/// object (also enforced by the server unique index), so already-bound
/// items are never offered.
List<AdminApparatus> unboundFactoryMapApparatus(
  Iterable<AdminApparatus> apparatus,
) {
  return [
    for (final item in apparatus)
      if (item.isActive && item.factoryMapObjectId.trim().isEmpty) item,
  ];
}

bool hasLegacyFactoryMapBinding(
  Iterable<AdminApparatus> apparatus,
  String objectId,
) {
  if (resolveFactoryMapApparatus(apparatus, objectId) != null) {
    return false;
  }
  final legacyObjectId = _legacyFactoryMapObjectId(objectId);
  if (legacyObjectId == null) {
    return false;
  }
  final canonicalLegacy = canonicalFactoryMapObjectId(legacyObjectId);
  return apparatus.any(
    (item) {
      final itemObjectId = item.factoryMapObjectId.trim();
      return itemObjectId == legacyObjectId ||
          canonicalFactoryMapObjectId(itemObjectId) == canonicalLegacy;
    },
  );
}

String factoryMapLoadErrorMessage(Object error, String fallback) {
  if (error is MobileApiException) {
    return error.message;
  }
  final detail = error.toString().trim();
  return detail.isEmpty ? fallback : '$fallback: $detail';
}

String? _legacyFactoryMapObjectId(String objectId) {
  final match = RegExp(r'^(.*):instance:\d+$').firstMatch(objectId.trim());
  final legacyObjectId = match?.group(1)?.trim();
  return legacyObjectId == null || legacyObjectId.isEmpty
      ? null
      : legacyObjectId;
}
