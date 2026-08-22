part of '../mobile_api.dart';

const _trainingInputApparatus = 'training-input:bosma';
const _trainingRezkaInputApparatus = 'training-input:laminatsiya';

void _validateTrainingPhysicalApparatusId(
  String apparatusId, {
  bool allowEmpty = false,
}) {
  final normalized = apparatusId.trim();
  if ((allowEmpty && normalized.isEmpty) ||
      isCanonicalApparatusId(normalized)) {
    return;
  }
  throw const MobileApiException(
    code: 'apparatus_id_invalid',
    message: 'Canonical apparatus ID noto‘g‘ri',
  );
}

void _validateTrainingMapApparatus(ProductionMapDefinition map) {
  final apparatusNodes = map.nodes.where((node) => node.kind == 'apparatus');
  if (apparatusNodes.isEmpty ||
      apparatusNodes.any((node) {
        final assignedId = node.alternativeAssignedApparatusId.trim();
        return !isCanonicalApparatusId(node.apparatusId) ||
            (assignedId.isNotEmpty && !isCanonicalApparatusId(assignedId));
      })) {
    throw const MobileApiException(
      code: 'training_map_apparatus_invalid',
      message: 'Training map canonical apparatlari noto‘g‘ri',
    );
  }
}

bool _isTrainingStageApparatusId(String apparatusId) {
  final normalized = apparatusId.trim();
  return isCanonicalApparatusId(normalized) ||
      normalized == _trainingInputApparatus ||
      normalized == _trainingRezkaInputApparatus;
}

void _validateTrainingInputBatch(AdminProgressBatch batch) {
  final apparatusIds = [
    batch.apparatus,
    batch.currentApparatus,
    batch.usedByApparatus,
    batch.processedByApparatus,
  ];
  if (batch.batchId.trim().isEmpty ||
      !batch.orderId.trim().startsWith('training-') ||
      !isCanonicalApparatusId(batch.nextApparatus.trim()) ||
      apparatusIds.any(
        (id) => id.trim().isNotEmpty && !_isTrainingStageApparatusId(id),
      )) {
    throw const MobileApiException(
      code: 'training_input_batch_invalid_response',
      message: 'Training batch javobi noto‘g‘ri',
    );
  }
}

final _trainingOrderNumberPattern = RegExp(
  r'^T-(\d{1,4})$',
  caseSensitive: false,
);
final Set<String> _testModeTrainingInputBatchGeneratedOrderIds = {};
final Set<String> _testModeTrainingInputBatchSetClosedOrderIds = {};
int _testModeTrainingInputBatchSequence = 0;

void _resetTestModeTrainingInputBatches() {
  _testModeTrainingInputBatchGeneratedOrderIds.clear();
  _testModeTrainingInputBatchSetClosedOrderIds.clear();
  _testModeTrainingInputBatchSequence = 0;
}

ProductionMapDefinition _testModePrepareTrainingMapForSave(
  ProductionMapDefinition map,
) {
  final mapId = map.id.trim().toLowerCase();
  if (!mapId.startsWith('zakaz-draft-')) {
    return map;
  }
  var maxOrderNumber = 0;
  for (final saved in _testModeProductionMaps) {
    final match = _trainingOrderNumberPattern.firstMatch(
      saved.map.orderNumber.trim(),
    );
    final value = int.tryParse(match?.group(1) ?? '');
    if (value != null && value > maxOrderNumber) {
      maxOrderNumber = value;
    }
  }
  final orderNumber = map.orderNumber.trim().isEmpty
      ? 'T-${(maxOrderNumber + 1).toString().padLeft(4, '0')}'
      : map.orderNumber.trim();
  final suffix = (maxOrderNumber + 1).toString().padLeft(4, '0');
  return map.copyWith(
    id: 'training-zakaz-$suffix',
    code: map.code.trim().isEmpty ? orderNumber : map.code,
    orderNumber: orderNumber,
  );
}

bool _isTrainingOrderMap(ProductionMapDefinition map) {
  return map.id.trim().startsWith('training-');
}

String? _testModeTrainingPreviousStage({
  required ProductionMapDefinition map,
  required String station,
}) {
  final previousStage = productionMapPreviousWorkStageStation(
    map: map,
    station: station,
  );
  if (previousStage != null) {
    return previousStage;
  }
  return _testModeVirtualTrainingInputStage(map: map, station: station);
}

String? _testModeVirtualTrainingInputStage({
  required ProductionMapDefinition map,
  required String station,
}) {
  if (!_isTrainingOrderMap(map) ||
      productionMapPreviousWorkStageStation(map: map, station: station) !=
          null) {
    return null;
  }
  ProductionMapNode? target;
  for (final node in map.nodes) {
    if (node.kind == 'apparatus' && node.apparatusId.trim() == station.trim()) {
      target = node;
      break;
    }
  }
  if (target == null) return null;
  final operation = _testModeRequiredApparatus(
    target.apparatusId,
  ).operation.trim().toLowerCase();
  if (operation == 'laminate') {
    return _trainingInputApparatus;
  }
  if (operation == 'cut') {
    return _trainingRezkaInputApparatus;
  }
  return null;
}

bool _testModeUsesVirtualTrainingInput({
  required ProductionMapDefinition map,
  required String station,
}) {
  return _testModeVirtualTrainingInputStage(map: map, station: station) != null;
}

String? _trainingInputTargetStation(ProductionMapDefinition map) {
  for (final node in map.nodes) {
    if (node.kind == 'apparatus' &&
        _testModeVirtualTrainingInputStage(
              map: map,
              station: node.apparatusId,
            ) !=
            null) {
      final station = node.apparatusId.trim();
      if (station.isNotEmpty) {
        return station;
      }
    }
  }
  return null;
}

AdminProgressBatch? _testModeTrainingInputProgressBatch({
  required ProductionMapDefinition map,
  required String station,
  bool forceNewIdentity = false,
}) {
  final orderId = map.id.trim();
  final targetStation = station.trim();
  final inputApparatus = _testModeVirtualTrainingInputStage(
    map: map,
    station: targetStation,
  );
  if (orderId.isEmpty || targetStation.isEmpty || inputApparatus == null) {
    return null;
  }
  final itemCode = map.productCode.trim().isNotEmpty
      ? map.productCode.trim()
      : (map.orderNumber.trim().isNotEmpty ? map.orderNumber.trim() : orderId);
  final title = map.title.trim().isNotEmpty ? map.title.trim() : itemCode;
  final producedQty =
      map.orderKg != null && map.orderKg!.isFinite && map.orderKg! > 0
          ? map.orderKg!
          : 1.0;
  const status = 'completed';
  const action = 'complete';
  const wipStatus = 'waiting';
  final statusDetail = AdminProgressBatchStatusDetail.fromJsonOrBatchJson({
    'action': action,
    'status': status,
    'wip_status': wipStatus,
    'next_apparatus': targetStation,
  });
  AdminProgressBatch? existingIdentity;
  if (!forceNewIdentity) {
    for (final candidate in _testModeProgressBatchesByQr.values) {
      if (candidate.payloadJson['training_input'] == true &&
          candidate.orderId.trim() == orderId &&
          candidate.nextApparatus.trim() == targetStation &&
          _isProductionProgressQrPayload(candidate.qrPayload)) {
        existingIdentity = candidate;
        break;
      }
    }
  }
  final generatedBatchId = _testModeProductionProgressBatchId(
    apparatus: inputApparatus,
    orderId: orderId,
    action: action,
  );
  final batchId = existingIdentity?.batchId ??
      (forceNewIdentity
          ? '$generatedBatchId:training-input:${++_testModeTrainingInputBatchSequence}'
          : generatedBatchId);
  final qrPayload = existingIdentity?.qrPayload ??
      _testModeProductionProgressQrPayload(batchId);
  return AdminProgressBatch(
    batchId: batchId,
    sessionId: existingIdentity?.sessionId ?? 'training-input-session:$batchId',
    apparatus: inputApparatus,
    orderId: orderId,
    action: action,
    status: status,
    producedQty: producedQty,
    uom: 'kg',
    qrPayload: qrPayload,
    labelItemCode: itemCode,
    labelItemName: '$title, training input: $inputApparatus',
    executorName: 'Training input',
    workerRole: 'training',
    workerRef: 'training-input',
    workerDisplayName: 'Training input',
    wipStatus: wipStatus,
    statusDetail: statusDetail,
    currentApparatus: inputApparatus,
    currentApparatusKey: inputApparatus,
    currentLocation: 'Training input chiqim',
    nextApparatus: targetStation,
    finishedGoodsKg: producedQty,
    description: 'Training uchun generatsiya qilingan input batch',
    payloadJson: {
      'training': true,
      'training_input': true,
      'source': 'generated_training_order_batch',
      'source_apparatus': inputApparatus,
    },
  );
}

void _ensureTestModeTrainingInputBatch(
  ProductionMapDefinition map, {
  bool reset = false,
}) {
  final station = _trainingInputTargetStation(map);
  if (station == null) {
    return;
  }
  if (reset) {
    _testModeProgressBatchesByQr.removeWhere(
      (_, batch) =>
          batch.payloadJson['training_input'] == true &&
          batch.orderId.trim() == map.id.trim(),
    );
  }
  final batch = _testModeTrainingInputProgressBatch(map: map, station: station);
  if (batch == null) {
    return;
  }
  if (!_testModeTrainingInputBatchGeneratedOrderIds.contains(batch.orderId)) {
    return;
  }
  if (!_testModeProgressBatchesByQr.containsKey(batch.qrPayload)) {
    _testModeProgressBatchesByQr[batch.qrPayload] = batch;
  }
}

Future<List<AdminApparatus>> _trainingApparatusCatalog() {
  return MobileApi.instance.adminApparatus(limit: 10000);
}

extension MobileApiAdminTrainingWorkspace on MobileApi {
  Future<List<AdminApparatus>> adminTrainingApparatus() async {
    final apparatus = await _trainingApparatusCatalog();
    final modes = await adminTrainingApparatusModes();
    return apparatus
        .map(
          (item) => item.copyWith(
            trainingEnabled: modes[item.id] ?? false,
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, bool>> adminTrainingApparatusModes() async {
    if (await TestModeController.instance.isEnabled()) {
      return {
        for (final item in _testModeApparatusCatalog())
          item.id: item.trainingEnabled,
      };
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/training/apparatus'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'training_apparatus_modes',
      );
    }
    final payload = await decodeJsonMapPayload(response.body);
    final raw = payload['modes'];
    if (raw is! Map) {
      return const <String, bool>{};
    }
    final modes = <String, bool>{};
    for (final entry in raw.entries) {
      final apparatusId = entry.key.toString().trim();
      _validateTrainingPhysicalApparatusId(apparatusId);
      modes[apparatusId] = entry.value == true;
    }
    return modes;
  }

  Future<void> adminSetTrainingApparatusMode({
    required AdminApparatus apparatus,
    required bool enabled,
  }) async {
    final apparatusId = apparatus.id.trim();
    _validateTrainingPhysicalApparatusId(apparatusId);
    if (await TestModeController.instance.isEnabled()) {
      final catalog = await _trainingApparatusCatalog();
      final current = catalog.firstWhere(
        (item) => item.id == apparatusId,
        orElse: () => throw const MobileApiException(
          code: 'training_apparatus_not_found',
          message: 'Aparat topilmadi',
        ),
      );
      await adminCreateApparatus(
        current.name,
        id: current.id,
        family: current.family,
        kind: current.kind,
        capabilities: current.capabilities,
        capabilityProfiles: current.capabilityProfiles,
        colorStations: current.colorStations,
        factoryMapObjectId: current.factoryMapObjectId,
        trainingEnabled: enabled,
      );
      return;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/training/apparatus'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'apparatus': apparatusId, 'enabled': enabled}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'training_apparatus_mode_save',
      );
    }
  }

  Future<void> adminRestartTraining({String apparatus = ''}) async {
    final normalizedApparatus = apparatus.trim();
    _validateTrainingPhysicalApparatusId(
      normalizedApparatus,
      allowEmpty: true,
    );
    if (await TestModeController.instance.isEnabled()) {
      bool matchesApparatus(String candidate) {
        return normalizedApparatus.isEmpty ||
            candidate.trim() == normalizedApparatus;
      }

      final trainingOrderIds = <String>{};
      for (final entry in _testModeApparatusQueueStates.entries) {
        if (!matchesApparatus(entry.key)) {
          continue;
        }
        trainingOrderIds.addAll(
          entry.value.keys.where(
            (orderId) => orderId.trim().startsWith('training-'),
          ),
        );
      }
      for (final entry in _testModeApparatusSequences.entries) {
        if (!matchesApparatus(entry.key)) {
          continue;
        }
        trainingOrderIds.addAll(
          entry.value.where(
            (orderId) => orderId.trim().startsWith('training-'),
          ),
        );
      }
      for (final saved in _testModeProductionMaps) {
        final orderId = saved.map.id.trim();
        if (!orderId.startsWith('training-')) {
          continue;
        }
        final belongsToApparatus = saved.map.nodes.any(
          (node) =>
              node.kind == 'apparatus' && matchesApparatus(node.apparatusId),
        );
        if (belongsToApparatus) {
          trainingOrderIds.add(orderId);
        }
      }
      for (final entry in _testModeApparatusQueueStates.entries) {
        if (!matchesApparatus(entry.key)) {
          continue;
        }
        entry.value.removeWhere(
          (orderId, _) => orderId.trim().startsWith('training-'),
        );
      }
      _testModeCompletedQueueOrders.removeWhere(
        (item) => trainingOrderIds.contains(item.order.orderId.trim()),
      );
      _testModeProgressBatchesByQr.removeWhere(
        (_, batch) => trainingOrderIds.contains(batch.orderId.trim()),
      );
      for (final saved in _testModeProductionMaps) {
        if (trainingOrderIds.contains(saved.map.id.trim())) {
          _ensureTestModeTrainingInputBatch(saved.map, reset: true);
        }
      }
      _testModeActiveProgressInputByQueue.removeWhere((key, _) {
        final separator = key.indexOf('|');
        if (separator < 0) {
          return false;
        }
        final orderId = key.substring(separator + 1).trim();
        return trainingOrderIds.contains(orderId);
      });
      _testModeOrderStartedAtUnix.removeWhere(
        (orderId, _) => trainingOrderIds.contains(orderId.trim()),
      );
      _testModeOrderControls.removeWhere(
        (orderId, _) => trainingOrderIds.contains(orderId.trim()),
      );
      return;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/training/restart'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'apparatus': normalizedApparatus}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'training_restart');
    }
  }

  Future<List<AdminCompletedQueueOrder>>
      adminTrainingCompletedProductionMapOrders() async {
    if (await TestModeController.instance.isEnabled()) {
      final actorRef = AppSession.instance.profile?.ref.trim() ?? '';
      return [
        for (final item in _testModeCompletedQueueOrders)
          if (item.actorRef == actorRef &&
              item.order.orderId.trim().startsWith('training-'))
            item.order,
      ];
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/training/completed-orders',
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'training_completed_orders');
    }
    final payload = await decodeJsonMapPayload(response.body);
    final raw = payload['completed_orders'];
    if (raw is! List) {
      throw const MobileApiException(
        code: 'training_completed_orders_invalid_response',
        message: 'Training yakunlangan orderlar javobi noto‘g‘ri',
      );
    }
    final completed = <AdminCompletedQueueOrder>[];
    for (final item in raw) {
      if (item is! Map) {
        throw const MobileApiException(
          code: 'training_completed_orders_invalid_response',
          message: 'Training yakunlangan orderlar javobi noto‘g‘ri',
        );
      }
      final order = AdminCompletedQueueOrder.fromJson(
        item.cast<String, dynamic>(),
      );
      _validateTrainingPhysicalApparatusId(order.apparatus);
      completed.add(order);
    }
    return completed;
  }

  Future<Map<String, AdminTrainingOrderStatus>>
      adminTrainingOrderStatuses() async {
    if (await TestModeController.instance.isEnabled()) {
      final completedByOrderId = <String, AdminCompletedQueueOrder>{
        for (final item in _testModeCompletedQueueOrders)
          if (item.order.orderId.trim().startsWith('training-'))
            item.order.orderId.trim(): item.order,
      };
      final statuses = <String, AdminTrainingOrderStatus>{};
      for (final saved in _testModeProductionMaps) {
        final orderId = saved.map.id.trim();
        if (!orderId.startsWith('training-')) {
          continue;
        }
        final apparatusId = saved.map.nodes
            .where((node) => node.kind == 'apparatus')
            .map((node) => node.apparatusId.trim())
            .firstWhere((id) => id.isNotEmpty, orElse: () => '');
        var state = 'pending';
        for (final entry in _testModeApparatusQueueStates.entries) {
          if (apparatusId.isNotEmpty && entry.key.trim() != apparatusId) {
            continue;
          }
          final candidate = entry.value[orderId]?.trim() ?? '';
          if (candidate.isNotEmpty) {
            state = candidate;
            break;
          }
        }
        final completed = completedByOrderId[orderId];
        if (completed != null && state == 'pending') {
          state = completed.status.trim().isEmpty
              ? 'completed'
              : completed.status.trim();
        }
        statuses[orderId] = AdminTrainingOrderStatus(
          orderId: orderId,
          apparatus: completed?.apparatus.trim().isNotEmpty == true
              ? completed!.apparatus
              : apparatusId,
          state: state,
          updatedAtUnix: completed?.completedAtUnix ?? 0,
          completedAtUnix:
              state == 'completed' ? completed?.completedAtUnix ?? 0 : 0,
        );
      }
      return statuses;
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/training/statuses'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'training_statuses');
    }
    final payload = await decodeJsonMapPayload(response.body);
    final raw = payload['statuses'];
    if (raw is! Map) {
      throw const MobileApiException(
        code: 'training_statuses_invalid_response',
        message: 'Training holatlari javobi noto‘g‘ri',
      );
    }
    final statuses = <String, AdminTrainingOrderStatus>{};
    for (final entry in raw.entries) {
      final orderId = entry.key.toString().trim();
      if (!orderId.startsWith('training-') || entry.value is! Map) {
        throw const MobileApiException(
          code: 'training_statuses_invalid_response',
          message: 'Training holatlari javobi noto‘g‘ri',
        );
      }
      final status = AdminTrainingOrderStatus.fromJson(
        (entry.value as Map).cast<String, dynamic>(),
      );
      if (status.orderId != orderId) {
        throw const MobileApiException(
          code: 'training_statuses_invalid_response',
          message: 'Training holatlari javobi noto‘g‘ri',
        );
      }
      statuses[orderId] = status;
    }
    return statuses;
  }

  Future<List<ProductionMapSaved>> adminTrainingProductionMaps({
    String id = '',
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      if (id.trim().isEmpty) {
        for (final saved in _testModeProductionMaps) {
          _ensureTestModeTrainingInputBatch(saved.map);
        }
        return List<ProductionMapSaved>.unmodifiable(_testModeProductionMaps);
      }
      final matches = _testModeProductionMaps
          .where((item) => item.map.id.trim() == id.trim())
          .toList(growable: false);
      for (final saved in matches) {
        _ensureTestModeTrainingInputBatch(saved.map);
      }
      return matches;
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/training/production-maps',
        ).replace(queryParameters: {if (id.trim().isNotEmpty) 'id': id.trim()}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'training_maps_list');
    }
    final payload = await decodeJsonPayload(response.body);
    if (payload is List) {
      final maps = <ProductionMapSaved>[];
      for (final item in payload) {
        if (item is! Map) {
          throw const MobileApiException(
            code: 'training_map_invalid_response',
            message: 'Training map javobi noto‘g‘ri',
          );
        }
        try {
          final saved = ProductionMapSaved.fromJson(
            item.cast<String, dynamic>(),
          );
          _validateTrainingMapApparatus(saved.map);
          maps.add(saved);
        } on FormatException {
          throw const MobileApiException(
            code: 'training_map_invalid_response',
            message: 'Training map javobi noto‘g‘ri',
          );
        }
      }
      return maps;
    }
    final saved = ProductionMapSaved.fromJson(
      (payload as Map).cast<String, dynamic>(),
    );
    _validateTrainingMapApparatus(saved.map);
    return [saved];
  }

  Future<List<AdminProgressBatch>> adminTrainingInputBatches({
    String orderId = '',
    String apparatus = '',
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedApparatus = apparatus.trim();
    _validateTrainingPhysicalApparatusId(
      normalizedApparatus,
      allowEmpty: true,
    );
    if (await TestModeController.instance.isEnabled()) {
      return [
        for (final batch in _testModeProgressBatchesByQr.values)
          if (batch.payloadJson['training_input'] == true &&
              _testModeTrainingInputBatchGeneratedOrderIds.contains(
                batch.orderId.trim(),
              ) &&
              (normalizedOrderId.isEmpty ||
                  batch.orderId.trim() == normalizedOrderId) &&
              (normalizedApparatus.isEmpty ||
                  batch.nextApparatus.trim() == normalizedApparatus))
            batch,
      ];
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/training/input-batches',
        ).replace(
          queryParameters: {
            if (normalizedOrderId.isNotEmpty) 'order_id': normalizedOrderId,
            if (normalizedApparatus.isNotEmpty)
              'apparatus': normalizedApparatus,
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'training_input_batches');
    }
    final payload = await decodeJsonMapPayload(response.body);
    final raw = payload['batches'];
    if (raw is! List) {
      throw const MobileApiException(
        code: 'training_input_batch_invalid_response',
        message: 'Training batch javobi noto‘g‘ri',
      );
    }
    final batches = <AdminProgressBatch>[];
    for (final item in raw) {
      if (item is! Map) {
        throw const MobileApiException(
          code: 'training_input_batch_invalid_response',
          message: 'Training batch javobi noto‘g‘ri',
        );
      }
      final batch = AdminProgressBatch.fromJson(item.cast<String, dynamic>());
      _validateTrainingInputBatch(batch);
      batches.add(batch);
    }
    return batches;
  }

  Future<List<AdminProgressBatch>> adminGenerateTrainingInputBatches({
    required String orderId,
    String apparatus = '',
    int count = 1,
  }) async {
    final normalizedOrderId = orderId.trim();
    _validateTrainingPhysicalApparatusId(apparatus, allowEmpty: true);
    if (normalizedOrderId.isEmpty ||
        !normalizedOrderId.startsWith('training-')) {
      throw const MobileApiException(
        code: 'training_order_required',
        message: 'Training order tanlanmadi',
      );
    }
    if (count < 1 || count > 100) {
      throw const MobileApiException(
        code: 'training_input_batch_count_invalid',
        message: 'Batch soni 1 dan 100 tagacha bo‘lishi kerak',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final saved = _testModeProductionMaps.firstWhere(
        (item) => item.map.id.trim() == normalizedOrderId,
        orElse: () => throw const MobileApiException(
          code: 'training_map_not_found',
          message: 'Training order topilmadi',
        ),
      );
      final station = apparatus.trim().isEmpty
          ? _trainingInputTargetStation(saved.map)
          : apparatus.trim();
      if (station == null) {
        throw const MobileApiException(
          code: 'training_input_batch_not_applicable',
          message: 'Bu order uchun training batch yaratib bo‘lmaydi',
        );
      }
      final storageKey = station;
      final queueState = apparatusQueueOrderStateFromRaw(
        _testModeApparatusQueueStates[storageKey]?[normalizedOrderId],
      );
      final inputSetStarted = _testModeTrainingInputBatchSetClosedOrderIds
          .contains(normalizedOrderId);
      if (queueState != ApparatusQueueOrderState.pending || inputSetStarted) {
        throw const MobileApiException(
          code: 'training_input_batch_set_closed',
          message:
              'Ish boshlanganidan keyin yangi training batch qo‘shib bo‘lmaydi',
        );
      }
      final batches = <AdminProgressBatch>[];
      for (var index = 0; index < count; index += 1) {
        final batch = _testModeTrainingInputProgressBatch(
          map: saved.map,
          station: station,
          forceNewIdentity: true,
        );
        if (batch == null) {
          throw const MobileApiException(
            code: 'training_input_batch_not_applicable',
            message: 'Bu order uchun training batch yaratib bo‘lmaydi',
          );
        }
        _testModeProgressBatchesByQr[batch.qrPayload] = batch;
        batches.add(batch);
      }
      _testModeTrainingInputBatchGeneratedOrderIds.add(normalizedOrderId);
      return List<AdminProgressBatch>.unmodifiable(batches);
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/training/input-batches',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'order_id': normalizedOrderId,
          if (apparatus.trim().isNotEmpty) 'apparatus': apparatus.trim(),
          'count': count,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'training_input_batch_generate',
      );
    }
    final payload = await decodeJsonMapPayload(response.body);
    final raw = payload['batches'];
    final batches = [
      if (raw is List)
        for (final item in raw)
          if (item is Map)
            AdminProgressBatch.fromJson(item.cast<String, dynamic>()),
    ];
    if (batches.isEmpty) {
      final batch = payload['batch'];
      if (batch is Map) {
        batches.add(AdminProgressBatch.fromJson(batch.cast<String, dynamic>()));
      }
    }
    if (batches.isEmpty) {
      throw const MobileApiException(
        code: 'training_input_batch_invalid_response',
        message: 'Training batch javobi noto‘g‘ri',
      );
    }
    return List<AdminProgressBatch>.unmodifiable(batches);
  }

  Future<AdminProgressBatch> adminGenerateTrainingInputBatch({
    required String orderId,
    String apparatus = '',
  }) async {
    final batches = await adminGenerateTrainingInputBatches(
      orderId: orderId,
      apparatus: apparatus,
    );
    return batches.first;
  }

  Future<void> adminDeleteTrainingInputBatch({
    required String orderId,
    String apparatus = '',
    String qrPayload = '',
  }) async {
    final normalizedOrderId = orderId.trim();
    _validateTrainingPhysicalApparatusId(apparatus, allowEmpty: true);
    if (normalizedOrderId.isEmpty ||
        !normalizedOrderId.startsWith('training-')) {
      throw const MobileApiException(
        code: 'training_order_required',
        message: 'Training order tanlanmadi',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final removed = _testModeProgressBatchesByQr.values.any(
        (batch) =>
            batch.payloadJson['training_input'] == true &&
            batch.orderId.trim() == normalizedOrderId &&
            (qrPayload.trim().isEmpty ||
                batch.qrPayload.trim().toLowerCase() ==
                    qrPayload.trim().toLowerCase()),
      );
      if (!removed) {
        throw const MobileApiException(
          code: 'training_input_batch_not_found',
          message: 'Training batch topilmadi',
        );
      }
      _testModeProgressBatchesByQr.removeWhere(
        (_, batch) =>
            batch.payloadJson['training_input'] == true &&
            batch.orderId.trim() == normalizedOrderId &&
            (qrPayload.trim().isEmpty ||
                batch.qrPayload.trim().toLowerCase() ==
                    qrPayload.trim().toLowerCase()),
      );
      final hasRemainingBatches = _testModeProgressBatchesByQr.values.any(
        (batch) =>
            batch.payloadJson['training_input'] == true &&
            batch.orderId.trim() == normalizedOrderId,
      );
      if (!hasRemainingBatches) {
        _testModeTrainingInputBatchGeneratedOrderIds.remove(normalizedOrderId);
      }
      return;
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/training/input-batches',
        ).replace(
          queryParameters: {
            'order_id': normalizedOrderId,
            if (apparatus.trim().isNotEmpty) 'apparatus': apparatus.trim(),
            if (qrPayload.trim().isNotEmpty) 'qr_payload': qrPayload.trim(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'training_input_batch_delete',
      );
    }
  }

  Future<ProductionMapSaved> adminSaveTrainingProductionMap(
    ProductionMapDefinition map,
  ) async {
    _requireCanonicalProductionMapApparatusIds(map);
    _validateTrainingMapApparatus(map);
    if (await TestModeController.instance.isEnabled()) {
      final saved = await adminSaveProductionMap(
        _testModePrepareTrainingMapForSave(map),
      );
      _ensureTestModeTrainingInputBatch(saved.map);
      return saved;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/training/production-maps',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(map.toJson()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'training_map_save');
    }
    return ProductionMapSaved.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> adminDeleteTrainingProductionMap(String orderId) async {
    final normalized = orderId.trim();
    if (normalized.isEmpty || !normalized.startsWith('training-')) {
      throw const MobileApiException(
        code: 'training_order_required',
        message: 'Training order tanlanmadi',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final exists = _testModeProductionMaps.any(
        (saved) => saved.map.id.trim() == normalized,
      );
      if (!exists) {
        throw const MobileApiException(
          code: 'training_map_not_found',
          message: 'Training order topilmadi',
        );
      }
      _testModeProductionMaps.removeWhere(
        (saved) => saved.map.id.trim() == normalized,
      );
      _testModeRawMaterialAssignments.removeWhere(
        (assignment) => assignment.orderId.trim() == normalized,
      );
      _testModeInventoryAssets.removeWhere(
        (asset) =>
            asset.assetRef.startsWith('training-raw-material:$normalized:'),
      );
      _testModeProgressBatchesByQr.removeWhere(
        (_, batch) => batch.orderId.trim() == normalized,
      );
      _testModeTrainingInputBatchGeneratedOrderIds.remove(normalized);
      _testModeTrainingInputBatchSetClosedOrderIds.remove(normalized);
      _testModeCompletedQueueOrders.removeWhere(
        (entry) => entry.order.orderId.trim() == normalized,
      );
      _testModeOrderStartedAtUnix.remove(normalized);
      _testModeOrderControls.remove(normalized);
      _testModeQolipOrderNotes.remove(normalized);
      for (final sequence in _testModeApparatusSequences.values) {
        sequence.removeWhere((id) => id.trim() == normalized);
      }
      for (final states in _testModeApparatusQueueStates.values) {
        states.remove(normalized);
      }
      return;
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/training/production-maps',
        ).replace(queryParameters: {'id': normalized}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'training_map_delete');
    }
  }

  Future<List<AdminRawMaterialAssignment>> adminTrainingRawMaterialAssignments({
    String orderId = '',
    String apparatus = '',
  }) async {
    _validateTrainingPhysicalApparatusId(apparatus, allowEmpty: true);
    if (await TestModeController.instance.isEnabled()) {
      return adminRawMaterialAssignments(
        orderId: orderId,
        apparatus: apparatus,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/training/raw-material-assignments',
        ).replace(
          queryParameters: {
            if (orderId.trim().isNotEmpty) 'order_id': orderId.trim(),
            if (apparatus.trim().isNotEmpty) 'apparatus': apparatus.trim(),
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'training_material_assignments',
      );
    }
    final payload = await decodeJsonListPayload(response.body);
    final assignments = <AdminRawMaterialAssignment>[];
    for (final item in payload) {
      if (item is! Map) {
        debugPrint(
          'Admin training material assignment list skipped a non-object item',
        );
        continue;
      }
      try {
        final assignment = AdminRawMaterialAssignment.fromJson(
          item.cast<String, dynamic>(),
        );
        _validateTrainingPhysicalApparatusId(assignment.apparatus);
        assignments.add(assignment);
      } on FormatException {
        throw const MobileApiException(
          code: 'training_material_assignment_invalid_response',
          message: 'Training homashyo javobi noto‘g‘ri',
        );
      }
    }
    return assignments;
  }

  Future<void> adminDeleteTrainingRawMaterial({
    required String orderId,
    required String apparatus,
    required String barcode,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedApparatus = apparatus.trim();
    final normalizedBarcode = barcode.trim().toUpperCase();
    _validateTrainingPhysicalApparatusId(normalizedApparatus);
    if (normalizedOrderId.isEmpty ||
        !normalizedOrderId.startsWith('training-') ||
        normalizedApparatus.isEmpty ||
        normalizedBarcode.isEmpty) {
      throw const MobileApiException(
        code: 'training_material_assignment_required',
        message: 'Training homashyo tanlanmadi',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeRawMaterialAssignments.indexWhere(
        (assignment) =>
            assignment.orderId.trim() == normalizedOrderId &&
            assignment.apparatus.trim() == normalizedApparatus &&
            assignment.barcode.trim().toUpperCase() == normalizedBarcode,
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'training_material_assignment_not_found',
          message: 'Training homashyo topilmadi',
        );
      }
      _testModeRawMaterialAssignments.removeAt(index);
      _testModeInventoryAssets.removeWhere(
        (asset) =>
            asset.identifier.trim().toUpperCase() == normalizedBarcode &&
            asset.assetRef ==
                'training-raw-material:$normalizedOrderId:'
                    '$normalizedApparatus:$normalizedBarcode',
      );
      return;
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/training/raw-material-assignments',
        ).replace(
          queryParameters: {
            'order_id': normalizedOrderId,
            'apparatus': normalizedApparatus,
            'barcode': normalizedBarcode,
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'training_material_assignment_delete',
      );
    }
  }

  Future<ProductionMapSaveWithOrderResult>
      adminSaveTrainingProductionMapWithOrder({
    required ProductionMapDefinition map,
    required CalculateOrderTemplate template,
  }) async {
    _requireCanonicalProductionMapApparatusIds(map);
    _validateTrainingMapApparatus(map);
    if (await TestModeController.instance.isEnabled()) {
      final trainingMap = _testModePrepareTrainingMapForSave(map);
      final saved = await adminSaveProductionMapWithOrder(
        map: trainingMap,
        template: template,
      );
      _ensureTestModeTrainingInputBatch(saved.saved.map);
      return saved;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/training/production-maps/with-order',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'map': map.toJson(), 'template': template.toJson()}),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'training_map_save_with_order',
      );
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductionMapSaveWithOrderResult(
      saved: ProductionMapSaved.fromJson(
        (payload['saved'] as Map).cast<String, dynamic>(),
      ),
      template: payload['template'] is Map
          ? CalculateOrderTemplate.fromJson(
              (payload['template'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }

  Future<CalculateOrderImage> uploadTrainingCalculateOrderImage({
    required List<int> bytes,
    required String filename,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return CalculateOrderImage(
        imageId: 'training-test-image-${DateTime.now().microsecondsSinceEpoch}',
        imageName: filename.trim().isEmpty ? 'rang.jpg' : filename.trim(),
        imageMime: 'image/jpeg',
        imageSizeBytes: bytes.length,
        imageUrl: '',
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/training/images'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'image/jpeg'
          ..['x-file-name'] = filename,
        body: bytes,
      ),
    );
    final payload = await decodeJsonMapPayload(response.body);
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'training_image_save');
    }
    final raw = payload['image'];
    return CalculateOrderImage.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{},
    );
  }

  Future<ReturnedPaintImage> uploadTrainingReturnedPaintImage({
    required List<int> bytes,
    required String filename,
    required String mime,
  }) async {
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/training/images'),
        headers: _headers(requireToken())
          ..['Content-Type'] = mime
          ..['x-file-name'] = filename,
        body: bytes,
      ),
    );
    final payload = await decodeJsonMapPayload(response.body);
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'training_returned_paint_image_save',
      );
    }
    final raw = payload['image'];
    return ReturnedPaintImage.fromJson(
      raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{},
    );
  }

  Future<void> deleteTrainingReturnedPaintImage(String imageId) async {
    final normalized = imageId.trim();
    if (normalized.isEmpty) return;
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/training/images',
        ).replace(queryParameters: {'id': normalized}),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminProductionMapException(
        response,
        'training_returned_paint_image_delete',
      );
    }
  }
}

class AdminTrainingOrderStatus {
  const AdminTrainingOrderStatus({
    required this.orderId,
    required this.apparatus,
    required this.state,
    this.action = '',
    this.actorRef = '',
    this.actorDisplayName = '',
    this.updatedAtUnix = 0,
    this.completedAtUnix = 0,
  });

  final String orderId;
  final String apparatus;
  final String state;
  final String action;
  final String actorRef;
  final String actorDisplayName;
  final int updatedAtUnix;
  final int completedAtUnix;

  bool get isCompleted => state.trim().toLowerCase() == 'completed';

  factory AdminTrainingOrderStatus.fromJson(Map<String, dynamic> json) {
    int readInt(Object? value) => value is num ? value.toInt() : 0;
    final orderId = json['order_id']?.toString().trim() ?? '';
    final apparatus = json['apparatus']?.toString().trim() ?? '';
    if (!orderId.startsWith('training-') ||
        !isCanonicalApparatusId(apparatus)) {
      throw const FormatException('Invalid canonical training order status');
    }
    return AdminTrainingOrderStatus(
      orderId: orderId,
      apparatus: apparatus,
      state: json['state']?.toString().trim().isNotEmpty == true
          ? json['state'].toString().trim()
          : json['status']?.toString().trim() ?? 'pending',
      action: json['action']?.toString() ?? '',
      actorRef: json['actor_ref']?.toString() ?? '',
      actorDisplayName: json['actor_display_name']?.toString() ?? '',
      updatedAtUnix: readInt(json['updated_at_unix']),
      completedAtUnix: readInt(json['completed_at_unix']),
    );
  }
}

extension MobileApiAdminTraining on MobileApi {
  /// Creates the complete test-mode representation of a training material:
  /// order assignment, an inventory asset, and a state location in front of
  /// the selected apparatus.
  ///
  /// Production persistence uses the server-backed training workspace. The
  /// local branch remains available only when the explicit client test mode is
  /// enabled.
  Future<AdminRawMaterialAssignment> adminLinkTrainingRawMaterial({
    required String orderId,
    required String apparatus,
    required String materialId,
    required String materialName,
    required int micron,
    required String barcode,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedApparatus = apparatus.trim();
    final normalizedMaterialId = materialId.trim();
    final normalizedMaterialName = materialName.trim();
    final normalizedBarcode = barcode.trim().toUpperCase();
    _validateTrainingPhysicalApparatusId(normalizedApparatus);
    if (normalizedOrderId.isEmpty ||
        normalizedApparatus.isEmpty ||
        normalizedMaterialName.isEmpty ||
        normalizedBarcode.isEmpty ||
        micron <= 0) {
      throw const MobileApiException(
        code: 'training_material_invalid',
        message: 'Order, aparat, homashyo va micronni to‘liq kiriting',
      );
    }
    final displayName = '$normalizedMaterialName / $micron mikron';
    final itemCode = normalizedMaterialId.isEmpty
        ? 'TRAINING-MATERIAL'
        : normalizedMaterialId;

    if (!await TestModeController.instance.isEnabled()) {
      final response = await _sendAuthorized(
        () => _post(
          Uri.parse(
            '${MobileApi.baseUrl}/v1/mobile/admin/training/raw-material-assignments',
          ),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({
            'order_id': normalizedOrderId,
            'apparatus': normalizedApparatus,
            'barcode': normalizedBarcode,
            'material_id': normalizedMaterialId,
            'material_name': normalizedMaterialName,
            'micron': micron,
            'item_code': itemCode,
            'item_name': displayName,
            'item_group': normalizedMaterialName,
            'assigned_by_ref': AppSession.instance.profile?.ref ?? '',
            'assigned_by_display_name':
                AppSession.instance.profile?.displayName ?? '',
            'assigned_at': DateTime.now().toUtc().toIso8601String(),
            'stock_status': 'available',
            'stock_warehouse': 'Training',
            'stock_qty': 1,
            'stock_uom': 'kg',
            'remaining_qty': 1,
          }),
        ),
      );
      if (response.statusCode != 200) {
        throw _adminProductionMapException(
          response,
          'training_material_assignment',
        );
      }
      return AdminRawMaterialAssignment.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    final orderExists = _testModeProductionMaps.any(
      (saved) => saved.map.id.trim() == normalizedOrderId,
    );
    if (!orderExists) {
      throw const MobileApiException(
        code: 'training_order_not_found',
        message: 'Tanlangan training order topilmadi',
      );
    }
    final duplicate = _testModeRawMaterialAssignments.any(
      (assignment) =>
          assignment.orderId.trim() == normalizedOrderId &&
          assignment.apparatus.trim() == normalizedApparatus &&
          assignment.barcode.trim().toUpperCase() == normalizedBarcode,
    );
    if (duplicate) {
      throw const MobileApiException(
        code: 'training_material_barcode_exists',
        message: 'Bu QR kodi shu order uchun allaqachon ulangan',
      );
    }

    final canonicalApparatus = _testModeRequiredApparatus(normalizedApparatus);
    final locationId = 'training-apparatus:$normalizedApparatus';
    final locationName = 'Training: ${canonicalApparatus.name}';
    final locationReference = InventoryLocationReference(
      id: locationId,
      kind: InventoryLocationKind.state,
      name: locationName,
    );
    _upsertTrainingApparatusLocation(
      locationId: locationId,
      locationName: locationName,
      apparatus: normalizedApparatus,
    );

    final assignment = AdminRawMaterialAssignment(
      orderId: normalizedOrderId,
      apparatus: normalizedApparatus,
      barcode: normalizedBarcode,
      itemCode: itemCode,
      itemName: displayName,
      itemGroup: normalizedMaterialName,
      assignedByRef: AppSession.instance.profile?.ref ?? '',
      assignedByName: AppSession.instance.profile?.displayName ?? '',
      assignedAt: DateTime.now().toUtc().toIso8601String(),
      stockStatus: 'available',
      stockWarehouse: 'Training',
      stockQty: 1,
      stockUom: 'kg',
      remainingQty: 1,
    );
    _testModeRawMaterialAssignments.add(assignment);
    _testModeInventoryAssets.add(
      InventoryAsset(
        kind: InventoryAssetKind.rawMaterial,
        assetRef:
            'training-raw-material:$normalizedOrderId:$normalizedApparatus:$normalizedBarcode',
        custodyWarehouseId: 'training',
        custodyWarehouse: 'Training',
        itemCode: itemCode,
        itemName: displayName,
        identifier: normalizedBarcode,
        qty: 1,
        uom: 'kg',
        status: 'available',
        physicalLocation: locationReference,
      ),
    );
    return assignment;
  }
}

void _upsertTrainingApparatusLocation({
  required String locationId,
  required String locationName,
  required String apparatus,
}) {
  final canonical = _testModeRequiredApparatus(apparatus);
  final index = _testModeInventoryLocations.indexWhere(
    (location) => location.id == locationId,
  );
  if (index < 0) {
    _testModeInventoryLocations.add(
      InventoryLocation(
        id: locationId,
        kind: InventoryLocationKind.state,
        name: locationName,
        apparatus: [
          InventoryLocationApparatus(
            id: canonical.id,
            name: canonical.name,
          ),
        ],
      ),
    );
    return;
  }
  final current = _testModeInventoryLocations[index];
  final hasApparatus = current.apparatus.any(
    (linked) => linked.id.trim() == canonical.id.trim(),
  );
  if (hasApparatus) {
    return;
  }
  _testModeInventoryLocations[index] = InventoryLocation(
    id: current.id,
    kind: current.kind,
    name: current.name,
    warehouseId: current.warehouseId,
    factoryLocationId: current.factoryLocationId,
    active: current.active,
    apparatus: [
      ...current.apparatus,
      InventoryLocationApparatus(
        id: canonical.id,
        name: canonical.name,
      ),
    ],
  );
}
