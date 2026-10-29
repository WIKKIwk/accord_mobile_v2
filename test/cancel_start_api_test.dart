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
  const machine = 'apparatus:default:asset-010';
  final token = 'a' * 64;
  late Map<String, Object> identity;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Worker',
        legalName: '',
        ref: 'worker',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.manage'],
        assignedApparatus: [machine]);
    identity = {
      'session_id': 'fresh-session',
      'token': token,
      'worker_ref': 'worker',
      'previous_state': 'pending'
    };
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });
  Map<String, dynamic> control(Object? cancel) => {
        ...scanControl(),
        'state': 'in_progress',
        'allowed_actions': ['pause', 'complete'],
        'interaction': {
          ...scanControl()['interaction'] as Map,
          'mode': 'in_progress'
        },
        if (cancel != null) 'cancel_start': cancel
      };

  test('cancel start is additive, with strict authority and state validation',
      () {
    final parsed =
        AdminApparatusQueueOrderActionControl.fromJson(control(identity));
    expect(parsed.contractValid, isTrue);
    expect(parsed.cancelStart!.workerRef, 'worker');
    expect(
        AdminApparatusQueueOrderActionControl.fromJson(control(null))
            .contractValid,
        isTrue);
    for (final malformed in [
      <String, Object>{},
      'bad',
      {...identity, 'token': 'bad'},
      {...identity, 'worker_ref': ''},
      {...identity, 'session_id': ' session '},
      {...identity, 'previous_state': 'in_progress'}
    ]) {
      final invalid =
          AdminApparatusQueueOrderActionControl.fromJson(control(malformed));
      expect(invalid.contractValid, isFalse);
      expect(invalid.cancelStart, isNull);
    }
    expect(
        AdminApparatusQueueOrderActionControl.fromJson(
            {...control(identity), 'state': 'paused'}).contractValid,
        isFalse);
  });

  Future<void> cancel() => MobileApi.instance.adminCancelStartedWork(
      apparatus: machine,
      orderId: 'order',
      control: AdminCancelStartControl.tryFromJson(identity)!);
  test('cancel sends only scoped session authority, without output data',
      () async {
    await http.runWithClient(
        cancel,
        () => MockClient((request) async {
              expect(request.method, 'POST');
              expect(request.url.path,
                  '/v1/mobile/admin/production-maps/cancel-start');
              expect(request.headers['Authorization'], 'Bearer token');
              expect(jsonDecode(request.body), {
                'apparatus': machine,
                'order_id': 'order',
                'session_id': 'fresh-session',
                'token': token
              });
              return http.Response('{"ok":true}', 200);
            }));
  });
  test('another worker cannot submit the checkpoint', () async {
    identity['worker_ref'] = 'other-worker';
    await http.runWithClient(() async {
      await expectLater(cancel(), throwsA(isA<MobileApiException>()));
    }, () => MockClient((_) async => fail('No cross-worker mutation')));
  });
  test('late success cannot cross an account change', () async {
    await http.runWithClient(() async {
      await expectLater(cancel(), throwsA(isA<MobileApiException>()));
    },
        () => MockClient((_) async {
              AppSession.instance.token = 'another-session';
              AppSession.instance.profile = null;
              return http.Response('{"ok":true}', 200);
            }));
  });
}
