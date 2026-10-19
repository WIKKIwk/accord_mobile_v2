import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/production/worker_queue_limit_store.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'queue-window-test';
  });
  tearDown(() => AppSession.instance.token = null);

  test('queue preference survives reload and is isolated by account/server',
      () async {
    expect(await WorkerQueueLimitStore.load('server-a/worker-a'), 10);
    await WorkerQueueLimitStore.save('server-a/worker-a', 5);
    expect(await WorkerQueueLimitStore.load('server-a/worker-a'), 5);
    await WorkerQueueLimitStore.save(
        'server-a/worker-a', WorkerQueueLimitStore.allLimit);
    expect(await WorkerQueueLimitStore.load('server-a/worker-a'),
        WorkerQueueLimitStore.allLimit);
    expect(await WorkerQueueLimitStore.load('server-a/worker-b'), 10);
    expect(await WorkerQueueLimitStore.load('server-b/worker-a'), 10);
    await expectLater(WorkerQueueLimitStore.save('server-a/worker-a', 999),
        throwsArgumentError);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt('worker_queue_limit_v1:server-a/worker-a', 999);
    expect(await WorkerQueueLimitStore.load('server-a/worker-a'), 10);
  });

  for (final limit in [5, WorkerQueueLimitStore.allLimit]) {
    test('REST and websocket carry the same search window with limit $limit',
        () async {
      await http.runWithClient(() async {
        await MobileApi.instance.adminProductionMapQueueSnapshot(
          workerScope: true,
          queueLimit: limit,
          queueSearch: 'old order',
        );
      },
          () => MockClient((request) async {
                expect(request.url.queryParameters, {
                  'worker_scope': 'true',
                  'queue_limit': '$limit',
                  'queue_search': 'old order',
                });
                return http.Response(
                    jsonEncode({
                      'ok': true,
                      'epoch': 'server',
                      'rev': 1,
                      'scope': 'window-5',
                      'maps': [],
                      'sequences': {},
                      'visible_order_ids': {},
                      'queue_states': {},
                      'queue_policies': [],
                      'queue_action_controls': {},
                      'stage_states': {},
                      'order_controls': {},
                      'order_statuses': {},
                      'frozen_orders_by_apparatus': {},
                    }),
                    200);
              }));
      final uri = MobileApi.instance.adminProductionMapLiveUri(
        stateDelta: true,
        queueLimit: limit,
        queueSearch: 'old order',
      );
      expect(uri.queryParameters['queue_limit'], '$limit');
      expect(uri.queryParameters['queue_search'], 'old order');
      expect(uri.queryParameters['worker_scope'], 'true');
      expect(uri.queryParameters['protocol'], 'state_delta_v1');
      final legacy = MobileApi.instance.adminProductionMapLiveUri(delta: true);
      expect(legacy.queryParameters.containsKey('queue_limit'), isFalse);
    });
  }

  test('concurrent reads for different limits never coalesce', () async {
    final requests = <http.Request>[];
    final release = Completer<void>();
    await http.runWithClient(() async {
      final five = MobileApi.instance
          .adminProductionMapQueueSnapshot(workerScope: true, queueLimit: 5);
      final ten = MobileApi.instance
          .adminProductionMapQueueSnapshot(workerScope: true, queueLimit: 10);
      final all = MobileApi.instance.adminProductionMapQueueSnapshot(
          workerScope: true, queueLimit: WorkerQueueLimitStore.allLimit);
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await Future.wait([five, ten, all]);
    },
        () => MockClient((request) async {
              requests.add(request);
              await release.future;
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'epoch': 'server',
                    'rev': 1,
                    'scope':
                        'window-${request.url.queryParameters['queue_limit']}',
                    'maps': [],
                    'sequences': {},
                    'visible_order_ids': {},
                    'queue_states': {},
                    'queue_policies': [],
                    'queue_action_controls': {},
                    'stage_states': {},
                    'order_controls': {},
                    'order_statuses': {},
                    'frozen_orders_by_apparatus': {},
                  }),
                  200);
            }));
    expect(requests.map((r) => r.url.queryParameters['queue_limit']).toSet(),
        {'5', '10', '0'});
  });

  test('a delta from a previous limit cannot mutate the new window', () {
    const current = AdminApparatusQueueSnapshot(
      epoch: 'server',
      revision: 7,
      scope: 'window-0',
      sequences: {},
      visibleOrderIds: {},
      queueStates: {},
      queuePolicies: {},
      orderControls: {},
    );
    final stale = AdminProductionMapLiveStateDelta.fromJson({
      'epoch': 'server',
      'base_rev': 7,
      'rev': 8,
      'scope': 'window-10',
      'patch': {},
    });
    expect(() => stale.applyTo(current), throwsA(isA<MobileApiException>()));
    expect(current.revision, 7);
  });
}
