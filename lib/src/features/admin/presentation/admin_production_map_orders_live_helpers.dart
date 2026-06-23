part of 'admin_production_map_orders_screen.dart';

class _ProductionMapLiveStreamParser {
  final List<String> _dataLines = [];

  AdminProductionMapLiveSnapshot? readLine(String line) {
    if (line.isEmpty) {
      return _flush();
    }
    if (line.startsWith(':')) {
      return null;
    }
    if (line.startsWith('data:')) {
      _dataLines.add(line.substring(5).trimLeft());
    }
    return null;
  }

  AdminProductionMapLiveSnapshot? _flush() {
    if (_dataLines.isEmpty) {
      return null;
    }
    final payloadText = _dataLines.join('\n');
    _dataLines.clear();
    final payload = jsonDecode(payloadText) as Map<String, dynamic>;
    if (payload['ok'] != true) {
      return null;
    }
    return AdminProductionMapLiveSnapshot.fromJson(payload);
  }
}

Future<http.StreamedResponse> _connectProductionMapLiveStream() async {
  final response = await MobileApi.instance.adminProductionMapLiveConnect();
  if (response.statusCode < 200 || response.statusCode > 299) {
    throw MobileApiException(
      code: 'production_map_live',
      message: 'Live ulanish ochilmadi',
      statusCode: response.statusCode,
    );
  }
  return response;
}

_ProductionMapLiveConnection _productionMapLiveConnection({
  required http.StreamedResponse response,
  required bool Function() isActive,
  required void Function(AdminProductionMapLiveSnapshot snapshot) onSnapshot,
}) {
  final completer = Completer<void>();
  final parser = _ProductionMapLiveStreamParser();
  final subscription = response.stream
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen(
    (line) {
      if (!isActive()) {
        return;
      }
      final snapshot = parser.readLine(line);
      if (snapshot != null) {
        onSnapshot(snapshot);
      }
    },
    onError: (error, _) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    },
    onDone: () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    },
    cancelOnError: true,
  );
  return _ProductionMapLiveConnection(
    subscription: subscription,
    completed: completer.future,
  );
}

List<ProductionMapSaved> _productionMapZakazOrders(
  List<ProductionMapSaved> maps,
) {
  return maps
      .where((item) => item.map.id.trim().startsWith('zakaz-'))
      .toList(growable: false);
}

List<AdminCompletionRequestDecisionNotification>
    _newRejectedCompletionRequestDecisions({
  required List<AdminCompletionRequestDecisionNotification> decisions,
  required Set<String> shownDecisionIds,
}) {
  return decisions
      .where(
        (decision) =>
            decision.decision.trim() == 'rejected' &&
            decision.eventId.trim().isNotEmpty &&
            !shownDecisionIds.contains(decision.eventId.trim()),
      )
      .toList(growable: false);
}

String _completionRejectedNoticeText(
  AdminCompletionRequestDecisionNotification decision,
) {
  final message = decision.message.trim();
  return message.isNotEmpty ? message : "Sizni so'rovingiz rad etildi";
}

bool _apparatusListsSameByWarehouse(
  List<AdminWarehouse> current,
  List<AdminWarehouse> next,
) {
  return current.length == next.length &&
      current.every(
        (item) =>
            next.any((candidate) => candidate.warehouse == item.warehouse),
      );
}

Future<List<AdminCompletedQueueOrder>> _loadCompletedProductionMapOrders() {
  return MobileApi.instance.adminCompletedProductionMapOrders();
}

Future<List<AdminCompletionRequestDecisionNotification>>
    _loadProductionMapCompletionRequestDecisions() {
  return MobileApi.instance.adminProductionMapCompletionRequestDecisions();
}

Future<List<AdminClosedProductionOrder>> _loadClosedProductionMapOrders() {
  return MobileApi.instance.adminClosedProductionMapOrders();
}

Future<List<AdminCompletionRequestNotification>>
    _loadProductionMapCompletionRequests() {
  return MobileApi.instance.adminProductionMapCompletionRequests();
}

Future<List<AdminWarehouse>> _loadProductionMapApparatus() {
  return MobileApi.instance.adminWarehouses(parent: 'aparat - A', limit: 200);
}

Future<_ProductionMapOrdersAndApparatus>
    _loadProductionMapOrdersAndApparatus() async {
  final results = await Future.wait([
    MobileApi.instance.adminProductionMaps(),
    _loadProductionMapApparatus(),
  ]);
  final maps = results[0] as List<ProductionMapSaved>;
  final apparatus = results[1] as List<AdminWarehouse>;
  return _ProductionMapOrdersAndApparatus(
    orders: _productionMapZakazOrders(maps),
    apparatus: apparatus,
  );
}

bool _productionMapOrdersOrApparatusChanged({
  required List<ProductionMapSaved> currentOrders,
  required List<ProductionMapSaved> nextOrders,
  required List<AdminWarehouse> currentApparatus,
  required List<AdminWarehouse> nextApparatus,
}) {
  return _ordersRevision(nextOrders) != _ordersRevision(currentOrders) ||
      !_apparatusListsSameByWarehouse(currentApparatus, nextApparatus);
}

bool _shouldRefreshWorkerOnlyData(bool workerMode) {
  return workerMode;
}

bool _shouldRefreshAdminOnlyData(bool workerMode) {
  return !workerMode;
}
