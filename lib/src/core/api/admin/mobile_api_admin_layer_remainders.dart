part of '../mobile_api.dart';

/// A physical input roll included in the lamination Astatka report.
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

class AdminLaminationAstatkaSnapshot {
  const AdminLaminationAstatkaSnapshot({
    required this.sessionId,
    required this.sessionStatus,
    this.sources = const [],
    this.allowEmptySources = false,
    this.requestResult,
  });

  final String sessionId;
  final String sessionStatus;
  final List<AdminLayerRemainderSource> sources;
  final bool allowEmptySources;
  final AdminLaminationAstatkaResult? requestResult;
  bool get outputRequired => sessionStatus == 'active';

  factory AdminLaminationAstatkaSnapshot.fromJson(Map<String, dynamic> json) {
    final session = json['session'];
    final saved = json['request_result'];
    return AdminLaminationAstatkaSnapshot(
      sessionId: session is Map ? session['session_id']?.toString() ?? '' : '',
      sessionStatus: session is Map ? session['status']?.toString() ?? '' : '',
      allowEmptySources: json['allow_empty_sources'] == true,
      sources: [
        if (json['sources'] is List)
          for (final source in json['sources'] as List)
            AdminLayerRemainderSource.fromJson(
                (source as Map).cast<String, dynamic>()),
      ],
      requestResult: saved is Map
          ? AdminLaminationAstatkaResult.fromJson(saved.cast<String, dynamic>())
          : null,
    );
  }
}

class AdminLaminationAstatkaResult {
  const AdminLaminationAstatkaResult({
    this.action = 'pause',
    this.sessionStatus = '',
    this.remainders = const [],
    this.progressBatches = const [],
    this.prints = const [],
  });

  final String action;
  final String sessionStatus;
  final List<AdminLayerRemainder> remainders;
  final List<AdminProgressBatch> progressBatches;
  final List<Map<String, dynamic>> prints;

  factory AdminLaminationAstatkaResult.fromJson(Map<String, dynamic> json) {
    final action = json['action']?.toString() ?? 'pause';
    if (json['ok'] != true ||
        (action != 'pause' && action != 'complete') ||
        (action == 'pause' && json['report'] is! Map) ||
        (action == 'complete' &&
            (json['session'] is! Map ||
                (json['session'] as Map)['status'] != 'completed'))) {
      throw const MobileApiException(
        code: 'laminatsiya_astatka_invalid_response',
        message: 'Astatka qaydi javobi noto‘g‘ri',
      );
    }
    final session = json['session'];
    return AdminLaminationAstatkaResult(
      action: action,
      sessionStatus: session is Map ? session['status']?.toString() ?? '' : '',
      remainders: [
        if (json['remainders'] is List)
          for (final value in json['remainders'] as List)
            AdminLayerRemainder.fromJson(
                (value as Map).cast<String, dynamic>()),
      ],
      progressBatches: [
        if (json['progress_batches'] is List)
          for (final value in json['progress_batches'] as List)
            AdminProgressBatch.fromJson((value as Map).cast<String, dynamic>()),
      ],
      prints: [
        if (json['prints'] is List)
          for (final value in json['prints'] as List)
            (value as Map).cast<String, dynamic>(),
      ],
    );
  }
}

extension MobileApiAdminLayerRemainders on MobileApi {
  Future<AdminLaminationAstatkaSnapshot> adminLaminationAstatkaSnapshot({
    required String apparatus,
    required String orderId,
    String requestId = '',
  }) async {
    _validateLayerRemainderContext(apparatus, orderId);
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/laminatsiya-astatka')
              .replace(queryParameters: {
            'apparatus': apparatus.trim(),
            'order_id': orderId.trim(),
            if (requestId.trim().isNotEmpty) 'request_id': requestId.trim(),
          }),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
          response, 'laminatsiya_astatka_report_failed');
    }
    return AdminLaminationAstatkaSnapshot.fromJson(
        await decodeJsonMapPayload(response.body));
  }

  /// The caller persists this complete request before sending it. Retries must
  /// retain its request ID and quantities, including explicit zero dispositions.
  Future<AdminLaminationAstatkaResult> adminSubmitLaminationAstatka(
      Map<String, dynamic> request) async {
    _validateLayerRemainderContext(request['apparatus']?.toString() ?? '',
        request['order_id']?.toString() ?? '');
    if (request['request_id']?.toString().trim().isNotEmpty != true ||
        request['session_id']?.toString().trim().isNotEmpty != true ||
        request['layer_remainders'] is! List) {
      throw const MobileApiException(
          code: 'laminatsiya_astatka_metrics_required',
          message: 'Astatka hisobotini to‘liq kiriting');
    }
    final response = await _sendAuthorized(() => _post(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/laminatsiya-astatka'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode(request),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
          response, 'laminatsiya_astatka_report_failed');
    }
    return AdminLaminationAstatkaResult.fromJson(
        await decodeJsonMapPayload(response.body));
  }

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
