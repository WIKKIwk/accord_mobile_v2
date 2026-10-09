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
    this.totalGrossKg,
    this.totalNetKg,
    this.lockedAtUnix,
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
  final double? totalGrossKg;
  final double? totalNetKg;
  final int? lockedAtUnix;
  bool get isLocked => lockedAtUnix != null;

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
      totalGrossKg: _paddonWeight(json['total_gross_kg']),
      totalNetKg: _paddonWeight(json['total_net_kg']),
      lockedAtUnix: (json['locked_at_unix'] as num?)?.toInt(),
    );
  }
}

double? _paddonWeight(Object? value) {
  final weight = value is num
      ? value.toDouble()
      : value is String
          ? double.tryParse(value)
          : null;
  return weight != null && weight.isFinite && weight >= 0 ? weight : null;
}

class AdminPaddonSnapshot {
  const AdminPaddonSnapshot({
    required this.paddon,
    required this.items,
    this.availableItems = const [],
    this.freeMovementEnabled = false,
    bool? canManageItems,
  }) : _canManageItems = canManageItems;

  final AdminPaddon paddon;
  final List<AdminProgressBatch> items;
  final List<AdminProgressBatch> availableItems;
  final bool freeMovementEnabled;
  final bool? _canManageItems;
  bool get canManageItems => _canManageItems ?? !paddon.isLocked;

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
      freeMovementEnabled: json['free_movement_enabled'] == true,
      canManageItems: json['can_manage_items'] as bool?,
    );
  }
}

class AdminPaddonQrPrintResult {
  const AdminPaddonQrPrintResult({
    required this.ok,
    required this.paddon,
    required this.qrPayload,
    this.printJob,
    this.printStatus = '',
    this.canCloseAfterPrint = false,
  });

  final bool ok;
  final AdminPaddon paddon;
  final String qrPayload;
  final UsbRpsPrintRequest? printJob;
  final String printStatus;
  final bool canCloseAfterPrint;
}

class PaddonPrintConfirmation {
  const PaddonPrintConfirmation(
      {required this.paddon,
      required this.newlyLocked,
      required this.apparatusOptions,
      this.apparatus});
  final AdminPaddon paddon;
  final bool newlyLocked;
  final String? apparatus;
  final Map<String, String> apparatusOptions;
}

extension MobileApiPaddons on MobileApi {
  Future<bool> paddonFreeMovementEnabled() async {
    final response = await _sendAuthorized(() => _get(
      Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/management-settings'),
      headers: _headers(requireToken()),
    ));
    return _paddonManagementResponse(response);
  }

  Future<bool> setPaddonFreeMovementEnabled(bool enabled) async {
    final response = await _sendAuthorized(() => _put(
      Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/management-settings'),
      headers: _headers(requireToken())..['Content-Type'] = 'application/json',
      body: jsonEncode({'free_movement_enabled': enabled}),
    ));
    return _paddonManagementResponse(response);
  }

  bool _paddonManagementResponse(http.Response response) {
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_management_settings');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map || payload['ok'] != true ||
        payload['settings'] is! Map ||
        payload['settings']['free_movement_enabled'] is! bool) {
      throw const MobileApiException(code: 'paddon_management_settings', message: 'Paddon sozlamalari tasdiqlanmadi');
    }
    return payload['settings']['free_movement_enabled'] as bool;
  }

  Future<PaddonPrintConfirmation> confirmPaddonPrint(String code) async {
    final response = await _sendAuthorized(() => _post(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/qr/confirm'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({'code': code.trim()}),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_print_confirm');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final paddon = AdminPaddon.fromJson(
        (payload['paddon'] as Map).cast<String, dynamic>());
    if (payload['ok'] != true ||
        paddon.code != code.trim() ||
        !paddon.isLocked) {
      throw const MobileApiException(
          code: 'paddon_print_confirm', message: 'Paddon qulfi tasdiqlanmadi');
    }
    return PaddonPrintConfirmation(
      paddon: paddon,
      newlyLocked: payload['newly_locked'] == true,
      apparatus: payload['apparatus'] as String?,
      apparatusOptions: {
        if (payload['apparatus_options'] case final List options)
          for (final option in options)
            if (option is Map &&
                option['id'] is String &&
                option['name'] is String)
              option['id'] as String: option['name'] as String,
      },
    );
  }

  Future<AdminPaddon> createActivePaddonSuccessor(
      {required String code, required String apparatus}) async {
    final response = await _sendAuthorized(() => _post(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/active/next'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body:
              jsonEncode({'code': code.trim(), 'apparatus': apparatus.trim()}),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_create');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final paddon = AdminPaddon.fromJson(
        (payload['paddon'] as Map).cast<String, dynamic>());
    if (payload['ok'] != true ||
        payload['apparatus'] != apparatus.trim() ||
        payload['code'] != paddon.code ||
        paddon.code.isEmpty ||
        paddon.isLocked) {
      throw const MobileApiException(
          code: 'paddon_create', message: 'Yangi paddon tasdiqlanmadi');
    }
    return paddon;
  }

  Future<String?> activeRezkaPaddon(String apparatus) async {
    final response = await _sendAuthorized(() => _get(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/active')
              .replace(queryParameters: {'apparatus': apparatus.trim()}),
          headers: _headers(requireToken()),
        ));
    return _activePaddonResponse(response, apparatus);
  }

  Future<String?> setActiveRezkaPaddon(String apparatus, String? code) async {
    final response = await _sendAuthorized(() => _put(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/active'),
          headers: _headers(requireToken())..['Content-Type'] = 'application/json',
          body: jsonEncode({'apparatus': apparatus.trim(), 'code': code?.trim() ?? ''}),
        ));
    return _activePaddonResponse(response, apparatus);
  }

  String? _activePaddonResponse(http.Response response, String apparatus) {
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'active_paddon');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map || payload['ok'] != true ||
        payload['apparatus'] != apparatus.trim() || !payload.containsKey('code') ||
        (payload['code'] != null &&
            (payload['code'] is! String || (payload['code'] as String).trim().isEmpty))) {
      throw const MobileApiException(code: 'active_paddon_invalid_response',
          message: 'Faol paddon ma’lumoti yuklanmadi. Qayta urinib ko‘ring.');
    }
    return payload['code'] as String?;
  }

  Future<List<AdminPaddon>> adminPaddons(
      {int limit = 100, bool selectableOnly = false}) async {
    final boundedLimit = limit.clamp(1, 200).toInt();
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons',
        ).replace(
          queryParameters: {
            'limit': boundedLimit.toString(),
            if (selectableOnly) 'selectable_only': 'true'
          },
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

  Future<AdminPaddonSnapshot> adminPaddonQrReport(String code) async {
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
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/qr/report',
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

  Future<AdminPaddonQrPrintResult> adminPaddonPrintQr({
    required String code,
    String driverUrl = '',
    String printer = '',
    String printMode = '',
    int printCount = 1,
    PrintTransport printTransport = PrintTransport.wifi,
  }) async {
    final normalizedCode = code.trim();
    if (normalizedCode.isEmpty) {
      throw const MobileApiException(
        code: 'paddon_not_found',
        message: 'Paddon topilmadi',
      );
    }
    final boundedPrintCount = printCount.clamp(1, 100).toInt();
    final normalizedDriverUrl =
        driverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final normalizedPrinter = printer.trim();
    final normalizedPrintMode = printMode.trim();
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/qr/print',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'code': normalizedCode,
          if (normalizedDriverUrl.isNotEmpty) 'driver_url': normalizedDriverUrl,
          if (printTransport.isLocal)
            'print_transport': printTransport.clientApiValue,
          if (normalizedPrinter.isNotEmpty) 'printer': normalizedPrinter,
          if (normalizedPrintMode.isNotEmpty) 'print_mode': normalizedPrintMode,
          'print_count': boundedPrintCount,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_qr_print');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawPaddon = payload['paddon'];
    if (rawPaddon is! Map) {
      throw const MobileApiException(
        code: 'paddon_not_found',
        message: 'Paddon topilmadi',
      );
    }
    final rawPrint = payload['print'];
    final printMap = rawPrint is Map
        ? rawPrint.cast<String, dynamic>()
        : const <String, dynamic>{};
    return AdminPaddonQrPrintResult(
      ok: payload['ok'] == true,
      paddon: AdminPaddon.fromJson(rawPaddon.cast<String, dynamic>()),
      qrPayload: payload['qr_payload']?.toString() ?? normalizedCode,
      printJob: printMap.isEmpty
          ? null
          : UsbRpsPrintRequest.fromPrintJson(
              printMap,
              paddonLabelLines: printTransport.isBluetooth
                  ? _paddonBluetoothLabelLines(
                      rawPaddon.cast<String, dynamic>(), payload['items'])
                  : const [],
            ),
      printStatus: printMap['status']?.toString() ?? '',
      canCloseAfterPrint: payload['can_close_after_print'] == true,
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

  Future<void> adminPaddonDelete(String code) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/delete',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'code': code.trim()}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_delete');
    }
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

  Future<AdminPaddonSnapshot> adminPaddonAddWips({
    required String paddonCode,
    required List<String> progressBatchIds,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/items/add-batch',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'code': paddonCode.trim(),
          'progress_batch_ids': progressBatchIds
              .map((batchId) => batchId.trim())
              .where((batchId) => batchId.isNotEmpty)
              .toList(growable: false),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_items_add');
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

  Future<AdminPaddonSnapshot> adminPaddonRemoveWips({
    required String paddonCode,
    required List<String> progressBatchIds,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/paddons/items/remove-batch',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'code': paddonCode.trim(),
          'progress_batch_ids': progressBatchIds
              .map((batchId) => batchId.trim())
              .where((batchId) => batchId.isNotEmpty)
              .toList(growable: false),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'paddon_items_remove');
    }
    return AdminPaddonSnapshot.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

List<String> _paddonBluetoothLabelLines(
  Map<String, dynamic> paddon,
  Object? rawItems,
) {
  // Use the same authoritative summary that prepared this label, including
  // frozen receipt totals. Never infer kilograms from WIP lengths/quantities.
  final rawCount = paddon['item_count'];
  final count =
      rawCount is num &&
          rawCount.isFinite &&
          rawCount >= 0 &&
          rawCount == rawCount.toInt()
      ? rawCount.toInt().toString()
      : '—';
  String weight(Object? raw) {
    final kg = _paddonWeight(raw);
    return kg == null
        ? '—'
        : kg.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  final items = rawItems is List && rawItems.every((item) => item is Map)
      ? rawItems
            .cast<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList()
      : null;
  // Require the full print snapshot, never the page's filtered WIP list.
  final complete = items != null && items.length.toString() == count;
  var bobinaCount = count == '0' ? '0' : '—';
  (String, String)? product;
  if (complete) {
    final weights = <int>{};
    var knownWeights = true;
    var sameProduct = items.isNotEmpty;
    String identity(String value) =>
        value.trim().replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
    for (final item in items) {
      final kg = _paddonWeight(item['bobina_kg'] ?? item['babina_kg']);
      final units = kg != null && kg > 0 ? (kg * 1000000).round() : 0;
      if (units > 0) {
        weights.add(units);
      } else {
        knownWeights = false;
      }
      final payload = item['payload_json'];
      final customer = payload is Map
          ? payload['customer_name']?.toString().trim() ?? ''
          : '';
      var name = payload is Map
          ? payload['order_title']?.toString().trim() ?? ''
          : '';
      if (name.isEmpty) {
        // Remove the production-stage suffix using the same markers as WIP.
        name = (item['label_item_name']?.toString() ?? '')
            .split(
              RegExp(
                r'\s+(?:yarim tayyor(?: mahsulot)?|tayyor mahsulot)|,\s*apparat:',
                caseSensitive: false,
              ),
            )
            .first
            .trim();
      }
      final candidate = (customer, name);
      if (name.isEmpty ||
          (product != null &&
              (identity(product.$1) != identity(customer) ||
                  identity(product.$2) != identity(name)))) {
        sameProduct = false;
      }
      product ??= candidate;
    }
    if (knownWeights) bobinaCount = weights.length.toString();
    if (!sameProduct) product = null;
  }
  return [
    if (product != null) ...[
      'Mijoz: ${product.$1.isEmpty ? '—' : product.$1}',
      'Mahsulot nomi: ${product.$2}',
    ],
    'Paddon ${paddon['code']?.toString().trim() ?? ''}',
    'Mahsulot soni: $count',
    'Turli babinalar soni: $bobinaCount',
    'Brutto: ${weight(paddon['total_gross_kg'])} kg',
    'Netto: ${weight(paddon['total_net_kg'])} kg',
  ];
}
