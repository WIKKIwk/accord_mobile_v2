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
