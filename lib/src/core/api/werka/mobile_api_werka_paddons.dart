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
      this.receipt,
      this.apparatusNames = const {}});
  final AdminPaddonSnapshot snapshot;
  final List<String> warehouses;
  final bool canReceive;
  final String snapshotToken;
  final Map<String, dynamic>? receipt;
  final Map<String, String> apparatusNames;
  factory WerkaPaddonPreview.fromJson(Map<String, dynamic> json) =>
      WerkaPaddonPreview(
        snapshot: AdminPaddonSnapshot.fromJson(json),
        warehouses: (json['warehouses'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        canReceive: json['can_receive'] == true,
        snapshotToken: json['snapshot_token']?.toString() ?? '',
        apparatusNames: _werkaApparatusNames(json),
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
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_preview_failed');
    }
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
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_receive_failed');
    }
    return Map<String, dynamic>.from(
        (jsonDecode(response.body) as Map)['receipt'] as Map);
  }
}

Map<String, String> _werkaApparatusNames(Map<String, dynamic> json) =>
    json['apparatus_names'] is Map
        ? {
            for (final entry in (json['apparatus_names'] as Map).entries)
              if (entry.key is String && entry.value is String)
                entry.key as String: entry.value as String,
          }
        : const {};

/// Identity and eligibility come from the warehouse-scoped read-only endpoint.
class WerkaQrPreview {
  const WerkaQrPreview({required this.code, this.paddon, this.wip});
  final String code;
  final WerkaPaddonPreview? paddon;
  final WerkaWipPreview? wip;

  factory WerkaQrPreview.fromJson(String code, Map<String, dynamic> json) {
    return switch (json['kind']) {
      'paddon' =>
        WerkaQrPreview(code: code, paddon: WerkaPaddonPreview.fromJson(json)),
      'wip' => WerkaQrPreview(code: code, wip: WerkaWipPreview.fromJson(json)),
      _ => throw const MobileApiException(
          code: 'qr_preview_invalid', message: 'QR javobi noto‘g‘ri'),
    };
  }
}

class WerkaWipPreview {
  const WerkaWipPreview({
    required this.batch,
    required this.warehouses,
    required this.canReceive,
    required this.snapshotToken,
    this.receipt,
    this.receiveBlockedReason = '',
    this.paddonCode = '',
    this.apparatusNames = const {},
  });
  final AdminProgressBatch batch;
  final List<String> warehouses;
  final bool canReceive;
  final String snapshotToken;
  final Map<String, dynamic>? receipt;
  final String receiveBlockedReason;
  final String paddonCode;
  final Map<String, String> apparatusNames;

  factory WerkaWipPreview.fromJson(Map<String, dynamic> json) =>
      WerkaWipPreview(
        batch: AdminProgressBatch.fromJson(
            Map<String, dynamic>.from(json['batch'] as Map)),
        warehouses: (json['warehouses'] as List? ?? const [])
            .whereType<String>()
            .toList(),
        canReceive: json['can_receive'] == true,
        snapshotToken: json['snapshot_token']?.toString() ?? '',
        receipt: json['receipt'] is Map
            ? Map<String, dynamic>.from(json['receipt'] as Map)
            : null,
        receiveBlockedReason: json['receive_blocked_reason']?.toString() ?? '',
        paddonCode: json['paddon_code']?.toString() ?? '',
        apparatusNames: _werkaApparatusNames(json),
      );
}

extension MobileApiWerkaQr on MobileApi {
  Future<WerkaQrPreview> werkaQrPreview(String rawCode) async {
    final code = rawCode.trim();
    final response = await _sendAuthorized(() => _get(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/werka/qr/preview')
              .replace(queryParameters: {'qr_payload': code}),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'qr_preview_failed');
    }
    return WerkaQrPreview.fromJson(
        code, jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> werkaReceiveWip(
      WerkaWipPreview preview, String warehouse) async {
    final response = await _sendAuthorized(() => _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/werka/wip/receive'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({
            'progress_batch_id': preview.batch.batchId,
            'qr_payload': preview.batch.qrPayload,
            'warehouse': warehouse,
            'snapshot_token': preview.snapshotToken,
          }),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'wip_receive_failed');
    }
    return Map<String, dynamic>.from(
        (jsonDecode(response.body) as Map)['receipt'] as Map);
  }
}
