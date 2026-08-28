part of '../mobile_api.dart';

class AdminQolipOrderNote {
  const AdminQolipOrderNote({
    required this.orderId,
    required this.itemCode,
    required this.itemName,
    required this.qolipCodes,
    required this.status,
    this.updatedAt = '',
  });

  final String orderId;
  final String itemCode;
  final String itemName;
  final List<String> qolipCodes;
  final String status;
  final String updatedAt;

  bool get isGiven => status.trim().toLowerCase() == 'given';
  bool get isReturned => status.trim().toLowerCase() == 'returned';

  factory AdminQolipOrderNote.fromJson(Map<String, dynamic> json) {
    return AdminQolipOrderNote(
      orderId: json['order_id']?.toString().trim() ?? '',
      itemCode: json['item_code']?.toString().trim() ?? '',
      itemName: json['item_name']?.toString().trim() ?? '',
      qolipCodes: (json['qolip_codes'] as List? ?? const [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false),
      status: json['status']?.toString().trim() ?? '',
      updatedAt: json['updated_at']?.toString().trim() ?? '',
    );
  }
}

class AdminQolipOrderNoteDetails {
  const AdminQolipOrderNoteDetails({
    required this.orderId,
    required this.itemCode,
    required this.itemName,
    required this.requiredQolips,
    this.note,
  });

  final String orderId;
  final String itemCode;
  final String itemName;
  final List<AdminProductionMapRequiredQolip> requiredQolips;
  final AdminQolipOrderNote? note;

  factory AdminQolipOrderNoteDetails.fromJson(Map<String, dynamic> json) {
    return AdminQolipOrderNoteDetails(
      orderId: json['order_id']?.toString().trim() ?? '',
      itemCode: json['item_code']?.toString().trim() ?? '',
      itemName: json['item_name']?.toString().trim() ?? '',
      requiredQolips: [
        for (final item in json['required_qolips'] as List? ?? const [])
          if (item is Map)
            AdminProductionMapRequiredQolip.fromJson(
              item.cast<String, dynamic>(),
            ),
      ],
      note: json['note'] is Map
          ? AdminQolipOrderNote.fromJson(
              (json['note'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

enum AdminQueueQolipMode {
  notRequired,
  scanRequired;

  static AdminQueueQolipMode? tryParse(Object? raw) {
    return switch (raw?.toString().trim()) {
      'not_required' => AdminQueueQolipMode.notRequired,
      'scan_required' => AdminQueueQolipMode.scanRequired,
      _ => null,
    };
  }
}

Map<String, AdminQolipOrderNote> _parseAdminQolipOrderNotes(Object? raw) {
  if (raw is! List) {
    return const {};
  }
  final notes = <String, AdminQolipOrderNote>{};
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final note = AdminQolipOrderNote.fromJson(item.cast<String, dynamic>());
    if (note.orderId.isNotEmpty) {
      notes[note.orderId] = note;
    }
  }
  return notes;
}

class AdminProductionMapRequiredQolip {
  const AdminProductionMapRequiredQolip({
    required this.qolipCode,
    required this.color,
    this.isInUse = false,
  });

  final String qolipCode;
  final String color;
  final bool isInUse;

  factory AdminProductionMapRequiredQolip.fromJson(Map<String, dynamic> json) {
    return AdminProductionMapRequiredQolip(
      qolipCode: json['qolip_code']?.toString().trim() ?? '',
      color: json['color']?.toString().trim() ?? '',
      isInUse: json['in_use'] == true,
    );
  }
}

class AdminProductionMapQolipValidation {
  const AdminProductionMapQolipValidation({
    required this.qolipCode,
    this.requiredQolips = const [],
  });

  final String qolipCode;
  final List<AdminProductionMapRequiredQolip> requiredQolips;

  List<String> get requiredQolipCodes => [
        for (final qolip in requiredQolips) qolip.qolipCode,
      ];

  factory AdminProductionMapQolipValidation.fromJson(
    Map<String, dynamic> json,
  ) {
    final requiredQolips = <AdminProductionMapRequiredQolip>[];
    for (final rawQolip in json['required_qolips'] as List? ?? const []) {
      if (rawQolip is! Map) {
        continue;
      }
      final qolip = AdminProductionMapRequiredQolip.fromJson(
        rawQolip.cast<String, dynamic>(),
      );
      if (qolip.qolipCode.isNotEmpty) {
        requiredQolips.add(qolip);
      }
    }
    return AdminProductionMapQolipValidation(
      qolipCode: json['qolip_code']?.toString().trim() ?? '',
      requiredQolips: requiredQolips,
    );
  }
}

extension MobileApiAdminQolipOrders on MobileApi {
Future<String> adminValidateProductionMapQolip({
    required String apparatus,
    required String orderId,
    required String qolipCode,
  }) async {
    final validation = await adminValidateProductionMapQolipDetails(
      apparatus: apparatus,
      orderId: orderId,
      qolipCode: qolipCode,
    );
    return validation.qolipCode;
  }

Future<AdminProductionMapQolipValidation>
      adminProductionMapQolipRequirements({
    required String apparatus,
    required String orderId,
  }) {
    return adminValidateProductionMapQolipDetails(
      apparatus: apparatus,
      orderId: orderId,
      qolipCode: '',
    );
  }

Future<AdminProductionMapQolipValidation>
      adminValidateProductionMapQolipDetails({
    required String apparatus,
    required String orderId,
    required String qolipCode,
  }) async {
    final normalizedApparatus = _requireCanonicalApparatusId(apparatus);
    if (await TestModeController.instance.isEnabled()) {
      if (qolipCode.trim().isEmpty) {
        ProductionMapSaved? order;
        for (final candidate in _testModeProductionMaps) {
          if (candidate.map.id.trim() == orderId.trim()) {
            order = candidate;
            break;
          }
        }
        final itemCode = order?.map.productCode.trim() ?? '';
        final products = itemCode.isEmpty
            ? const <QolipProduct>[]
            : await qolipProducts(
                query: itemCode,
                limit: 20000,
                withQolipOnly: true,
              );
        return AdminProductionMapQolipValidation(
          qolipCode: '',
          requiredQolips: [
            for (final product in products)
              if (product.code.trim().toLowerCase() == itemCode.toLowerCase() &&
                  product.qolipCode.trim().isNotEmpty)
                AdminProductionMapRequiredQolip(
                  qolipCode: product.qolipCode.trim(),
                  color: product.qolipColor.trim(),
                ),
          ],
        );
      }
      final product = await qolipProductByQr(qolipCode);
      final products = await qolipProducts(
        query: product.code,
        limit: 20000,
        withQolipOnly: true,
      );
      return AdminProductionMapQolipValidation(
        qolipCode: product.qolipCode.trim().isEmpty
            ? qolipCode.trim()
            : product.qolipCode.trim(),
        requiredQolips: [
          for (final candidate in products)
            if (candidate.code.trim().toLowerCase() ==
                    product.code.trim().toLowerCase() &&
                candidate.qolipCode.trim().isNotEmpty)
              AdminProductionMapRequiredQolip(
                qolipCode: candidate.qolipCode.trim(),
                color: candidate.qolipColor.trim(),
              ),
        ],
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/qolip-validate'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalizedApparatus,
          'order_id': orderId.trim(),
          'qolip_code': qolipCode.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'qolip_code_not_found');
    }
    final payload = await decodeJsonMapPayload(response.body);
    final rawQolip = payload['qolip'];
    if (rawQolip is Map) {
      return AdminProductionMapQolipValidation.fromJson(
        rawQolip.cast<String, dynamic>(),
      );
    }
    return AdminProductionMapQolipValidation(qolipCode: qolipCode.trim());
  }

Future<AdminQolipOrderNoteDetails> adminProductionMapQolipOrderNoteDetails({
    required String orderId,
  }) async {
    final normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      throw const MobileApiException(
        code: 'order_id_required',
        message: 'Order identifikatori topilmadi',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      ProductionMapSaved? order;
      for (final candidate in _testModeProductionMaps) {
        if (candidate.map.id.trim() == normalizedOrderId) {
          order = candidate;
          break;
        }
      }
      if (order == null) {
        throw const MobileApiException(
          code: 'map_not_found',
          message: 'Order topilmadi',
        );
      }
      final itemCode = order.map.productCode.trim();
      final products = itemCode.isEmpty
          ? const <QolipProduct>[]
          : await qolipProducts(
              query: itemCode,
              limit: 20000,
              withQolipOnly: true,
            );
      final requiredQolips = <AdminProductionMapRequiredQolip>[];
      final seen = <String>{};
      final inUseCodes = <String>{};
      for (final entry in _testModeQolipOrderNotes.entries) {
        if (entry.key == normalizedOrderId || !entry.value.isGiven) {
          continue;
        }
        inUseCodes.addAll(
          entry.value.qolipCodes.map((code) => code.trim().toLowerCase()),
        );
      }
      for (final product in products) {
        final code = product.qolipCode.trim();
        if (product.code.trim().toLowerCase() != itemCode.toLowerCase() ||
            code.isEmpty ||
            !seen.add(code.toLowerCase())) {
          continue;
        }
        requiredQolips.add(
          AdminProductionMapRequiredQolip(
            qolipCode: code,
            color: product.qolipColor.trim(),
            isInUse: inUseCodes.contains(code.toLowerCase()),
          ),
        );
      }
      return AdminQolipOrderNoteDetails(
        orderId: normalizedOrderId,
        itemCode: itemCode,
        itemName: order.map.title.trim(),
        requiredQolips: requiredQolips,
        note: _testModeQolipOrderNotes[normalizedOrderId],
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/qolip-order-notes',
        ).replace(queryParameters: {'order_id': normalizedOrderId}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'qolip_order_note_load_failed',
      );
    }
    return AdminQolipOrderNoteDetails.fromJson(
      await decodeJsonMapPayload(response.body),
    );
  }

Future<List<AdminQolipOrderNote>> adminProductionMapQolipOrderNotes() async {
    if (await TestModeController.instance.isEnabled()) {
      return _testModeQolipOrderNotes.values.toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/qolip-order-notes'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'qolip_order_notes_load_failed',
      );
    }
    final payload = await decodeJsonMapPayload(response.body);
    final rawNotes = payload['notes'];
    return [
      if (rawNotes is List)
        for (final item in rawNotes)
          if (item is Map)
            AdminQolipOrderNote.fromJson(item.cast<String, dynamic>()),
    ];
  }

Future<AdminQolipOrderNote> adminSaveProductionMapQolipOrderNote({
    required String orderId,
    required String status,
    List<String> qolipCodes = const [],
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedStatus = status.trim().toLowerCase();
    if (await TestModeController.instance.isEnabled()) {
      final details = await adminProductionMapQolipOrderNoteDetails(
        orderId: normalizedOrderId,
      );
      if (normalizedStatus == 'returned') {
        final existing = details.note;
        if (existing == null) {
          throw const MobileApiException(
            code: 'qolip_order_note_not_found',
            message: 'Bu order uchun berilgan qolip qaydi topilmadi',
          );
        }
        final returned = AdminQolipOrderNote(
          orderId: existing.orderId,
          itemCode: existing.itemCode,
          itemName: existing.itemName,
          qolipCodes: existing.qolipCodes,
          status: 'returned',
        );
        _testModeQolipOrderNotes[normalizedOrderId] = returned;
        return returned;
      }
      if (normalizedStatus != 'given') {
        throw const MobileApiException(
          code: 'qolip_order_note_status_invalid',
          message: 'Qolip qaydi holati noto‘g‘ri',
        );
      }
      final requiredCodes = details.requiredQolips
          .map((item) => item.qolipCode.trim().toLowerCase())
          .where((item) => item.isNotEmpty)
          .toSet();
      final selectedCodes = <String>[];
      for (final rawCode in qolipCodes) {
        final code = rawCode.trim();
        if (code.isEmpty) continue;
        if (!requiredCodes.contains(code.toLowerCase())) {
          throw const MobileApiException(
            code: 'qolip_code_mismatch',
            message: 'Tanlangan qolip bu order mahsulotiga tegishli emas',
          );
        }
        if (!selectedCodes.any(
          (saved) => saved.toLowerCase() == code.toLowerCase(),
        )) {
          selectedCodes.add(code);
        }
      }
      if (selectedCodes.isEmpty) {
        throw const MobileApiException(
          code: 'qolip_code_required',
          message: 'Kamida bitta qolipni tanlang',
        );
      }
      for (final entry in _testModeQolipOrderNotes.entries) {
        if (entry.key == normalizedOrderId || !entry.value.isGiven) {
          continue;
        }
        final occupied = entry.value.qolipCodes.any(
          (saved) => selectedCodes.any(
            (selected) => saved.trim().toLowerCase() == selected.toLowerCase(),
          ),
        );
        if (occupied) {
          throw const MobileApiException(
            code: 'qolip_order_note_in_use',
            message: 'Bu qolip boshqa order uchun band qilingan',
          );
        }
      }
      final note = AdminQolipOrderNote(
        orderId: details.orderId,
        itemCode: details.itemCode,
        itemName: details.itemName,
        qolipCodes: selectedCodes,
        status: 'given',
      );
      _testModeQolipOrderNotes[normalizedOrderId] = note;
      return note;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/qolip-order-notes'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'order_id': normalizedOrderId,
          'status': normalizedStatus,
          'qolip_codes': qolipCodes
              .map((code) => code.trim())
              .where((code) => code.isNotEmpty)
              .toList(growable: false),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'qolip_order_note_save_failed',
      );
    }
    final payload = await decodeJsonMapPayload(response.body);
    final rawNote = payload['note'];
    if (rawNote is! Map) {
      throw const MobileApiException(
        code: 'qolip_order_note_invalid_response',
        message: 'Qolip qaydi javobi noto‘g‘ri',
      );
    }
    return AdminQolipOrderNote.fromJson(rawNote.cast<String, dynamic>());
  }
}
