import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/mobile_api.dart';
import '../../shared/models/app_models.dart';
import '../models/production_map_models.dart';
import 'factory_map_mapping.dart';

/// Read-only ERP projection. Animation describes queue state, not PLC telemetry.
class FactoryMapLive extends ChangeNotifier {
  FactoryMapLive({
    Future<AdminApparatusQueueSnapshot> Function()? load,
    Future<List<ProductionMapSaved>> Function()? loadMaps,
    DateTime Function()? clock,
  })  : _load = load ?? MobileApi.instance.adminProductionMapQueueSnapshot,
        _loadMaps = loadMaps ?? MobileApi.instance.adminProductionMaps,
        _clock = clock ?? DateTime.now;

  static const freshness = Duration(seconds: 30);
  final Future<AdminApparatusQueueSnapshot> Function() _load;
  final Future<List<ProductionMapSaved>> Function() _loadMaps;
  final DateTime Function() _clock;
  AdminApparatusQueueSnapshot? snapshot;
  List<ProductionMapSaved> maps = const [];
  DateTime? receivedAt;
  bool failed = false;
  bool _active = false;
  bool _disposed = false;
  int _generation = 0;
  int? _request;
  Timer? _poll;
  Timer? _expiry;

  bool get fresh =>
      _active &&
      !failed &&
      receivedAt != null &&
      _clock().difference(receivedAt!) < freshness;

  void start() {
    if (_active || _disposed) return;
    _active = true;
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
    unawaited(refresh());
  }

  void stop() {
    _active = false;
    _generation++;
    _request = null;
    _poll?.cancel();
    _expiry?.cancel();
    receivedAt = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    if (!_active || _disposed || _request != null) return;
    final generation = _generation;
    _request = generation;
    try {
      final next = await _load().timeout(const Duration(seconds: 12));
      if (_disposed || generation != _generation) return;
      if (snapshot?.revision != null &&
          next.revision != null &&
          next.revision! < snapshot!.revision!) {
        throw StateError('Older queue snapshot');
      }
      // Order metadata is optional; it must never delay or invalidate status.
      snapshot = next;
      if (next.maps.isNotEmpty) maps = next.maps;
      receivedAt = _clock();
      failed = false;
      _expiry?.cancel();
      _expiry = Timer(freshness, () {
        if (!_disposed && generation == _generation) notifyListeners();
      });
      notifyListeners();
      final known = maps.map((item) => item.map.id).toSet();
      final missing = next.queueStates.values
          .any((states) => states.keys.any((id) => !known.contains(id)));
      if (next.maps.isEmpty && missing) {
        try {
          final fallback =
              await _loadMaps().timeout(const Duration(seconds: 8));
          if (!_disposed && generation == _generation) {
            maps = fallback;
            notifyListeners();
          }
        } catch (_) {/* A real order ID remains a truthful fallback label. */}
      }
    } catch (_) {
      if (!_disposed && generation == _generation) {
        failed = true;
        notifyListeners();
      }
    } finally {
      if (_request == generation) _request = null;
    }
  }

  Map<String, dynamic> payload(
      List<AdminApparatus> apparatus, String Function(String key) text,
      {String focusedObjectId = ''}) {
    final orderMaps = {for (final item in maps) item.map.id: item.map};
    final machines = <Map<String, dynamic>>[];
    final objectByApparatus = <String, String>{};
    String? focusedOrder;
    for (final item in apparatus) {
      final objectId = canonicalFactoryMapObjectId(item.factoryMapObjectId);
      if (objectId.isEmpty ||
          factoryMapObjectOwners(apparatus, objectId).length != 1) {
        continue;
      }
      objectByApparatus[item.id] = objectId;
      final states = snapshot?.queueStates[item.id] ?? const <String, String>{};
      final ids = <String>{...?(snapshot?.sequences[item.id]), ...states.keys};
      String state = fresh ? 'idle' : 'unknown';
      String orderId = '';
      for (final candidate in const [
        'in_progress',
        'paused',
        'frozen',
        'pending'
      ]) {
        final matching = ids.where((id) => states[id] == candidate);
        if (matching.isNotEmpty) {
          orderId = matching.first;
          if (fresh) state = candidate;
          break;
        }
      }
      if (objectId == canonicalFactoryMapObjectId(focusedObjectId)) {
        focusedOrder = orderId;
      }
      final order = orderMaps[orderId];
      final orderLabel = order == null
          ? orderId
          : [
              order.orderNumber.isNotEmpty ? '#${order.orderNumber}' : order.id,
              order.title
            ].where((value) => value.isNotEmpty).join(' · ');
      machines.add({
        'objectId': objectId,
        'apparatusId': item.id,
        'name': item.name,
        'state': state,
        'statusLabel': text('factory_map.live.$state'),
        'orderId': orderId,
        'orderLabel': orderLabel,
      });
    }
    return {
      'fresh': fresh,
      'validUntil':
          fresh ? receivedAt!.add(freshness).millisecondsSinceEpoch : 0,
      'machines': machines,
      'unknownLabel': text('factory_map.live.unknown'),
      'routeLabel': text('factory_map.live.planned_route'),
      'connections': plannedFactoryMapConnections(
          orderMaps[focusedOrder], objectByApparatus),
    };
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}

/// Traverse graph edges, including intermediate non-machine nodes. This is a
/// planned route, never a claim that material physically moved between machines.
List<Map<String, String>> plannedFactoryMapConnections(
    ProductionMapDefinition? map, Map<String, String> objectByApparatus) {
  if (map == null) return const [];
  final nodes = {for (final node in map.nodes) node.id: node};
  String? objectFor(String id) {
    final node = nodes[id];
    if (node == null) return null;
    final apparatus = node.alternativeAssignedApparatusId.isNotEmpty
        ? node.alternativeAssignedApparatusId
        : node.apparatusId;
    return objectByApparatus[apparatus];
  }

  final links = <String, Map<String, String>>{};
  for (final node in map.nodes) {
    final from = objectFor(node.id);
    if (from == null) continue;
    final visited = <String>{node.id};
    final pending = [node.id];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      for (final edge in map.edges.where((edge) => edge.from == current)) {
        if (!visited.add(edge.to)) continue;
        final to = objectFor(edge.to);
        if (to != null) {
          if (from != to) links['$from/$to'] = {'from': from, 'to': to};
        } else {
          // Do not bridge an unmapped physical apparatus with an invented hop.
          final next = nodes[edge.to];
          if (next != null &&
              next.apparatusId.isEmpty &&
              next.alternativeAssignedApparatusId.isEmpty) {
            pending.add(edge.to);
          }
        }
      }
    }
  }
  return links.values.toList(growable: false);
}
