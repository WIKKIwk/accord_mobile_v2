part of '../mobile_api.dart';

/// Display labels only. A row is never a complete production map or authority
/// for an order operation; the sheet obtains a fresh, scoped detail instead.
class PreparationOrderListRow {
  const PreparationOrderListRow({
    required this.id,
    required this.code,
    required this.orderNumber,
    required this.title,
    required this.customerName,
    required this.imageId,
    required this.position,
  });

  final String id;
  final String code;
  final String orderNumber;
  final String title;
  final String customerName;
  final String imageId;
  final int position;

  factory PreparationOrderListRow.fromJson(Map<String, dynamic> json) {
    if (const {
          'id',
          'code',
          'order_number',
          'title',
          'customer_name',
          'image_id'
        }.any((key) => json[key] is! String) ||
        (json['id'] as String).trim().isEmpty ||
        json['position'] is! int ||
        (json['position'] as int) < 1) {
      throw _invalidPreparationOrderList();
    }
    return PreparationOrderListRow(
      id: json['id'] as String,
      code: json['code'] as String,
      orderNumber: json['order_number'] as String,
      title: json['title'] as String,
      customerName: json['customer_name'] as String,
      imageId: json['image_id'] as String,
      position: json['position'] as int,
    );
  }

  ProductionMapSaved toPresentationOrder() => ProductionMapSaved(
        map: ProductionMapDefinition(
          id: id,
          code: code,
          orderNumber: orderNumber,
          title: title,
          customerName: customerName,
          imageId: imageId,
          productCode: '',
          nodes: const [],
          edges: const [],
        ),
        program: ProductionMapProgram(
            mapId: id, productCode: '', operations: const []),
      );
}

class PreparationOrderListWindow {
  const PreparationOrderListWindow({
    required this.scope,
    required this.epoch,
    required this.revision,
    required this.version,
    required this.apparatusId,
    required this.apparatus,
    required this.rows,
    required this.total,
    this.nextCursor,
  });

  final String scope;
  final String epoch;
  final int revision;
  final String version;
  final String apparatusId;
  final List<AdminApparatus> apparatus;
  final List<PreparationOrderListRow> rows;
  final int total;
  final String? nextCursor;

  factory PreparationOrderListWindow.fromJson(Map<String, dynamic> json) {
    if (json['ok'] != true ||
        json['projection'] != 'preparation_order_list_v1' ||
        const {'scope', 'epoch', 'version', 'apparatus_id'}
            .any((key) => json[key] is! String) ||
        (json['scope'] as String).isEmpty ||
        (json['epoch'] as String).isEmpty ||
        (json['version'] as String).isEmpty ||
        json['rev'] is! int ||
        (json['rev'] as int) < 0 ||
        json['total'] is! int ||
        (json['total'] as int) < 0 ||
        json['rows'] is! List ||
        json['apparatus'] is! List ||
        (json['next_cursor'] != null && json['next_cursor'] is! String)) {
      throw _invalidPreparationOrderList();
    }
    final apparatus = <AdminApparatus>[];
    for (final raw in json['apparatus'] as List) {
      if (raw is! Map ||
          raw['id'] is! String ||
          raw['name'] is! String ||
          !isCanonicalApparatusId(raw['id'] as String)) {
        throw _invalidPreparationOrderList();
      }
      apparatus.add(
          AdminApparatus(id: raw['id'] as String, name: raw['name'] as String));
    }
    final rows = <PreparationOrderListRow>[];
    for (final raw in json['rows'] as List) {
      if (raw is! Map) throw _invalidPreparationOrderList();
      rows.add(PreparationOrderListRow.fromJson(raw.cast<String, dynamic>()));
    }
    final selected = json['apparatus_id'] as String;
    if ((selected.isNotEmpty &&
            !apparatus.any((item) => item.id == selected)) ||
        rows.map((row) => row.id).toSet().length != rows.length ||
        rows.length > (json['total'] as int)) {
      throw _invalidPreparationOrderList();
    }
    return PreparationOrderListWindow(
      scope: json['scope'] as String,
      epoch: json['epoch'] as String,
      revision: json['rev'] as int,
      version: json['version'] as String,
      apparatusId: selected,
      apparatus: List.unmodifiable(apparatus),
      rows: List.unmodifiable(rows),
      total: json['total'] as int,
      nextCursor: json['next_cursor'] as String?,
    );
  }
}

MobileApiException _invalidPreparationOrderList() => const MobileApiException(
    code: 'preparation_orders_invalid',
    message: 'Buyurtmalar yuklanmadi. Qayta urinib ko‘ring.');

extension MobileApiPreparationOrders on MobileApi {
  Future<PreparationOrderListWindow> preparationOrders({
    String apparatus = '',
    String search = '',
    String? cursor,
  }) async {
    final owner = _preparationStorageKey();
    final scope = currentSessionReadScope();
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != owner ||
          scope != currentSessionReadScope()) {
        throw _invalidPreparationOrderList();
      }
      return _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/preparation/orders')
            .replace(queryParameters: {
          'limit': '30',
          if (apparatus.isNotEmpty) 'apparatus': apparatus,
          if (search.isNotEmpty) 'search': search,
          if (cursor != null) 'cursor': cursor,
        }),
        headers: _headers(requireToken()),
      );
    });
    if (_preparationStorageKey() != owner ||
        scope != currentSessionReadScope()) {
      throw _invalidPreparationOrderList();
    }
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'preparation_orders_failed');
    }
    return PreparationOrderListWindow.fromJson(
        await decodeJsonMapPayload(response.body));
  }

  Future<AdminApparatusQueueSnapshot> preparationOrderDetail(
      String orderId) async {
    final owner = _preparationStorageKey();
    final scope = currentSessionReadScope();
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != owner ||
          scope != currentSessionReadScope()) {
        throw _invalidPreparationOrderList();
      }
      return _get(
        Uri.parse(
            '${MobileApi.baseUrl}/v1/mobile/preparation/orders/${Uri.encodeComponent(orderId)}'),
        headers: _headers(requireToken()),
      );
    });
    final snapshot = response.statusCode == 200
        ? await decodeProductionMapQueueSnapshotPayload(response.body)
        : throw _adminProductionMapException(
            response, 'preparation_order_detail_failed');
    if (_preparationStorageKey() != owner ||
        scope != currentSessionReadScope() ||
        snapshot.maps.length != 1 ||
        snapshot.maps.single.map.id != orderId ||
        snapshot.epoch.isEmpty ||
        snapshot.revision == null ||
        snapshot.scope.isEmpty) {
      throw _invalidPreparationOrderList();
    }
    return snapshot;
  }

  Stream<Map<String, dynamic>> preparationOrdersLive(
          PreparationOrderListWindow window,
          {String search = ''}) =>
      _productionMapDecodedLive(() {
        final base = Uri.parse(MobileApi.baseUrl);
        return base.replace(
          scheme: base.scheme == 'https' ? 'wss' : 'ws',
          path: '/v1/mobile/preparation/orders/live',
          queryParameters: {
            'token': requireToken(),
            'apparatus': window.apparatusId,
            'search': search,
            'limit': '30',
            'epoch': window.epoch,
            'rev': '${window.revision}',
            'scope': window.scope,
          },
        );
      }, (event) => event);
}
