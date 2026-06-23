part of 'admin_production_map_orders_screen.dart';

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
