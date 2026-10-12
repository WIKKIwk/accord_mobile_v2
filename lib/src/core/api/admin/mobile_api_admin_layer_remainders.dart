part of '../mobile_api.dart';

/// A physical input roll, rather than the order-level astatka report.
class AdminLayerRemainderSource {
  const AdminLayerRemainderSource({
    required this.sourceKind,
    required this.sourceId,
    required this.sessionId,
    required this.revision,
    required this.qrPayload,
    required this.itemCode,
    required this.itemName,
    required this.sourceNetKg,
    required this.sourceMeter,
    this.tareKg = 0,
    this.producerName = '',
  });

  final String sourceKind;
  final String sourceId;
  final String sessionId;
  final int revision;
  final String qrPayload;
  final String itemCode;
  final String itemName;
  final double sourceNetKg;
  final double sourceMeter;
  final double tareKg;
  final String producerName;

  bool get canCalculate =>
      const {'progress_batch', 'raw_material'}.contains(sourceKind) &&
      sourceId.isNotEmpty &&
      sessionId.isNotEmpty &&
      revision > 0 &&
      sourceNetKg.isFinite &&
      sourceNetKg > 0 &&
      sourceMeter.isFinite &&
      sourceMeter > 0;

  double? estimateMeter(double remainingNetKg) {
    if (!canCalculate ||
        !remainingNetKg.isFinite ||
        remainingNetKg <= 0 ||
        remainingNetKg > sourceNetKg) {
      return null;
    }
    final result = sourceMeter * remainingNetKg / sourceNetKg;
    return result.isFinite ? result : null;
  }

  factory AdminLayerRemainderSource.fromJson(Map<String, dynamic> json) =>
      AdminLayerRemainderSource(
        sourceKind: json['source_kind']?.toString() ?? '',
        sourceId: json['source_id']?.toString() ?? '',
        sessionId: json['session_id']?.toString() ?? '',
        revision: (json['revision'] as num?)?.toInt() ?? 0,
        qrPayload: json['qr_payload']?.toString() ?? '',
        itemCode: json['item_code']?.toString() ?? '',
        itemName: json['item_name']?.toString() ?? '',
        sourceNetKg: (json['source_net_kg'] as num?)?.toDouble() ?? 0,
        sourceMeter: (json['source_meter'] as num?)?.toDouble() ?? 0,
        tareKg: (json['tare_kg'] as num?)?.toDouble() ?? 0,
        producerName: json['producer_name']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'source_kind': sourceKind,
        'source_id': sourceId,
        'session_id': sessionId,
        'revision': revision,
        'qr_payload': qrPayload,
        'item_code': itemCode,
        'item_name': itemName,
        'source_net_kg': sourceNetKg,
        'source_meter': sourceMeter,
        'tare_kg': tareKg,
        'producer_name': producerName,
      };
}

class AdminLayerRemainder {
  const AdminLayerRemainder({
    required this.operationId,
    required this.sourceKind,
    required this.sourceId,
    required this.qrPayload,
    required this.remainingNetKg,
    required this.remainingMeter,
    this.requestId = '',
    this.itemName = '',
    this.producerName = '',
    this.recordedByName = '',
  });

  final String operationId;
  final String sourceKind;
  final String sourceId;
  final String qrPayload;
  final double remainingNetKg;
  final double remainingMeter;
  final String requestId;
  final String itemName;
  final String producerName;
  final String recordedByName;

  factory AdminLayerRemainder.fromJson(Map<String, dynamic> json) {
    final actor = json['recorded_by'];
    return AdminLayerRemainder(
      operationId: json['operation_id']?.toString() ?? '',
      sourceKind: json['source_kind']?.toString() ?? '',
      sourceId: json['source_id']?.toString() ?? '',
      qrPayload: json['qr_payload']?.toString() ?? '',
      remainingNetKg: (json['remaining_net_kg'] as num?)?.toDouble() ?? 0,
      remainingMeter: (json['remaining_meter'] as num?)?.toDouble() ?? 0,
      requestId: json['request_id']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      producerName: json['producer_name']?.toString() ?? '',
      recordedByName: json['recorded_by_name']?.toString() ??
          (actor is Map ? actor['display_name']?.toString() : null) ??
          '',
    );
  }
}

class AdminLayerRemainderSnapshot {
  const AdminLayerRemainderSnapshot({
    this.sources = const [],
    this.remainders = const [],
  });

  final List<AdminLayerRemainderSource> sources;
  final List<AdminLayerRemainder> remainders;

  factory AdminLayerRemainderSnapshot.fromJson(Map<String, dynamic> json) =>
      AdminLayerRemainderSnapshot(
        sources: [
          if (json['sources'] is List)
            for (final value in json['sources'] as List)
              AdminLayerRemainderSource.fromJson(
                  (value as Map).cast<String, dynamic>()),
        ],
        remainders: [
          if (json['remainders'] is List)
            for (final value in json['remainders'] as List)
              AdminLayerRemainder.fromJson(
                  (value as Map).cast<String, dynamic>()),
        ],
      );
}

class AdminLayerRemainderResult {
  const AdminLayerRemainderResult({
    required this.remainder,
    required this.printOk,
    this.printJob,
    this.printStatus = '',
  });

  final AdminLayerRemainder remainder;
  final bool printOk;
  final UsbRpsPrintRequest? printJob;
  final String printStatus;

  factory AdminLayerRemainderResult.fromJson(Map<String, dynamic> json) {
    final remainder = json['remainder'];
    if (json['ok'] != true || remainder is! Map) {
      throw const MobileApiException(
        code: 'layer_remainder_invalid_response',
        message: 'Qavat astatkasi javobi noto‘g‘ri',
      );
    }
    final rawPrint = json['print'];
    final printMap = rawPrint is Map
        ? rawPrint.cast<String, dynamic>()
        : const <String, dynamic>{};
    return AdminLayerRemainderResult(
      remainder:
          AdminLayerRemainder.fromJson(remainder.cast<String, dynamic>()),
      printOk: printMap['ok'] == true,
      printJob: printMap['ok'] == true
          ? UsbRpsPrintRequest.fromPrintJson(printMap)
          : null,
      printStatus: printMap['status']?.toString() ?? '',
    );
  }
}

extension MobileApiAdminLayerRemainders on MobileApi {
  Future<AdminLayerRemainderSnapshot> adminLayerRemainders({
    required String apparatus,
    required String orderId,
  }) async {
    _validateLayerRemainderContext(apparatus, orderId);
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/layer-remainders')
              .replace(queryParameters: {
            'apparatus': apparatus.trim(),
            'order_id': orderId.trim(),
          }),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'layer_remainder_failed');
    }
    return AdminLayerRemainderSnapshot.fromJson(
        await decodeJsonMapPayload(response.body));
  }

  Future<AdminLayerRemainderResult> adminRecordLayerRemainder({
    required String apparatus,
    required String orderId,
    required AdminLayerRemainderSource source,
    required double remainingNetKg,
    required String requestId,
    String driverUrl = '',
    String printer = '',
    String printMode = '',
    PrintTransport printTransport = PrintTransport.wifi,
  }) async {
    _validateLayerRemainderContext(apparatus, orderId);
    if (source.estimateMeter(remainingNetKg) == null ||
        requestId.trim().isEmpty) {
      throw const MobileApiException(
        code: 'layer_remainder_metrics_invalid',
        message: 'Qoldiqning sof og‘irligini to‘g‘ri kiriting',
      );
    }
    return _layerRemainderPost('', {
      'apparatus': apparatus.trim(),
      'order_id': orderId.trim(),
      'source_kind': source.sourceKind,
      'source_id': source.sourceId,
      'session_id': source.sessionId,
      'expected_revision': source.revision,
      'remaining_net_kg': remainingNetKg,
      'request_id': requestId.trim(),
      ..._layerRemainderPrinterFields(
          driverUrl, printer, printMode, printTransport),
    });
  }

  Future<AdminLayerRemainderResult> adminLayerRemainderReprint({
    required String apparatus,
    required String orderId,
    required String operationId,
    String driverUrl = '',
    String printer = '',
    String printMode = '',
    PrintTransport printTransport = PrintTransport.wifi,
  }) async {
    _validateLayerRemainderContext(apparatus, orderId);
    if (operationId.trim().isEmpty) {
      throw const MobileApiException(
          code: 'layer_remainder_not_found',
          message: 'Qavat astatkasi topilmadi');
    }
    return _layerRemainderPost('/reprint', {
      'apparatus': apparatus.trim(),
      'order_id': orderId.trim(),
      'operation_id': operationId.trim(),
      ..._layerRemainderPrinterFields(
          driverUrl, printer, printMode, printTransport),
    });
  }

  Future<AdminLayerRemainderResult> _layerRemainderPost(
      String suffix, Map<String, dynamic> body) async {
    final response = await _sendAuthorized(() => _post(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/layer-remainders$suffix'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode(body),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'layer_remainder_failed');
    }
    return AdminLayerRemainderResult.fromJson(
        await decodeJsonMapPayload(response.body));
  }
}

void _validateLayerRemainderContext(String apparatus, String orderId) {
  if (!isCanonicalApparatusId(apparatus.trim()) || orderId.trim().isEmpty) {
    throw const MobileApiException(
        code: 'layer_remainder_context_invalid',
        message: 'Buyurtma yoki aparat noto‘g‘ri');
  }
}

Map<String, dynamic> _layerRemainderPrinterFields(String driverUrl,
        String printer, String printMode, PrintTransport transport) =>
    {
      if (driverUrl.trim().isNotEmpty) 'driver_url': driverUrl.trim(),
      if (printer.trim().isNotEmpty) 'printer': printer.trim(),
      if (printMode.trim().isNotEmpty) 'print_mode': printMode.trim(),
      if (transport.isLocal) 'print_transport': transport.clientApiValue,
      'print_count': 1,
    };
