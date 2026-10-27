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

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'order_number': orderNumber,
        'title': title,
        'customer_name': customerName,
        'image_id': imageId,
        'position': position,
      };

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
    this.search = '',
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
  final String search;

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
      search: json['search'] is String
          ? (json['search'] as String).trim().toLowerCase()
          : '',
    );
  }

  Map<String, dynamic> toJson() => {
        'ok': true,
        'projection': 'preparation_order_list_v1',
        'scope': scope,
        'epoch': epoch,
        'rev': revision,
        'version': version,
        'apparatus_id': apparatusId,
        'apparatus': [
          for (final item in apparatus) {'id': item.id, 'name': item.name},
        ],
        'rows': rows.map((row) => row.toJson()).toList(),
        'total': total,
        'next_cursor': nextCursor,
        'search': search,
      };

  PreparationOrderListWindow copyWith({
    String? search,
    int? revision,
    String? version,
    List<PreparationOrderListRow>? rows,
    int? total,
    String? nextCursor,
    bool clearNextCursor = false,
  }) =>
      PreparationOrderListWindow(
        scope: scope,
        epoch: epoch,
        revision: revision ?? this.revision,
        version: version ?? this.version,
        apparatusId: apparatusId,
        apparatus: apparatus,
        rows: rows == null ? this.rows : List.unmodifiable(rows),
        total: total ?? this.total,
        nextCursor: clearNextCursor ? null : nextCursor ?? this.nextCursor,
        search: search ?? this.search,
      );

  /// A checkpoint validates existing display rows without another HTTP read.
  PreparationOrderListWindow applyLiveCheckpoint(Map<String, dynamic> event) {
    if (event['epoch'] != epoch ||
        event['scope'] != scope ||
        event['version'] != version ||
        (event['apparatus_id'] != null &&
            event['apparatus_id'] != apparatusId) ||
        event['rev'] is! int ||
        (event['rev'] as int) < revision) {
      throw _preparationOrdersResync();
    }
    return copyWith(revision: event['rev'] as int);
  }

  /// Only an exact visible baseline may accept a patch. Cached labels never
  /// grant detail access; the screen separately tracks server validation.
  PreparationOrderListWindow applyLiveDelta(Map<String, dynamic> event) {
    if (event['base_version'] != version ||
        event['scope'] != scope ||
        event['epoch'] != epoch ||
        event['apparatus_id'] != apparatusId ||
        event['rev'] is! int ||
        (event['rev'] as int) < revision ||
        event['order_ids'] is! List ||
        event['upserts'] is! List ||
        event['removed_ids'] is! List) {
      throw _preparationOrdersResync();
    }
    List<String> ids(Object? raw) {
      if (raw is! List || raw.any((id) => id is! String || id.isEmpty)) {
        throw _preparationOrdersResync();
      }
      final result = raw.cast<String>();
      if (result.toSet().length != result.length) {
        throw _preparationOrdersResync();
      }
      return result;
    }

    final orderIds = ids(event['order_ids']);
    final removed = ids(event['removed_ids']);
    final orderIdSet = orderIds.toSet();
    final removedSet = removed.toSet();
    final byId = {for (final row in rows) row.id: row};
    if (removed.any((id) => !byId.containsKey(id) || orderIdSet.contains(id)) ||
        byId.keys.any(
            (id) => !orderIdSet.contains(id) && !removedSet.contains(id))) {
      throw _preparationOrdersResync();
    }
    for (final id in removed) {
      byId.remove(id);
    }
    final upserts = <String>{};
    for (final raw in event['upserts'] as List) {
      if (raw is! Map) throw _preparationOrdersResync();
      final row = PreparationOrderListRow.fromJson(raw.cast<String, dynamic>());
      if (!upserts.add(row.id) || !orderIdSet.contains(row.id)) {
        throw _preparationOrdersResync();
      }
      byId[row.id] = row;
    }
    if (orderIds.any((id) => !byId.containsKey(id))) {
      throw _preparationOrdersResync();
    }
    final metadata = PreparationOrderListWindow.fromJson({
      ...event,
      'ok': true,
      'search': search,
      'rows': const [],
    });
    if (orderIds.length > metadata.total) throw _preparationOrdersResync();
    return metadata.copyWith(rows: [for (final id in orderIds) byId[id]!]);
  }
}

MobileApiException _preparationOrdersResync() => const MobileApiException(
    code: 'preparation_orders_resync',
    statusCode: 409,
    message: 'Buyurtmalar o‘zgardi. Qayta yuklang.');

MobileApiException _invalidPreparationOrderList() => const MobileApiException(
    code: 'preparation_orders_invalid',
    message: 'Buyurtmalar yuklanmadi. Qayta urinib ko‘ring.');

extension MobileApiPreparationOrders on MobileApi {
  Future<PreparationOrderListWindow> preparationOrders({
    String apparatus = '',
    String search = '',
    String? cursor,
    PreparationOrderListWindow? baseline,
    bool refresh = false,
  }) async {
    final normalizedSearch = search.trim().toLowerCase();
    final conditional = cursor == null &&
            baseline != null &&
            baseline.search == normalizedSearch &&
            (apparatus.isEmpty || apparatus == baseline.apparatusId)
        ? baseline
        : null;
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
          if (normalizedSearch.isNotEmpty) 'search': normalizedSearch,
          if (cursor != null) 'cursor': cursor,
          if (conditional != null && conditional.rows.length > 30)
            'length': '${conditional.rows.length.clamp(30, 10000)}',
          if (conditional != null && !refresh)
            'if_version': conditional.version,
          if (refresh) 'refresh': 'true',
        }),
        headers: _headers(requireToken()),
      );
    });
    if (_preparationStorageKey() != owner ||
        scope != currentSessionReadScope()) {
      throw _invalidPreparationOrderList();
    }
    if (response.statusCode == 304) {
      if (conditional == null || refresh) throw _invalidPreparationOrderList();
      final epoch = response.headers['x-production-epoch'];
      final serverScope = response.headers['x-preparation-scope'];
      final version = response.headers['x-preparation-version'];
      final revision =
          int.tryParse(response.headers['x-production-revision'] ?? '');
      if ((epoch != null && epoch != conditional.epoch) ||
          (serverScope != null && serverScope != conditional.scope) ||
          (version != null && version != conditional.version) ||
          (revision != null && revision < conditional.revision)) {
        throw _preparationOrdersResync();
      }
      return conditional.copyWith(revision: revision);
    }
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'preparation_orders_failed');
    }
    return PreparationOrderListWindow.fromJson(
            await decodeJsonMapPayload(response.body))
        .copyWith(search: normalizedSearch);
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
          {String search = '',
          int? length}) =>
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
            'version': window.version,
            'length': '${length ?? window.rows.length}',
          },
        );
      }, (event) => event);
}
