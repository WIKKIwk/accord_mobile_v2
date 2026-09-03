import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:flutter_test/flutter_test.dart';

ProductionMapDefinition _testMap({
  String id = 'zakaz-0002',
  String code = '0002',
  String orderNumber = '0002',
  String title = 'Magnus',
  String customerName = 'Magnus',
}) {
  return ProductionMapDefinition(
    id: id,
    productCode: 'MAGNUS',
    title: title,
    code: code,
    orderNumber: orderNumber,
    customerName: customerName,
    nodes: const [],
    edges: const [],
  );
}

ProductionMapSaved _testSaved({
  String id = 'zakaz-0002',
  String title = 'Magnus',
  String customerName = 'Magnus',
}) {
  final map = _testMap(id: id, title: title, customerName: customerName);
  return ProductionMapSaved(
    map: map,
    program: ProductionMapProgram(
      mapId: map.id,
      productCode: map.productCode,
      operations: const [],
    ),
  );
}

void main() {
  group('snapshot rev parsing (backward-compatible)', () {
    test('num rev parses to int', () {
      expect(parseProductionMapSnapshotRevision(7), 7);
      expect(parseProductionMapSnapshotRevision(7.0), 7);
    });

    test('numeric string rev parses', () {
      expect(parseProductionMapSnapshotRevision('42'), 42);
    });

    test('missing rev returns null (legacy)', () {
      expect(parseProductionMapSnapshotRevision(null), isNull);
      expect(parseProductionMapSnapshotRevisionFromJson({}), isNull);
      expect(
        parseProductionMapSnapshotRevisionFromJson({'ok': true}),
        isNull,
      );
    });

    test('rev key preferred, revision fallback', () {
      expect(
        parseProductionMapSnapshotRevisionFromJson({'rev': 5}),
        5,
      );
      expect(
        parseProductionMapSnapshotRevisionFromJson({'revision': 6}),
        6,
      );
    });
  });

  group('snapshot maps parsing (legacy-safe)', () {
    test('missing maps returns empty (legacy fallback trigger)', () {
      expect(parseProductionMapSnapshotMaps(null), isEmpty);
      expect(parseProductionMapSnapshotMaps('oops'), isEmpty);
    });

    test('queue snapshot without maps/rev still parses (old backend)', () {
      const snapshot = AdminApparatusQueueSnapshot(
        sequences: {},
        visibleOrderIds: {},
        queueStates: {},
        queuePolicies: {},
        orderControls: {},
      );
      expect(snapshot.maps, isEmpty);
      expect(snapshot.revision, isNull);
    });

    test('live snapshot parses rev + maps', () {
      final saved = _testSaved();
      final snapshot = AdminProductionMapLiveSnapshot.fromJson({
        'ok': true,
        'rev': 9,
        'maps': [
          {
            'map': saved.map.toJson(),
            'program': {
              'map_id': saved.map.id,
              'product_code': saved.map.productCode,
              'operations': const [],
            },
          },
        ],
        'sequences': const {},
        'visible_order_ids': const {},
        'queue_states': const {},
        'queue_policies': const [],
        'queue_action_controls': const {},
        'completed_orders': const [],
        'completion_requests': const [],
        'completion_request_decisions': const [],
        'order_controls': const {},
        'order_customers': const {'zakaz-0002': 'Magnus'},
        'order_statuses': const {},
        'frozen_orders_by_apparatus': const {},
      });
      expect(snapshot.revision, 9);
      expect(snapshot.maps.length, 1);
      expect(snapshot.maps.first.map.title, 'Magnus');
      expect(snapshot.orderCustomers['zakaz-0002'], 'Magnus');
    });
  });

  group('canonical revision guard', () {
    test('first revision applies', () {
      expect(
        canonicalSnapshotDecision(
          incomingRevision: 1,
          lastAppliedRevision: null,
        ),
        CanonicalSnapshotDecision.apply,
      );
    });

    test('duplicate revision does not rewrite', () {
      expect(
        canonicalSnapshotDecision(
          incomingRevision: 5,
          lastAppliedRevision: 5,
        ),
        CanonicalSnapshotDecision.ignoreDuplicate,
      );
    });

    test('stale revision ignored', () {
      expect(
        canonicalSnapshotDecision(
          incomingRevision: 3,
          lastAppliedRevision: 7,
        ),
        CanonicalSnapshotDecision.ignoreStale,
      );
    });

    test('newer revision applies once', () {
      expect(
        canonicalSnapshotDecision(
          incomingRevision: 8,
          lastAppliedRevision: 7,
        ),
        CanonicalSnapshotDecision.apply,
      );
    });

    test('legacy null rev uses fail-safe path', () {
      expect(
        canonicalSnapshotDecision(
          incomingRevision: null,
          lastAppliedRevision: 7,
        ),
        CanonicalSnapshotDecision.applyLegacy,
      );
    });
  });

  group('customer authority (no delayed flicker)', () {
    test('snapshot customer wins', () {
      final map = _testMap(customerName: 'MapCustomer');
      expect(
        resolveCanonicalOrderCustomer(
          map: map,
          customersByMapId: {'zakaz-0002': 'SnapshotCustomer'},
        ),
        'SnapshotCustomer',
      );
    });

    test('missing lookup falls back to map.customerName immediately', () {
      final map = _testMap(customerName: 'Magnus');
      expect(
        resolveCanonicalOrderCustomer(
          map: map,
          customersByMapId: const {},
        ),
        'Magnus',
      );
    });

    test('template must not rewrite card label: only snapshot/map used', () {
      // Simulates a delayed calculate-template arriving with a different
      // customer: the card label must stay on snapshot/map authority.
      final map = _testMap(customerName: 'Magnus');
      final before = resolveCanonicalOrderCustomer(
        map: map,
        customersByMapId: const {'zakaz-0002': 'Magnus'},
      );
      final afterTemplate = resolveCanonicalOrderCustomer(
        map: map,
        customersByMapId: const {'zakaz-0002': 'Magnus'},
      );
      expect(before, 'Magnus');
      expect(afterTemplate, 'Magnus');
    });
  });

  group('live reconnect backoff', () {
    test('1s -> 2s -> 4s -> 8s -> capped at 30s', () {
      expect(productionMapLiveReconnectDelay(0), const Duration(seconds: 1));
      expect(productionMapLiveReconnectDelay(1), const Duration(seconds: 2));
      expect(productionMapLiveReconnectDelay(2), const Duration(seconds: 4));
      expect(productionMapLiveReconnectDelay(3), const Duration(seconds: 8));
      expect(productionMapLiveReconnectDelay(5), const Duration(seconds: 30));
      expect(productionMapLiveReconnectDelay(10), const Duration(seconds: 30));
    });
  });

  group('order title authority', () {
    test('map.title is primary, code fallback preserved', () {
      final map = _testMap(title: 'Mono elektrik', code: '0003');
      expect(map.title.trim(), 'Mono elektrik');
      expect(map.code.trim(), '0003');
    });

    test('legacy empty code keeps orderNumber fallback', () {
      final map = _testMap(code: '', orderNumber: '0099');
      final code =
          map.code.trim().isNotEmpty ? map.code.trim() : map.orderNumber.trim();
      expect(code, '0099');
    });
  });
}
