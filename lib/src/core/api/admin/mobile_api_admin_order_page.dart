part of '../mobile_api.dart';

const adminSequenceListProjection = 'sequence_list_v1';
const adminOrdersListProjection = 'orders_list_v1';

/// Diagnostic opt-in for compact admin pages and single-order details.
/// Normal content-encoding negotiation remains the default after comparison.
const adminProductionReadIdentityCompression = bool.fromEnvironment(
    'ACCORD_ADMIN_IDENTITY_COMPRESSION',
    defaultValue: false);
final _adminSequencePresentationOrders = Expando<ProductionMapSaved>();

/// Presentation states are deliberately separate from authoritative work states.
const adminSequenceListDisplayStates = <String>{
  'pending',
  'print_preflight',
  'print_preflight_passed',
  'in_progress',
  'waiting_next_stage',
  'paused',
  'frozen',
  'issue',
  'completed',
};

/// A list row is never an action contract or a complete production map.
class AdminSequenceListRow {
  const AdminSequenceListRow({
    required this.id,
    required this.code,
    required this.title,
    required this.customerName,
    required this.imageId,
    required this.queueState,
    required this.displayState,
    required this.canReorder,
    this.frozen = false,
  });

  final String id;
  final String code;
  final String title;
  final String customerName;
  final String imageId;
  final String queueState;
  final String displayState;
  final bool canReorder;
  final bool frozen;

  factory AdminSequenceListRow.fromJson(Map<String, dynamic> json) {
    const strings = {
      'id',
      'code',
      'title',
      'customer_name',
      'image_id',
      'queue_state',
      'display_state'
    };
    if (strings.any((key) => json[key] is! String) ||
        (json['id'] as String).trim().isEmpty ||
        !_knownApparatusQueueStates.contains(json['queue_state']) ||
        !adminSequenceListDisplayStates.contains(json['display_state']) ||
        json['can_reorder'] is! bool ||
        (json.containsKey('frozen') && json['frozen'] is! bool)) {
      throw _invalidAdminOrderPage();
    }
    return AdminSequenceListRow(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      customerName: json['customer_name'] as String,
      imageId: json['image_id'] as String,
      queueState: json['queue_state'] as String,
      displayState: json['display_state'] as String,
      canReorder: json['can_reorder'] as bool,
      frozen: json['frozen'] as bool? ?? json['queue_state'] == 'frozen',
    );
  }

  /// Compatibility for display widgets only. Never persist this shell as a
  /// canonical map or pass it to an editor/action: hydrate the detail first.
  ProductionMapSaved toPresentationOrder() =>
      _adminSequencePresentationOrders[this] ??= ProductionMapSaved(
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
            mapId: id, productCode: '', operations: const []),
      );
}

/// A compact Orders card; these values carry no editor or action authority.
class AdminOrderListRow {
  const AdminOrderListRow({
    required this.id,
    required this.code,
    required this.title,
    required this.customerName,
    required this.imageId,
    required this.displayState,
    this.watermarks = const [],
  });

  final String id;
  final String code;
  final String title;
  final String customerName;
  final String imageId;
  final String displayState;
  final List<AdminOrderListWatermark> watermarks;

  factory AdminOrderListRow.fromJson(Map<String, dynamic> json) {
    _validateOrderListLabels(json);
    final watermarks = json['watermarks'];
    if (!adminSequenceListDisplayStates.contains(json['display_state']) ||
        watermarks is! List) {
      throw _invalidAdminOrderPage();
    }
    return AdminOrderListRow(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      customerName: json['customer_name'] as String,
      imageId: json['image_id'] as String,
      displayState: json['display_state'] as String,
      watermarks: List.unmodifiable([
        for (final value in watermarks)
          if (value is Map)
            AdminOrderListWatermark.fromJson(value.cast<String, dynamic>())
          else
            throw _invalidAdminOrderPage(),
      ]),
    );
  }

  /// Display compatibility only; hydrate before opening any action or editor.
  ProductionMapSaved toPresentationOrder() =>
      _adminOrdersPresentationOrders[this] ??= ProductionMapSaved(
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
            mapId: id, productCode: '', operations: const []),
      );
}

final _adminOrdersPresentationOrders = Expando<ProductionMapSaved>();

class AdminOrderListWatermark {
  const AdminOrderListWatermark(
      {required this.apparatusId, required this.kind});
  final String apparatusId;
  final String kind;

  factory AdminOrderListWatermark.fromJson(Map<String, dynamic> json) {
    final apparatus = json['apparatus_id'];
    final kind = json['kind'];
    if (apparatus is! String ||
        (apparatus.isNotEmpty && !isCanonicalApparatusId(apparatus)) ||
        !const {'active', 'paused', 'frozen', 'issue', 'waiting'}
            .contains(kind)) {
      throw _invalidAdminOrderPage();
    }
    return AdminOrderListWatermark(
        apparatusId: apparatus, kind: kind as String);
  }
}

/// An unfinished order card contains no calculation template. Fetch the full
/// pending order by its ID before opening its details or resuming calculation.
class AdminPendingOrderListRow {
  const AdminPendingOrderListRow({
    required this.id,
    required this.code,
    required this.title,
    required this.customerName,
    required this.imageId,
    required this.kg,
  });
  final String id;
  final String code;
  final String title;
  final String customerName;
  final String imageId;
  final double kg;

  factory AdminPendingOrderListRow.fromJson(Map<String, dynamic> json) {
    _validateOrderListLabels(json);
    final kg = json['kg'];
    if (kg is! num || !kg.isFinite) throw _invalidAdminOrderPage();
    return AdminPendingOrderListRow(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      customerName: json['customer_name'] as String,
      imageId: json['image_id'] as String,
      kg: kg.toDouble(),
    );
  }
}

void _validateOrderListLabels(Map<String, dynamic> json) {
  if (const {'id', 'code', 'title', 'customer_name', 'image_id'}
          .any((key) => json[key] is! String) ||
      (json['id'] as String).trim().isEmpty) {
    throw _invalidAdminOrderPage();
  }
}

MobileApiException _invalidAdminOrderPage() => const MobileApiException(
      code: 'order_page_invalid',
      message: 'Buyurtmalar sahifasi noto‘g‘ri. Qayta yuklang.',
    );

/// The existing delta socket's paged bootstrap/invalidation has no order bodies.
class AdminProductionMapPageChange implements AdminProductionMapLiveMessage {
  const AdminProductionMapPageChange({
    required this.epoch,
    required this.revision,
    this.ready = false,
  });
  final String epoch;
  final int revision;
  final bool ready;

  factory AdminProductionMapPageChange.fromJson(Map<String, dynamic> json) {
    final epoch = json['epoch'];
    final revision = json['rev'];
    if (epoch is! String || epoch.isEmpty || revision is! int || revision < 0) {
      throw _productionMapQueueContractException('invalid page live cursor');
    }
    return AdminProductionMapPageChange(
        epoch: epoch, revision: revision, ready: json['type'] == 'page_ready');
  }
}

/// An admin page is a read projection, never a replacement for a whole queue.
class AdminProductionOrderPage {
  const AdminProductionOrderPage({
    required this.version,
    required this.total,
    required this.offset,
    this.epoch = '',
    this.scope = '',
    this.projection = '',
    this.revision,
    this.nextCursor,
    this.snapshot,
    this.orderIds = const [],
    this.sequencePositions = const {},
    this.sequenceRows = const {},
    this.orderRows = const {},
    this.pendingRows = const {},
    this.pendingIds = const [],
    Map<String, String> sequenceVersions = const {},
    Map<String, int> sequenceRevisions = const {},
    Map<String, AdminApparatusQueuePolicy> queuePolicies = const {},
    this.pendingOrders = const [],
    this.closedOrders = const [],
    this.calculationTemplates = const {},
    this.workflowAudit,
    this.wireValue,
  })  : _sequenceVersions = sequenceVersions,
        _sequenceRevisions = sequenceRevisions,
        _queuePolicies = queuePolicies;

  /// Immutable wire baseline used by sparse page-window updates.
  final Map<String, dynamic>? wireValue;
  final String version;
  final int total;
  final int offset;
  final String epoch;
  final String scope;
  final String projection;
  bool get isSequenceList => projection == adminSequenceListProjection;
  bool get isOrdersList => projection == adminOrdersListProjection;
  bool get isList => isSequenceList || isOrdersList;
  final int? revision;
  final String? nextCursor;
  final AdminApparatusQueueSnapshot? snapshot;
  final List<String> orderIds;

  /// One-based ranks before server search and pagination, scoped to apparatus.
  final Map<String, int> sequencePositions;
  final Map<String, AdminSequenceListRow> sequenceRows;
  final Map<String, AdminOrderListRow> orderRows;
  final Map<String, AdminPendingOrderListRow> pendingRows;
  final List<String> pendingIds;
  final Map<String, String> _sequenceVersions;
  final Map<String, int> _sequenceRevisions;
  final Map<String, AdminApparatusQueuePolicy> _queuePolicies;
  Map<String, String> get sequenceVersions =>
      snapshot?.sequenceVersions ?? _sequenceVersions;
  Map<String, int> get sequenceRevisions =>
      snapshot?.sequenceRevisions ?? _sequenceRevisions;
  Map<String, AdminApparatusQueuePolicy> get queuePolicies =>
      snapshot?.queuePolicies ?? _queuePolicies;
  final List<PendingOrder> pendingOrders;
  final List<AdminClosedProductionOrder> closedOrders;
  final Map<String, CalculateOrderTemplate> calculationTemplates;
  final AdminProductionWorkflowAuditReport? workflowAudit;
  int get length =>
      orderIds.length +
      pendingIds.length +
      pendingOrders.length +
      closedOrders.length +
      (workflowAudit?.violations.length ?? 0);

  /// Decode the HTTP body and construct models together, without serializing
  /// an already-decoded page to JSON a second time on the UI isolate.
  static Future<AdminProductionOrderPage> fromPayload(
    String source, {
    int backgroundThresholdCodeUnits = defaultBackgroundJsonThresholdCodeUnits,
  }) async {
    if (!kIsWeb && source.length >= backgroundThresholdCodeUnits) {
      return compute(_decodeAdminProductionOrderPagePayload, source,
          debugLabel: 'production-order-page');
    }
    return _decodeAdminProductionOrderPagePayload(source);
  }

  static Future<AdminProductionOrderPage> fromJson(
    Map<String, dynamic> json, {
    int backgroundThresholdCodeUnits = defaultBackgroundJsonThresholdCodeUnits,
  }) async {
    AdminApparatusQueueSnapshot? snapshot;
    _validateOrderPageProjection(json);
    if (json.containsKey('maps') &&
        !_isAdminListProjection(json['projection'])) {
      // Cached pages and sparse deltas are already decoded. Keep large model
      // conversions off the native UI isolate without encoding the page again.
      snapshot = !kIsWeb &&
              _adminOrderPageNeedsBackgroundDecode(
                  json, backgroundThresholdCodeUnits)
          ? await compute(decodeCachedProductionMapQueueSnapshot, json,
              debugLabel: 'production-order-page-models')
          : decodeCachedProductionMapQueueSnapshot(json);
    }
    return _fromDecodedJson(json, snapshot);
  }

  static AdminProductionOrderPage _fromDecodedJson(
      Map<String, dynamic> json, AdminApparatusQueueSnapshot? snapshot) {
    _validateOrderPageProjection(json);
    final orderIds = (json['order_ids'] as List? ?? const []).cast<String>();
    final sequenceSummary = json['projection'] == adminSequenceListProjection;
    final ordersSummary = json['projection'] == adminOrdersListProjection;
    final summary = sequenceSummary || ordersSummary;
    final rows = sequenceSummary
        ? _decodeSequenceRows(json, orderIds)
        : const <String, AdminSequenceListRow>{};
    final versions = sequenceSummary
        ? _decodeSummaryVersions(json)
        : const <String, String>{};
    final revisions = sequenceSummary
        ? _decodeSummaryRevisions(json, versions.keys.single)
        : const <String, int>{};
    final policies = sequenceSummary
        ? MobileApi.instance
            .parseApparatusQueuePolicyMap(json['queue_policies'])
        : const <String, AdminApparatusQueuePolicy>{};
    if (sequenceSummary &&
        (policies.length != 1 ||
            policies.keys.single != versions.keys.single ||
            policies.values.single.apparatusId != versions.keys.single)) {
      throw _invalidAdminOrderPage();
    }
    final pendingIds = ordersSummary
        ? List<String>.unmodifiable(
            (json['pending_ids'] as List).cast<String>())
        : const <String>[];
    final page = AdminProductionOrderPage(
      wireValue: json,
      version: json['version'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? -1,
      offset: (json['offset'] as num?)?.toInt() ?? -1,
      epoch: json['epoch'] as String? ?? '',
      scope: json['scope'] as String? ?? '',
      projection: json['projection'] as String? ?? '',
      revision: (json['rev'] as num?)?.toInt(),
      nextCursor: json['next_cursor'] as String?,
      workflowAudit: json['workflow_audit'] is Map
          ? AdminProductionWorkflowAuditReport.fromJson(
              (json['workflow_audit'] as Map).cast<String, dynamic>())
          : null,
      snapshot: snapshot,
      orderIds: orderIds,
      sequenceRows: rows,
      orderRows: ordersSummary
          ? _decodeKeyedListRows(json['rows'], orderIds,
              AdminOrderListRow.fromJson, (row) => row.id)
          : const {},
      pendingRows: ordersSummary
          ? _decodeKeyedListRows(json['pending_rows'], pendingIds,
              AdminPendingOrderListRow.fromJson, (row) => row.id)
          : const {},
      pendingIds: pendingIds,
      sequenceVersions: versions,
      sequenceRevisions: revisions,
      queuePolicies: policies,
      sequencePositions: _decodeSequencePositions(json, orderIds),
      pendingOrders: [
        for (final item in json['pending_orders'] as List? ?? const [])
          PendingOrder.fromJson((item as Map).cast<String, dynamic>()),
      ],
      closedOrders: [
        for (final item in json['closed_orders'] as List? ?? const [])
          AdminClosedProductionOrder.fromJson(
              (item as Map).cast<String, dynamic>()),
      ],
      calculationTemplates: snapshot?.calculationTemplates ??
          {
            for (final entry
                in (json['calculation_templates'] as Map? ?? const {}).entries)
              entry.key.toString(): CalculateOrderTemplate.fromJson(
                  (entry.value as Map).cast<String, dynamic>()),
          },
    );
    final ids = [
      ...page.orderIds,
      ...page.pendingIds,
      ...page.pendingOrders.map((o) => o.id),
      ...page.closedOrders.map((o) => o.orderId)
    ];
    if (page.version.isEmpty ||
        page.epoch.isEmpty ||
        page.revision == null ||
        page.revision! < 0 ||
        page.offset < 0 ||
        page.total < page.offset + page.length ||
        page.length > 20 ||
        ids.toSet().length != ids.length ||
        page.nextCursor == '' ||
        (page.nextCursor != null &&
            (page.length == 0 || page.offset + page.length >= page.total)) ||
        (page.nextCursor == null && page.offset + page.length != page.total) ||
        (summary &&
            (page.snapshot != null ||
                page.scope.isEmpty ||
                (sequenceSummary &&
                    page.sequencePositions.length != page.orderIds.length) ||
                (ordersSummary && page.sequencePositions.isNotEmpty) ||
                page.pendingOrders.isNotEmpty ||
                page.closedOrders.isNotEmpty ||
                page.workflowAudit != null ||
                page.calculationTemplates.isNotEmpty)) ||
        (!summary &&
            ((page.snapshot?.maps.length ?? 0) != page.orderIds.length ||
                page.orderIds.any((id) =>
                    !(page.snapshot?.maps.any((map) => map.map.id == id) ??
                        false))))) {
      throw const MobileApiException(
          code: 'order_page_invalid',
          message: 'Buyurtmalar sahifasi noto‘g‘ri. Qayta yuklang.');
    }
    return page;
  }

  static Map<String, T> _decodeKeyedListRows<T>(Object? raw, List<String> ids,
      T Function(Map<String, dynamic>) decode, String Function(T) rowId) {
    if (raw is! Map ||
        raw.length != ids.length ||
        raw.keys.any((key) => key is! String || !ids.contains(key))) {
      throw _invalidAdminOrderPage();
    }
    final rows = <String, T>{};
    for (final id in ids) {
      final value = raw[id];
      if (value is! Map) throw _invalidAdminOrderPage();
      final row = decode(value.cast<String, dynamic>());
      if (rowId(row) != id) throw _invalidAdminOrderPage();
      rows[id] = row;
    }
    return Map.unmodifiable(rows);
  }

  static Map<String, AdminSequenceListRow> _decodeSequenceRows(
      Map<String, dynamic> json, List<String> orderIds) {
    final raw = json['rows'];
    if (raw is! Map ||
        raw.length != orderIds.length ||
        raw.keys.any((key) => key is! String || !orderIds.contains(key))) {
      throw _invalidAdminOrderPage();
    }
    final rows = <String, AdminSequenceListRow>{};
    for (final id in orderIds) {
      final value = raw[id];
      if (value is! Map) throw _invalidAdminOrderPage();
      final row = AdminSequenceListRow.fromJson(value.cast<String, dynamic>());
      if (row.id != id) throw _invalidAdminOrderPage();
      rows[id] = row;
    }
    return Map.unmodifiable(rows);
  }

  static Map<String, String> _decodeSummaryVersions(Map<String, dynamic> json) {
    final raw = json['sequence_versions'];
    if (raw is! Map ||
        raw.length != 1 ||
        raw.keys.single is! String ||
        !isCanonicalApparatusId(raw.keys.single as String) ||
        raw.values.single is! String ||
        (raw.values.single as String).isEmpty) {
      throw _invalidAdminOrderPage();
    }
    return Map.unmodifiable(raw.cast<String, String>());
  }

  static Map<String, int> _decodeSummaryRevisions(
      Map<String, dynamic> json, String apparatus) {
    final raw = json['sequence_revisions'];
    if (raw is! Map ||
        raw.length != 1 ||
        raw.keys.single != apparatus ||
        raw.values.single is! int ||
        (raw.values.single as int) < 0) {
      throw _invalidAdminOrderPage();
    }
    return Map.unmodifiable(raw.cast<String, int>());
  }

  static Map<String, int> _decodeSequencePositions(
      Map<String, dynamic> wire, List<String> orderIds) {
    // Older servers and non-sequence projections may omit this metadata.
    if (!wire.containsKey('sequence_positions')) return const {};
    final raw = wire['sequence_positions'];
    if (raw is! Map ||
        raw.entries.any((entry) =>
            entry.key is! String ||
            !orderIds.contains(entry.key) ||
            entry.value is! int ||
            (entry.value as int) <= 0) ||
        (raw.isNotEmpty && raw.length != orderIds.length) ||
        raw.values.toSet().length != raw.length) {
      throw const MobileApiException(
          code: 'order_page_invalid',
          message: 'Buyurtmalar sahifasi noto‘g‘ri. Qayta yuklang.');
    }
    return Map<String, int>.unmodifiable(raw.cast<String, int>());
  }
}

bool _isAdminListProjection(Object? value) =>
    value == adminSequenceListProjection || value == adminOrdersListProjection;

void _validateOrderPageProjection(Map<String, dynamic> json) {
  if (json.containsKey('projection') &&
      !_isAdminListProjection(json['projection'])) {
    throw _invalidAdminOrderPage();
  }
  if (_isAdminListProjection(json['projection']) &&
      (json.containsKey('maps') ||
          json['order_ids'] is! List ||
          (json['order_ids'] as List)
              .any((id) => id is! String || id.trim().isEmpty) ||
          json['scope'] is! String ||
          json['version'] is! String ||
          json['epoch'] is! String ||
          json['rev'] is! int ||
          json['offset'] is! int ||
          json['total'] is! int ||
          (json['next_cursor'] != null && json['next_cursor'] is! String))) {
    throw _invalidAdminOrderPage();
  }
  if (json['projection'] == adminSequenceListProjection) {
    final policies = json['queue_policies'];
    if (policies is! List || policies.length != 1 || policies.single is! Map) {
      throw _invalidAdminOrderPage();
    }
    final policy = policies.single as Map;
    if (!const {'strict_sequence', 'free_pick'}
        .contains(policy['discipline'] ?? policy['policy'])) {
      throw _invalidAdminOrderPage();
    }
  }
  if (json['projection'] == adminOrdersListProjection) {
    final ids = json['pending_ids'];
    if (ids is! List ||
        ids.any((id) => id is! String || id.trim().isEmpty) ||
        const {
          'sequence_versions',
          'sequence_revisions',
          'queue_policies',
          'queue_states',
          'stage_order_controls',
          'order_controls',
          'stage_states',
          'order_statuses',
          'queue_action_controls',
          'calculation_templates',
          'pending_orders',
          'closed_orders',
          'workflow_audit'
        }.any(json.containsKey)) {
      throw _invalidAdminOrderPage();
    }
  }
}

AdminProductionOrderPage _decodeAdminProductionOrderPagePayload(String source) {
  final json = (jsonDecode(source) as Map).cast<String, dynamic>();
  _validateOrderPageProjection(json);
  return AdminProductionOrderPage._fromDecodedJson(
      json,
      json.containsKey('maps')
          ? decodeCachedProductionMapQueueSnapshot(json)
          : null);
}

/// A bounded size estimate chooses an isolate without allocating a JSON copy.
/// The threshold is a scheduling hint, never part of contract validation.
bool _adminOrderPageNeedsBackgroundDecode(Object? value, int threshold) {
  if (threshold <= 0) return true;
  var remaining = threshold;
  void visit(Object? value) {
    if (remaining <= 0) return;
    if (value is String) {
      remaining -= value.length + 2;
    } else if (value is Map) {
      remaining -= 2;
      for (final entry in value.entries) {
        visit(entry.key);
        remaining -= 2;
        visit(entry.value);
        if (remaining <= 0) break;
      }
    } else if (value is List) {
      remaining -= 2;
      for (final item in value) {
        visit(item);
        remaining--;
        if (remaining <= 0) break;
      }
    } else {
      remaining -= value == null ? 4 : 8;
    }
  }

  visit(value);
  return remaining <= 0;
}

class AdminProductionOrderPageRequest {
  const AdminProductionOrderPageRequest({
    required this.view,
    this.apparatus = '',
    this.target = '',
    this.search = '',
    this.cursor,
    this.ifVersion,
  });
  final String view;
  final String apparatus;
  final String target;
  final String search;
  final String? cursor;
  final String? ifVersion;
}

typedef AdminProductionOrderPageLoader = Future<AdminProductionOrderPage?>
    Function(AdminProductionOrderPageRequest request);

extension MobileApiAdminOrderPage on MobileApi {
  /// Null means that a conditional first-page read is unchanged.
  Future<AdminProductionOrderPage?> adminProductionOrderPage(
      AdminProductionOrderPageRequest request) async {
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/order-page')
              .replace(queryParameters: {
            'view': request.view,
            'limit': '20',
            if (request.view == 'sequence')
              'projection': adminSequenceListProjection,
            if (request.view == 'orders')
              'projection': adminOrdersListProjection,
            if ((request.view == 'sequence' || request.view == 'orders') &&
                adminProductionReadIdentityCompression)
              'compression': 'identity',
            if (request.apparatus.isNotEmpty) 'apparatus': request.apparatus,
            if (request.target.isNotEmpty) 'target': request.target,
            if (request.search.isNotEmpty) 'search': request.search,
            if (request.cursor != null) 'cursor': request.cursor!,
            if (request.ifVersion != null) 'if_version': request.ifVersion!,
          }),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode == 304 && request.ifVersion != null) return null;
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'order_page_failed');
    }
    return AdminProductionOrderPage.fromPayload(response.body);
  }

  /// A single complete order with its current route control authority. Summary
  /// rows must never be used as the baseline for a detail/editor/action.
  Future<AdminApparatusQueueSnapshot> adminProductionOrderDetail({
    required String apparatus,
    required String orderId,
  }) async {
    final station =
        apparatus.trim().isEmpty ? '' : _requireCanonicalApparatusId(apparatus);
    final id = orderId.trim();
    if (id.isEmpty) throw _invalidAdminOrderPage();
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/sequence')
              .replace(queryParameters: {
            if (station.isNotEmpty) 'apparatus': station,
            'order_id': id,
            'detail': 'true',
            if (adminProductionReadIdentityCompression)
              'compression': 'identity',
          }),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'order_detail_failed');
    }
    final snapshot =
        await decodeProductionMapQueueSnapshotPayload(response.body);
    if (snapshot.maps.length != 1 ||
        snapshot.maps.single.map.id != id ||
        snapshot.revision == null ||
        snapshot.revision! < 0 ||
        snapshot.epoch.isEmpty ||
        snapshot.scope.isEmpty ||
        snapshot.calculationTemplates.keys.any((key) => key != id)) {
      throw _invalidAdminOrderPage();
    }
    return snapshot;
  }

  Future<PendingOrder> pendingOrderDetail(String orderId) async {
    final id = orderId.trim();
    if (id.isEmpty) throw _invalidAdminOrderPage();
    final response = await _sendAuthorized(() => _get(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/pending-orders')
              .replace(queryParameters: {'id': id}),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'pending_order_detail');
    }
    final wire = jsonDecode(response.body);
    if (wire is! Map || wire['id'] != id || wire['template'] is! Map) {
      throw _invalidAdminOrderPage();
    }
    return PendingOrder.fromJson(wire.cast<String, dynamic>());
  }

  Future<AdminClosedProductionOrder> adminClosedProductionOrderDetail(
      String id) async {
    final response = await _sendAuthorized(() => _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/admin/production-maps/closed-order')
              .replace(queryParameters: {'id': id}),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'closed_order_failed');
    }
    return AdminClosedProductionOrder.fromJson(
        (jsonDecode(response.body) as Map).cast<String, dynamic>());
  }
}

/// A scoped prefix update. Window IDs are local opaque IDs, never credentials.
class AdminProductionMapPageWindowMessage
    implements AdminProductionMapLiveMessage {
  AdminProductionMapPageWindowMessage.fromJson(this.value) {
    if (!const {
          'page_window_ready',
          'page_window_delta',
          'page_window_checkpoint',
          'page_window_resync'
        }.contains(value['type']) ||
        value['window'] is! String ||
        (value['window'] as String).isEmpty ||
        value['epoch'] is! String ||
        (value['epoch'] as String).isEmpty ||
        value['rev'] is! int ||
        (value['rev'] as int) < 0 ||
        value['version'] is! String ||
        (value['version'] as String).isEmpty) {
      throw _productionMapQueueContractException('invalid page window event');
    }
  }
  final Map<String, dynamic> value;
  String get type => value['type'] as String;
  String get window => value['window'] as String;
  String get epoch => value['epoch'] as String;
  int get revision => value['rev'] as int;
  String get version => value['version'] as String;
}

Object? _patchOrderPageValue(
    Object? node, List path, int at, String operation, Object? value) {
  if (at == path.length) {
    if (operation != 'set') {
      throw _productionMapQueueContractException('invalid root remove');
    }
    return value;
  }
  final key = path[at];
  final last = at == path.length - 1;
  if (node is Map && key is String) {
    final copy = Map<String, dynamic>.from(node);
    if (last && operation == 'remove') {
      if (!copy.containsKey(key)) {
        throw _productionMapQueueContractException('missing page key');
      }
      copy.remove(key);
    } else {
      if (!last && !copy.containsKey(key)) {
        throw _productionMapQueueContractException('missing page path');
      }
      copy[key] =
          _patchOrderPageValue(copy[key], path, at + 1, operation, value);
    }
    return copy;
  }
  if (node is List && key is int && key >= 0 && key < node.length) {
    final copy = List<Object?>.from(node);
    if (last && operation == 'remove') {
      copy.removeAt(key);
    } else {
      copy[key] =
          _patchOrderPageValue(copy[key], path, at + 1, operation, value);
    }
    return copy;
  }
  throw _productionMapQueueContractException('invalid page patch path');
}

AdminApparatusQueueSnapshot _copyOrderPageSnapshot(
        AdminApparatusQueueSnapshot before, int revision,
        {List<ProductionMapSaved>? maps}) =>
    AdminApparatusQueueSnapshot(
      sequences: before.sequences,
      sequenceVersions: before.sequenceVersions,
      sequenceRevisions: before.sequenceRevisions,
      visibleOrderIds: before.visibleOrderIds,
      sequencePositionsByApparatus: before.sequencePositionsByApparatus,
      queueStates: before.queueStates,
      queuePolicies: before.queuePolicies,
      stageOrderControls: before.stageOrderControls,
      stageFreezeSupported: before.stageFreezeSupported,
      orderControls: before.orderControls,
      earlyClosingOrderIds: before.earlyClosingOrderIds,
      queueActionControls: before.queueActionControls,
      stageStates: before.stageStates,
      orderCustomers: before.orderCustomers,
      orderStatuses: before.orderStatuses,
      frozenOrdersByApparatus: before.frozenOrdersByApparatus,
      maps: maps ?? before.maps,
      projection: before.projection,
      workerListRows: before.workerListRows,
      workerDisplayStates: before.workerDisplayStates,
      workerReportPrompts: before.workerReportPrompts,
      calculationTemplates: before.calculationTemplates,
      revision: revision,
      epoch: before.epoch,
      scope: before.scope,
      workerShowAllApparatusTabs: before.workerShowAllApparatusTabs,
    );

AdminProductionOrderPage _copyOrderPage(
        AdminProductionOrderPage page, Map<String, dynamic> wire,
        {AdminApparatusQueueSnapshot? snapshot,
        Map<String, int>? sequencePositions,
        Map<String, AdminSequenceListRow>? sequenceRows,
        Map<String, AdminOrderListRow>? orderRows,
        Map<String, AdminPendingOrderListRow>? pendingRows}) =>
    AdminProductionOrderPage(
      version: wire['version'] as String,
      epoch: page.epoch,
      revision: wire['rev'] as int,
      nextCursor: wire['next_cursor'] as String?,
      total: page.total,
      offset: page.offset,
      snapshot: snapshot ?? page.snapshot,
      scope: page.scope,
      projection: page.projection,
      orderIds: page.orderIds,
      sequencePositions: sequencePositions ?? page.sequencePositions,
      sequenceRows: sequenceRows ?? page.sequenceRows,
      orderRows: orderRows ?? page.orderRows,
      pendingRows: pendingRows ?? page.pendingRows,
      pendingIds: page.pendingIds,
      sequenceVersions: page.sequenceVersions,
      sequenceRevisions: page.sequenceRevisions,
      queuePolicies: page.queuePolicies,
      pendingOrders: page.pendingOrders,
      closedOrders: page.closedOrders,
      calculationTemplates: page.calculationTemplates,
      workflowAudit: page.workflowAudit,
      wireValue: wire,
    );

/// Copy-on-path and staged decoding keep malformed/reordered frames atomic.
/// Unchanged map objects retain identity so card subtrees can stay mounted.
Future<List<AdminProductionOrderPage>> applyAdminOrderPageWindow(
    List<AdminProductionOrderPage> before,
    AdminProductionMapPageWindowMessage message) async {
  final value = message.value;
  if (before.isEmpty ||
      before.any((page) =>
          page.wireValue == null ||
          page.version != value['base_version'] ||
          page.epoch != message.epoch ||
          (page.revision ?? -1) >= message.revision)) {
    throw _productionMapQueueContractException('page window base mismatch');
  }
  final next = <AdminProductionOrderPage>[];
  if (message.type == 'page_window_checkpoint') {
    final cursors = value['next_cursors'];
    if (cursors is! List ||
        cursors.length != before.length ||
        cursors.any((cursor) =>
            cursor != null && (cursor is! String || cursor.isEmpty))) {
      throw _productionMapQueueContractException('invalid page checkpoint');
    }
    for (var index = 0; index < before.length; index++) {
      final page = before[index];
      final wire = {
        ...page.wireValue!,
        'version': message.version,
        'rev': message.revision,
        'next_cursor': cursors[index]
      };
      next.add(_copyOrderPage(page, wire,
          snapshot: page.snapshot == null
              ? null
              : _copyOrderPageSnapshot(page.snapshot!, message.revision)));
    }
  } else if (message.type == 'page_window_delta') {
    final count = value['page_count'];
    final changes = value['changes'];
    if (count is! int || count < 1 || count > 500 || changes is! List) {
      throw _productionMapQueueContractException('invalid page window length');
    }
    final wires = <Object?>[
      for (var index = 0; index < count; index++)
        index < before.length ? before[index].wireValue : null,
    ];
    final touched = <int>{};
    for (final change in changes) {
      if (change is! Map || change['index'] is! int || change['ops'] is! List) {
        throw _productionMapQueueContractException('invalid page change');
      }
      final index = change['index'] as int;
      if (index < 0 || index >= count || !touched.add(index)) {
        throw _productionMapQueueContractException('duplicate page change');
      }
      for (final op in change['ops'] as List) {
        if (op is! Map ||
            op['path'] is! List ||
            !const {'set', 'remove'}.contains(op['op']) ||
            (op['op'] == 'set' && !op.containsKey('value'))) {
          throw _productionMapQueueContractException('invalid page operation');
        }
        wires[index] = _patchOrderPageValue(
            wires[index], op['path'], 0, op['op'] as String, op['value']);
      }
    }
    for (var index = 0; index < wires.length; index++) {
      final raw = wires[index];
      if (raw is! Map<String, dynamic>) {
        throw _productionMapQueueContractException('missing page body');
      }
      if (index < before.length) {
        final previous = before[index];
        final oldWire = previous.wireValue!;
        const metadata = {
          'version',
          'rev',
          'next_cursor',
          'sequence_positions'
        };
        if (raw.length == oldWire.length &&
            raw.keys.every(oldWire.containsKey) &&
            raw.keys.every((key) =>
                metadata.contains(key) || identical(raw[key], oldWire[key]))) {
          next.add(_copyOrderPage(previous, raw,
              sequencePositions: identical(
                      raw['sequence_positions'], oldWire['sequence_positions'])
                  ? previous.sequencePositions
                  : AdminProductionOrderPage._decodeSequencePositions(
                      raw, previous.orderIds),
              snapshot: previous.snapshot == null
                  ? null
                  : _copyOrderPageSnapshot(
                      previous.snapshot!, message.revision)));
          continue;
        }
      }
      var page = await AdminProductionOrderPage.fromJson(raw);
      if (index < before.length &&
          page.isSequenceList &&
          before[index].isSequenceList) {
        final oldRows = before[index].wireValue!['rows'];
        final newRows = raw['rows'];
        if (oldRows is Map && newRows is Map) {
          page = _copyOrderPage(page, raw,
              sequenceRows: Map.unmodifiable({
                for (final entry in page.sequenceRows.entries)
                  entry.key: identical(oldRows[entry.key], newRows[entry.key])
                      ? before[index].sequenceRows[entry.key] ?? entry.value
                      : entry.value,
              }));
        }
      }
      if (index < before.length &&
          page.isOrdersList &&
          before[index].isOrdersList) {
        final previous = before[index];
        Map<String, T> preserve<T>(
            String key, Map<String, T> rows, Map<String, T> oldRows) {
          final oldWire = previous.wireValue![key];
          final newWire = raw[key];
          if (oldWire is! Map || newWire is! Map) return rows;
          return Map.unmodifiable({
            for (final entry in rows.entries)
              entry.key: identical(oldWire[entry.key], newWire[entry.key])
                  ? oldRows[entry.key] ?? entry.value
                  : entry.value,
          });
        }

        page = _copyOrderPage(page, raw,
            orderRows: preserve('rows', page.orderRows, previous.orderRows),
            pendingRows: preserve(
                'pending_rows', page.pendingRows, previous.pendingRows));
      }
      if (index < before.length &&
          page.snapshot != null &&
          before[index].snapshot != null) {
        final oldRaw = before[index].wireValue!['maps'];
        final newRaw = raw['maps'];
        if (oldRaw is List && newRaw is List) {
          final oldMaps = before[index].snapshot!.maps;
          final byId = {
            for (var i = 0; i < oldMaps.length; i++)
              oldMaps[i].map.id: (oldRaw[i], oldMaps[i])
          };
          final maps = identical(oldRaw, newRaw)
              ? oldMaps
              : [
                  for (var i = 0; i < page.snapshot!.maps.length; i++)
                    identical(
                            byId[page.snapshot!.maps[i].map.id]?.$1, newRaw[i])
                        ? byId[page.snapshot!.maps[i].map.id]!.$2
                        : page.snapshot!.maps[i]
                ];
          page = _copyOrderPage(page, raw,
              snapshot: _copyOrderPageSnapshot(page.snapshot!, message.revision,
                  maps: maps));
        }
      }
      next.add(page);
    }
  } else {
    throw _productionMapQueueContractException('unexpected page update');
  }
  var offset = 0;
  final ids = <String>{};
  for (var index = 0; index < next.length; index++) {
    final page = next[index];
    if (page.epoch != message.epoch ||
        page.revision != message.revision ||
        page.projection != before.first.projection ||
        (page.isList && page.scope != before.first.scope) ||
        page.version != message.version ||
        page.offset != offset ||
        page.total != next.first.total ||
        (index < next.length - 1 && page.nextCursor == null) ||
        (page.nextCursor == null) !=
            (page.offset + page.length == page.total) ||
        [
          ...page.orderIds,
          ...page.pendingIds,
          ...page.pendingOrders.map((o) => o.id),
          ...page.closedOrders.map((o) => o.orderId)
        ].any((id) => !ids.add(id))) {
      throw _productionMapQueueContractException('inconsistent page window');
    }
    offset += page.length;
  }
  return next;
}
