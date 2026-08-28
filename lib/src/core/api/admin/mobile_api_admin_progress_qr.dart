part of '../mobile_api.dart';

class AdminLaminatsiyaAstatkaReport {
  const AdminLaminatsiyaAstatkaReport({
    required this.reportId,
    required this.orderId,
    required this.apparatus,
    required this.fromAtUnix,
    required this.toAtUnix,
    required this.laminationPrintLeftoverRolls,
    required this.laminationFilmLeftoverRolls,
    required this.totalWaste,
    this.finishedGoodsMeter,
    this.finishedGoodsKg,
    this.bobinaKg,
    required this.workerRole,
    required this.workerRef,
    required this.workerDisplayName,
    this.description = '',
    required this.createdAtUnix,
  });

  final String reportId;
  final String orderId;
  final String apparatus;
  final int fromAtUnix;
  final int toAtUnix;
  final double laminationPrintLeftoverRolls;
  final double laminationFilmLeftoverRolls;
  final double totalWaste;
  final double? finishedGoodsMeter;
  final double? finishedGoodsKg;
  final double? bobinaKg;
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final String description;
  final int createdAtUnix;

  factory AdminLaminatsiyaAstatkaReport.fromJson(Map<String, dynamic> json) {
    return AdminLaminatsiyaAstatkaReport(
      reportId: json['report_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      fromAtUnix: (json['from_at_unix'] as num?)?.toInt() ?? 0,
      toAtUnix: (json['to_at_unix'] as num?)?.toInt() ?? 0,
      laminationPrintLeftoverRolls:
          (json['lamination_print_leftover_rolls'] as num?)?.toDouble() ?? 0,
      laminationFilmLeftoverRolls:
          (json['lamination_film_leftover_rolls'] as num?)?.toDouble() ?? 0,
      totalWaste: (json['total_waste'] as num?)?.toDouble() ?? 0,
      finishedGoodsMeter: (json['finished_goods_meter'] as num?)?.toDouble(),
      finishedGoodsKg: (json['finished_goods_kg'] as num?)?.toDouble(),
      bobinaKg: (json['bobina_kg'] as num?)?.toDouble() ??
          (json['babina_kg'] as num?)?.toDouble(),
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminRezkaAstatkaReport {
  const AdminRezkaAstatkaReport({
    required this.reportId,
    required this.orderId,
    required this.apparatus,
    required this.fromAtUnix,
    required this.toAtUnix,
    required this.totalWaste,
    required this.rezkaBosmaWaste,
    required this.rezkaLaminationWaste,
    required this.rezkaEdgeWaste,
    this.finishedGoodsMeter,
    this.finishedGoodsKg,
    this.bobinaKg,
    required this.workerRole,
    required this.workerRef,
    required this.workerDisplayName,
    this.description = '',
    required this.createdAtUnix,
  });

  final String reportId;
  final String orderId;
  final String apparatus;
  final int fromAtUnix;
  final int toAtUnix;
  final double totalWaste;
  final double rezkaBosmaWaste;
  final double rezkaLaminationWaste;
  final double rezkaEdgeWaste;
  final double? finishedGoodsMeter;
  final double? finishedGoodsKg;
  final double? bobinaKg;
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final String description;
  final int createdAtUnix;

  factory AdminRezkaAstatkaReport.fromJson(Map<String, dynamic> json) {
    return AdminRezkaAstatkaReport(
      reportId: json['report_id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      fromAtUnix: (json['from_at_unix'] as num?)?.toInt() ?? 0,
      toAtUnix: (json['to_at_unix'] as num?)?.toInt() ?? 0,
      totalWaste: (json['total_waste'] as num?)?.toDouble() ?? 0,
      rezkaBosmaWaste: (json['rezka_bosma_waste'] as num?)?.toDouble() ?? 0,
      rezkaLaminationWaste:
          (json['rezka_lamination_waste'] as num?)?.toDouble() ?? 0,
      rezkaEdgeWaste: (json['rezka_edge_waste'] as num?)?.toDouble() ?? 0,
      finishedGoodsMeter: (json['finished_goods_meter'] as num?)?.toDouble(),
      finishedGoodsKg: (json['finished_goods_kg'] as num?)?.toDouble(),
      bobinaKg: (json['bobina_kg'] as num?)?.toDouble() ??
          (json['babina_kg'] as num?)?.toDouble(),
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminProgressBatch {
  const AdminProgressBatch({
    required this.batchId,
    this.revision = 1,
    required this.sessionId,
    required this.apparatus,
    required this.orderId,
    required this.action,
    required this.status,
    required this.producedQty,
    required this.uom,
    required this.qrPayload,
    required this.labelItemCode,
    required this.labelItemName,
    required this.executorName,
    this.diameter,
    this.returnInkKg,
    this.laminationPrintLeftoverRolls,
    this.laminationFilmLeftoverRolls,
    this.rezkaBosmaWaste,
    this.rezkaLaminationWaste,
    this.rezkaEdgeWaste,
    this.totalWaste,
    this.finishedGoodsKg,
    this.bobinaKg,
    this.finishedGoodsMeter,
    this.description = '',
    this.workerRole = '',
    this.workerRef = '',
    this.workerDisplayName = '',
    this.wipStatus = '',
    this.statusDetail = const AdminProgressBatchStatusDetail(),
    this.currentApparatus = '',
    this.currentApparatusKey = '',
    this.currentLocation = '',
    this.nextApparatus = '',
    this.parentBatchId = '',
    this.usedBySessionId = '',
    this.usedByApparatus = '',
    this.processedBySessionId = '',
    this.processedByApparatus = '',
    this.startedAtUnix = 0,
    this.completedAtUnix = 0,
    this.payloadJson = const {},
  });

  final String batchId;
  final int revision;
  final String sessionId;
  final String apparatus;
  final String orderId;
  final String action;
  final String status;
  final double producedQty;
  final String uom;
  final String qrPayload;
  final String labelItemCode;
  final String labelItemName;
  final String executorName;
  final double? diameter;
  final double? returnInkKg;
  final double? laminationPrintLeftoverRolls;
  final double? laminationFilmLeftoverRolls;
  final double? rezkaBosmaWaste;
  final double? rezkaLaminationWaste;
  final double? rezkaEdgeWaste;
  final double? totalWaste;
  final double? finishedGoodsKg;
  final double? bobinaKg;
  final double? finishedGoodsMeter;
  final String description;
  final String workerRole;
  final String workerRef;
  final String workerDisplayName;
  final String wipStatus;
  final AdminProgressBatchStatusDetail statusDetail;
  final String currentApparatus;
  final String currentApparatusKey;
  final String currentLocation;
  final String nextApparatus;
  final String parentBatchId;
  final String usedBySessionId;
  final String usedByApparatus;
  final String processedBySessionId;
  final String processedByApparatus;
  final int startedAtUnix;
  final int completedAtUnix;
  final Map<String, dynamic> payloadJson;

  factory AdminProgressBatch.fromJson(Map<String, dynamic> json) {
    final currentApparatus = _requireCanonicalApparatusId(
      json['current_apparatus']?.toString() ?? '',
      allowEmpty: true,
    );
    final currentApparatusKey = _requireCanonicalApparatusId(
      json['current_apparatus_key']?.toString() ?? '',
      allowEmpty: true,
    );
    if (currentApparatus.isNotEmpty &&
        currentApparatusKey.isNotEmpty &&
        currentApparatus != currentApparatusKey) {
      throw const MobileApiException(
        code: 'apparatus_id_mismatch',
        message: 'Progress aparat identity mos emas',
      );
    }
    return AdminProgressBatch(
      batchId: json['batch_id']?.toString() ?? '',
      revision: (json['revision'] as num?)?.toInt() ?? 1,
      sessionId: json['session_id']?.toString() ?? '',
      apparatus: _requireCanonicalApparatusId(
        json['apparatus']?.toString() ?? '',
      ),
      orderId: json['order_id']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      producedQty: (json['produced_qty'] as num?)?.toDouble() ?? 0,
      uom: json['uom']?.toString() ?? '',
      qrPayload: json['qr_payload']?.toString() ?? '',
      labelItemCode: json['label_item_code']?.toString() ?? '',
      labelItemName: json['label_item_name']?.toString() ?? '',
      executorName: json['executor_name']?.toString() ?? '',
      diameter: (json['diameter'] as num?)?.toDouble(),
      returnInkKg: (json['return_ink_kg'] as num?)?.toDouble(),
      laminationPrintLeftoverRolls:
          (json['lamination_print_leftover_rolls'] as num?)?.toDouble(),
      laminationFilmLeftoverRolls:
          (json['lamination_film_leftover_rolls'] as num?)?.toDouble(),
      rezkaBosmaWaste: (json['rezka_bosma_waste'] as num?)?.toDouble(),
      rezkaLaminationWaste:
          (json['rezka_lamination_waste'] as num?)?.toDouble(),
      rezkaEdgeWaste: (json['rezka_edge_waste'] as num?)?.toDouble(),
      totalWaste: (json['total_waste'] as num?)?.toDouble(),
      finishedGoodsKg: (json['finished_goods_kg'] as num?)?.toDouble(),
      bobinaKg: (json['bobina_kg'] as num?)?.toDouble() ??
          (json['babina_kg'] as num?)?.toDouble(),
      finishedGoodsMeter: (json['finished_goods_meter'] as num?)?.toDouble(),
      description: json['description']?.toString() ?? '',
      workerRole: json['worker_role']?.toString() ?? '',
      workerRef: json['worker_ref']?.toString() ?? '',
      workerDisplayName: json['worker_display_name']?.toString() ?? '',
      wipStatus: json['wip_status']?.toString() ?? '',
      statusDetail: AdminProgressBatchStatusDetail.fromJsonOrBatchJson(json),
      currentApparatus: currentApparatus,
      currentApparatusKey: currentApparatusKey,
      currentLocation: json['current_location']?.toString() ?? '',
      nextApparatus: _requireCanonicalApparatusId(
        json['next_apparatus']?.toString() ?? '',
        allowEmpty: true,
      ),
      parentBatchId: json['parent_batch_id']?.toString() ?? '',
      usedBySessionId: json['used_by_session_id']?.toString() ?? '',
      usedByApparatus: _requireCanonicalApparatusId(
        json['used_by_apparatus']?.toString() ?? '',
        allowEmpty: true,
      ),
      processedBySessionId: json['processed_by_session_id']?.toString() ?? '',
      processedByApparatus: _requireCanonicalApparatusId(
        json['processed_by_apparatus']?.toString() ?? '',
        allowEmpty: true,
      ),
      startedAtUnix: (json['started_at_unix'] as num?)?.toInt() ?? 0,
      completedAtUnix: (json['completed_at_unix'] as num?)?.toInt() ?? 0,
      payloadJson: _jsonObject(json['payload_json']),
    );
  }

  AdminProgressBatch copyWith({
    int? revision,
    String? status,
    String? wipStatus,
    String? currentApparatus,
    String? currentLocation,
    String? nextApparatus,
    String? usedBySessionId,
    String? usedByApparatus,
    String? processedBySessionId,
    String? processedByApparatus,
    Map<String, dynamic>? payloadJson,
  }) {
    return AdminProgressBatch(
      batchId: batchId,
      revision: revision ?? this.revision,
      sessionId: sessionId,
      apparatus: apparatus,
      orderId: orderId,
      action: action,
      status: status ?? this.status,
      producedQty: producedQty,
      uom: uom,
      qrPayload: qrPayload,
      labelItemCode: labelItemCode,
      labelItemName: labelItemName,
      executorName: executorName,
      diameter: diameter,
      returnInkKg: returnInkKg,
      laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
      laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
      rezkaBosmaWaste: rezkaBosmaWaste,
      rezkaLaminationWaste: rezkaLaminationWaste,
      rezkaEdgeWaste: rezkaEdgeWaste,
      totalWaste: totalWaste,
      finishedGoodsKg: finishedGoodsKg,
      bobinaKg: bobinaKg,
      finishedGoodsMeter: finishedGoodsMeter,
      description: description,
      workerRole: workerRole,
      workerRef: workerRef,
      workerDisplayName: workerDisplayName,
      wipStatus: wipStatus ?? this.wipStatus,
      statusDetail: statusDetail,
      currentApparatus: currentApparatus ?? this.currentApparatus,
      currentApparatusKey: currentApparatusKey,
      currentLocation: currentLocation ?? this.currentLocation,
      nextApparatus: nextApparatus ?? this.nextApparatus,
      parentBatchId: parentBatchId,
      usedBySessionId: usedBySessionId ?? this.usedBySessionId,
      usedByApparatus: usedByApparatus ?? this.usedByApparatus,
      processedBySessionId: processedBySessionId ?? this.processedBySessionId,
      processedByApparatus: processedByApparatus ?? this.processedByApparatus,
      startedAtUnix: startedAtUnix,
      completedAtUnix: completedAtUnix,
      payloadJson: payloadJson ?? this.payloadJson,
    );
  }
}

class AdminProgressBatchCorrectionInput {
  const AdminProgressBatchCorrectionInput({
    required this.batchId,
    required this.expectedRevision,
    required this.producedQty,
    required this.uom,
    required this.reason,
    this.returnInkKg,
    this.laminationPrintLeftoverRolls,
    this.laminationFilmLeftoverRolls,
    this.rezkaBosmaWaste,
    this.rezkaLaminationWaste,
    this.rezkaEdgeWaste,
    this.totalWaste,
    this.finishedGoodsKg,
    this.bobinaKg,
    this.finishedGoodsMeter,
    this.diameter,
    this.description = '',
  });

  final String batchId;
  final int expectedRevision;
  final double producedQty;
  final String uom;
  final double? returnInkKg;
  final double? laminationPrintLeftoverRolls;
  final double? laminationFilmLeftoverRolls;
  final double? rezkaBosmaWaste;
  final double? rezkaLaminationWaste;
  final double? rezkaEdgeWaste;
  final double? totalWaste;
  final double? finishedGoodsKg;
  final double? bobinaKg;
  final double? finishedGoodsMeter;
  final double? diameter;
  final String description;
  final String reason;

  Map<String, dynamic> toJson() => {
        'batch_id': batchId.trim(),
        'expected_revision': expectedRevision,
        'produced_qty': producedQty,
        'uom': uom.trim(),
        'return_ink_kg': returnInkKg,
        'lamination_print_leftover_rolls': laminationPrintLeftoverRolls,
        'lamination_film_leftover_rolls': laminationFilmLeftoverRolls,
        'rezka_bosma_waste': rezkaBosmaWaste,
        'rezka_lamination_waste': rezkaLaminationWaste,
        'rezka_edge_waste': rezkaEdgeWaste,
        'total_waste': totalWaste,
        'finished_goods_kg': finishedGoodsKg,
        'bobina_kg': bobinaKg,
        'finished_goods_meter': finishedGoodsMeter,
        'diameter': diameter,
        'description': description.trim(),
        'reason': reason.trim(),
      };
}

class AdminProgressBatchCorrectionRecord {
  const AdminProgressBatchCorrectionRecord({
    required this.batchId,
    required this.previousRevision,
    required this.newRevision,
    required this.reason,
    required this.actorRole,
    required this.actorRef,
    required this.actorDisplayName,
    required this.oldValues,
    required this.newValues,
    required this.createdAtUnix,
  });

  final String batchId;
  final int previousRevision;
  final int newRevision;
  final String reason;
  final String actorRole;
  final String actorRef;
  final String actorDisplayName;
  final Map<String, dynamic> oldValues;
  final Map<String, dynamic> newValues;
  final int createdAtUnix;

  factory AdminProgressBatchCorrectionRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    final actor = json['actor'];
    final actorJson = actor is Map
        ? actor.cast<String, dynamic>()
        : const <String, dynamic>{};
    return AdminProgressBatchCorrectionRecord(
      batchId: json['batch_id']?.toString() ?? '',
      previousRevision: (json['previous_revision'] as num?)?.toInt() ?? 0,
      newRevision: (json['new_revision'] as num?)?.toInt() ?? 0,
      reason: json['reason']?.toString() ?? '',
      actorRole: actorJson['role']?.toString() ?? '',
      actorRef:
          actorJson['ref_']?.toString() ?? actorJson['ref']?.toString() ?? '',
      actorDisplayName: actorJson['display_name']?.toString() ?? '',
      oldValues: _jsonObject(json['old_values']),
      newValues: _jsonObject(json['new_values']),
      createdAtUnix: (json['created_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminProgressQrReprintResult {
  const AdminProgressQrReprintResult({
    required this.ok,
    required this.batch,
    this.printJob,
    this.printStatus = '',
  });

  final bool ok;
  final AdminProgressBatch batch;
  final UsbRpsPrintRequest? printJob;
  final String printStatus;
}

class AdminProgressBatchStatusDetail {
  const AdminProgressBatchStatusDetail({
    this.workStatus = '',
    this.wipStatus = '',
    this.flowStatus = '',
    this.stockStatus = '',
  });

  final String workStatus;
  final String wipStatus;
  final String flowStatus;
  final String stockStatus;

  factory AdminProgressBatchStatusDetail.fromJsonOrBatchJson(
    Map<String, dynamic> batchJson,
  ) {
    final raw = batchJson['status_detail'];
    if (raw is Map) {
      return AdminProgressBatchStatusDetail(
        workStatus: raw['work_status']?.toString() ?? '',
        wipStatus: raw['wip_status']?.toString() ?? '',
        flowStatus: raw['flow_status']?.toString() ?? '',
        stockStatus: raw['stock_status']?.toString() ?? '',
      );
    }
    final batchStatus = batchJson['status']?.toString().trim() ?? '';
    final action = batchJson['action']?.toString().trim() ?? '';
    final wipStatus = batchJson['wip_status']?.toString().trim() ?? '';
    final nextApparatus = batchJson['next_apparatus']?.toString().trim() ?? '';
    final processedBy =
        batchJson['processed_by_apparatus']?.toString().trim() ?? '';
    final workStatus = switch (batchStatus) {
      'paused' => 'paused',
      'roll_detached' => 'roll_detached',
      'resumed' => 'in_progress',
      'completed' => 'completed',
      _ => batchStatus,
    };
    final isFinalOutput = adminProgressBatchIsFinishedGoodsOutput(
      action: action,
      status: batchStatus,
      nextApparatus: nextApparatus,
    );
    final flowStatus = switch (wipStatus) {
      'waiting' when isFinalOutput => 'free_wip',
      'waiting' => 'waiting_next_stage',
      'in_use' => 'in_progress',
      'processed' when processedBy.toLowerCase().startsWith('warehouse:') =>
        'accepted_to_stock',
      'processed' => 'consumed_by_next_stage',
      _ => '',
    };
    final stockStatus = switch (flowStatus) {
      'accepted_to_stock' => 'accepted',
      _ => '',
    };
    return AdminProgressBatchStatusDetail(
      workStatus: workStatus,
      wipStatus: wipStatus,
      flowStatus: flowStatus,
      stockStatus: stockStatus,
    );
  }
}

bool adminProgressBatchIsFinishedGoodsOutput({
  required String action,
  required String status,
  required String nextApparatus,
}) {
  if (nextApparatus.trim().isNotEmpty) return false;
  final normalizedAction = action.trim();
  final normalizedStatus = status.trim();
  if (normalizedAction == 'pause') {
    return normalizedStatus == 'paused' || normalizedStatus == 'resumed';
  }
  if (normalizedAction == 'detach_roll') {
    return normalizedStatus == 'roll_detached' || normalizedStatus == 'resumed';
  }
  return (normalizedAction == 'roll_complete' ||
          normalizedAction == 'complete') &&
      normalizedStatus == 'completed';
}

class AdminProgressQrOpenedBy {
  const AdminProgressQrOpenedBy({
    required this.actorRole,
    required this.actorRef,
    required this.actorDisplayName,
    required this.openedAtUnix,
  });

  final String actorRole;
  final String actorRef;
  final String actorDisplayName;
  final int openedAtUnix;

  factory AdminProgressQrOpenedBy.fromJson(Map<String, dynamic> json) {
    return AdminProgressQrOpenedBy(
      actorRole: json['actor_role']?.toString() ?? '',
      actorRef: json['actor_ref']?.toString() ?? '',
      actorDisplayName: json['actor_display_name']?.toString() ?? '',
      openedAtUnix: (json['opened_at_unix'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminProgressQrReport {
  const AdminProgressQrReport({
    required this.scannedBatch,
    required this.isStale,
    required this.staleReason,
    required this.queueStates,
    required this.logs,
    required this.progressBatches,
    required this.runSessions,
    required this.activeSessions,
    this.corrections = const [],
    this.currentBatch,
    this.order,
    this.orderStatus = const AdminProductionOrderStatusDetail(),
    this.openedBy,
  });

  final AdminProgressBatch scannedBatch;
  final AdminProgressBatch? currentBatch;
  final bool isStale;
  final String staleReason;
  final ProductionMapDefinition? order;
  final AdminProductionOrderStatusDetail orderStatus;
  final Map<String, Map<String, String>> queueStates;
  final List<AdminProductionOrderLogEntry> logs;
  final List<AdminProgressBatchCorrectionRecord> corrections;
  final List<AdminProgressBatch> progressBatches;
  final List<AdminWorkerRunSession> runSessions;
  final List<AdminWorkerRunSession> activeSessions;
  final AdminProgressQrOpenedBy? openedBy;

  factory AdminProgressQrReport.fromJson(Map<String, dynamic> json) {
    final scannedRaw = json['scanned_batch'];
    if (scannedRaw is! Map) {
      throw const MobileApiException(
        code: 'progress_batch_not_found',
        message: 'Progress QR topilmadi',
      );
    }
    final currentRaw = json['current_batch'];
    final orderRaw = json['order'];
    final openedRaw = json['opened_by'];
    return AdminProgressQrReport(
      scannedBatch: AdminProgressBatch.fromJson(
        scannedRaw.cast<String, dynamic>(),
      ),
      currentBatch: currentRaw is Map
          ? AdminProgressBatch.fromJson(currentRaw.cast<String, dynamic>())
          : null,
      isStale: json['is_stale'] == true,
      staleReason: json['stale_reason']?.toString() ?? '',
      order: orderRaw is Map
          ? ProductionMapDefinition.fromJson(orderRaw.cast<String, dynamic>())
          : null,
      orderStatus: AdminProductionOrderStatusDetail.fromJson(
        json['order_status'],
      ),
      queueStates: MobileApi.instance.parseApparatusQueueStateMap(
        json['queue_states'],
      ),
      logs: [
        for (final item in (json['logs'] as List? ?? const []))
          AdminProductionOrderLogEntry.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
      ],
      corrections: [
        for (final item in (json['corrections'] as List? ?? const []))
          AdminProgressBatchCorrectionRecord.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
      ],
      progressBatches: [
        for (final item in (json['progress_batches'] as List? ?? const []))
          AdminProgressBatch.fromJson((item as Map).cast<String, dynamic>()),
      ],
      runSessions: [
        for (final item in (json['run_sessions'] as List? ?? const []))
          AdminWorkerRunSession.fromJson((item as Map).cast<String, dynamic>()),
      ],
      activeSessions: [
        for (final item in (json['active_sessions'] as List? ?? const []))
          AdminWorkerRunSession.fromJson((item as Map).cast<String, dynamic>()),
      ],
      openedBy: openedRaw is Map
          ? AdminProgressQrOpenedBy.fromJson(openedRaw.cast<String, dynamic>())
          : null,
    );
  }
}

ProductionMapDefinition _orderMapWithTemplateRezkaKadrCount(
  ProductionMapDefinition map,
  CalculateOrderTemplate template,
) {
  if ((!_isSheetOrderMap(map) && !_isTrainingOrderMap(map)) ||
      !template.frameCount.isFinite ||
      template.frameCount <= 0) {
    return map;
  }
  final frameCount = template.frameCount.round();
  if (frameCount <= 0) {
    return map;
  }
  var changed = false;
  final nodes = map.nodes.map((node) {
    if (node.kind == 'apparatus' && _testModeNodeHasOperation(node, 'cut')) {
      if (node.rezkaKadrCount == frameCount) {
        return node;
      }
      changed = true;
      return node.copyWith(rezkaKadrCount: frameCount);
    }
    return node;
  }).toList(growable: false);
  return changed ? map.copyWith(nodes: nodes) : map;
}

AdminProgressBatch _testModeProgressBatch({
  required String apparatus,
  required String orderId,
  required String action,
  required String status,
  required double producedQty,
  required String uom,
  String? batchIdOverride,
  String? qrPayloadOverride,
  String parentBatchId = '',
  Map<String, dynamic> payloadJson = const {},
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
  double? bobinaKg,
}) {
  final nowUnix = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final batchId = batchIdOverride?.trim().isNotEmpty == true
      ? batchIdOverride!.trim()
      : _testModeProductionProgressBatchId(
          apparatus: apparatus,
          orderId: orderId,
          action: action,
        );
  final qrPayload = qrPayloadOverride?.trim().isNotEmpty == true
      ? qrPayloadOverride!.trim()
      : _testModeProductionProgressQrPayload(batchId);
  final executor = AppSession.instance.profile?.displayName.trim() ?? '';
  final orderMap = _testModeOrderById(orderId)?.map;
  final nextApparatus = orderMap == null
      ? ''
      : productionMapNextWorkStageStation(map: orderMap, station: apparatus) ??
          '';
  final isFinalOutput = orderMap != null &&
      productionMapIsFinalWorkStageStation(map: orderMap, station: apparatus);
  final orderTitle = orderMap == null
      ? orderId
      : (orderMap.title.trim().isNotEmpty
          ? orderMap.title.trim()
          : orderMap.productCode.trim());
  final productKind =
      isFinalOutput ? 'tayyor mahsulot' : 'yarim tayyor mahsulot';
  final actionLabel = switch (action.trim()) {
    'pause' => 'chiqarildi',
    'detach_roll' => 'rulon yechildi',
    'roll_complete' => 'rulon tugatildi',
    'complete' => 'ish tugatildi',
    _ => status.trim(),
  };
  final statusDetail = AdminProgressBatchStatusDetail.fromJsonOrBatchJson({
    'action': action,
    'status': status,
    'wip_status': 'waiting',
    'next_apparatus': nextApparatus,
  });
  return AdminProgressBatch(
    batchId: batchId,
    sessionId: 'test-session-$orderId',
    apparatus: apparatus,
    orderId: orderId,
    action: action,
    status: status,
    producedQty: producedQty,
    uom: uom,
    qrPayload: qrPayload,
    labelItemCode: orderId,
    labelItemName:
        '$orderTitle $productKind, apparat: $apparatus, $actionLabel',
    executorName: executor,
    diameter: diameter,
    returnInkKg: returnInkKg,
    laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
    laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
    rezkaBosmaWaste: rezkaBosmaWaste,
    rezkaLaminationWaste: rezkaLaminationWaste,
    rezkaEdgeWaste: rezkaEdgeWaste,
    totalWaste: totalWaste,
    finishedGoodsKg: finishedGoodsKg,
    finishedGoodsMeter: finishedGoodsMeter,
    bobinaKg: bobinaKg,
    wipStatus: 'waiting',
    statusDetail: statusDetail,
    currentApparatus: apparatus,
    currentLocation: apparatus,
    nextApparatus: nextApparatus,
    parentBatchId: parentBatchId,
    startedAtUnix: nowUnix,
    completedAtUnix: nowUnix,
    payloadJson: payloadJson,
  );
}

String _testModeProductionProgressBatchId({
  required String apparatus,
  required String orderId,
  required String action,
}) {
  final stamp =
      BigInt.from(DateTime.now().microsecondsSinceEpoch) * BigInt.from(1000);
  return 'progress-batch:$stamp:'
      '${_testModeProgressSanitizeId(apparatus)}:'
      '${_testModeProgressSanitizeId(orderId)}:'
      '${action.trim().toLowerCase()}';
}

String _testModeProductionProgressQrPayload(String batchId) {
  final parts = batchId.split(':');
  final stamp = parts.length > 1
      ? BigInt.tryParse(parts[1]) ??
          BigInt.from(DateTime.now().microsecondsSinceEpoch) * BigInt.from(1000)
      : BigInt.from(DateTime.now().microsecondsSinceEpoch) * BigInt.from(1000);
  final stampHex = (stamp & BigInt.parse('ffffffffffffffff', radix: 16))
      .toRadixString(16)
      .padLeft(16, '0');
  final hashHex = _testModeProductionProgressQrHash(
    batchId,
  ).toRadixString(16).padLeft(4, '0');
  return '4001$stampHex$hashHex'.toUpperCase();
}

bool _isProductionProgressQrPayload(String value) =>
    RegExp(r'^4001[0-9A-F]{20}$', caseSensitive: false).hasMatch(value.trim());

int _testModeProductionProgressQrHash(String value) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  for (final byte in utf8.encode(value.trim())) {
    hash = hash ^ BigInt.from(byte);
    hash = (hash * prime) & mask;
  }
  return (hash & BigInt.from(0xffff)).toInt();
}

String _testModeProgressSanitizeId(String value) {
  final out = StringBuffer();
  for (final rune in value.trim().runes) {
    final isAsciiNumber = rune >= 0x30 && rune <= 0x39;
    final isAsciiUpper = rune >= 0x41 && rune <= 0x5a;
    final isAsciiLower = rune >= 0x61 && rune <= 0x7a;
    if (isAsciiNumber || isAsciiUpper || isAsciiLower) {
      out.writeCharCode(isAsciiUpper ? rune + 0x20 : rune);
    } else {
      out.write('-');
    }
  }
  final sanitized = out.toString().replaceAll(RegExp(r'^-+|-+$'), '');
  return sanitized.isEmpty ? 'blank' : sanitized;
}

String _testModeProgressQueueKey(String apparatus, String orderId) =>
    '${apparatus.trim()}|${orderId.trim()}';

AdminProgressBatch? _testModeProgressBatchForKey(String key) {
  final normalized = key.trim();
  if (normalized.isEmpty) return null;
  for (final batch in _testModeProgressBatchesByQr.values) {
    if (batch.qrPayload.trim().toLowerCase() == normalized.toLowerCase() ||
        batch.batchId.trim().toLowerCase() == normalized.toLowerCase()) {
      return batch;
    }
  }
  return null;
}

int? _testModeRezkaKadrCount({
  required String orderId,
  required String apparatus,
}) {
  final map = _testModeOrderById(orderId)?.map;
  if (map == null) return null;
  for (final node in map.nodes) {
    if (node.kind == 'apparatus' &&
        _testModeNodeHasOperation(node, 'cut') &&
        _testModeProductionMapNodeMatchesStation(node, apparatus) &&
        node.rezkaKadrCount != null &&
        node.rezkaKadrCount! > 0) {
      return node.rezkaKadrCount;
    }
  }
  for (final template in _testModeCalculateOrderTemplates) {
    final matchesOrder = template.sourceMapId.trim() == map.id.trim() ||
        (map.orderNumber.trim().isNotEmpty &&
            template.orderNumber.trim() == map.orderNumber.trim());
    if (!matchesOrder ||
        !template.frameCount.isFinite ||
        template.frameCount <= 0) {
      continue;
    }
    final frameCount = template.frameCount.round();
    if (frameCount > 0) {
      return frameCount;
    }
  }
  return null;
}

AdminProgressBatch _testModeMarkProgressInputProcessed({
  required AdminProgressBatch batch,
  required String apparatus,
  required String orderId,
  List<Map<String, dynamic>> rezkaFrameIssues = const [],
}) {
  final payloadJson = <String, dynamic>{...batch.payloadJson};
  if (rezkaFrameIssues.isNotEmpty) {
    payloadJson['rezka_frame_issues'] = rezkaFrameIssues;
    payloadJson['rezka_issue'] = true;
  }
  return batch.copyWith(
    wipStatus: 'processed',
    currentApparatus: apparatus,
    currentLocation: apparatus,
    processedBySessionId: 'test-session-${orderId.trim()}',
    processedByApparatus: apparatus,
    payloadJson: payloadJson,
  );
}

List<Map<String, dynamic>> _testModeRezkaFrameIssues({
  required List<Map<String, dynamic>> rezkaFrames,
  required int frameCount,
  required String inputProgressBatchId,
}) {
  return [
    for (var index = 0; index < rezkaFrames.length; index += 1)
      if ((rezkaFrames[index]['issue_note']?.toString().trim() ?? '')
          .isNotEmpty)
        {
          'frame_index': index + 1,
          'frame_count': frameCount,
          'issue_note': rezkaFrames[index]['issue_note'].toString().trim(),
          'input_progress_batch_id': inputProgressBatchId.trim(),
        },
  ];
}

List<AdminProgressBatch> _testModeRezkaProgressBatches({
  required String apparatus,
  required String orderId,
  required String action,
  required String status,
  required double producedQty,
  required String uom,
  required int frameCount,
  required AdminProgressBatch? inputBatch,
  List<Map<String, dynamic>> rezkaFrames = const [],
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
  double? bobinaKg,
  List<Map<String, dynamic>> rezkaFrameIssues = const [],
}) {
  final baseBatchId = _testModeProductionProgressBatchId(
    apparatus: apparatus,
    orderId: orderId,
    action: action,
  );
  final parentBatchId = inputBatch?.batchId.trim() ?? '';
  final map = _testModeOrderById(orderId)?.map;
  double? labelLength;
  if (map != null) {
    for (final node in map.nodes) {
      final value = node.rezkaLabelLength;
      if (node.kind == 'apparatus' &&
          _testModeNodeHasOperation(node, 'cut') &&
          _testModeProductionMapNodeMatchesStation(node, apparatus) &&
          value != null &&
          value > 0) {
        labelLength = value;
        break;
      }
    }
  }
  AdminProgressBatch buildFrame(int index) {
    final frame = index < rezkaFrames.length
        ? rezkaFrames[index]
        : const <String, dynamic>{};
    double? frameMetric(String key) {
      final value = frame[key];
      return value is num ? value.toDouble() : null;
    }

    final explicitFrameValues = rezkaFrames.isNotEmpty;
    final frameProducedQty = explicitFrameValues
        ? (frameMetric('produced_qty') ??
            frameMetric('finished_goods_meter') ??
            producedQty)
        : producedQty;
    final frameFinishedGoodsKg = explicitFrameValues
        ? (frameMetric('finished_goods_kg') ??
            frameMetric('gross_qty') ??
            finishedGoodsKg)
        : finishedGoodsKg;
    final frameFinishedGoodsMeter = explicitFrameValues
        ? (frameMetric('finished_goods_meter') ??
            frameMetric('produced_qty') ??
            finishedGoodsMeter)
        : finishedGoodsMeter;
    final frameGrossQty = explicitFrameValues
        ? (frameMetric('gross_qty') ??
            frameMetric('finished_goods_kg') ??
            frameFinishedGoodsKg)
        : null;
    final frameHasWaste = [
      'rezka_bosma_waste',
      'rezka_lamination_waste',
      'rezka_edge_waste',
      'total_waste',
    ].any(frame.containsKey);
    final frameRezkaBosmaWaste = explicitFrameValues
        ? (frameHasWaste
            ? frameMetric('rezka_bosma_waste')
            : (index == 0 ? rezkaBosmaWaste : null))
        : (index == 0 ? rezkaBosmaWaste : null);
    final frameRezkaLaminationWaste = explicitFrameValues
        ? (frameHasWaste
            ? frameMetric('rezka_lamination_waste')
            : (index == 0 ? rezkaLaminationWaste : null))
        : (index == 0 ? rezkaLaminationWaste : null);
    final frameRezkaEdgeWaste = explicitFrameValues
        ? (frameHasWaste
            ? frameMetric('rezka_edge_waste')
            : (index == 0 ? rezkaEdgeWaste : null))
        : (index == 0 ? rezkaEdgeWaste : null);
    final frameTotalWaste = explicitFrameValues
        ? (frameHasWaste
            ? frameMetric('total_waste')
            : (index == 0 ? totalWaste : null))
        : (index == 0 ? totalWaste : null);
    final frameDiameter = explicitFrameValues
        ? (frameMetric('diameter') ?? diameter)
        : (index == 0 ? diameter : null);
    final frameBobinaKg = explicitFrameValues
        ? (frameMetric('bobina_kg') ?? frameMetric('babina_kg'))
        : (index == 0 ? bobinaKg : null);
    return _testModeProgressBatch(
      apparatus: apparatus,
      orderId: orderId,
      action: action,
      status: status,
      producedQty: frameProducedQty,
      uom: uom,
      batchIdOverride: '$baseBatchId:frame:${index + 1}',
      parentBatchId: parentBatchId,
      diameter: frameDiameter,
      returnInkKg: index == 0 ? returnInkKg : null,
      laminationPrintLeftoverRolls: laminationPrintLeftoverRolls,
      laminationFilmLeftoverRolls: laminationFilmLeftoverRolls,
      rezkaBosmaWaste: frameRezkaBosmaWaste,
      rezkaLaminationWaste: frameRezkaLaminationWaste,
      rezkaEdgeWaste: frameRezkaEdgeWaste,
      totalWaste: frameTotalWaste,
      finishedGoodsKg: frameFinishedGoodsKg,
      finishedGoodsMeter: frameFinishedGoodsMeter,
      bobinaKg: frameBobinaKg,
      payloadJson: {
        'rezka_frame_index': index + 1,
        'rezka_frame_count': frameCount,
        'rezka_output_kind': 'frame',
        'rezka_metrics_owner': explicitFrameValues || index == 0,
        if (frameGrossQty != null) 'gross_qty': frameGrossQty,
        if (labelLength != null) 'rezka_label_length': labelLength,
        if (rezkaFrameIssues.isNotEmpty) 'rezka_frame_issues': rezkaFrameIssues,
      },
    );
  }

  return [
    for (var index = 0; index < frameCount; index += 1)
      if (index >= rezkaFrames.length ||
          (rezkaFrames[index]['issue_note']?.toString().trim() ?? '').isEmpty)
        buildFrame(index),
  ];
}

List<UsbRpsPrintRequest> _testModeProgressPrintJobs({
  required List<AdminProgressBatch> batches,
  required String printer,
  required String printMode,
  String customerName = '',
}) {
  return [
    for (final batch in batches)
      UsbRpsPrintRequest(
        epc: batch.qrPayload,
        itemCode: batch.labelItemCode,
        itemName: batch.labelItemName,
        warehouse: 'Ijrochi: ${batch.executorName}',
        printer: printer.trim().isEmpty ? 'godex' : printer.trim(),
        printMode: printMode.trim().isEmpty ? 'label' : printMode.trim(),
        grossQty: (batch.payloadJson['gross_qty'] as num?)?.toDouble() ??
            batch.finishedGoodsKg ??
            batch.producedQty,
        unit: 'kg',
        labelKind: 'progress',
        executorName: batch.executorName,
        progressQty: batch.finishedGoodsMeter ?? batch.producedQty,
        progressUnit: batch.uom.isEmpty ? 'm' : batch.uom,
        tareEnabled: (batch.bobinaKg ?? 0) > 0,
        tareKg: batch.bobinaKg ?? 0,
        customerName: customerName.trim().isEmpty
            ? (batch.payloadJson['customer_name']?.toString() ?? '')
            : customerName.trim(),
      ),
  ];
}

extension MobileApiAdminProgressQr on MobileApi {
Future<AdminProgressBatch> adminProgressQrLookup(String qrPayload) async {
    final normalized = qrPayload.trim();
    if (await TestModeController.instance.isEnabled()) {
      final batch = _testModeProgressBatchForKey(normalized);
      if (batch == null) {
        throw const MobileApiException(
          code: 'progress_batch_not_found',
          message: 'Progress QR topilmadi',
        );
      }
      return batch;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/progress-qr/lookup',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'qr_payload': normalized}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'progress_batch_not_found');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['batch'];
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'progress_batch_not_found',
        message: 'Progress QR topilmadi',
      );
    }
    return AdminProgressBatch.fromJson(raw.cast<String, dynamic>());
  }

Future<List<AdminProgressBatch>> adminProgressQrHistory({
    int limit = 200,
  }) async {
    final boundedLimit = limit.clamp(1, 200).toInt();
    final profile = AppSession.instance.profile;
    final workerRef = profile?.ref.trim() ?? '';
    final workerName = profile?.displayName.trim() ?? '';
    if (await TestModeController.instance.isEnabled()) {
      if (workerRef.isEmpty && workerName.isEmpty) {
        return const [];
      }
      return _testModeProgressBatchesByQr.values
          .where(
            (batch) =>
                (workerRef.isNotEmpty && batch.workerRef.trim() == workerRef) ||
                (workerName.isNotEmpty &&
                    (batch.workerDisplayName.trim() == workerName ||
                        batch.executorName.trim() == workerName)),
          )
          .take(boundedLimit)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/progress-qr/history',
        ).replace(queryParameters: {'limit': boundedLimit.toString()}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'progress_qr_history');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['batches'];
    return [
      if (raw is List)
        for (final item in raw)
          AdminProgressBatch.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

Future<AdminProgressBatch> adminProgressBatchCorrect(
    AdminProgressBatchCorrectionInput input,
  ) async {
    if (input.batchId.trim().isEmpty ||
        input.expectedRevision <= 0 ||
        !input.producedQty.isFinite ||
        input.producedQty <= 0 ||
        input.uom.trim().isEmpty ||
        input.reason.trim().isEmpty) {
      throw const MobileApiException(
        code: 'progress_input_invalid',
        message: 'WIP o‘zgartirish ma’lumoti to‘liq emas',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      AdminProgressBatch? current;
      for (final batch in _testModeProgressBatchesByQr.values) {
        if (batch.batchId.trim() == input.batchId.trim()) {
          current = batch;
          break;
        }
      }
      if (current == null) {
        throw const MobileApiException(
          code: 'progress_batch_not_found',
          message: 'Progress QR topilmadi',
        );
      }
      if (current.wipStatus.trim().toLowerCase() != 'waiting') {
        throw const MobileApiException(
          code: 'progress_batch_correction_locked',
          message: 'Ishlatilgan WIPni o‘zgartirib bo‘lmaydi',
        );
      }
      if (current.revision != input.expectedRevision) {
        throw const MobileApiException(
          code: 'progress_batch_correction_conflict',
          message: 'WIP boshqa joyda yangilangan',
        );
      }
      final corrected = AdminProgressBatch(
        batchId: current.batchId,
        revision: current.revision + 1,
        sessionId: current.sessionId,
        apparatus: current.apparatus,
        orderId: current.orderId,
        action: current.action,
        status: current.status,
        producedQty: input.producedQty,
        uom: input.uom.trim(),
        qrPayload: current.qrPayload,
        labelItemCode: current.labelItemCode,
        labelItemName: current.labelItemName,
        executorName: current.executorName,
        diameter: input.diameter,
        returnInkKg: input.returnInkKg,
        laminationPrintLeftoverRolls: input.laminationPrintLeftoverRolls,
        laminationFilmLeftoverRolls: input.laminationFilmLeftoverRolls,
        rezkaBosmaWaste: input.rezkaBosmaWaste,
        rezkaLaminationWaste: input.rezkaLaminationWaste,
        rezkaEdgeWaste: input.rezkaEdgeWaste,
        totalWaste: input.totalWaste,
        finishedGoodsKg: input.finishedGoodsKg,
        bobinaKg: input.bobinaKg,
        finishedGoodsMeter: input.finishedGoodsMeter,
        description: input.description.trim(),
        workerRole: current.workerRole,
        workerRef: current.workerRef,
        workerDisplayName: current.workerDisplayName,
        wipStatus: current.wipStatus,
        statusDetail: current.statusDetail,
        currentApparatus: current.currentApparatus,
        currentApparatusKey: current.currentApparatusKey,
        currentLocation: current.currentLocation,
        nextApparatus: current.nextApparatus,
        parentBatchId: current.parentBatchId,
        usedBySessionId: current.usedBySessionId,
        usedByApparatus: current.usedByApparatus,
        processedBySessionId: current.processedBySessionId,
        processedByApparatus: current.processedByApparatus,
        startedAtUnix: current.startedAtUnix,
        completedAtUnix: current.completedAtUnix,
        payloadJson: current.payloadJson,
      );
      _testModeProgressBatchesByQr[current.qrPayload] = corrected;
      return corrected;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/progress-qr/correct',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(input.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'progress_batch_correction_failed',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = payload['batch'];
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'progress_batch_correction_failed',
        message: 'Yangilangan WIP ma’lumoti kelmadi',
      );
    }
    return AdminProgressBatch.fromJson(raw.cast<String, dynamic>());
  }

Future<AdminProgressQrReprintResult> adminProgressQrReprint({
    required String qrPayload,
    String progressBatchId = '',
    String driverUrl = '',
    String printer = '',
    String printMode = '',
    int printCount = 1,
    PrintTransport printTransport = PrintTransport.wifi,
  }) async {
    final normalizedQrPayload = qrPayload.trim();
    final normalizedBatchId = progressBatchId.trim();
    if (normalizedQrPayload.isEmpty && normalizedBatchId.isEmpty) {
      throw const MobileApiException(
        code: 'progress_batch_not_found',
        message: 'Progress QR topilmadi',
      );
    }
    final boundedPrintCount = printCount.clamp(1, 100).toInt();
    final normalizedDriverUrl = driverUrl.trim().replaceFirst(
          RegExp(r'/+$'),
          '',
        );
    final normalizedPrinter = printer.trim();
    final normalizedPrintMode = printMode.trim();

    if (await TestModeController.instance.isEnabled()) {
      final batch = _testModeProgressBatchForKey(
        normalizedQrPayload.isNotEmpty
            ? normalizedQrPayload
            : normalizedBatchId,
      );
      if (batch == null) {
        throw const MobileApiException(
          code: 'progress_batch_not_found',
          message: 'Progress QR topilmadi',
        );
      }
      final printJob = UsbRpsPrintRequest(
        epc: batch.qrPayload,
        itemCode: batch.labelItemCode,
        itemName: batch.labelItemName,
        apparatus: batch.apparatus,
        warehouse: 'Ijrochi: ${batch.executorName}',
        printer: normalizedPrinter.isEmpty ? 'godex' : normalizedPrinter,
        printMode: normalizedPrintMode.isEmpty ? 'label' : normalizedPrintMode,
        grossQty: (batch.payloadJson['gross_qty'] as num?)?.toDouble() ??
            batch.finishedGoodsKg ??
            batch.producedQty,
        unit: 'kg',
        tareEnabled: (batch.bobinaKg ?? 0) > 0,
        tareKg: batch.bobinaKg ?? 0,
        printCount: boundedPrintCount,
        labelKind: 'progress',
        executorName: batch.executorName,
        progressQty: batch.finishedGoodsMeter ?? batch.producedQty,
        progressUnit: batch.uom.isEmpty ? 'm' : batch.uom,
        customerName: batch.payloadJson['customer_name']?.toString() ?? '',
      );
      return AdminProgressQrReprintResult(
        ok: true,
        batch: batch,
        printJob: printJob,
        printStatus: 'prepared',
      );
    }

    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/progress-qr/reprint',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          if (normalizedBatchId.isNotEmpty)
            'progress_batch_id': normalizedBatchId,
          if (normalizedQrPayload.isNotEmpty) 'qr_payload': normalizedQrPayload,
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
      throw _adminProductionMapException(response, 'progress_qr_reprint');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final rawBatch = payload['batch'];
    if (rawBatch is! Map) {
      throw const MobileApiException(
        code: 'progress_batch_not_found',
        message: 'Progress QR topilmadi',
      );
    }
    final rawPrint = payload['print'];
    final printMap = rawPrint is Map
        ? rawPrint.cast<String, dynamic>()
        : const <String, dynamic>{};
    return AdminProgressQrReprintResult(
      ok: payload['ok'] == true,
      batch: AdminProgressBatch.fromJson(rawBatch.cast<String, dynamic>()),
      printJob: printMap['ok'] == true
          ? UsbRpsPrintRequest.fromPrintJson(printMap)
          : null,
      printStatus: printMap['status']?.toString() ?? '',
    );
  }

Future<AdminProgressQrReport> adminProgressQrReport(String qrPayload) async {
    final normalized = qrPayload.trim();
    if (await TestModeController.instance.isEnabled()) {
      final batch = _testModeProgressBatchForKey(normalized);
      if (batch == null) {
        throw const MobileApiException(
          code: 'progress_batch_not_found',
          message: 'Progress QR topilmadi',
        );
      }
      final progressBatches = _testModeProgressBatchesByQr.values
          .where((item) => item.orderId.trim() == batch.orderId.trim())
          .toList(growable: false);
      return AdminProgressQrReport(
        scannedBatch: batch,
        currentBatch: batch,
        isStale: false,
        staleReason: '',
        queueStates: const {},
        logs: const [],
        progressBatches: progressBatches.isEmpty ? [batch] : progressBatches,
        runSessions: const [],
        activeSessions: const [],
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/progress-qr/report',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'qr_payload': normalized}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'progress_batch_not_found');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return AdminProgressQrReport.fromJson(payload);
  }
}
