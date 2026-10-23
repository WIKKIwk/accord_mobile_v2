part of '../mobile_api.dart';

const workerOrderListProjection = 'worker_list_v1';
const workerOrderDetailProjection = 'worker_detail_v1';
final _workerPresentationRows = Expando<ProductionMapSaved>();
final _workerPresentationOrders = Expando<bool>();

/// True only for an explicitly tagged display row, never for a canonical map.
bool isWorkerListPresentationOrder(ProductionMapSaved saved) =>
    _workerPresentationOrders[saved] == true;

/// A worker card has no route graph, program, action contract or editor data.
class WorkerOrderListRow {
  const WorkerOrderListRow({
    required this.id,
    required this.code,
    required this.title,
    required this.customerName,
    required this.imageId,
  });
  final String id, code, title, customerName, imageId;

  factory WorkerOrderListRow.fromJson(Map<String, dynamic> json) {
    _validateOrderListLabels(json);
    return WorkerOrderListRow(
        id: json['id'] as String,
        code: json['code'] as String,
        title: json['title'] as String,
        customerName: json['customer_name'] as String,
        imageId: json['image_id'] as String);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'title': title,
        'customer_name': customerName,
        'image_id': imageId,
      };

  /// Compatibility for display widgets only. Never use this shell for QR,
  /// actions, controls or persistence as a complete production map.
  ProductionMapSaved toPresentationOrder() {
    final cached = _workerPresentationRows[this];
    if (cached != null) return cached;
    final saved = ProductionMapSaved(
        map: ProductionMapDefinition(
            id: id,
            code: code,
            title: title,
            productCode: '',
            customerName: customerName,
            imageId: imageId,
            nodes: const [],
            edges: const []),
        program: ProductionMapProgram(
            mapId: id, productCode: '', operations: const []));
    _workerPresentationOrders[saved] = true;
    return _workerPresentationRows[this] = saved;
  }
}

class WorkerStageReportPrompt {
  const WorkerStageReportPrompt(
      {required this.reportSessionId, required this.upstreamTitle});
  final String reportSessionId;
  final String upstreamTitle;
  factory WorkerStageReportPrompt.fromJson(Map<String, dynamic> json) {
    if (json['report_session_id'] is! String ||
        (json['report_session_id'] as String).trim().isEmpty ||
        json['upstream_title'] is! String) {
      throw _productionMapQueueContractException(
          'invalid worker report prompt');
    }
    return WorkerStageReportPrompt(
        reportSessionId: json['report_session_id'] as String,
        upstreamTitle: json['upstream_title'] as String);
  }
  Map<String, dynamic> toJson() => {
        'report_session_id': reportSessionId,
        'upstream_title': upstreamTitle,
      };
}

const _workerListForbiddenFields = {
  'maps',
  'stage_states',
  'queue_action_controls',
  'stage_order_controls',
  'order_statuses',
  'frozen_orders_by_apparatus',
  'calculation_templates',
  'order_customers',
};
const _workerListFields = {
  'worker_list_rows',
  'worker_display_states',
  'worker_report_prompts',
};

Map<String, WorkerOrderListRow> _parseWorkerListRows(Object? raw) {
  if (raw is! Map) {
    throw _productionMapQueueContractException('worker rows must be an object');
  }
  final rows = <String, WorkerOrderListRow>{};
  for (final entry in raw.entries) {
    if (entry.key is! String || entry.value is! Map) {
      throw _productionMapQueueContractException('invalid worker row');
    }
    final row = WorkerOrderListRow.fromJson(
        (entry.value as Map).cast<String, dynamic>());
    if (row.id != entry.key) {
      throw _productionMapQueueContractException(
          'worker row identity mismatch');
    }
    rows[entry.key as String] = row;
  }
  return Map.unmodifiable(rows);
}

String _workerDisplayState(Object? raw) {
  if (raw is! String || !adminSequenceListDisplayStates.contains(raw)) {
    throw _productionMapQueueContractException('invalid worker display state');
  }
  return raw;
}

Map<String, Map<String, T>> _parseWorkerListNested<T>(
    Object? raw, T Function(Object?) decode) {
  if (raw is! Map) {
    throw _productionMapQueueContractException(
        'worker scopes must be an object');
  }
  final result = <String, Map<String, T>>{};
  for (final entry in raw.entries) {
    if (entry.key is! String ||
        !isCanonicalApparatusId(entry.key as String) ||
        entry.value is! Map) {
      throw _productionMapQueueContractException(
          'invalid worker apparatus scope');
    }
    final values = <String, T>{};
    for (final order in (entry.value as Map).entries) {
      if (order.key is! String || (order.key as String).trim().isEmpty) {
        throw _productionMapQueueContractException(
            'invalid worker order scope');
      }
      values[order.key as String] = decode(order.value);
    }
    result[entry.key as String] = Map.unmodifiable(values);
  }
  return Map.unmodifiable(result);
}

void _validateWorkerListControls(Object? raw) {
  if (raw is! Map ||
      raw.entries.any((entry) =>
          entry.key is! String ||
          (entry.key as String).trim().isEmpty ||
          entry.value is! Map ||
          (entry.value as Map).length != 1 ||
          !const {'active', 'freeze_requested', 'frozen'}
              .contains((entry.value as Map)['state']))) {
    throw _productionMapQueueContractException(
        'invalid worker display control');
  }
}

AdminProductionMapLiveSnapshot _workerListSnapshotFromJson(
    Map<String, dynamic> json) {
  if (json['projection'] != workerOrderListProjection ||
      _workerListForbiddenFields.any(json.containsKey) ||
      json['rev'] is! int ||
      (json['rev'] as int) < 0 ||
      json['epoch'] is! String ||
      (json['epoch'] as String).isEmpty ||
      json['scope'] is! String ||
      (json['scope'] as String).isEmpty ||
      json['queue_policies'] is! List ||
      json['completed_orders'] is! List ||
      json['completion_requests'] is! List ||
      json['completion_request_decisions'] is! List) {
    throw _productionMapQueueContractException('invalid worker list envelope');
  }
  _requireProductionMapSnapshotShape(
      {...json, 'queue_action_controls': const <String, dynamic>{}},
      includesMaps: false);
  _requireProductionMapStringListMap(json['sequences'], 'sequences');
  _requireProductionMapStringListMap(
      json['visible_order_ids'], 'visible_order_ids');
  _requireProductionMapQueueStates(json['queue_states']);
  _validateWorkerListControls(json['order_controls']);
  final snapshot = AdminProductionMapLiveSnapshot(
    projection: workerOrderListProjection,
    workerListRows: _parseWorkerListRows(json['worker_list_rows']),
    workerDisplayStates: _parseWorkerListNested(
        json['worker_display_states'], _workerDisplayState),
    workerReportPrompts: _parseWorkerListNested(
        json['worker_report_prompts'],
        (value) =>
            WorkerStageReportPrompt.fromJson(_productionMapPatchObject(value))),
    maps: const [],
    sequences: MobileApi.instance.parseApparatusSequenceMap(json['sequences']),
    sequenceVersions: _stringMapOfStrings(json['sequence_versions']),
    sequenceRevisions: _parseSequenceRevisions(json['sequence_revisions']),
    sequencePositionsByApparatus: _parseProductionMapSequencePositions(json),
    visibleOrderIds: _parseRequiredProductionMapVisibleOrderIds(json),
    queueStates:
        MobileApi.instance.parseApparatusQueueStateMap(json['queue_states']),
    queuePolicies:
        MobileApi.instance.parseApparatusQueuePolicyMap(json['queue_policies']),
    orderControls: _parseAdminOrderControls(json['order_controls']),
    completedOrders: [
      for (final raw in json['completed_orders'] as List)
        AdminCompletedQueueOrder.fromJson(_productionMapPatchObject(raw))
    ],
    completionRequests: [
      for (final raw in json['completion_requests'] as List)
        AdminCompletionRequestNotification.fromJson(
            _productionMapPatchObject(raw))
    ],
    completionRequestDecisions: [
      for (final raw in json['completion_request_decisions'] as List)
        AdminCompletionRequestDecisionNotification.fromJson(
            _productionMapPatchObject(raw))
    ],
    revision: json['rev'] as int,
    epoch: json['epoch'] as String,
    scope: json['scope'] as String,
    workerShowAllApparatusTabs: json['worker_show_all_apparatus_tabs'] == true,
  );
  snapshot.validateContract();
  return snapshot;
}

void _validateWorkerListSnapshot(AdminApparatusQueueSnapshot snapshot) {
  if (snapshot.maps.isNotEmpty ||
      snapshot.queueActionControls.isNotEmpty ||
      snapshot.stageStates.isNotEmpty ||
      snapshot.stageOrderControls.isNotEmpty ||
      snapshot.stageFreezeSupported ||
      snapshot.orderStatuses.isNotEmpty ||
      snapshot.frozenOrdersByApparatus.isNotEmpty ||
      snapshot.calculationTemplates.isNotEmpty ||
      snapshot.orderCustomers.isNotEmpty ||
      snapshot.earlyClosingOrderIds.isNotEmpty ||
      snapshot.workerListRows.entries.any((e) => e.key != e.value.id)) {
    throw _productionMapQueueContractException(
        'worker list contains canonical data');
  }
  for (final values in snapshot.visibleOrderIds.values) {
    if (values.any((id) => !snapshot.workerListRows.containsKey(id))) {
      throw _productionMapQueueContractException('missing visible worker row');
    }
  }
  if (snapshot is AdminProductionMapLiveSnapshot &&
      snapshot.completedOrders.any(
          (order) => !snapshot.workerListRows.containsKey(order.orderId))) {
    throw _productionMapQueueContractException('missing completed worker row');
  }
  for (final scope in snapshot.visibleOrderIds.entries) {
    if (scope.value.any((id) =>
        snapshot.workerDisplayStates[scope.key]?[id] == null ||
        snapshot.queueStates[scope.key]?[id] == null)) {
      throw _productionMapQueueContractException(
          'missing worker display state');
    }
  }
  for (final scope in snapshot.workerDisplayStates.entries) {
    if (!isCanonicalApparatusId(scope.key) ||
        scope.value.entries.any((e) =>
            !snapshot.workerListRows.containsKey(e.key) ||
            !adminSequenceListDisplayStates.contains(e.value))) {
      throw _productionMapQueueContractException(
          'invalid worker display membership');
    }
  }
  for (final scope in snapshot.workerReportPrompts.entries) {
    if (!isCanonicalApparatusId(scope.key) ||
        scope.value.entries.any((e) =>
            !snapshot.workerListRows.containsKey(e.key) ||
            e.value.reportSessionId.isEmpty)) {
      throw _productionMapQueueContractException(
          'invalid worker prompt membership');
    }
  }
}

extension MobileApiWorkerOrderDetail on MobileApi {
  Future<AdminApparatusQueueSnapshot> workerProductionOrderDetail({
    required String apparatus,
    required String orderId,
  }) async {
    final station = _requireCanonicalApparatusId(apparatus);
    final id = orderId.trim();
    if (id.isEmpty) throw _invalidAdminOrderPage();
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/sequence')
              .replace(queryParameters: {
            'worker_scope': 'true',
            'detail': 'true',
            'apparatus': station,
            'order_id': id
          }),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'worker_order_detail');
    }
    final snapshot =
        await decodeProductionMapQueueSnapshotPayload(response.body);
    if ((snapshot.projection.isNotEmpty &&
            snapshot.projection != workerOrderDetailProjection) ||
        snapshot.isWorkerList ||
        snapshot.maps.length != 1 ||
        snapshot.maps.single.map.id != id ||
        snapshot.epoch.isEmpty ||
        snapshot.scope.isEmpty ||
        snapshot.revision == null ||
        snapshot.revision! < 0) {
      throw _productionMapQueueContractException(
          'invalid scoped worker detail');
    }
    return snapshot;
  }
}
