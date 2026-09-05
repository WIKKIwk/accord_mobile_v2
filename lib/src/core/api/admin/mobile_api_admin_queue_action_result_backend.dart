part of '../mobile_api.dart';

extension MobileApiAdminQueueActionResultBackend on MobileApi {
  Future<AdminApparatusQueueActionResult>
      _adminApparatusQueueActionResultBackend({
    required String apparatus,
    required String orderId,
    required String action,
    String materialBarcode = '',
    List<String> materialBarcodes = const [],
    String qolipCode = '',
    List<String> qolipCodes = const [],
    double? producedQty,
    double? grossQty,
    double? bobinaKg,
    double? diameter,
    double? returnInkKg,
    double? laminationPrintLeftoverRolls,
    double? laminationFilmLeftoverRolls,
    double? rezkaBosmaWaste,
    double? rezkaLaminationWaste,
    double? rezkaEdgeWaste,
    double? totalWaste,
    double? finishedGoodsKg,
    double? finishedGoodsMeter,
    List<Map<String, dynamic>> rezkaFrames = const [],
    int? rezkaRecordFrameIndex,
    String rezkaOutputCycle = '',
    String uom = '',
    String qrPayload = '',
    String progressBatchId = '',
    String customerName = '',
    String driverUrl = '',
    PrintTransport printTransport = PrintTransport.wifi,
    String printer = '',
    String printMode = '',
    String completionRequestNote = '',
    List<ReturnedPaintItemInput> returnedPaintItems = const [],
    String returnedPaintImageId = '',
    bool fullCompletionReportRequired = false,
    bool workerHandoff = false,
    bool removeRollFromApparatus = false,
    String freezeRequestId = '',
    bool freezeWithIssue = false,
    String issueNote = '',
    required String trimmedIssueNote,
  }) async {
    final trimmedBarcode = materialBarcode.trim();
    final trimmedQolipCode = qolipCode.trim();
    final trimmedQolipCodes = <String>[];
    for (final code in qolipCodes) {
      final trimmed = code.trim();
      if (trimmed.isEmpty ||
          trimmedQolipCodes.any(
            (existing) => existing.toLowerCase() == trimmed.toLowerCase(),
          )) {
        continue;
      }
      trimmedQolipCodes.add(trimmed);
    }
    final trimmedBarcodes = [
      for (final barcode in materialBarcodes)
        if (barcode.trim().isNotEmpty) barcode.trim(),
    ];
    final trimmedDriverUrl = driverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final trimmedCompletionRequestNote = completionRequestNote.trim();
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
            '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/queue-action'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': apparatus,
          'order_id': orderId,
          'action': action,
          if (freezeWithIssue) 'freeze_with_issue': true,
          if (freezeWithIssue) 'issue_note': trimmedIssueNote,
          if (freezeRequestId.trim().isNotEmpty)
            'freeze_request_id': freezeRequestId.trim(),
          if (trimmedBarcodes.isNotEmpty) 'material_barcodes': trimmedBarcodes,
          if (trimmedBarcodes.isEmpty && trimmedBarcode.isNotEmpty)
            'material_barcode': trimmedBarcode,
          if (trimmedQolipCodes.isNotEmpty) 'qolip_codes': trimmedQolipCodes,
          if (trimmedQolipCodes.isEmpty && trimmedQolipCode.isNotEmpty)
            'qolip_code': trimmedQolipCode,
          if (producedQty != null) 'produced_qty': producedQty,
          if (grossQty != null) 'gross_qty': grossQty,
          if (bobinaKg != null) 'bobina_kg': bobinaKg,
          if (diameter != null) 'diameter': diameter,
          if (returnInkKg != null) 'return_ink_kg': returnInkKg,
          if (laminationPrintLeftoverRolls != null)
            'lamination_print_leftover_rolls': laminationPrintLeftoverRolls,
          if (laminationFilmLeftoverRolls != null)
            'lamination_film_leftover_rolls': laminationFilmLeftoverRolls,
          if (rezkaBosmaWaste != null) 'rezka_bosma_waste': rezkaBosmaWaste,
          if (rezkaLaminationWaste != null)
            'rezka_lamination_waste': rezkaLaminationWaste,
          if (rezkaEdgeWaste != null) 'rezka_edge_waste': rezkaEdgeWaste,
          if (totalWaste != null) 'total_waste': totalWaste,
          if (finishedGoodsKg != null) 'finished_goods_kg': finishedGoodsKg,
          if (finishedGoodsMeter != null)
            'finished_goods_meter': finishedGoodsMeter,
          if (rezkaFrames.isNotEmpty) 'rezka_frames': rezkaFrames,
          if (rezkaRecordFrameIndex != null)
            'rezka_record_frame_index': rezkaRecordFrameIndex,
          if (rezkaOutputCycle.isNotEmpty)
            'rezka_output_cycle': rezkaOutputCycle,
          if (uom.trim().isNotEmpty) 'uom': uom.trim(),
          if (qrPayload.trim().isNotEmpty) 'qr_payload': qrPayload.trim(),
          if (progressBatchId.trim().isNotEmpty)
            'progress_batch_id': progressBatchId.trim(),
          if (customerName.trim().isNotEmpty)
            'customer_name': customerName.trim(),
          if (trimmedDriverUrl.isNotEmpty) 'driver_url': trimmedDriverUrl,
          if (printTransport.isLocal)
            'print_transport': printTransport.clientApiValue,
          if (printer.trim().isNotEmpty) 'printer': printer.trim(),
          if (printMode.trim().isNotEmpty) 'print_mode': printMode.trim(),
          if (trimmedCompletionRequestNote.isNotEmpty)
            'completion_request_note': trimmedCompletionRequestNote,
          if (fullCompletionReportRequired)
            'full_completion_report_required': true,
          if (workerHandoff) 'worker_handoff': true,
          if (removeRollFromApparatus) 'remove_roll_from_apparatus': true,
          if (returnedPaintItems.isNotEmpty)
            'returned_paint_items': returnedPaintItems
                .map((item) => item.toJson())
                .toList(growable: false),
          if (returnedPaintImageId.trim().isNotEmpty)
            'returned_paint_image_id': returnedPaintImageId.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'queue_action_not_allowed');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['states'];
    final rawOrderControl = payload['order_control'];
    final orderControl = rawOrderControl is Map
        ? AdminOrderControlState.fromRaw(rawOrderControl['state'])
        : null;
    final orderStatus = AdminProductionOrderStatusDetail.fromJson(
      payload['order_status'],
    );
    if (raw is! Map) {
      return AdminApparatusQueueActionResult(
        states: const {},
        orderStatus: orderStatus,
        orderControl: orderControl,
      );
    }
    final progressRaw = payload['progress_batch'];
    final progressBatches = <AdminProgressBatch>[
      if (payload['progress_batches'] is List)
        for (final item in payload['progress_batches'] as List)
          if (item is Map)
            AdminProgressBatch.fromJson(item.cast<String, dynamic>()),
    ];
    final requestRaw = payload['completion_request'];
    final printRaw = payload['print'];
    final parsedPrintJobs = <UsbRpsPrintRequest>[
      if (payload['prints'] is List)
        for (final item in payload['prints'] as List)
          if (item is Map && item['ok'] == true)
            UsbRpsPrintRequest.fromPrintJson(item.cast<String, dynamic>()),
    ];
    final trainingLocalPrintJobs = orderId.trim().startsWith('training-') &&
            printTransport.isLocal &&
            parsedPrintJobs.isEmpty
        ? _testModeProgressPrintJobs(
            batches: progressBatches,
            printer: printer,
            printMode: printMode,
            customerName: customerName,
          )
        : const <UsbRpsPrintRequest>[];
    final printJobs = <UsbRpsPrintRequest>[
      ...parsedPrintJobs,
      ...trainingLocalPrintJobs,
    ];
    final legacyProgressBatch = progressRaw is Map
        ? AdminProgressBatch.fromJson(progressRaw.cast<String, dynamic>())
        : (progressBatches.isEmpty ? null : progressBatches.first);
    final legacyPrintJob = printRaw is Map && printRaw['ok'] == true
        ? UsbRpsPrintRequest.fromPrintJson(printRaw.cast<String, dynamic>())
        : (printJobs.isEmpty ? null : printJobs.first);
    final parsedStates = <String, String>{
      for (final entry in raw.entries)
        entry.key.toString(): entry.value.toString(),
    };
    return AdminApparatusQueueActionResult(
      states: Map<String, String>.unmodifiable(parsedStates),
      orderStatus: orderStatus,
      orderControl: orderControl,
      progressBatch: legacyProgressBatch,
      progressBatches: progressBatches,
      rezkaOutputReport: payload['session'] is Map
          ? AdminRezkaOutputReport.fromSession(payload['session'] as Map)
          : null,
      completionRequest: requestRaw is Map
          ? AdminCompletionRequestNotification.fromJson(
              requestRaw.cast<String, dynamic>(),
            )
          : null,
      printJob: legacyPrintJob,
      printJobs: printJobs,
    );
  }
}
