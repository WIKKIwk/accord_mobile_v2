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

String canonicalFactoryMapObjectId(String objectId) {
  final trimmed = objectId.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final match = RegExp(r'^(.*):instance:(\d+)$').firstMatch(trimmed);
  if (match != null) {
    final base = match.group(1)?.trim() ?? '';
    final instance = match.group(2)?.trim() ?? '';
    final canonicalBase = _apparatusAttachmentBaseMap[base] ?? base;
    return '$canonicalBase:instance:$instance';
  }
  return _apparatusAttachmentBaseMap[trimmed] ?? trimmed;
}

AdminApparatus? resolveFactoryMapApparatus(
  Iterable<AdminApparatus> apparatus,
  String objectId,
) {
  final normalizedObjectId = objectId.trim();
  if (normalizedObjectId.isEmpty) {
    return null;
  }
  for (final item in apparatus) {
    if (item.factoryMapObjectId.trim() == normalizedObjectId) {
      return item;
    }
  }
  final canonicalTarget = canonicalFactoryMapObjectId(normalizedObjectId);
  if (canonicalTarget.isNotEmpty) {
    for (final item in apparatus) {
      final itemObjectId = item.factoryMapObjectId.trim();
      if (canonicalFactoryMapObjectId(itemObjectId) == canonicalTarget) {
        return item;
      }
    }
  }
  return null;
}

bool hasLegacyFactoryMapBinding(
  Iterable<AdminApparatus> apparatus,
  String objectId,
) {
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
