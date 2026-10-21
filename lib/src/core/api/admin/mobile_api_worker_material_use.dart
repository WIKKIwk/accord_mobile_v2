part of '../mobile_api.dart';

class WorkerMaterialCandidate {
  WorkerMaterialCandidate.fromJson(Map<String, dynamic> json)
      : barcode = json['barcode']?.toString().trim() ?? '',
        itemName = json['item_name']?.toString() ?? '',
        placementVersion = (json['placement_version'] as num?)?.toInt() ?? 0;
  final String barcode, itemName;
  final int placementVersion;
}

class WorkerMaterialCandidates {
  WorkerMaterialCandidates.fromJson(Map<String, dynamic> json)
      : enabled = json['enabled'] == true,
        candidates = (json['candidates'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => WorkerMaterialCandidate.fromJson(
                Map<String, dynamic>.from(row)))
            .where((row) =>
                row.barcode.trim().isNotEmpty && row.placementVersion > 0)
            .toList();
  final bool enabled;
  final List<WorkerMaterialCandidate> candidates;
}

extension MobileApiWorkerMaterialUse on MobileApi {
  Future<WorkerMaterialCandidates> workerMaterialCandidates({
    required String orderId,
    required String apparatus,
  }) async {
    final response = await _sendAuthorized(() => _get(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/worker-material-use')
              .replace(queryParameters: {
            'order_id': orderId,
            'apparatus': apparatus
          }),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
          response, 'worker_material_candidates');
    }
    return WorkerMaterialCandidates.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> useWorkerMaterial({
    required String orderId,
    required String apparatus,
    required WorkerMaterialCandidate material,
  }) async {
    final response = await _sendAuthorized(() => _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/worker-material-use'),
          headers: {
            ..._headers(requireToken()),
            'Content-Type': 'application/json'
          },
          body: jsonEncode({
            'order_id': orderId,
            'apparatus': apparatus,
            'barcode': material.barcode,
            'placement_version': material.placementVersion
          }),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'worker_material_use');
    }
    final result = jsonDecode(response.body);
    if (result is! Map ||
        result['ok'] != true ||
        result['barcode']?.toString().toUpperCase() !=
            material.barcode.toUpperCase()) {
      throw const MobileApiException(
          code: 'worker_material_use_unconfirmed',
          message: 'Xomashyo ulanishi tasdiqlanmadi');
    }
  }
}
