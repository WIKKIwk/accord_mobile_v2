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
    this.pendingOrders = const [],
    this.closedOrders = const [],
    this.calculationTemplates = const {},
    this.workflowAudit,
  });

  final String version;
  final int total;
  final int offset;
  final String epoch;
  final int? revision;
  final String? nextCursor;
  final AdminApparatusQueueSnapshot? snapshot;
  final List<String> orderIds;
  final List<PendingOrder> pendingOrders;
  final List<AdminClosedProductionOrder> closedOrders;
  final Map<String, CalculateOrderTemplate> calculationTemplates;
  final AdminProductionWorkflowAuditReport? workflowAudit;
  int get length =>
      orderIds.length +
      pendingOrders.length +
      closedOrders.length +
      (workflowAudit?.violations.length ?? 0);

  static Future<AdminProductionOrderPage> fromJson(
      Map<String, dynamic> json) async {
    final page = AdminProductionOrderPage(
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
      snapshot: json.containsKey('maps')
          ? await decodeProductionMapQueueSnapshotPayload(jsonEncode(json))
          : null,
      orderIds: (json['order_ids'] as List? ?? const []).cast<String>(),
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
    return AdminProductionOrderPage.fromJson(
        (jsonDecode(response.body) as Map).cast<String, dynamic>());
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
