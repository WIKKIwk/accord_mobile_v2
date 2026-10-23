import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/core/production/worker_queue_warm_store.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_scan_bootstrap_fixtures.dart';

const _station = scanApparatus;
Map<String, dynamic> _workerList() => {
      'projection': 'worker_list_v1',
      'ok': true,
      'epoch': 'worker-server',
      'scope': 'worker-list-scope',
      'rev': 7,
      'worker_show_all_apparatus_tabs': false,
      'worker_list_rows': {
        for (final id in ['work-1', 'work-2', 'work-history'])
          id: {
            'id': id,
            'code': id,
            'title': 'Mahsulot 😀',
            'customer_name': 'Mijoz',
            'image_id': 'image-1'
          },
      },
      'worker_display_states': {
        _station: {
          'work-1': 'pending',
          'work-2': 'in_progress',
          'work-history': 'completed'
        }
      },
      'worker_pending_report_ids': {
        _station: ['work-history', 'work-2']
      },
      'worker_report_prompts': {
        _station: {
          'work-2': {'report_session_id': 'report-1', 'upstream_title': 'Bosma'}
        }
      },
      'sequences': {
        _station: ['work-1', 'work-2']
      },
      'sequence_versions': {_station: 'seq-1'},
      'sequence_revisions': {_station: 4},
      'sequence_positions_by_apparatus': {
        _station: {'work-1': 1, 'work-2': 2}
      },
      'visible_order_ids': {
        _station: ['work-1', 'work-2']
      },
      'queue_states': {
        _station: {
          'work-1': 'pending',
          'work-2': 'in_progress',
          'work-history': 'completed'
        }
      },
      'queue_policies': [
        {
          'apparatus_id': _station,
          'apparatus': 'Bosma',
          'policy': 'strict_sequence',
          'locked': true,
          'reason': ''
        }
      ],
      'order_controls': {
        'work-1': {'state': 'frozen'}
      },
      'completed_orders': [
        {
          'apparatus': _station,
          'order_id': 'work-history',
          'status': 'completed',
          'completed_at_unix': 123
        }
      ],
      'completion_requests': [],
      'completion_request_decisions': [],
    };

Map<String, dynamic> _fullDetail() => {
      ...scanSequence(),
      'scope': 'worker-detail-scope',
      'projection': 'worker_detail_v1',
      'maps': [
        {
          'map': {
            'id': scanOrder,
            'code': '7',
            'title': 'Full graph',
            'product_code': 'P',
            'nodes': [],
            'edges': []
          },
          'program': {
            'map_id': scanOrder,
            'product_code': 'P',
            'operations': []
          },
        }
      ],
    };

Map<String, dynamic> _field(Map<String, dynamic> values,
        [List<String> remove = const []]) =>
    {'upsert': values, 'remove': remove};
Map<String, dynamic> _nested(Map<String, dynamic> values) => {
      'scopes': {_station: _field(values)},
      'remove': <String>[]
    };
AdminProductionMapLiveStateDelta _delta(Map<String, dynamic> patch) =>
    AdminProductionMapLiveStateDelta.fromJson({
      'epoch': 'worker-server',
      'scope': 'worker-list-scope',
      'base_rev': 7,
      'rev': 8,
      'protocol': 'state_delta_v2',
      'patch': patch,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'worker-list-token';
  });
  tearDown(() => AppSession.instance.token = null);

  test('worker compact decode never constructs canonical maps or controls',
      () async {
    final wire = _workerList();
    for (final snapshot in [
      decodeCachedProductionMapQueueSnapshot(wire),
      await decodeProductionMapQueueSnapshotPayload(jsonEncode(wire)),
      await decodeProductionMapQueueSnapshotPayload(jsonEncode(wire),
          backgroundThresholdCodeUnits: 0),
      AdminProductionMapLiveSnapshot.fromJson(wire),
    ]) {
      expect(snapshot.isWorkerList, isTrue);
      expect(snapshot.maps, isEmpty);
      expect(snapshot.workerPendingReportIds[_station],
          ['work-history', 'work-2']);
      expect(snapshot.workerListRows.length, 3);
      expect(snapshot.workerListRows['work-1']!.title, 'Mahsulot 😀');
      expect(snapshot.workerDisplayStates[_station]!['work-2'], 'in_progress');
      expect(snapshot.workerReportPrompts[_station]!['work-2']!.reportSessionId,
          'report-1');
      expect(snapshot.workerReportPrompts[_station]!['work-2']!.upstreamTitle,
          'Bosma');
      expect(snapshot.sequenceVersions[_station], 'seq-1');
      expect(snapshot.sequencePositionsByApparatus[_station]!['work-2'], 2);
      expect(snapshot.orderControlFor('work-1'), AdminOrderControlState.frozen);
      expect(snapshot.queueActionControls, isEmpty);
      expect(snapshot.stageStates, isEmpty);
      expect(snapshot.stageOrderControls, isEmpty);
      expect(snapshot.orderStatuses, isEmpty);
      expect(snapshot.calculationTemplates, isEmpty);
      expect(snapshot is AdminProductionMapLiveSnapshot, isTrue);
      expect(
          (snapshot as AdminProductionMapLiveSnapshot)
              .completedOrders
              .single
              .orderId,
          'work-history');
      expect(() => snapshot.workerListRows.clear(), throwsUnsupportedError);
      expect(() => snapshot.workerDisplayStates[_station]!.clear(),
          throwsUnsupportedError);
    }
  });

  test(
      'display shell is identity-tagged and remains separate from canonical data',
      () {
    final row = decodeCachedProductionMapQueueSnapshot(_workerList())
        .workerListRows['work-1']!;
    final shell = row.toPresentationOrder();
    expect(identical(shell, row.toPresentationOrder()), isTrue);
    expect(isWorkerListPresentationOrder(shell), isTrue);
    expect(shell.map.nodes, isEmpty);
    expect(shell.program.operations, isEmpty);
    final canonical =
        ProductionMapSaved(map: shell.map, program: shell.program);
    expect(isWorkerListPresentationOrder(canonical), isFalse);
    expect(
        isWorkerListPresentationOrder(
            WorkerOrderListRow.fromJson({...row.toJson(), 'title': 'new'})
                .toPresentationOrder()),
        isTrue);
  });

  test(
      'worker compact cache roundtrip preserves projection, history and prompts',
      () {
    final before = decodeCachedProductionMapQueueSnapshot(_workerList());
    final wire = encodeProductionMapQueueSnapshot(before);
    for (final key in [
      'maps',
      'queue_action_controls',
      'stage_order_controls',
      'stage_states',
      'order_statuses',
      'frozen_orders_by_apparatus',
      'calculation_templates',
      'order_customers'
    ]) {
      expect(wire.containsKey(key), isFalse, reason: key);
    }
    final after = decodeCachedProductionMapQueueSnapshot(
        (jsonDecode(jsonEncode(wire)) as Map).cast<String, dynamic>());
    expect(after.isWorkerList, isTrue);
    expect(after.workerListRows.keys, before.workerListRows.keys);
    expect(after.workerDisplayStates, before.workerDisplayStates);
    expect(after.workerPendingReportIds[_station], ['work-history', 'work-2']);
    expect(after.workerReportPrompts[_station]!['work-2']!.reportSessionId,
        'report-1');
    expect(after.maps, isEmpty);
    expect(after.orderControlFor('work-1'), AdminOrderControlState.frozen);
    expect(
        (after as AdminProductionMapLiveSnapshot)
            .completedOrders
            .single
            .orderId,
        'work-history');
  });

  test('compact list rejects malformed rows, authority and incomplete states',
      () async {
    final mutations = <void Function(Map<String, dynamic>)>[
      (w) => w['worker_list_rows']['work-1']['id'] = 'wrong',
      (w) => w['worker_list_rows']['work-1'].remove('customer_name'),
      (w) => w['worker_list_rows'].remove('work-1'),
      (w) => w['worker_list_rows'].remove('work-history'),
      (w) => w['worker_list_rows'] = [],
      (w) => w['worker_pending_report_ids'] = {'bad': <String>[]},
      (w) => w['worker_pending_report_ids'][_station] = ['work-1', 'work-1'],
      (w) => w['worker_pending_report_ids'][_station] = ['unknown'],
      (w) => w['worker_pending_report_ids'][_station] = [1],
      (w) => w['worker_display_states'][_station]['work-1'] = 'unknown',
      (w) => w['worker_display_states'][_station].remove('work-1'),
      (w) => w['worker_display_states']['bad'] = {},
      (w) => w['worker_display_states'][_station]['unrelated'] = 'pending',
      (w) => w['worker_report_prompts'][_station]['work-2']
          ['report_session_id'] = '',
      (w) => w['worker_report_prompts'][_station]['work-2']
          .remove('upstream_title'),
      (w) => w['worker_report_prompts'][_station]
          ['unrelated'] = {'report_session_id': 'x', 'upstream_title': 'x'},
      (w) => w['order_controls']['work-1']['actor'] = 'unwanted',
      (w) => w['order_controls']['work-1']['state'] = 'bad',
      (w) => w['queue_states'][_station].remove('work-1'),
      (w) => w['queue_policies'][0]['policy'] = 'bad',
      (w) => w['epoch'] = '',
      (w) => w['scope'] = '',
      (w) => w['rev'] = 7.5,
      (w) => w['completed_orders'] = null,
      for (final key in [
        'maps',
        'queue_action_controls',
        'stage_order_controls',
        'stage_states',
        'order_statuses',
        'frozen_orders_by_apparatus',
        'calculation_templates',
        'order_customers'
      ])
        (w) => w[key] = {},
    ];
    for (var i = 0; i < mutations.length; i++) {
      final wire = (jsonDecode(jsonEncode(_workerList())) as Map)
          .cast<String, dynamic>();
      mutations[i](wire);
      expect(() => decodeCachedProductionMapQueueSnapshot(wire),
          throwsA(isA<MobileApiException>()),
          reason: 'mutation $i');
    }
  });

  test('sparse row and state deltas retain untouched card identity', () {
    final before = decodeCachedProductionMapQueueSnapshot(_workerList());
    final after = _delta({
      'worker_list_rows': _field({
        'work-1': {
          ...before.workerListRows['work-1']!.toJson(),
          'title': 'Changed'
        }
      }),
      'worker_display_states': _nested({'work-1': 'issue'}),
      'worker_report_prompts': {
        'scopes': {
          _station: _field({}, ['work-2'])
        },
        'remove': <String>[]
      },
    }).applyTo(before);
    expect(after.isWorkerList, isTrue);
    expect(after.maps, isEmpty);
    expect(after.workerListRows['work-1']!.title, 'Changed');
    expect(before.workerListRows['work-1']!.title, 'Mahsulot 😀');
    expect(
        identical(
            after.workerListRows['work-2'], before.workerListRows['work-2']),
        isTrue);
    expect(after.workerDisplayStates[_station]!['work-1'], 'issue');
    expect(after.workerReportPrompts[_station], isEmpty);
    expect(before.workerReportPrompts[_station], isNotEmpty);
    final wrapped = workerWarmLiveSnapshot(after,
        completed: (before as AdminProductionMapLiveSnapshot).completedOrders,
        requests: before.completionRequests,
        decisions: before.completionRequestDecisions);
    expect(wrapped.isWorkerList, isTrue);
    expect(identical(wrapped.workerListRows, after.workerListRows), isTrue);
    expect(wrapped.completedOrders.single.orderId, 'work-history');
  });

  test('checkpoint retains worker rows and prompts without constructing maps',
      () {
    final before = decodeCachedProductionMapQueueSnapshot(_workerList());
    final after = _delta({}).applyTo(before);
    expect(identical(before.workerListRows, after.workerListRows), isTrue);
    expect(identical(before.workerDisplayStates, after.workerDisplayStates),
        isTrue);
    expect(identical(before.workerReportPrompts, after.workerReportPrompts),
        isTrue);
    expect(after.isWorkerList, isTrue);
    expect(after.revision, 8);
  });

  test('compact reducer rejects mixed schemas and invalid patches atomically',
      () {
    final before = decodeCachedProductionMapQueueSnapshot(_workerList());
    final patches = <Map<String, dynamic>>[
      {
        'worker_list_rows': _field({
          'work-1': {...before.workerListRows['work-1']!.toJson(), 'id': 'bad'}
        })
      },
      {
        'worker_display_states': _nested({'work-1': 'bad'})
      },
      {
        'worker_report_prompts': _nested({
          'work-2': {'report_session_id': '', 'upstream_title': 'x'}
        })
      },
      {
        'order_controls': _field({
          'work-1': {'state': 'frozen', 'actor': 'bad'}
        })
      },
      {
        'worker_list_rows': _field({}, ['work-history'])
      },
      for (final key in [
        'maps',
        'map_order',
        'stage_states',
        'queue_action_controls'
      ])
        {key: _field({})},
    ];
    for (final patch in patches) {
      expect(() => _delta(patch).applyTo(before),
          throwsA(isA<MobileApiException>()));
      expect(before.workerListRows['work-1']!.title, 'Mahsulot 😀');
      expect(before.revision, 7);
    }
    final full = decodeCachedProductionMapQueueSnapshot(_fullDetail());
    expect(
        () => AdminProductionMapLiveStateDelta(
            epoch: full.epoch,
            scope: full.scope,
            baseRevision: full.revision!,
            revision: full.revision! + 1,
            protocol: 'state_delta_v2',
            patch: {'worker_list_rows': _field({})}).applyTo(full),
        throwsA(isA<MobileApiException>()));
  });

  test(
      'worker HTTP and v2 socket opt into same compact projection, admin unaffected',
      () async {
    await http.runWithClient(() async {
      final snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot(
          workerScope: true, queueLimit: 10, queueSearch: 'old');
      expect(snapshot.isWorkerList, isTrue);
    },
        () => MockClient((request) async {
              expect(request.url.queryParameters, {
                'worker_scope': 'true',
                'projection': 'worker_list_v1',
                'queue_limit': '10',
                'queue_positions': 'true',
                'queue_search': 'old'
              });
              return http.Response(jsonEncode(_workerList()), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
    final worker = MobileApi.instance
        .adminProductionMapLiveUri(stateDelta: true, workerScope: true);
    expect(worker.queryParameters['projection'], 'worker_list_v1');
    final admin = MobileApi.instance
        .adminProductionMapLiveUri(stateDelta: true, workerScope: false);
    expect(admin.queryParameters.containsKey('projection'), isFalse);
    final legacy = MobileApi.instance.adminProductionMapLiveUri(
        stateDelta: true, workerScope: true, compactStateDelta: false);
    expect(legacy.queryParameters.containsKey('projection'), isFalse);
  });

  test('history removal is atomic with summary membership and metadata', () {
    final before = decodeCachedProductionMapQueueSnapshot(_workerList());
    final removal = {
      'worker_list_rows': _field({}, ['work-history']),
      'worker_display_states': {
        'scopes': {
          _station: _field({}, ['work-history'])
        },
        'remove': <String>[]
      },
      'queue_states': {
        'scopes': {
          _station: _field({}, ['work-history'])
        },
        'remove': <String>[]
      },
    };
    expect(() => _delta(removal).applyTo(before),
        throwsA(isA<MobileApiException>()));
    final after = _delta({
      ...removal,
      'completed_orders': <Object>[],
      'worker_pending_report_ids': _field({
        _station: ['work-2']
      })
    }).applyTo(before);
    expect(after.workerListRows.containsKey('work-history'), isFalse);
    expect(before.workerListRows.containsKey('work-history'), isTrue);
  });

  test(
      'pending report ordering is preserved through sparse deltas and warm copy',
      () {
    final before = decodeCachedProductionMapQueueSnapshot(_workerList());
    final after = _delta({
      'worker_pending_report_ids': _field({
        _station: ['work-2', 'work-history']
      })
    }).applyTo(before);
    expect(after.workerPendingReportIds[_station], ['work-2', 'work-history']);
    expect(before.workerPendingReportIds[_station], ['work-history', 'work-2']);
    final wrapped = workerWarmLiveSnapshot(after,
        completed: (before as AdminProductionMapLiveSnapshot).completedOrders,
        requests: before.completionRequests,
        decisions: before.completionRequestDecisions);
    expect(
        identical(wrapped.workerPendingReportIds, after.workerPendingReportIds),
        isTrue);
    expect(
        decodeCachedProductionMapQueueSnapshot(
                encodeProductionMapQueueSnapshot(wrapped))
            .workerPendingReportIds[_station],
        ['work-2', 'work-history']);
    expect(
        () => _delta({
              'worker_pending_report_ids': _field({
                _station: ['work-1', 'work-1']
              })
            }).applyTo(before),
        throwsA(isA<MobileApiException>()));
    expect(
        () => _delta({
              'worker_pending_report_ids': _field({
                _station: ['unknown']
              })
            }).applyTo(before),
        throwsA(isA<MobileApiException>()));
  });

  test('worker single detail requests one ID and returns full action authority',
      () async {
    await http.runWithClient(() async {
      final snapshot = await MobileApi.instance
          .workerProductionOrderDetail(apparatus: _station, orderId: scanOrder);
      expect(snapshot.isWorkerList, isFalse);
      expect(snapshot.maps.single.map.title, 'Full graph');
      expect(snapshot.queueActionControls[_station]![scanOrder]!.contractValid,
          isTrue);
      expect(isWorkerListPresentationOrder(snapshot.maps.single), isFalse);
    },
        () => MockClient((request) async {
              expect(request.url.queryParameters, {
                'worker_scope': 'true',
                'detail': 'true',
                'apparatus': _station,
                'order_id': scanOrder
              });
              return http.Response(jsonEncode(_fullDetail()), 200);
            }));
  });

  test('worker detail rejects list replies, wrong orders and missing scope',
      () async {
    for (final wire in [
      _workerList(),
      {..._fullDetail(), 'maps': []},
      {..._fullDetail(), 'scope': ''},
      {
        ..._fullDetail(),
        'maps': [
          ..._fullDetail()['maps'] as List,
          ..._fullDetail()['maps'] as List
        ]
      },
    ]) {
      await http.runWithClient(() async {
        await expectLater(
            MobileApi.instance.workerProductionOrderDetail(
                apparatus: _station, orderId: scanOrder),
            throwsA(isA<MobileApiException>()));
      },
          () => MockClient((_) async => http.Response(jsonEncode(wire), 200,
              headers: {'content-type': 'application/json; charset=utf-8'})));
    }
  });

  test(
      'warm store applies worker rows and retains notifications through handoff',
      () async {
    final live = StreamController<AdminProductionMapLiveMessage>();
    final store = WorkerQueueWarmStore(
        scopeReader: () => 'account',
        limitLoader: (_) async => 10,
        snapshotLoader: (_, __) async =>
            decodeCachedProductionMapQueueSnapshot(_workerList()),
        apparatusLoader: () async => [],
        liveLoader: (_, __, ___) => live.stream);
    addTearDown(store.reset);
    addTearDown(live.close);
    await store.start(scope: 'account', preferenceAccount: 'account');
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    live.add(_delta({
      'worker_display_states': _nested({'work-1': 'paused'})
    }));
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    final ready = store.peek(scope: 'account', queueLimit: 10)!;
    expect(ready.snapshot.isWorkerList, isTrue);
    expect(ready.snapshot.workerDisplayStates[_station]!['work-1'], 'paused');
    expect(
        (ready.snapshot as AdminProductionMapLiveSnapshot)
            .completedOrders
            .single
            .orderId,
        'work-history');
    expect(ready.snapshot.maps, isEmpty);
  });
}
