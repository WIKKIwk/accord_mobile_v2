import '../../../core/api/mobile_api.dart';
import '../../shared/models/app_models.dart';

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
  return apparatus.any(
    (item) => item.factoryMapObjectId.trim() == legacyObjectId,
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
