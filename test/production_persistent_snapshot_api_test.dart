import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _wire({String epoch = 'server', int revision = 7}) => {
      'ok': true,
      'epoch': epoch,
      'rev': revision,
      'scope': 'worker-window',
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
      'completed_orders': [],
      'completion_requests': [],
      'completion_request_decisions': [],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'persisted-snapshot-test';
  });
  tearDown(() => AppSession.instance.token = null);

  test('disk-decoded empty baseline validates with a zero-body 304', () async {
    final diskDecoded =
        await decodeProductionMapQueueSnapshotPayload(jsonEncode(_wire()));
    await http.runWithClient(() async {
      final result = await MobileApi.instance.adminProductionMapQueueSnapshot(
          workerScope: true, queueLimit: 10, since: diskDecoded);
      expect(identical(result, diskDecoded), isTrue);
      expect(result.maps, isEmpty);
      expect(result.revision, 7);
    },
        () => MockClient((request) async {
              expect(request.url.queryParameters, {
                'worker_scope': 'true',
                'queue_limit': '10',
                'if_epoch': 'server',
                'if_rev': '7',
                'if_scope': 'worker-window',
              });
              expect(request.headers['Authorization'],
                  'Bearer persisted-snapshot-test');
              final response = http.Response('', 304);
              expect(response.bodyBytes, isEmpty);
              return response;
            }));
  });

  test('server restart replaces the disk epoch and accepts its lower revision',
      () async {
    final cached =
        await decodeProductionMapQueueSnapshotPayload(jsonEncode(_wire()));
    await http.runWithClient(() async {
      final result = await MobileApi.instance.adminProductionMapQueueSnapshot(
          workerScope: true, queueLimit: 10, since: cached);
      expect(result.epoch, 'restarted-server');
      expect(result.revision, 1);
      expect(identical(result, cached), isFalse);
    },
        () => MockClient((request) async {
              expect(request.url.queryParameters['if_epoch'], 'server');
              return http.Response(
                  jsonEncode(_wire(epoch: 'restarted-server', revision: 1)),
                  200);
            }));
  });

  test('explicit fresh recovery bypasses a retained cursor', () async {
    final cached =
        await decodeProductionMapQueueSnapshotPayload(jsonEncode(_wire()));
    await http.runWithClient(() async {
      await MobileApi.instance.adminProductionMapQueueSnapshot(
          workerScope: true, queueLimit: 10, since: cached, fresh: true);
    },
        () => MockClient((request) async {
              expect(request.url.queryParameters.keys,
                  isNot(contains('if_epoch')));
              expect(
                  request.url.queryParameters.keys, isNot(contains('if_rev')));
              expect(request.url.queryParameters.keys,
                  isNot(contains('if_scope')));
              return http.Response(jsonEncode(_wire()), 200);
            }));
  });

  test('304 without any baseline cannot become an empty success', () async {
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.adminProductionMapQueueSnapshot(
              workerScope: true, queueLimit: 10),
          throwsA(isA<MobileApiException>()));
    }, () => MockClient((_) async => http.Response('', 304)));
  });
}
