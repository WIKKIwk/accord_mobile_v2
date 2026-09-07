part of '../mobile_api.dart';

// Finished-goods receipts use a warehouse marker, not an apparatus identity.
// All actual apparatus fields continue to require canonical IDs.
String _progressBatchProcessorId(String value) {
  final normalized = value.trim();
  if (normalized.startsWith('warehouse:') &&
      normalized.substring(10).trim().isNotEmpty) {
    return normalized;
  }
  return _requireCanonicalApparatusId(normalized, allowEmpty: true);
}

class WerkaPaddonPreview {
  const WerkaPaddonPreview(
      {required this.snapshot,
      required this.warehouses,
      required this.canReceive,
      required this.snapshotToken,
      this.receipt});
  final AdminPaddonSnapshot snapshot;
  final List<String> warehouses;
  final bool canReceive;
  final String snapshotToken;
  final Map<String, dynamic>? receipt;
  factory WerkaPaddonPreview.fromJson(Map<String, dynamic> json) =>
      WerkaPaddonPreview(
        snapshot: AdminPaddonSnapshot.fromJson(json),
        warehouses: (json['warehouses'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        canReceive: json['can_receive'] == true,
        snapshotToken: json['snapshot_token']?.toString() ?? '',
        receipt: json['receipt'] is Map
            ? Map<String, dynamic>.from(json['receipt'] as Map)
            : null,
      );
}

extension MobileApiWerkaPaddons on MobileApi {
  Future<WerkaPaddonPreview> werkaPaddonPreview(String code) async {
    final response = await _sendAuthorized(() => _get(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/werka/paddons/preview')
              .replace(queryParameters: {'code': code.trim()}),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200)
      throw _adminProductionMapException(response, 'paddon_not_found');
    return WerkaPaddonPreview.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> werkaReceivePaddon(
      WerkaPaddonPreview preview, String warehouse) async {
    final response = await _sendAuthorized(() => _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/werka/paddons/receive'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({
            'code': preview.snapshot.paddon.code,
            'warehouse': warehouse,
            'expected_batch_ids':
                preview.snapshot.items.map((b) => b.batchId).toList(),
            'snapshot_token': preview.snapshotToken
          }),
        ));
    if (response.statusCode != 200)
      throw _adminProductionMapException(response, 'paddon_receive_failed');
    return Map<String, dynamic>.from(
        (jsonDecode(response.body) as Map)['receipt'] as Map);
  }
}
