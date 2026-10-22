import '../../features/shared/models/app_models.dart';

/// Keep capability validity intervals and the exact catalog model. The normal
/// edit projection turns profiles into a code/level map and loses those fields.
Map<String, dynamic> encodeCachedApparatus(AdminApparatus apparatus) => {
      ...apparatus.toJson(),
      'capabilities': [
        for (final value in apparatus.capabilityProfiles) value.toJson()
      ],
      '_cache_source': apparatus.source,
      '_cache_family': apparatus.family,
      '_cache_kind': apparatus.kind,
      '_cache_capabilities': apparatus.capabilities,
    };

AdminApparatus decodeCachedApparatus(Map<String, dynamic> value) {
  final capabilities = value['_cache_capabilities'];
  if (capabilities is! List ||
      capabilities.any((v) => v is! String) ||
      value['_cache_source'] is! String ||
      value['_cache_family'] is! String ||
      value['_cache_kind'] is! String) {
    throw const FormatException('Invalid cached apparatus');
  }
  return AdminApparatus.fromJson(value).copyWith(
    source: value['_cache_source'] as String,
    family: value['_cache_family'] as String,
    kind: value['_cache_kind'] as String,
    capabilities: capabilities.cast<String>(),
  );
}
