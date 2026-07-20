part of '../mobile_api.dart';

extension MobileApiGScale on MobileApi {
  Future<List<SupplierItem>> gscaleItemsPage({
    String query = '',
    String group = '',
    int limit = 80,
    int offset = 0,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return TestModeDemoData.itemPage(
        query: query,
        group: group,
        limit: limit,
        offset: offset,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/gscale/items').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (group.trim().isNotEmpty) 'group': group.trim(),
            if (limit > 0) 'limit': '$limit',
            if (offset > 0) 'offset': '$offset',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: 'gscale_items_failed',
        message: 'GScale items failed',
        statusCode: response.statusCode,
      );
    }
    final json = await decodeJsonListPayload(response.body);
    final items = json
        .map((item) => SupplierItem.fromJson(item as Map<String, dynamic>))
        .toList();
    return SearchActivityStore.instance.sortByItemCode(
      items,
      itemCode: (item) => item.code,
      fallback: _compareSupplierItems,
    );
  }

  Future<GScaleRpsBatchResponse> gscaleRpsBatchStart(
    GScaleRpsBatchStartRequest request,
  ) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/rps/batch/start'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(request.toJson()),
      ),
    );
    final payload = _gscaleDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _gscaleText(payload['error'], fallback: 'rps_batch_start_failed'),
        message: _gscaleText(
          payload['detail'],
          fallback: _gscaleText(
            payload['message'],
            fallback: 'RPS batch start failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return GScaleRpsBatchResponse.fromJson(payload);
  }

  Future<GScaleRpsBatchResponse> gscaleRpsBatchState() async {
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/rps/batch/state'),
        headers: _headers(requireToken()),
      ),
    );
    final payload = _gscaleDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _gscaleText(payload['error'], fallback: 'rps_batch_state_failed'),
        message: _gscaleText(
          payload['detail'],
          fallback: _gscaleText(
            payload['message'],
            fallback: 'RPS batch state failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return GScaleRpsBatchResponse.fromJson(payload);
  }

  Future<List<GScaleRpsBatchSession>> gscaleRpsBatchHistory({
    int limit = 50,
  }) async {
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/rps/batch/history').replace(
          queryParameters: {'limit': '${limit.clamp(1, 100)}'},
        ),
        headers: _headers(requireToken()),
      ),
    );
    final payload = _gscaleDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code:
            _gscaleText(payload['error'], fallback: 'rps_batch_history_failed'),
        message: _gscaleText(
          payload['detail'],
          fallback: _gscaleText(
            payload['message'],
            fallback: 'RPS batch history failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return (payload['batches'] as List?)
            ?.whereType<Map>()
            .map(
              (batch) => GScaleRpsBatchSession.fromJson(
                batch.cast<String, dynamic>(),
              ),
            )
            .toList(growable: false) ??
        const [];
  }

  Future<GScaleRpsBatchResponse> gscaleRpsBatchStop() async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/rps/batch/stop'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: '{}',
      ),
    );
    final payload = _gscaleDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _gscaleText(payload['error'], fallback: 'rps_batch_stop_failed'),
        message: _gscaleText(
          payload['detail'],
          fallback: _gscaleText(
            payload['message'],
            fallback: 'RPS batch stop failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return GScaleRpsBatchResponse.fromJson(payload);
  }

  Future<GScaleMaterialReceiptPrintResponse> gscaleRpsBatchPrint(
    GScaleRpsBatchPrintRequest request,
  ) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/rps/batch/print'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(request.toJson()),
      ),
    );
    final payload = _gscaleDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _gscaleText(payload['error'], fallback: 'rps_batch_print_failed'),
        message: _gscaleText(
          payload['detail'],
          fallback: _gscaleText(
            payload['message'],
            fallback: 'RPS batch print failed',
          ),
        ),
        statusCode: response.statusCode,
      );
    }
    return GScaleMaterialReceiptPrintResponse.fromJson(payload);
  }

  Future<GScaleMaterialReceiptPrintResponse> gscaleRpsBatchClientPrintPrepare(
    GScaleRpsBatchPrintRequest request,
  ) async {
    return _gscaleRpsBatchClientPrintRequest(
      '/v1/mobile/rps/batch/client-print/prepare',
      request.toJson(),
      fallbackCode: 'rps_batch_client_print_prepare_failed',
    );
  }

  Future<GScaleMaterialReceiptPrintResponse> gscaleRpsBatchClientPrintConfirm(
    GScaleRpsBatchPrintRequest request, {
    required String epc,
  }) async {
    return _gscaleRpsBatchClientPrintRequest(
      '/v1/mobile/rps/batch/client-print/confirm',
      {...request.toJson(), 'epc': epc.trim()},
      fallbackCode: 'rps_batch_client_print_confirm_failed',
    );
  }

  Future<GScaleMaterialReceiptPrintResponse> _gscaleRpsBatchClientPrintRequest(
    String path,
    Map<String, dynamic> body, {
    required String fallbackCode,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}$path'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(body),
      ),
    );
    final payload = _gscaleDecodeObject(response.body);
    if (response.statusCode != 200) {
      throw MobileApiException(
        code: _gscaleText(payload['error'], fallback: fallbackCode),
        message: _gscaleText(
          payload['detail'],
          fallback: _gscaleText(payload['message'], fallback: fallbackCode),
        ),
        statusCode: response.statusCode,
      );
    }
    return GScaleMaterialReceiptPrintResponse.fromJson(payload);
  }
}

class GScaleRpsBatchStartRequest {
  const GScaleRpsBatchStartRequest({
    required this.clientBatchId,
    required this.driverUrl,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.printer,
    required this.printMode,
    required this.quantitySource,
    this.manualQtyKg = 0,
    this.tareEnabled = false,
    this.tareKg = 0,
  });

  final String clientBatchId;
  final String driverUrl;
  final String itemCode;
  final String itemName;
  final String warehouse;
  final String printer;
  final String printMode;
  final String quantitySource;
  final double manualQtyKg;
  final bool tareEnabled;
  final double tareKg;

  Map<String, dynamic> toJson() {
    return {
      'client_batch_id': clientBatchId.trim(),
      'driver_url': driverUrl.trim().trimRightSlash(),
      'item_code': itemCode.trim(),
      'item_name': itemName.trim(),
      'warehouse': warehouse.trim(),
      'printer': printer.trim(),
      'print_mode': printMode.trim(),
      'quantity_source': quantitySource.trim(),
      'manual_qty_kg': manualQtyKg,
      'tare_enabled': tareEnabled,
      'tare_kg': tareKg,
    };
  }
}

class GScaleRpsBatchPrintRequest {
  const GScaleRpsBatchPrintRequest({
    required this.grossQty,
    required this.driverUrl,
    this.unit = 'kg',
    this.printCount = 1,
  });

  final double grossQty;
  final String driverUrl;
  final String unit;
  final int printCount;

  Map<String, dynamic> toJson() {
    return {
      'gross_qty': grossQty,
      'unit': unit.trim().isEmpty ? 'kg' : unit.trim(),
      'driver_url': driverUrl.trim().trimRightSlash(),
      'print_count': printCount > 1 ? printCount : 1,
    };
  }
}

class GScaleRpsBatchResponse {
  const GScaleRpsBatchResponse({required this.ok, required this.batch});

  factory GScaleRpsBatchResponse.fromJson(Map<String, dynamic> json) {
    final batch = (json['batch'] as Map?)?.cast<String, dynamic>() ?? const {};
    return GScaleRpsBatchResponse(
      ok: json['ok'] == true,
      batch: GScaleRpsBatchSession.fromJson(batch),
    );
  }

  final bool ok;
  final GScaleRpsBatchSession batch;
}

class GScaleRpsBatchSession {
  const GScaleRpsBatchSession({
    required this.id,
    required this.active,
    required this.driverUrl,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.printer,
    required this.printMode,
    required this.quantitySource,
    required this.manualQtyKg,
    required this.tareEnabled,
    required this.tareKg,
    this.batchCode = '',
    this.lastError = '',
    this.lastErrorAt = '',
    this.createdAt = '',
    this.updatedAt = '',
    this.prints = const [],
  });

  factory GScaleRpsBatchSession.fromJson(Map<String, dynamic> json) {
    return GScaleRpsBatchSession(
      id: _gscaleText(json['id']),
      batchCode: _gscaleText(json['batch_code']),
      active: json['active'] == true,
      driverUrl: _gscaleText(json['driver_url']),
      itemCode: _gscaleText(json['item_code']),
      itemName: _gscaleText(json['item_name']),
      warehouse: _gscaleText(json['warehouse']),
      printer: _gscaleText(json['printer']),
      printMode: _gscaleText(json['print_mode']),
      quantitySource: _gscaleText(json['quantity_source'], fallback: 'scale'),
      manualQtyKg: _gscaleNumber(json['manual_qty_kg']),
      tareEnabled: json['tare_enabled'] == true || json['tare'] == true,
      tareKg: _gscaleNumber(json['tare_kg']),
      lastError: _gscaleText(json['last_error']),
      lastErrorAt: _gscaleText(json['last_error_at']),
      createdAt: _gscaleText(json['created_at']),
      updatedAt: _gscaleText(json['updated_at']),
      prints: (json['prints'] as List?)
              ?.whereType<Map>()
              .map(
                (entry) => GScaleRpsBatchPrintEntry.fromJson(
                  entry.cast<String, dynamic>(),
                ),
              )
              .toList(growable: false) ??
          const [],
    );
  }

  final String id;
  final String batchCode;
  final bool active;
  final String driverUrl;
  final String itemCode;
  final String itemName;
  final String warehouse;
  final String printer;
  final String printMode;
  final String quantitySource;
  final double manualQtyKg;
  final bool tareEnabled;
  final double tareKg;
  final String lastError;
  final String lastErrorAt;
  final String createdAt;
  final String updatedAt;
  final List<GScaleRpsBatchPrintEntry> prints;

  String get displayItemName => itemName.isEmpty ? itemCode : itemName;
}

class GScaleRpsBatchPrintEntry {
  const GScaleRpsBatchPrintEntry({
    required this.epc,
    required this.draftName,
    required this.status,
    required this.qty,
    required this.netQty,
    required this.grossQty,
    required this.unit,
    required this.printer,
    required this.printMode,
    required this.printCount,
    required this.printedAt,
  });

  factory GScaleRpsBatchPrintEntry.fromJson(Map<String, dynamic> json) {
    return GScaleRpsBatchPrintEntry(
      epc: _gscaleText(json['epc']),
      draftName: _gscaleText(json['draft_name']),
      status: _gscaleText(json['status']),
      qty: _gscaleNumber(json['qty']),
      netQty: _gscaleNumber(json['net_qty']),
      grossQty: _gscaleNumber(json['gross_qty']),
      unit: _gscaleText(json['unit'], fallback: 'kg'),
      printer: _gscaleText(json['printer']),
      printMode: _gscaleText(json['print_mode']),
      printCount: (json['print_count'] as num?)?.toInt() ?? 1,
      printedAt: _gscaleText(json['printed_at']),
    );
  }

  final String epc;
  final String draftName;
  final String status;
  final double qty;
  final double netQty;
  final double grossQty;
  final String unit;
  final String printer;
  final String printMode;
  final int printCount;
  final String printedAt;
}

class GScaleMaterialReceiptPrintResponse {
  const GScaleMaterialReceiptPrintResponse({
    required this.ok,
    required this.status,
    required this.draftName,
    required this.epc,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.qty,
    required this.netQty,
    required this.grossQty,
    required this.unit,
    required this.printer,
    required this.printMode,
    required this.printerStatus,
    required this.printCount,
  });

  factory GScaleMaterialReceiptPrintResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return GScaleMaterialReceiptPrintResponse(
      ok: json['ok'] == true,
      status: _gscaleText(json['status']),
      draftName: _gscaleText(json['draft_name']),
      epc: _gscaleText(json['epc']),
      itemCode: _gscaleText(json['item_code']),
      itemName: _gscaleText(json['item_name']),
      warehouse: _gscaleText(json['warehouse']),
      qty: _gscaleNumber(json['qty']),
      netQty: _gscaleNumber(json['net_qty']),
      grossQty: _gscaleNumber(json['gross_qty']),
      unit: _gscaleText(json['unit'], fallback: 'kg'),
      printer: _gscaleText(json['printer']),
      printMode: _gscaleText(json['print_mode']),
      printerStatus: _gscaleText(json['printer_status']),
      printCount: (json['print_count'] as num?)?.toInt() ?? 1,
    );
  }

  final bool ok;
  final String status;
  final String draftName;
  final String epc;
  final String itemCode;
  final String itemName;
  final String warehouse;
  final double qty;
  final double netQty;
  final double grossQty;
  final String unit;
  final String printer;
  final String printMode;
  final String printerStatus;
  final int printCount;

  UsbRpsPrintRequest toUsbPrintRequest({String labelKind = ''}) {
    final tareKg = (grossQty - netQty).clamp(0, double.infinity).toDouble();
    return UsbRpsPrintRequest(
      epc: epc,
      itemCode: itemCode,
      itemName: itemName,
      warehouse: warehouse,
      printer: 'godex',
      printMode: 'label',
      grossQty: grossQty,
      unit: unit,
      tareEnabled: tareKg > 0,
      tareKg: tareKg,
      printCount: printCount,
      labelKind: labelKind,
    );
  }
}

Map<String, dynamic> _gscaleDecodeObject(String body) {
  try {
    return (jsonDecode(body) as Map?)?.cast<String, dynamic>() ?? const {};
  } catch (_) {
    return const {};
  }
}

double _gscaleNumber(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _gscaleText(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

extension _GScaleStringTrim on String {
  String trimRightSlash() {
    return replaceFirst(RegExp(r'/+$'), '');
  }
}
