import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/logic/factory_map_live.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

AdminApparatusQueueSnapshot snapshot(Map<String, String> states,
        {int revision = 1}) =>
    AdminApparatusQueueSnapshot(
        sequences: {'a': states.keys.toList()},
        visibleOrderIds: {'a': states.keys.toList()},
        queueStates: {'a': states},
        queuePolicies: const {},
        orderControls: const {},
        revision: revision);
const machine =
    AdminApparatus(id: 'a', name: 'Bosma', factoryMapObjectId: 'node:7');
Future<void> flush() => Future<void>.delayed(Duration.zero);
Map<String, dynamic> row(FactoryMapLive live) =>
    (live.payload([machine], (key) => key)['machines'] as List).single;

void main() {
  test(
      'running order wins over paused queue entries; pause/freeze/idle are distinct',
      () async {
    var states = {'paused-order': 'paused', 'current-order': 'in_progress'};
    final live = FactoryMapLive(
        load: () async => snapshot(states), loadMaps: () async => []);
    addTearDown(live.dispose);
    live.start();
    await flush();
    expect(row(live)['state'], 'in_progress');
    expect(row(live)['orderId'], 'current-order');
    for (final state in ['paused', 'frozen', 'pending']) {
      states = {'order': state};
      await live.refresh();
      expect(row(live)['state'], state);
    }
    states = {};
    await live.refresh();
    expect(row(live)['state'], 'idle');
  });

  test('stale, failed and stopped state cannot animate retained running data',
      () async {
    var now = DateTime(2026);
    var fail = false;
    final live = FactoryMapLive(
        clock: () => now,
        load: () async {
          if (fail) throw StateError('offline');
          return snapshot({'order': 'in_progress'});
        },
        loadMaps: () async => []);
    addTearDown(live.dispose);
    live.start();
    await flush();
    expect(live.fresh, isTrue);
    now = now.add(const Duration(seconds: 30));
    expect(row(live)['state'], 'unknown');
    await live.refresh();
    expect(live.fresh, isTrue);
    fail = true;
    await live.refresh();
    expect(live.payload([machine], (s) => s)['validUntil'], 0);
    expect(row(live)['state'], 'unknown');
    fail = false;
    await live.refresh();
    live.stop();
    expect(row(live)['state'], 'unknown');
  });

  test('overlapping reads coalesce and response after stop is ignored',
      () async {
    var count = 0;
    final pending = Completer<AdminApparatusQueueSnapshot>();
    final live = FactoryMapLive(load: () {
      count++;
      return pending.future;
    });
    live.start();
    await live.refresh();
    await live.refresh();
    expect(count, 1);
    live.stop();
    pending.complete(snapshot({'order': 'in_progress'}));
    await flush();
    expect(live.snapshot, isNull);
    live.dispose();
  });

  test('older server revision fails closed, missing map metadata does not',
      () async {
    var revision = 3;
    final live = FactoryMapLive(
        load: () async =>
            snapshot({'order': 'in_progress'}, revision: revision),
        loadMaps: () async => throw StateError('map unavailable'));
    addTearDown(live.dispose);
    live.start();
    await flush();
    expect(row(live)['orderLabel'], 'order');
    expect(live.fresh, isTrue);
    revision = 2;
    await live.refresh();
    expect(live.fresh, isFalse);
    expect(live.snapshot?.revision, 3);
  });

  test('unmapped and duplicate object owners do not produce live labels',
      () async {
    final live = FactoryMapLive(load: () async => snapshot({}));
    addTearDown(live.dispose);
    live.start();
    await flush();
    expect(
        live.payload(
            [machine, machine.copyWith(id: 'b')], (s) => s)['machines'],
        isEmpty);
    expect(
        live.payload(
            [machine.copyWith(factoryMapObjectId: '')], (s) => s)['machines'],
        isEmpty);
  });

  test(
      'planned route follows edges, handles cycles and selected alternatives, never skips unmapped apparatus',
      () {
    const map = ProductionMapDefinition(
        id: 'order',
        productCode: '',
        title: '',
        nodes: [
          ProductionMapNode(
              id: 'c', kind: 'apparatus', title: '', apparatusId: 'c'),
          ProductionMapNode(
              id: 'a', kind: 'apparatus', title: '', apparatusId: 'a'),
          ProductionMapNode(id: 'wip', kind: 'material', title: ''),
          ProductionMapNode(
              id: 'b',
              kind: 'apparatus',
              title: '',
              apparatusId: 'b',
              alternativeAssignedApparatusId: 'alt'),
          ProductionMapNode(
              id: 'missing',
              kind: 'apparatus',
              title: '',
              apparatusId: 'not-mapped'),
        ],
        edges: [
          ProductionMapEdge(from: 'a', to: 'wip'),
          ProductionMapEdge(from: 'wip', to: 'a'),
          ProductionMapEdge(from: 'wip', to: 'b'),
          ProductionMapEdge(from: 'b', to: 'c'),
          ProductionMapEdge(from: 'a', to: 'missing'),
          ProductionMapEdge(from: 'missing', to: 'c'),
        ]);
    expect(
        plannedFactoryMapConnections(
            map, {'a': 'node:1', 'b': 'wrong', 'alt': 'node:2', 'c': 'node:3'}),
        [
          {'from': 'node:1', 'to': 'node:2'},
          {'from': 'node:2', 'to': 'node:3'},
        ]);
  });
}
