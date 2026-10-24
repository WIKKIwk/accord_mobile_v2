part of '../mobile_api.dart';

const supplyTaskProjection = 'supply_tasks_v1';
const supplyTaskKinds = {'material', 'qolip'};
const supplyTaskLimits = {5, 10, 20, 50};

typedef SupplyTaskWindowLoader = Future<SupplyTaskWindow> Function({
  required String kind,
  required String apparatus,
  required int limit,
  required String search,
});
typedef SupplyTaskEventsLoader = Stream<SupplyTaskMessage> Function(
    SupplyTaskWindow baseline);

MobileApiException _invalidSupplyTask([bool resync = false]) =>
    MobileApiException(
        code: resync ? 'supply_tasks_resync' : 'supply_tasks_invalid',
        message: 'Vazifalar holatini qayta yuklang.');

bool _supplyInt(Object? value) =>
    value is int && value >= 0 && value <= 9007199254740991;
bool _supplyText(Object? value, {bool nonempty = false}) =>
    value is String && (!nonempty || value.trim().isNotEmpty);

final _supplyPresentationRows = Expando<ProductionMapSaved>();
final _supplyPresentationOrders = Expando<bool>();

/// Summary shells never carry route graphs, write authority or QR authority.
bool isSupplyTaskPresentationOrder(ProductionMapSaved order) =>
    _supplyPresentationOrders[order] == true;

class SupplyTaskRow {
  const SupplyTaskRow({
    required this.id,
    required this.code,
    required this.orderNumber,
    required this.title,
    required this.productCode,
    required this.customerName,
    required this.imageId,
    required this.position,
    required this.apparatusCount,
    required this.taskState,
  });
  final String id, code, orderNumber, title, productCode, customerName, imageId;
  final int position, apparatusCount;
  final String taskState;

  factory SupplyTaskRow.fromJson(Map<String, dynamic> json) {
    if (!const [
          'id',
          'code',
          'order_number',
          'title',
          'product_code',
          'customer_name',
          'image_id'
        ].every((key) => _supplyText(json[key])) ||
        !_supplyText(json['id'], nonempty: true) ||
        !_supplyInt(json['position']) ||
        !_supplyInt(json['apparatus_count']) ||
        !const {'missing', 'partial'}.contains(json['task_state'])) {
      throw _invalidSupplyTask();
    }
    return SupplyTaskRow(
      id: json['id'],
      code: json['code'],
      orderNumber: json['order_number'],
      title: json['title'],
      productCode: json['product_code'],
      customerName: json['customer_name'],
      imageId: json['image_id'],
      position: json['position'],
      apparatusCount: json['apparatus_count'],
      taskState: json['task_state'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'order_number': orderNumber,
        'title': title,
        'product_code': productCode,
        'customer_name': customerName,
        'image_id': imageId,
        'position': position,
        'apparatus_count': apparatusCount,
        'task_state': taskState,
      };

  ProductionMapSaved toPresentationOrder() {
    final cached = _supplyPresentationRows[this];
    if (cached != null) return cached;
    final order = ProductionMapSaved(
      map: ProductionMapDefinition(
          id: id,
          code: code,
          orderNumber: orderNumber,
          title: title,
          productCode: productCode,
          customerName: customerName,
          imageId: imageId,
          nodes: const [],
          edges: const []),
      program: ProductionMapProgram(
          mapId: id, productCode: productCode, operations: const []),
    );
    _supplyPresentationOrders[order] = true;
    return _supplyPresentationRows[this] = order;
  }
}

class SupplyTaskWindow {
  SupplyTaskWindow({
    required this.kind,
    required this.scope,
    required this.epoch,
    required this.revision,
    required this.version,
    required this.apparatusId,
    required this.limit,
    required this.search,
    required this.checkedCount,
    required this.missingCount,
    required List<SupplyTaskRow> rows,
    required List<AdminApparatus> apparatus,
  })  : rows = List.unmodifiable(rows),
        apparatus = List.unmodifiable(apparatus);

  final String kind, scope, epoch, version, apparatusId, search;
  final int revision, limit, checkedCount, missingCount;
  final List<SupplyTaskRow> rows;
  final List<AdminApparatus> apparatus;

  factory SupplyTaskWindow.fromJson(Map<String, dynamic> json) {
    if (json['ok'] != true ||
        json['projection'] != supplyTaskProjection ||
        !supplyTaskKinds.contains(json['kind']) ||
        !const ['scope', 'epoch', 'version']
            .every((key) => _supplyText(json[key], nonempty: true)) ||
        !_supplyInt(json['rev']) ||
        json['limit'] is! int ||
        !supplyTaskLimits.contains(json['limit']) ||
        !_supplyText(json['apparatus_id']) ||
        !_supplyText(json['search']) ||
        json['rows'] is! List ||
        json['apparatus'] is! List) {
      throw _invalidSupplyTask();
    }
    final rows = (json['rows'] as List).map((value) {
      if (value is! Map) throw _invalidSupplyTask();
      return SupplyTaskRow.fromJson(value.cast<String, dynamic>());
    }).toList(growable: false);
    final apparatus = (json['apparatus'] as List).map((value) {
      if (value is! Map) throw _invalidSupplyTask();
      try {
        return AdminApparatus.fromJson(value.cast<String, dynamic>());
      } catch (_) {
        throw _invalidSupplyTask();
      }
    }).toList(growable: false);
    final selected = json['apparatus_id'] as String;
    if (apparatus.map((item) => item.id).toSet().length != apparatus.length ||
        (apparatus.isEmpty
            ? selected.isNotEmpty
            : !apparatus.any((item) => item.id == selected))) {
      throw _invalidSupplyTask();
    }
    _validateSupplyRows(
        rows, json['checked_count'], json['missing_count'], json['limit']);
    if ((json['search'] as String).isEmpty &&
        rows.length != json['missing_count']) {
      throw _invalidSupplyTask();
    }
    if (apparatus.isEmpty && (json['checked_count'] != 0 || rows.isNotEmpty)) {
      throw _invalidSupplyTask();
    }
    return SupplyTaskWindow(
        kind: json['kind'],
        scope: json['scope'],
        epoch: json['epoch'],
        revision: json['rev'],
        version: json['version'],
        apparatusId: selected,
        limit: json['limit'],
        search: json['search'],
        checkedCount: json['checked_count'],
        missingCount: json['missing_count'],
        rows: rows,
        apparatus: apparatus);
  }

  Map<String, dynamic> toJson() => {
        'ok': true,
        'projection': supplyTaskProjection,
        'kind': kind,
        'scope': scope,
        'epoch': epoch,
        'rev': revision,
        'version': version,
        'apparatus_id': apparatusId,
        'limit': limit,
        'search': search,
        'checked_count': checkedCount,
        'missing_count': missingCount,
        'rows': rows.map((row) => row.toJson()).toList(growable: false),
        'apparatus':
            apparatus.map((item) => item.toJson()).toList(growable: false),
      };

  SupplyTaskWindow applyDelta(SupplyTaskDelta delta) {
    if (delta.epoch != epoch ||
        delta.scope != scope ||
        delta.baseRevision != revision ||
        delta.revision <= revision) {
      throw _invalidSupplyTask(true);
    }
    // Work on private copies; any incomplete/corrupt edit rejects atomically.
    final next = {for (final row in rows) row.id: row};
    final ids = delta.orderIds.toSet();
    final removed = delta.remove.toSet();
    final expectedRemoved = next.keys.where((id) => !ids.contains(id)).toSet();
    if (!setEquals(removed, expectedRemoved) ||
        delta.upsert
            .any((row) => !ids.contains(row.id) || removed.contains(row.id))) {
      throw _invalidSupplyTask(true);
    }
    for (final id in removed) {
      next.remove(id);
    }
    for (final row in delta.upsert) {
      next[row.id] = row;
    }
    if (next.length != ids.length || ids.any((id) => !next.containsKey(id))) {
      throw _invalidSupplyTask(true);
    }
    final ordered =
        delta.orderIds.map((id) => next[id]!).toList(growable: false);
    _validateSupplyRows(ordered, delta.checkedCount, delta.missingCount, limit,
        resync: true);
    if (search.isEmpty && ordered.length != delta.missingCount) {
      throw _invalidSupplyTask(true);
    }
    return SupplyTaskWindow(
        kind: kind,
        scope: scope,
        epoch: epoch,
        revision: delta.revision,
        version: delta.version,
        apparatusId: apparatusId,
        limit: limit,
        search: search,
        checkedCount: delta.checkedCount,
        missingCount: delta.missingCount,
        rows: ordered,
        apparatus: apparatus);
  }
}

void _validateSupplyRows(
    List<SupplyTaskRow> rows, Object? checked, Object? missing, int limit,
    {bool resync = false}) {
  if (!_supplyInt(checked) || !_supplyInt(missing)) {
    throw _invalidSupplyTask(resync);
  }
  final checkedCount = checked as int;
  final missingCount = missing as int;
  if (checkedCount > limit ||
      missingCount > checkedCount ||
      rows.length > missingCount ||
      rows.map((row) => row.id).toSet().length != rows.length) {
    throw _invalidSupplyTask(resync);
  }
  var previous = -1;
  for (final row in rows) {
    if (row.position <= previous || row.position >= checkedCount) {
      throw _invalidSupplyTask(resync);
    }
    previous = row.position;
  }
}

abstract class SupplyTaskMessage {
  const SupplyTaskMessage();
  factory SupplyTaskMessage.fromJson(Map<String, dynamic> json) {
    if (json['ok'] != true) {
      throw MobileApiException(
          code: json['error'] is String
              ? json['error'] as String
              : 'supply_tasks_failed',
          message: 'Vazifalar oqimi uzildi.',
          statusCode: json['status'] is int ? json['status'] as int : null);
    }
    switch (json['type']) {
      case 'tasks_snapshot':
        if (json['window'] is! Map) throw _invalidSupplyTask();
        return SupplyTaskSnapshot(SupplyTaskWindow.fromJson(
            (json['window'] as Map).cast<String, dynamic>()));
      case 'tasks_delta':
        return SupplyTaskDelta.fromJson(json);
      case 'tasks_ready':
        return SupplyTaskReady.fromJson(json);
      default:
        throw _invalidSupplyTask();
    }
  }
  SupplyTaskWindow applyTo(SupplyTaskWindow baseline);
}

class SupplyTaskSnapshot extends SupplyTaskMessage {
  const SupplyTaskSnapshot(this.window);
  final SupplyTaskWindow window;
  @override
  SupplyTaskWindow applyTo(SupplyTaskWindow baseline) {
    if (window.kind != baseline.kind ||
        window.limit != baseline.limit ||
        window.search != baseline.search ||
        (window.epoch == baseline.epoch &&
            window.revision < baseline.revision)) {
      throw _invalidSupplyTask(true);
    }
    return window;
  }
}

class SupplyTaskDelta extends SupplyTaskMessage {
  SupplyTaskDelta(
      {required this.epoch,
      required this.scope,
      required this.baseRevision,
      required this.revision,
      required this.version,
      required this.checkedCount,
      required this.missingCount,
      required List<String> orderIds,
      required List<SupplyTaskRow> upsert,
      required List<String> remove})
      : orderIds = List.unmodifiable(orderIds),
        upsert = List.unmodifiable(upsert),
        remove = List.unmodifiable(remove);
  final String epoch, scope, version;
  final int baseRevision, revision, checkedCount, missingCount;
  final List<String> orderIds, remove;
  final List<SupplyTaskRow> upsert;
  factory SupplyTaskDelta.fromJson(Map<String, dynamic> json) {
    _validateSupplyCursor(json);
    if (!_supplyInt(json['base_rev']) ||
        json['rev'] <= json['base_rev'] ||
        !_supplyInt(json['checked_count']) ||
        !_supplyInt(json['missing_count']) ||
        json['upsert'] is! List) {
      throw _invalidSupplyTask();
    }
    final upsert = (json['upsert'] as List).map((value) {
      if (value is! Map) throw _invalidSupplyTask();
      return SupplyTaskRow.fromJson(value.cast<String, dynamic>());
    }).toList(growable: false);
    if (upsert.map((row) => row.id).toSet().length != upsert.length) {
      throw _invalidSupplyTask();
    }
    return SupplyTaskDelta(
        epoch: json['epoch'],
        scope: json['scope'],
        baseRevision: json['base_rev'],
        revision: json['rev'],
        version: json['version'],
        checkedCount: json['checked_count'],
        missingCount: json['missing_count'],
        orderIds: _supplyIds(json['order_ids']),
        upsert: upsert,
        remove: _supplyIds(json['remove']));
  }
  @override
  SupplyTaskWindow applyTo(SupplyTaskWindow baseline) =>
      baseline.applyDelta(this);
}

class SupplyTaskReady extends SupplyTaskMessage {
  const SupplyTaskReady(
      {required this.epoch,
      required this.scope,
      required this.revision,
      required this.version});
  final String epoch, scope, version;
  final int revision;
  factory SupplyTaskReady.fromJson(Map<String, dynamic> json) {
    _validateSupplyCursor(json);
    if (json['resync'] != false) throw _invalidSupplyTask(true);
    return SupplyTaskReady(
        epoch: json['epoch'],
        scope: json['scope'],
        revision: json['rev'],
        version: json['version']);
  }
  bool matches(SupplyTaskWindow baseline) =>
      epoch == baseline.epoch &&
      scope == baseline.scope &&
      revision == baseline.revision &&
      version == baseline.version;
  @override
  SupplyTaskWindow applyTo(SupplyTaskWindow baseline) {
    if (!matches(baseline)) throw _invalidSupplyTask(true);
    return baseline;
  }
}

void _validateSupplyCursor(Map<String, dynamic> json) {
  if (!const ['epoch', 'scope', 'version']
          .every((key) => _supplyText(json[key], nonempty: true)) ||
      !_supplyInt(json['rev'])) {
    throw _invalidSupplyTask();
  }
}

List<String> _supplyIds(Object? raw) {
  if (raw is! List ||
      raw.any((id) => !_supplyText(id, nonempty: true)) ||
      raw.toSet().length != raw.length) {
    throw _invalidSupplyTask();
  }
  return List<String>.unmodifiable(raw.cast<String>());
}

final _supplyTaskReads = Expando<Map<String, Future<SupplyTaskWindow>>>();

extension MobileApiSupplyTasks on MobileApi {
  Future<SupplyTaskWindow> supplyTaskWindow(
      {required String kind,
      String apparatus = '',
      int limit = 10,
      String search = ''}) {
    final query = _supplyTaskQuery(kind, apparatus, limit, search);
    final owner = currentSessionReadScope();
    final endpoint = MobileApi.baseUrl;
    final reads = _supplyTaskReads[Zone.current] ??= {};
    final key = jsonEncode(
        [endpoint, owner, requireToken(), _queueSnapshotReadEpoch, query]);
    final existing = reads[key];
    if (existing != null) return existing;
    late final Future<SupplyTaskWindow> future;
    future = () async {
      final response = await _sendAuthorized(() => _get(
          Uri.parse('$endpoint/v1/mobile/production-tasks/window')
              .replace(queryParameters: query),
          headers: _headers(requireToken())));
      if (owner != currentSessionReadScope() || endpoint != MobileApi.baseUrl) {
        throw const MobileApiException(
            code: 'session_changed', message: 'Hisob o‘zgardi.');
      }
      if (response.statusCode != 200) {
        throw _adminProductionMapException(response, 'supply_tasks_failed');
      }
      final decoded = await decodeJsonMapPayload(response.body);
      if (owner != currentSessionReadScope() || endpoint != MobileApi.baseUrl) {
        throw const MobileApiException(
            code: 'session_changed', message: 'Hisob o‘zgardi.');
      }
      final window = SupplyTaskWindow.fromJson(decoded);
      if (window.kind != kind ||
          window.limit != limit ||
          window.search != search.trim().toLowerCase()) {
        throw _invalidSupplyTask();
      }
      return window;
    }()
        .whenComplete(() {
      if (identical(reads[key], future)) reads.remove(key);
    });
    reads[key] = future;
    return future;
  }

  Stream<SupplyTaskMessage> supplyTaskLive(SupplyTaskWindow baseline) =>
      _supplyTaskInitialMessage(_productionMapDecodedLive(() {
        final query = _supplyTaskQuery(baseline.kind, baseline.apparatusId,
            baseline.limit, baseline.search)
          ..addAll({
            'token': requireToken(),
            'epoch': baseline.epoch,
            'rev': '${baseline.revision}',
            'scope': baseline.scope
          });
        final uri =
            Uri.parse('${MobileApi.baseUrl}/v1/mobile/production-tasks/live');
        return uri.replace(
            scheme: uri.scheme == 'https' ? 'wss' : 'ws',
            queryParameters: query);
      }, SupplyTaskMessage.fromJson));
}

/// Bound only initial negotiation; a healthy unchanged window may stay silent.
Stream<SupplyTaskMessage> _supplyTaskInitialMessage(
    Stream<SupplyTaskMessage> source) {
  final controller = StreamController<SupplyTaskMessage>();
  StreamSubscription<SupplyTaskMessage>? subscription;
  Timer? firstMessage;
  var cancelled = false;
  void fail(Object error, StackTrace stack) {
    if (cancelled || controller.isClosed) return;
    firstMessage?.cancel();
    controller.addError(error, stack);
    unawaited(subscription?.cancel());
    unawaited(controller.close());
  }

  controller.onListen = () {
    firstMessage = Timer(
        const Duration(seconds: 10),
        () => fail(TimeoutException('Supply task initial snapshot'),
            StackTrace.current));
    subscription = source.listen(
        (message) {
          firstMessage?.cancel();
          if (!cancelled && !controller.isClosed) controller.add(message);
        },
        onError: fail,
        onDone: () {
          firstMessage?.cancel();
          if (!cancelled && !controller.isClosed) unawaited(controller.close());
        });
  };
  controller.onPause = () => subscription?.pause();
  controller.onResume = () => subscription?.resume();
  controller.onCancel = () {
    cancelled = true;
    firstMessage?.cancel();
    unawaited(subscription?.cancel());
  };
  return controller.stream;
}

Map<String, String> _supplyTaskQuery(
    String kind, String apparatus, int limit, String search) {
  if (!supplyTaskKinds.contains(kind) ||
      !supplyTaskLimits.contains(limit) ||
      (apparatus.isNotEmpty && !isCanonicalApparatusId(apparatus))) {
    throw ArgumentError('Invalid supply task window');
  }
  return {
    'kind': kind,
    'apparatus': apparatus,
    'limit': '$limit',
    'search': search.trim().toLowerCase()
  };
}
