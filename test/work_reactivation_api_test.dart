import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_scan_bootstrap_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const worker = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Worker',
      legalName: '',
      ref: 'reactivate-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
      assignedApparatus: [scanApparatus]);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = worker;
    await TestModeController.instance.setEnabled(false);
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });
  Map<String, dynamic> available({String batchId = ''}) => {
        'available': true,
        'target': <String, dynamic>{
          'apparatus': scanApparatus,
          'order_id': scanOrder,
          'batch_id': batchId,
          'session_id': 'session-exact',
          'stage_node_id': 'repeat-stage-2',
          'token': 'fingerprint-token'
        }
      };
  Future<AdminWorkReactivationPreview> preview({String batchId = ''}) =>
      MobileApi.instance.adminWorkReactivationPreview(
          apparatus: scanApparatus, orderId: scanOrder, batchId: batchId);

  for (final batchId in ['', 'batch-exact']) {
    test('reactivation retains exact preview identity and token: $batchId',
        () async {
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        final result = await preview(batchId: batchId);
        expect(result.available, isTrue);
        expect(result.target!.stageNodeId, 'repeat-stage-2');
        await MobileApi.instance.adminReactivateCompletedWork(result.target!);
      },
          () => MockClient((request) async {
                requests.add(request);
                return http.Response(
                    jsonEncode(request.url.path.endsWith('/preview')
                        ? available(batchId: batchId)
                        : {'ok': true, 'rev': 2, 'epoch': 's'}),
                    200);
              }));
      expect(requests, hasLength(2));
      expect(jsonDecode(requests.first.body), {
        'apparatus': scanApparatus,
        'order_id': scanOrder,
        if (batchId.isNotEmpty) 'batch_id': batchId
      });
      expect(jsonDecode(requests.last.body), {
        'apparatus': scanApparatus,
        'order_id': scanOrder,
        if (batchId.isNotEmpty) 'batch_id': batchId,
        'session_id': 'session-exact',
        'stage_node_id': 'repeat-stage-2',
        'token': 'fingerprint-token'
      });
      expect(requests.last.headers['authorization'], 'Bearer token');
    });
  }
  for (final reason in [
    'apparatus_busy',
    'source_not_free',
    'final_stage_closed',
    'resource_unavailable',
    'order_closed',
    'unsupported_history'
  ]) {
    test('reactivation denial cannot yield executable target: $reason',
        () async {
      await http.runWithClient(() async {
        final result = await preview();
        expect(result.available, isFalse);
        expect(result.target, isNull);
        expect(result.denialReason, reason);
      },
          () => MockClient((_) async => http.Response(
              jsonEncode({'available': false, 'denial_reason': reason}), 200)));
    });
  }
  for (final change in <Map<String, dynamic>>[
    {'apparatus': 'apparatus:another'},
    {'order_id': 'another-order'},
    {'batch_id': 'another-batch'},
    {'session_id': ''},
    {'stage_node_id': ''},
    {'token': ''},
    {'token': 12},
  ]) {
    test(
        'reactivation fails closed on malformed or substituted target: $change',
        () async {
      final payload = available();
      (payload['target'] as Map).addAll(change);
      await http.runWithClient(() async {
        await expectLater(preview(), throwsA(isA<FormatException>()));
      },
          () =>
              MockClient((_) async => http.Response(jsonEncode(payload), 200)));
    });
  }
  test('reactivation target is bound to preview account', () async {
    var writes = 0;
    await http.runWithClient(() async {
      final target = (await preview()).target!;
      AppSession.instance.profile = null;
      await expectLater(MobileApi.instance.adminReactivateCompletedWork(target),
          throwsA(isA<MobileApiException>()));
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/preview')) writes++;
              return http.Response(jsonEncode(available()), 200);
            }));
    expect(writes, 0);
  });
  test('reactivation discards preview received after an account switch',
      () async {
    final gate = Completer<void>();
    await http.runWithClient(() async {
      final pending = preview();
      await Future<void>.delayed(Duration.zero);
      AppSession.instance.profile = null;
      gate.complete();
      await expectLater(pending, throwsA(isA<MobileApiException>()));
    },
        () => MockClient((_) async {
              await gate.future;
              return http.Response(jsonEncode(available()), 200);
            }));
  });
  for (final status in [409, 500]) {
    test('reactivation write failure is not replayed: $status', () async {
      var writes = 0;
      await http.runWithClient(() async {
        final target = (await preview()).target!;
        await expectLater(
            MobileApi.instance.adminReactivateCompletedWork(target),
            throwsA(isA<MobileApiException>()));
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/preview')) {
                  return http.Response(jsonEncode(available()), 200);
                }
                writes++;
                return http.Response(
                    '{"error":"reactivation_stale_target"}', status);
              }));
      expect(writes, 1);
    });
  }
  test('reactivation rejects training and test mode without requests',
      () async {
    var calls = 0;
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.adminWorkReactivationPreview(
              apparatus: scanApparatus, orderId: 'training-order'),
          throwsA(isA<MobileApiException>()));
      await TestModeController.instance.setEnabled(true);
      await expectLater(preview(), throwsA(isA<MobileApiException>()));
    },
        () => MockClient((_) async {
              calls++;
              return http.Response('{}', 200);
            }));
    expect(calls, 0);
  });
}
