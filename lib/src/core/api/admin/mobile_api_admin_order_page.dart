part of '../mobile_api.dart';

/// The existing delta socket's paged bootstrap/invalidation has no order bodies.
class AdminProductionMapPageChange implements AdminProductionMapLiveMessage {
  const AdminProductionMapPageChange({
    required this.epoch, required this.revision, this.ready = false,
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
    this.revision,
    this.nextCursor,
    this.snapshot,
    this.orderIds = const [],
    this.sequencePositions = const {},
    this.pendingOrders = const [],
    this.closedOrders = const [],
    this.calculationTemplates = const {},
    this.workflowAudit,
    this.wireValue,
  });

  /// Immutable wire baseline used by sparse page-window updates.
  final Map<String, dynamic>? wireValue;
  final String version;
  final int total;
  final int offset;
  final String epoch;
  final int? revision;
  final String? nextCursor;
  final AdminApparatusQueueSnapshot? snapshot;
  final List<String> orderIds;

  /// One-based ranks before server search and pagination, scoped to apparatus.
  final Map<String, int> sequencePositions;
  final List<PendingOrder> pendingOrders;
  final List<AdminClosedProductionOrder> closedOrders;
  final Map<String, CalculateOrderTemplate> calculationTemplates;
  final AdminProductionWorkflowAuditReport? workflowAudit;
  int get length =>
      orderIds.length +
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
    if (json.containsKey('maps')) {
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
    final orderIds = (json['order_ids'] as List? ?? const []).cast<String>();
    final page = AdminProductionOrderPage(
      wireValue: json,
      version: json['version'] as String? ?? '',
      total: (json['total'] as num?)?.toInt() ?? -1,
      offset: (json['offset'] as num?)?.toInt() ?? -1,
      epoch: json['epoch'] as String? ?? '',
      revision: (json['rev'] as num?)?.toInt(),
      nextCursor: json['next_cursor'] as String?,
      workflowAudit: json['workflow_audit'] is Map
          ? AdminProductionWorkflowAuditReport.fromJson(
              (json['workflow_audit'] as Map).cast<String, dynamic>())
          : null,
      snapshot: snapshot,
      orderIds: orderIds,
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
      calculationTemplates: {
        for (final entry
            in (json['calculation_templates'] as Map? ?? const {}).entries)
          entry.key.toString(): CalculateOrderTemplate.fromJson(
              (entry.value as Map).cast<String, dynamic>()),
      },
    );
    final ids = [
      ...page.orderIds,
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
        (page.snapshot?.maps.length ?? 0) != page.orderIds.length ||
        page.orderIds.any((id) =>
            !(page.snapshot?.maps.any((map) => map.map.id == id) ?? false))) {
      throw const MobileApiException(
          code: 'order_page_invalid',
          message: 'Buyurtmalar sahifasi noto‘g‘ri. Qayta yuklang.');
    }
    return page;
  }

  static Map<String, int> _decodeSequencePositions(
      Map<String, dynamic> wire, List<String> orderIds) {
    // Older servers and non-sequence projections may omit this metadata.
    if (!wire.containsKey('sequence_positions')) return const {};
    final raw = wire['sequence_positions'];
    if (raw is! Map ||
        raw.entries.any((entry) => entry.key is! String ||
            !orderIds.contains(entry.key) || entry.value is! int ||
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

AdminProductionOrderPage _decodeAdminProductionOrderPagePayload(String source) {
  final json = (jsonDecode(source) as Map).cast<String, dynamic>();
  return AdminProductionOrderPage._fromDecodedJson(
      json, json.containsKey('maps')
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
class AdminProductionMapPageWindowMessage implements AdminProductionMapLiveMessage {
  AdminProductionMapPageWindowMessage.fromJson(this.value) {
    if (!const {'page_window_ready', 'page_window_delta',
      'page_window_checkpoint', 'page_window_resync'}.contains(value['type']) ||
        value['window'] is! String || (value['window'] as String).isEmpty ||
        value['epoch'] is! String || (value['epoch'] as String).isEmpty ||
        value['rev'] is! int || (value['rev'] as int) < 0 ||
        value['version'] is! String || (value['version'] as String).isEmpty) {
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

Object? _patchOrderPageValue(Object? node, List path, int at,
    String operation, Object? value) {
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
      copy[key] = _patchOrderPageValue(copy[key], path, at + 1, operation, value);
    }
    return copy;
  }
  if (node is List && key is int && key >= 0 && key < node.length) {
    final copy = List<Object?>.from(node);
    if (last && operation == 'remove') {
      copy.removeAt(key);
    } else {
      copy[key] = _patchOrderPageValue(copy[key], path, at + 1, operation, value);
    }
    return copy;
  }
  throw _productionMapQueueContractException('invalid page patch path');
}

AdminApparatusQueueSnapshot _copyOrderPageSnapshot(
    AdminApparatusQueueSnapshot before, int revision,
    {List<ProductionMapSaved>? maps}) => AdminApparatusQueueSnapshot(
  sequences: before.sequences, sequenceVersions: before.sequenceVersions,
  sequenceRevisions: before.sequenceRevisions, visibleOrderIds: before.visibleOrderIds,
  sequencePositionsByApparatus: before.sequencePositionsByApparatus,
  queueStates: before.queueStates, queuePolicies: before.queuePolicies,
  stageOrderControls: before.stageOrderControls,
  stageFreezeSupported: before.stageFreezeSupported,
  orderControls: before.orderControls, earlyClosingOrderIds: before.earlyClosingOrderIds,
  queueActionControls: before.queueActionControls, stageStates: before.stageStates,
  orderCustomers: before.orderCustomers, orderStatuses: before.orderStatuses,
  frozenOrdersByApparatus: before.frozenOrdersByApparatus, maps: maps ?? before.maps,
  revision: revision, epoch: before.epoch, scope: before.scope,
  workerShowAllApparatusTabs: before.workerShowAllApparatusTabs,
);

AdminProductionOrderPage _copyOrderPage(AdminProductionOrderPage page,
    Map<String, dynamic> wire, {AdminApparatusQueueSnapshot? snapshot,
      Map<String, int>? sequencePositions}) =>
  AdminProductionOrderPage(
    version: wire['version'] as String, epoch: page.epoch,
    revision: wire['rev'] as int, nextCursor: wire['next_cursor'] as String?,
    total: page.total, offset: page.offset, snapshot: snapshot ?? page.snapshot,
    orderIds: page.orderIds,
    sequencePositions: sequencePositions ?? page.sequencePositions,
    pendingOrders: page.pendingOrders,
    closedOrders: page.closedOrders, calculationTemplates: page.calculationTemplates,
    workflowAudit: page.workflowAudit, wireValue: wire,
  );

/// Copy-on-path and staged decoding keep malformed/reordered frames atomic.
/// Unchanged map objects retain identity so card subtrees can stay mounted.
Future<List<AdminProductionOrderPage>> applyAdminOrderPageWindow(
    List<AdminProductionOrderPage> before,
    AdminProductionMapPageWindowMessage message) async {
  final value = message.value;
  if (before.isEmpty || before.any((page) => page.wireValue == null ||
      page.version != value['base_version'] || page.epoch != message.epoch ||
      (page.revision ?? -1) >= message.revision)) {
    throw _productionMapQueueContractException('page window base mismatch');
  }
  final next = <AdminProductionOrderPage>[];
  if (message.type == 'page_window_checkpoint') {
    final cursors = value['next_cursors'];
    if (cursors is! List || cursors.length != before.length ||
        cursors.any((cursor) => cursor != null && (cursor is! String || cursor.isEmpty))) {
      throw _productionMapQueueContractException('invalid page checkpoint');
    }
    for (var index = 0; index < before.length; index++) {
      final page = before[index];
      final wire = {...page.wireValue!, 'version': message.version,
        'rev': message.revision, 'next_cursor': cursors[index]};
      next.add(_copyOrderPage(page, wire, snapshot: page.snapshot == null ? null :
          _copyOrderPageSnapshot(page.snapshot!, message.revision)));
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
        if (op is! Map || op['path'] is! List ||
            !const {'set', 'remove'}.contains(op['op']) ||
            (op['op'] == 'set' && !op.containsKey('value'))) {
          throw _productionMapQueueContractException('invalid page operation');
        }
        wires[index] = _patchOrderPageValue(wires[index], op['path'], 0,
            op['op'] as String, op['value']);
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
        const metadata = {'version', 'rev', 'next_cursor', 'sequence_positions'};
        if (raw.length == oldWire.length && raw.keys.every(oldWire.containsKey) && raw.keys.every((key) =>
            metadata.contains(key) || identical(raw[key], oldWire[key]))) {
          next.add(_copyOrderPage(previous, raw,
              sequencePositions: identical(raw['sequence_positions'], oldWire['sequence_positions'])
                  ? previous.sequencePositions
                  : AdminProductionOrderPage._decodeSequencePositions(raw, previous.orderIds),
              snapshot: previous.snapshot == null ? null :
              _copyOrderPageSnapshot(previous.snapshot!, message.revision)));
          continue;
        }
      }
      var page = await AdminProductionOrderPage.fromJson(raw);
      if (index < before.length && page.snapshot != null && before[index].snapshot != null) {
        final oldRaw = before[index].wireValue!['maps'];
        final newRaw = raw['maps'];
        if (oldRaw is List && newRaw is List) {
          final oldMaps = before[index].snapshot!.maps;
          final byId = {for (var i = 0; i < oldMaps.length; i++)
            oldMaps[i].map.id: (oldRaw[i], oldMaps[i])};
          final maps = identical(oldRaw, newRaw) ? oldMaps : [for (var i = 0; i < page.snapshot!.maps.length; i++)
            identical(byId[page.snapshot!.maps[i].map.id]?.$1, newRaw[i])
                ? byId[page.snapshot!.maps[i].map.id]!.$2 : page.snapshot!.maps[i]];
          page = _copyOrderPage(page, raw, snapshot:
              _copyOrderPageSnapshot(page.snapshot!, message.revision, maps: maps));
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
    if (page.epoch != message.epoch || page.revision != message.revision ||
        page.version != message.version || page.offset != offset ||
        page.total != next.first.total ||
        (index < next.length - 1 && page.nextCursor == null) ||
        (page.nextCursor == null) != (page.offset + page.length == page.total) ||
        [...page.orderIds, ...page.pendingOrders.map((o) => o.id),
          ...page.closedOrders.map((o) => o.orderId)].any((id) => !ids.add(id))) {
      throw _productionMapQueueContractException('inconsistent page window');
    }
    offset += page.length;
  }
  return next;
}
