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
      ref: 'worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.manage'],
      assignedApparatus: [scanApparatus]);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'repause-token';
    AppSession.instance.profile = worker;
    await TestModeController.instance.setEnabled(false);
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  Map<String, dynamic> control(Object? checkpoint) => {
        ...scanControl(),
        'state': 'in_progress',
        'allowed_actions': ['pause', 'complete'],
        'interaction': {
          ...scanControl()['interaction'] as Map,
          'mode': 'in_progress'
        },
        if (checkpoint != null) 're_pause': checkpoint,
      };
  final checkpoint = {
    'resume_id': 'resume-1',
    'worker_role': 'aparatchi',
    'worker_ref': 'worker'
  };
  test('re-pause additive field preserves the existing action contract', () {
    final decoded =
        AdminApparatusQueueOrderActionControl.fromJson(control(checkpoint));
    expect(decoded.contractValid, isTrue);
    expect(decoded.allowedActions, {'pause', 'complete'});
    expect(decoded.rePause!.resumeId, 'resume-1');
    expect(decoded.rePause!.belongsTo(worker), isTrue);
  });
  for (final invalid in [
    null,
    {},
    'resume-1',
    {...checkpoint, 'resume_id': ''},
    {...checkpoint, 'worker_role': 'admin'},
    {...checkpoint, 'worker_ref': ''}
  ]) {
    test('re-pause malformed or absent optional control is hidden: $invalid',
        () {
      final decoded =
          AdminApparatusQueueOrderActionControl.fromJson(control(invalid));
      expect(decoded.contractValid, isTrue);
      expect(decoded.rePause, isNull);
    });
  }
  test('re-pause command sends only identity and the expected resume',
      () async {
    final requests = <http.Request>[];
    await http.runWithClient(
        () => MobileApi.instance.adminRePauseResumedWork(
            apparatus: scanApparatus, orderId: scanOrder, resumeId: 'resume-1'),
        () => MockClient((request) async {
              requests.add(request);
              return http.Response('{"ok":true,"rev":2,"epoch":"server"}', 200);
            }));
    expect(requests, hasLength(1));
    expect(requests.single.url.path, endsWith('/production-maps/re-pause'));
    expect(requests.single.headers['Authorization'], 'Bearer repause-token');
    expect(jsonDecode(requests.single.body), {
      'apparatus': scanApparatus,
      'order_id': scanOrder,
      'resume_id': 'resume-1'
    });
  });
  for (final status in [409, 500]) {
    test(
        're-pause failed writes are not replayed or replaced with output: $status',
        () async {
      var calls = 0;
      await http.runWithClient(() async {
        await expectLater(
            MobileApi.instance.adminRePauseResumedWork(
                apparatus: scanApparatus,
                orderId: scanOrder,
                resumeId: 'resume-1'),
            throwsA(isA<MobileApiException>()));
      },
          () => MockClient((request) async {
                calls++;
                return http.Response(
                    '{"error":"queue_action_not_allowed"}', status);
              }));
      expect(calls, 1);
    });
  }
  test('re-pause rejects training and test-mode mutations locally', () async {
    var calls = 0;
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.adminRePauseResumedWork(
              apparatus: scanApparatus,
              orderId: 'training-order',
              resumeId: 'resume-1'),
          throwsA(isA<MobileApiException>()));
      await TestModeController.instance.setEnabled(true);
      await expectLater(
          MobileApi.instance.adminRePauseResumedWork(
              apparatus: scanApparatus,
              orderId: scanOrder,
              resumeId: 'resume-1'),
          throwsA(isA<MobileApiException>()));
    },
        () => MockClient((request) async {
              calls++;
              return http.Response('{"ok":true}', 200);
            }));
    expect(calls, 0);
  });

  test('re-pause does not send under an account selected during preparation',
      () async {
    var calls = 0;
    await http.runWithClient(() async {
      final action = MobileApi.instance.adminRePauseResumedWork(
          apparatus: scanApparatus, orderId: scanOrder, resumeId: 'resume-1');
      AppSession.instance.profile = const SessionProfile(
          role: UserRole.aparatchi,
          displayName: 'Other',
          legalName: '',
          ref: 'other',
          phone: '',
          avatarUrl: '');
      await expectLater(action, throwsA(isA<MobileApiException>()));
    },
        () => MockClient((request) async {
              calls++;
              return http.Response('{"ok":true}', 200);
            }));
    expect(calls, 0);
  });
}
