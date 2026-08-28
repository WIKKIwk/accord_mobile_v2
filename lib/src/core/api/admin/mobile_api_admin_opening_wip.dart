part of '../mobile_api.dart';

enum AdminOpeningWipQuantityBasis {
  measured('measured'),
  estimated('estimated'),
  unknown('unknown');

  const AdminOpeningWipQuantityBasis(this.apiValue);

  final String apiValue;

  static AdminOpeningWipQuantityBasis fromRaw(Object? raw) {
    return switch (raw?.toString().trim().toLowerCase()) {
      'measured' => AdminOpeningWipQuantityBasis.measured,
      'estimated' => AdminOpeningWipQuantityBasis.estimated,
      _ => AdminOpeningWipQuantityBasis.unknown,
    };
  }
}

class AdminOpeningWipBatchInput {
  const AdminOpeningWipBatchInput({
    required this.quantityBasis,
    required this.finishedGoodsMeter,
    required this.finishedGoodsKg,
    required this.bobinaKg,
    this.diameter,
  });

  final AdminOpeningWipQuantityBasis quantityBasis;
  final double finishedGoodsMeter;
  final double finishedGoodsKg;
  final double bobinaKg;
  final double? diameter;

  Map<String, dynamic> toJson() => {
        'quantity_basis': quantityBasis.apiValue,
        'finished_goods_meter': finishedGoodsMeter,
        'finished_goods_kg': finishedGoodsKg,
        'bobina_kg': bobinaKg,
        if (diameter != null) 'diameter': diameter,
      };
}

class AdminOpeningWipCreateInput {
  const AdminOpeningWipCreateInput({
    required this.idempotencyKey,
    required this.orderId,
    required this.sourceApparatus,
    required this.sourceStageNodeId,
    required this.batches,
    this.note = '',
  });

  final String idempotencyKey;
  final String orderId;
  final String sourceApparatus;
  final String sourceStageNodeId;
  final String note;
  final List<AdminOpeningWipBatchInput> batches;

  Map<String, dynamic> toJson() {
    return {
      'idempotency_key': idempotencyKey.trim(),
      'order_id': orderId.trim(),
      'source_apparatus': sourceApparatus.trim(),
      'source_stage_node_id': sourceStageNodeId.trim(),
      if (note.trim().isNotEmpty) 'note': note.trim(),
      'batches': batches.map((batch) => batch.toJson()).toList(growable: false),
    };
  }
}

class AdminOpeningWipIntake {
  const AdminOpeningWipIntake({
    required this.intakeId,
    required this.idempotencyKey,
    required this.orderId,
    required this.entryApparatus,
    required this.sourceOperation,
    required this.sourceApparatus,
    required this.currentLocation,
    required this.resumeApparatus,
    required this.resumeStageNodeId,
    required this.historyStatus,
    required this.status,
    required this.note,
    required this.actorRole,
    required this.actorRef,
    required this.actorDisplayName,
    required this.createdAtUnix,
    required this.updatedAtUnix,
  });

  final String intakeId;
  final String idempotencyKey;
  final String orderId;
  final String entryApparatus;
  final String sourceOperation;
  final String sourceApparatus;
  final String currentLocation;
  final String resumeApparatus;
  final String resumeStageNodeId;
  final String historyStatus;
  final String status;
  final String note;
  final String actorRole;
  final String actorRef;
  final String actorDisplayName;
  final int createdAtUnix;
  final int updatedAtUnix;

  String get sourceStageNodeId =>
      sourceApparatus.trim().isEmpty ? '' : resumeStageNodeId;

  factory AdminOpeningWipIntake.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'];
    final actorJson = actor is Map
        ? actor.cast<String, dynamic>()
        : const <String, dynamic>{};
    return AdminOpeningWipIntake(
      intakeId: json['intake_id']?.toString().trim() ?? '',
      idempotencyKey: json['idempotency_key']?.toString().trim() ?? '',
      orderId: json['order_id']?.toString().trim() ?? '',
      entryApparatus: json['entry_apparatus']?.toString().trim() ?? '',
      sourceOperation: json['source_operation']?.toString().trim() ?? '',
      sourceApparatus: json['source_apparatus']?.toString().trim() ?? '',
      currentLocation: json['current_location']?.toString().trim() ?? '',
      resumeApparatus: json['resume_apparatus']?.toString().trim() ?? '',
      resumeStageNodeId: json['resume_stage_node_id']?.toString().trim() ?? '',
      historyStatus: json['history_status']?.toString().trim() ?? '',
      status: json['status']?.toString().trim() ?? '',
      note: json['note']?.toString().trim() ?? '',
      actorRole: actorJson['role']?.toString().trim() ?? '',
      actorRef: actorJson['ref_']?.toString().trim() ?? '',
      actorDisplayName: actorJson['display_name']?.toString().trim() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
      updatedAtUnix: (json['updated_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminOpeningWipBatch {
  const AdminOpeningWipBatch({
    required this.batchId,
    required this.intakeId,
    required this.orderId,
    required this.sequenceNo,
    required this.qrPayload,
    required this.quantityBasis,
    required this.quantity,
    required this.uom,
    required this.finishedGoodsMeter,
    required this.finishedGoodsKg,
    required this.bobinaKg,
    required this.diameter,
    required this.wipStatus,
    required this.usedBySessionId,
    required this.usedByApparatus,
    required this.processedBySessionId,
    required this.processedByApparatus,
    required this.labelItemCode,
    required this.labelItemName,
    required this.createdAtUnix,
    required this.updatedAtUnix,
  });

  final String batchId;
  final String intakeId;
  final String orderId;
  final int sequenceNo;
  final String qrPayload;
  final AdminOpeningWipQuantityBasis quantityBasis;
  final double? quantity;
  final String uom;
  final double? finishedGoodsMeter;
  final double? finishedGoodsKg;
  final double? bobinaKg;
  final double? diameter;
  final String wipStatus;
  final String usedBySessionId;
  final String usedByApparatus;
  final String processedBySessionId;
  final String processedByApparatus;
  final String labelItemCode;
  final String labelItemName;
  final int createdAtUnix;
  final int updatedAtUnix;

  factory AdminOpeningWipBatch.fromJson(Map<String, dynamic> json) {
    return AdminOpeningWipBatch(
      batchId: json['batch_id']?.toString().trim() ?? '',
      intakeId: json['intake_id']?.toString().trim() ?? '',
      orderId: json['order_id']?.toString().trim() ?? '',
      sequenceNo: (json['sequence_no'] as num?)?.toInt() ?? 0,
      qrPayload: json['qr_payload']?.toString().trim() ?? '',
      quantityBasis: AdminOpeningWipQuantityBasis.fromRaw(
        json['quantity_basis'],
      ),
      quantity: (json['quantity'] as num?)?.toDouble(),
      uom: json['uom']?.toString().trim() ?? '',
      finishedGoodsMeter: (json['finished_goods_meter'] as num?)?.toDouble(),
      finishedGoodsKg: (json['finished_goods_kg'] as num?)?.toDouble(),
      bobinaKg: (json['bobina_kg'] as num?)?.toDouble(),
      diameter: (json['diameter'] as num?)?.toDouble(),
      wipStatus: json['wip_status']?.toString().trim() ?? '',
      usedBySessionId: json['used_by_session_id']?.toString().trim() ?? '',
      usedByApparatus: json['used_by_apparatus']?.toString().trim() ?? '',
      processedBySessionId:
          json['processed_by_session_id']?.toString().trim() ?? '',
      processedByApparatus:
          json['processed_by_apparatus']?.toString().trim() ?? '',
      labelItemCode: json['label_item_code']?.toString().trim() ?? '',
      labelItemName: json['label_item_name']?.toString().trim() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
      updatedAtUnix: (json['updated_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminOpeningWipRecord {
  const AdminOpeningWipRecord({
    required this.intake,
    required this.batches,
  });

  final AdminOpeningWipIntake intake;
  final List<AdminOpeningWipBatch> batches;

  factory AdminOpeningWipRecord.fromJson(Map<String, dynamic> json) {
    final rawIntake = json['intake'];
    return AdminOpeningWipRecord(
      intake: AdminOpeningWipIntake.fromJson(
        rawIntake is Map
            ? rawIntake.cast<String, dynamic>()
            : const <String, dynamic>{},
      ),
      batches: [
        for (final item in json['batches'] as List? ?? const [])
          if (item is Map)
            AdminOpeningWipBatch.fromJson(item.cast<String, dynamic>()),
      ],
    );
  }
}

class AdminOpeningWipPrintResult {
  const AdminOpeningWipPrintResult({
    required this.ok,
    required this.batch,
    this.printJob,
    this.printStatus = '',
  });

  final bool ok;
  final AdminOpeningWipBatch batch;
  final UsbRpsPrintRequest? printJob;
  final String printStatus;
}

extension MobileApiAdminOpeningWip on MobileApi {
  Future<AdminOpeningWipRecord> adminCreateOpeningWip(
    AdminOpeningWipCreateInput input,
  ) async {
    if (await TestModeController.instance.isEnabled()) {
      return _testModeCreateOpeningWip(input);
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/opening-wip',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(input.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'opening_wip_create');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawRecord = payload['record'];
    if (rawRecord is! Map) {
      throw const MobileApiException(
        code: 'opening_wip_create',
        message: 'Opening WIP yaratilmadi',
      );
    }
    return AdminOpeningWipRecord.fromJson(
      rawRecord.cast<String, dynamic>(),
    );
  }

  Future<List<AdminOpeningWipRecord>> adminOpeningWipRecords({
    String orderId = '',
    String status = '',
    int limit = 100,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalizedOrderId = orderId.trim();
      final normalizedStatus = status.trim().toLowerCase();
      return _testModeOpeningWipRecords.where((record) {
        final orderMatches = normalizedOrderId.isEmpty ||
            record.intake.orderId == normalizedOrderId;
        final statusMatches = normalizedStatus.isEmpty ||
            normalizedStatus == 'all' ||
            record.batches.any(
              (batch) => batch.wipStatus.toLowerCase() == normalizedStatus,
            );
        return orderMatches && statusMatches;
      }).toList(growable: false);
    }
    final boundedLimit = limit.clamp(1, 500).toInt();
    final query = <String, String>{'limit': boundedLimit.toString()};
    if (orderId.trim().isNotEmpty) query['order_id'] = orderId.trim();
    if (status.trim().isNotEmpty) query['status'] = status.trim();
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/opening-wip',
        ).replace(queryParameters: query),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'opening_wip_list');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return [
      for (final item in payload['records'] as List? ?? const [])
        if (item is Map)
          AdminOpeningWipRecord.fromJson(item.cast<String, dynamic>()),
    ];
  }

  Future<AdminOpeningWipBatch> adminLookupOpeningWip({
    required String apparatus,
    required String orderId,
    required String qrPayload,
    String batchId = '',
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return _testModeLookupOpeningWip(
        apparatus: apparatus,
        orderId: orderId,
        qrPayload: qrPayload,
        batchId: batchId,
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/opening-wip/lookup',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': apparatus.trim(),
          'order_id': orderId.trim(),
          'qr_payload': qrPayload.trim(),
          if (batchId.trim().isNotEmpty) 'batch_id': batchId.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'opening_wip_lookup');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawBatch = payload['batch'];
    if (rawBatch is! Map) {
      throw const MobileApiException(
        code: 'opening_wip_lookup',
        message: 'Opening WIP QR tasdiqlanmadi',
      );
    }
    return AdminOpeningWipBatch.fromJson(
      rawBatch.cast<String, dynamic>(),
    );
  }

  Future<List<AdminOpeningWipBatch>> adminOpeningWipCandidates({
    required String apparatus,
    required String orderId,
  }) async {
    final normalizedApparatus = apparatus.trim();
    final normalizedOrderId = orderId.trim();
    if (await TestModeController.instance.isEnabled()) {
      return List<AdminOpeningWipBatch>.unmodifiable([
        for (final record in _testModeOpeningWipRecords)
          if (record.intake.status.trim().toLowerCase() == 'confirmed' &&
              record.intake.orderId.trim() == normalizedOrderId &&
              _testModeOpeningWipCanScanAt(record, normalizedApparatus))
            for (final batch in record.batches)
              if (batch.orderId.trim() == normalizedOrderId &&
                  batch.wipStatus.trim().toLowerCase() == 'waiting')
                batch,
      ]);
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/opening-wip/lookup',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'apparatus': normalizedApparatus,
          'order_id': normalizedOrderId,
          'qr_payload': '',
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'opening_wip_lookup');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return [
      for (final item in payload['batches'] as List? ?? const [])
        if (item is Map)
          AdminOpeningWipBatch.fromJson(item.cast<String, dynamic>()),
    ];
  }

  Future<AdminOpeningWipPrintResult> adminPrintOpeningWip({
    required String batchId,
    String qrPayload = '',
    String driverUrl = '',
    String printer = '',
    String printMode = '',
    int printCount = 1,
    PrintTransport printTransport = PrintTransport.wifi,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return _testModePrintOpeningWip(
        batchId: batchId,
        qrPayload: qrPayload,
        printer: printer,
        printMode: printMode,
        printCount: printCount,
      );
    }
    final normalizedDriverUrl =
        driverUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/opening-wip/print',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'batch_id': batchId.trim(),
          if (qrPayload.trim().isNotEmpty) 'qr_payload': qrPayload.trim(),
          if (normalizedDriverUrl.isNotEmpty) 'driver_url': normalizedDriverUrl,
          if (printer.trim().isNotEmpty) 'printer': printer.trim(),
          if (printMode.trim().isNotEmpty) 'print_mode': printMode.trim(),
          'print_count': printCount.clamp(1, 100).toInt(),
          if (printTransport.isLocal)
            'print_transport': printTransport.clientApiValue,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'opening_wip_print');
    }
    return _openingWipPrintResultFromPayload(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

AdminOpeningWipRecord _testModeCreateOpeningWip(
  AdminOpeningWipCreateInput input,
) {
  final normalized = input.toJson();
  final key = normalized['idempotency_key']?.toString() ?? '';
  final existing = _testModeOpeningWipRecords.where(
    (record) => record.intake.idempotencyKey == key,
  );
  if (existing.isNotEmpty) {
    if (!_testModeOpeningWipMatchesInput(existing.first, input)) {
      throw const MobileApiException(
        code: 'opening_wip_idempotency_conflict',
        message: 'Bu Opening WIP so‘rovi boshqa ma’lumot bilan ishlatilgan',
      );
    }
    return existing.first;
  }
  if (key.isEmpty ||
      input.orderId.trim().isEmpty ||
      input.sourceApparatus.trim().isEmpty ||
      input.sourceStageNodeId.trim().isEmpty ||
      input.batches.isEmpty) {
    throw const MobileApiException(
      code: 'opening_wip_invalid_input',
      message: 'Opening WIP ma’lumotlari to‘liq emas',
    );
  }
  final sourceStage = _testModeOpeningWipSourceStage(input);
  final apparatus = _testModeRequiredApparatus(input.sourceApparatus);
  final requiresDiameter = apparatus.operation.trim().toLowerCase() == 'cut';
  for (final batch in input.batches) {
    final values = [
      batch.finishedGoodsMeter,
      batch.finishedGoodsKg,
      batch.bobinaKg,
      if (batch.diameter != null) batch.diameter!,
    ];
    if (batch.quantityBasis == AdminOpeningWipQuantityBasis.unknown ||
        values.any((value) => !value.isFinite || value <= 0) ||
        requiresDiameter != (batch.diameter != null)) {
      throw const MobileApiException(
        code: 'opening_wip_invalid_input',
        message: 'Opening WIP rulon passporti to‘liq emas',
      );
    }
  }
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final suffix = now.toRadixString(36);
  final intakeId = 'opening-wip-test-$suffix';
  final intake = AdminOpeningWipIntake(
    intakeId: intakeId,
    idempotencyKey: key,
    orderId: input.orderId.trim(),
    entryApparatus: input.sourceApparatus.trim(),
    sourceOperation: apparatus.operation.trim().toLowerCase(),
    sourceApparatus: input.sourceApparatus.trim(),
    currentLocation: '',
    resumeApparatus: '',
    resumeStageNodeId: sourceStage.nodeId.trim(),
    historyStatus: 'unavailable_before_cutover',
    status: 'confirmed',
    note: input.note.trim(),
    actorRole: 'admin',
    actorRef: 'test-admin',
    actorDisplayName: 'Test Admin',
    createdAtUnix: now,
    updatedAtUnix: now,
  );
  final batches = <AdminOpeningWipBatch>[
    for (var index = 0; index < input.batches.length; index++)
      AdminOpeningWipBatch(
        batchId: '$intakeId-${index + 1}',
        intakeId: intakeId,
        orderId: intake.orderId,
        sequenceNo: index + 1,
        qrPayload: 'OPENING-WIP:$intakeId:${index + 1}',
        quantityBasis: input.batches[index].quantityBasis,
        quantity: input.batches[index].finishedGoodsMeter,
        uom: 'm',
        finishedGoodsMeter: input.batches[index].finishedGoodsMeter,
        finishedGoodsKg: input.batches[index].finishedGoodsKg,
        bobinaKg: input.batches[index].bobinaKg,
        diameter: input.batches[index].diameter,
        wipStatus: 'waiting',
        usedBySessionId: '',
        usedByApparatus: '',
        processedBySessionId: '',
        processedByApparatus: '',
        labelItemCode: intake.orderId,
        labelItemName: 'Opening WIP ${index + 1}',
        createdAtUnix: now,
        updatedAtUnix: now,
      ),
  ];
  final record = AdminOpeningWipRecord(intake: intake, batches: batches);
  _testModeOpeningWipRecords.insert(0, record);
  return record;
}

AdminOpeningWipBatch _testModeLookupOpeningWip({
  required String apparatus,
  required String orderId,
  required String qrPayload,
  required String batchId,
}) {
  final normalizedApparatus = apparatus.trim();
  final normalizedOrderId = orderId.trim();
  final normalizedQr = qrPayload.trim().toUpperCase();
  final normalizedBatchId = batchId.trim();
  final profile = AppSession.instance.profile;
  final canUseApparatus = profile?.role == UserRole.admin ||
      (profile?.assignedApparatus ?? const <String>[])
          .any((item) => item.trim() == normalizedApparatus);
  if (!canUseApparatus) {
    throw const MobileApiException(
      code: 'apparatus_not_assigned',
      message: 'Bu aparat sizga biriktirilmagan',
    );
  }
  for (final record in _testModeOpeningWipRecords) {
    if (record.intake.orderId.trim() != normalizedOrderId ||
        !_testModeOpeningWipCanScanAt(record, normalizedApparatus) ||
        record.intake.status.trim().toLowerCase() != 'confirmed') {
      continue;
    }
    for (final batch in record.batches) {
      if (batch.wipStatus.trim().toLowerCase() == 'waiting' &&
          batch.qrPayload.trim().toUpperCase() == normalizedQr &&
          (normalizedBatchId.isEmpty || batch.batchId == normalizedBatchId)) {
        return batch;
      }
    }
  }
  throw const MobileApiException(
    code: 'opening_wip_qr_mismatch',
    message: 'Bu QR ushbu orderning kutilayotgan Opening WIP ruloniga mos emas',
  );
}

bool _testModeOpeningWipMatchesInput(
  AdminOpeningWipRecord record,
  AdminOpeningWipCreateInput input,
) {
  final intake = record.intake;
  final sourceStage = _testModeOpeningWipSourceStage(input);
  if (intake.orderId != input.orderId.trim() ||
      intake.entryApparatus != input.sourceApparatus.trim() ||
      intake.sourceApparatus != input.sourceApparatus.trim() ||
      intake.sourceStageNodeId != sourceStage.nodeId.trim() ||
      intake.currentLocation.isNotEmpty ||
      intake.resumeApparatus.isNotEmpty ||
      intake.note != input.note.trim() ||
      record.batches.length != input.batches.length) {
    return false;
  }
  for (var index = 0; index < record.batches.length; index++) {
    final stored = record.batches[index];
    final requested = input.batches[index];
    if (stored.quantityBasis != requested.quantityBasis ||
        stored.finishedGoodsMeter != requested.finishedGoodsMeter ||
        stored.finishedGoodsKg != requested.finishedGoodsKg ||
        stored.bobinaKg != requested.bobinaKg ||
        stored.diameter != requested.diameter) {
      return false;
    }
  }
  return true;
}

ProductionMapChainStage _testModeOpeningWipSourceStage(
  AdminOpeningWipCreateInput input,
) {
  final saved = _testModeOpeningWipMap(input.orderId);
  final stages = productionMapLinearWorkStages(saved.map)
      .where((stage) => stage.apparatusId != null)
      .toList(growable: false);
  for (final stage in stages) {
    if (stage.nodeId.trim() == input.sourceStageNodeId.trim() &&
        stage.apparatusId?.trim() == input.sourceApparatus.trim()) {
      if (productionMapNextWorkStagesForNode(
        map: saved.map,
        stageNodeId: stage.nodeId,
      ).isEmpty) {
        throw const MobileApiException(
          code: 'opening_wip_source_final_stage',
          message: 'Oxirgi aparat chiqish WIP manbasi bo‘la olmaydi',
        );
      }
      return stage;
    }
  }
  throw const MobileApiException(
    code: 'opening_wip_source_mismatch',
    message: 'Tanlangan chiqish apparati production mapga mos emas',
  );
}

ProductionMapSaved _testModeOpeningWipMap(String orderId) {
  for (final candidate in _testModeProductionMaps) {
    if (candidate.map.id.trim() == orderId.trim()) return candidate;
  }
  throw const MobileApiException(
    code: 'production_map_not_found',
    message: 'Production map topilmadi',
  );
}

bool _testModeOpeningWipCanScanAt(
  AdminOpeningWipRecord record,
  String apparatus,
) {
  if (record.intake.sourceApparatus.trim().isEmpty) {
    return record.intake.resumeApparatus.trim() == apparatus.trim();
  }
  final map = _testModeOpeningWipMap(record.intake.orderId).map;
  return productionMapNextWorkStagesForNode(
    map: map,
    stageNodeId: record.intake.sourceStageNodeId,
  ).any((stage) => stage.apparatusId?.trim() == apparatus.trim());
}

AdminOpeningWipPrintResult _testModePrintOpeningWip({
  required String batchId,
  required String qrPayload,
  required String printer,
  required String printMode,
  required int printCount,
}) {
  for (final record in _testModeOpeningWipRecords) {
    for (final batch in record.batches) {
      final matchesBatch =
          batchId.trim().isNotEmpty && batch.batchId == batchId.trim();
      final matchesQr = qrPayload.trim().isNotEmpty &&
          batch.qrPayload.toLowerCase() == qrPayload.trim().toLowerCase();
      if (!matchesBatch && !matchesQr) continue;
      final printJob = UsbRpsPrintRequest.fromPrintJson({
        'ok': true,
        'epc': batch.qrPayload,
        'item_code': batch.labelItemCode,
        'item_name': batch.labelItemName,
        'apparatus': record.intake.sourceApparatus.trim().isEmpty
            ? record.intake.entryApparatus
            : record.intake.sourceApparatus,
        'apparatus_display_name': record.intake.sourceApparatus.trim().isEmpty
            ? record.intake.entryApparatus
            : record.intake.sourceApparatus,
        'printer': printer.trim().isEmpty ? 'godex' : printer.trim(),
        'print_mode': printMode.trim().isEmpty ? 'label' : printMode.trim(),
        'gross_qty': batch.finishedGoodsKg ?? 0,
        'progress_qty': batch.finishedGoodsMeter ?? 0,
        'unit': 'kg',
        'progress_unit': 'm',
        'tare_enabled': batch.bobinaKg != null,
        'tare_kg': batch.bobinaKg ?? 0,
        'label_kind': 'progress',
        'print_count': printCount.clamp(1, 100).toInt(),
      });
      return AdminOpeningWipPrintResult(
        ok: true,
        batch: batch,
        printJob: printJob,
        printStatus: 'prepared',
      );
    }
  }
  throw const MobileApiException(
    code: 'progress_batch_not_found',
    message: 'Opening WIP ruloni topilmadi',
  );
}

AdminOpeningWipPrintResult _openingWipPrintResultFromPayload(
  Map<String, dynamic> payload,
) {
  final rawBatch = payload['batch'];
  if (rawBatch is! Map) {
    throw const MobileApiException(
      code: 'opening_wip_print',
      message: 'Opening WIP print javobi noto‘g‘ri',
    );
  }
  final rawPrint = payload['print'];
  final printMap = rawPrint is Map
      ? rawPrint.cast<String, dynamic>()
      : const <String, dynamic>{};
  return AdminOpeningWipPrintResult(
    ok: payload['ok'] == true,
    batch: AdminOpeningWipBatch.fromJson(rawBatch.cast<String, dynamic>()),
    printJob:
        printMap.isEmpty ? null : UsbRpsPrintRequest.fromPrintJson(printMap),
    printStatus: printMap['status']?.toString().trim() ?? '',
  );
}
