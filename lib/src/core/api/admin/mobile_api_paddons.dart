part of '../mobile_api.dart';

class AdminPaddon {
  const AdminPaddon({
    required this.id,
    required this.code,
    required this.location,
    required this.note,
    required this.createdByRef,
    required this.createdByDisplayName,
    required this.createdAtUnix,
    required this.updatedAtUnix,
    required this.itemCount,
  });

  final String id;
  final String code;
  final String location;
  final String note;
  final String createdByRef;
  final String createdByDisplayName;
  final int createdAtUnix;
  final int updatedAtUnix;
  final int itemCount;

  factory AdminPaddon.fromJson(Map<String, dynamic> json) {
    return AdminPaddon(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      createdByRef: json['created_by_ref']?.toString() ?? '',
      createdByDisplayName: json['created_by_display_name']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
      updatedAtUnix: (json['updated_at_unix'] as num?)?.toInt() ?? 0,
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminPaddonSnapshot {
  const AdminPaddonSnapshot({
    required this.paddon,
    required this.items,
    this.availableItems = const [],
  });

  final AdminPaddon paddon;
  final List<AdminProgressBatch> items;
  final List<AdminProgressBatch> availableItems;

  factory AdminPaddonSnapshot.fromJson(Map<String, dynamic> json) {
    final rawPaddon = json['paddon'];
    final rawItems = json['items'];
    final rawAvailableItems = json['available_items'];
    final items = [
      if (rawItems is List)
        for (final item in rawItems)
          if (item is Map)
            AdminProgressBatch.fromJson(item.cast<String, dynamic>()),
    ];
    final assignedBatchIds = items
        .map((item) => item.batchId.trim())
        .where((batchId) => batchId.isNotEmpty)
        .toSet();
    final availableItems = <AdminProgressBatch>[];
    if (rawAvailableItems is List) {
      for (final item in rawAvailableItems) {
        if (item is! Map) {
          continue;
        }
        final batch = AdminProgressBatch.fromJson(
          item.cast<String, dynamic>(),
        );
        if (!assignedBatchIds.contains(batch.batchId.trim())) {
          availableItems.add(batch);
        }
      }
    }
    return AdminPaddonSnapshot(
      paddon: AdminPaddon.fromJson(
        rawPaddon is Map
            ? rawPaddon.cast<String, dynamic>()
            : const <String, dynamic>{},
      ),
      items: items,
      availableItems: availableItems,
    );
  }
}

extension MobileApiPaddons on MobileApi {
  Future<List<AdminPaddon>> adminPaddons({int limit = 100}) async {
    final boundedLimit = limit.clamp(1, 200).toInt();
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons',
        ).replace(
          queryParameters: {'limit': boundedLimit.toString()},
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddons_list');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawPaddons = payload['paddons'];
    return [
      if (rawPaddons is List)
        for (final item in rawPaddons)
          if (item is Map) AdminPaddon.fromJson(item.cast<String, dynamic>()),
    ];
  }

  Future<AdminPaddonSnapshot> adminPaddonDetail(String code) async {
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      throw const MobileApiException(
        code: 'paddon_not_found',
        message: 'Paddon topilmadi',
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/detail',
        ).replace(
          queryParameters: {'code': normalizedCode},
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_not_found');
    }
    return AdminPaddonSnapshot.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminPaddon> adminPaddonCreate({
    String location = '',
    String note = '',
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/create',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'location': location.trim(),
          'note': note.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_create');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawPaddon = payload['paddon'];
    if (rawPaddon is! Map) {
      throw const MobileApiException(
        code: 'paddon_create',
        message: 'Paddon yaratilmadi',
      );
    }
    return AdminPaddon.fromJson(rawPaddon.cast<String, dynamic>());
  }

  Future<AdminPaddonSnapshot> adminPaddonAddWip({
    required String paddonCode,
    String progressBatchId = '',
    String qrPayload = '',
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/items/add',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'code': paddonCode.trim(),
          'progress_batch_id': progressBatchId.trim(),
          'qr_payload': qrPayload.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_item_add');
    }
    return AdminPaddonSnapshot.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AdminPaddonSnapshot> adminPaddonRemoveWip({
    required String paddonCode,
    required String progressBatchId,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/items/remove',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'code': paddonCode.trim(),
          'progress_batch_id': progressBatchId.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_item_remove');
    }
    return AdminPaddonSnapshot.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
