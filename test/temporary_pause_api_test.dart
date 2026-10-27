import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
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
    assignedApparatus: [scanApparatus],
  );
  final token = List.filled(64, 'a').join();
  final identity = {'session_id': 'open-roll-session', 'token': token};
  late String originalBaseUrl;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    originalBaseUrl = ServerEndpointStore.instance.baseUrl;
    AppSession.instance.token = 'temporary-pause-token';
    AppSession.instance.profile = worker;
    await TestModeController.instance.setEnabled(false);
  });
  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await ServerEndpointStore.instance.setBaseUrl(originalBaseUrl);
  });

  Map<String, dynamic> control(
          {Object? temporaryPause, Object? paused = false}) =>
      {
        ...scanControl(),
        'state': 'in_progress',
        'allowed_actions': ['pause', 'complete'],
        'interaction': {
          ...scanControl()['interaction'] as Map,
          'mode': 'in_progress'
        },
        if (temporaryPause != null) 'temporary_pause': temporaryPause,
        'temporarily_paused': paused,
      };

  test('temporary pause is additive and retains normal action vocabulary', () {
    final decoded = AdminApparatusQueueOrderActionControl.fromJson(
        control(temporaryPause: identity));
    expect(decoded.contractValid, isTrue);
    expect(decoded.allowedActions, {'pause', 'complete'});
    expect(decoded.temporaryPause!.sessionId, 'open-roll-session');
    expect(decoded.temporaryPause!.token, token);
    expect(decoded.temporarilyPaused, isFalse);
    final legacy = control()..remove('temporarily_paused');
    expect(AdminApparatusQueueOrderActionControl.fromJson(legacy).contractValid,
        isTrue);
  });

  for (final invalid in <Object>[
    {},
    'session',
    {...identity, 'session_id': ''},
    {...identity, 'session_id': ' session '},
    {...identity, 'token': 'bad'},
    {...identity, 'token': List.filled(64, 'z').join()},
    {...identity, 'token': '$token '},
  ]) {
    test('temporary pause rejects malformed server authority: $invalid', () {
      final decoded = AdminApparatusQueueOrderActionControl.fromJson(
          control(temporaryPause: invalid));
      expect(decoded.temporaryPause, isNull);
      expect(decoded.contractValid, isFalse);
    });
  }

  test('temporary pause rejects contradictory marker and permission states',
      () {
    for (final raw in [
      control(temporaryPause: identity, paused: true),
      control(paused: 'true'),
      {...control(temporaryPause: identity), 'state': 'pending'},
    ]) {
      expect(AdminApparatusQueueOrderActionControl.fromJson(raw).contractValid,
          isFalse);
    }
    final paused = {
      ...control(paused: true),
      'state': 'paused',
      'allowed_actions': ['resume'],
      'interaction': {
        ...scanControl()['interaction'] as Map,
        'mode': 'paused',
        'resume_input_required': false,
      },
    };
    final decoded = AdminApparatusQueueOrderActionControl.fromJson(paused);
    expect(decoded.contractValid, isTrue);
    expect(decoded.temporarilyPaused, isTrue);
    expect(decoded.temporaryPause, isNull);
  });

  Future<void> pause() => MobileApi.instance.adminTemporarilyPauseWork(
        apparatus: scanApparatus,
        orderId: scanOrder,
        control: AdminTemporaryPauseControl(
            sessionId: 'open-roll-session', token: token),
      );

  test('temporary pause sends session authority without output or print data',
      () async {
    final requests = <http.Request>[];
    await http.runWithClient(
        pause,
        () => MockClient((request) async {
              requests.add(request);
              return http.Response('{"ok":true}', 200);
            }));
    expect(requests, hasLength(1));
    expect(
        requests.single.url.path, endsWith('/production-maps/temporary-pause'));
    expect(requests.single.headers['Authorization'],
        'Bearer temporary-pause-token');
    expect(jsonDecode(requests.single.body), {
      'apparatus': scanApparatus,
      'order_id': scanOrder,
      ...identity,
    });
  });

  for (final status in [409, 500, 200]) {
    test(
        'temporary pause uncertain or malformed response is not replayed: $status',
        () async {
      var calls = 0;
      await http.runWithClient(
          () => expectLater(pause(), throwsA(isA<MobileApiException>())),
          () => MockClient((request) async {
                calls++;
                return http.Response(
                    '{"error":"queue_action_not_allowed"}', status);
              }));
      expect(calls, 1);
    });
  }

  test('temporary pause lost response never retries the write', () async {
    var calls = 0;
    await http.runWithClient(
        () => expectLater(pause(), throwsA(anything)),
        () => MockClient((request) async {
              calls++;
              throw http.ClientException('Response lost after commit');
            }));
    expect(calls, 1);
  });

  test('temporary pause rejects training and demo locally', () async {
    var calls = 0;
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.adminTemporarilyPauseWork(
            apparatus: scanApparatus,
            orderId: 'training-order',
            control:
                AdminTemporaryPauseControl(sessionId: 'session', token: token),
          ),
          throwsA(isA<MobileApiException>()));
      await TestModeController.instance.setEnabled(true);
      await expectLater(pause(), throwsA(isA<MobileApiException>()));
    },
        () => MockClient((request) async {
              calls++;
              return http.Response('{"ok":true}', 200);
            }));
    expect(calls, 0);
  });

  for (final switchServer in [false, true]) {
    test(
        'temporary pause ignores completion after scope changes, server=$switchServer',
        () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      var calls = 0;
      await http.runWithClient(() async {
        final action = pause();
        await started.future;
        final result = expectLater(action, throwsA(isA<MobileApiException>()));
        if (switchServer) {
          await ServerEndpointStore.instance
              .setBaseUrl('https://other.example.com');
        } else {
          AppSession.instance.profile = const SessionProfile(
            role: UserRole.aparatchi,
            displayName: 'Other',
            legalName: '',
            ref: 'other-worker',
            phone: '',
            avatarUrl: '',
          );
        }
        response.complete(http.Response('{"ok":true}', 200));
        await result;
      },
          () => MockClient((request) {
                calls++;
                started.complete();
                return response.future;
              }));
      expect(calls, 1);
    });
  }

  test('print apparatus demo policy follows configured free selection',
      () async {
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(true);
    final apparatus = (await MobileApi.instance.adminApparatus(limit: 300))
        .firstWhere((item) => item.id == scanApparatus);
    final saved = await MobileApi.instance.adminUpdateApparatusQueuePolicy(
      apparatusId: scanApparatus,
      expectedRevision: apparatus.sourceRevision,
      policy: ApparatusQueuePolicy.freePick,
    );
    expect(saved.policy, ApparatusQueuePolicy.freePick);
    expect(saved.locked, isFalse);
    final snapshot = await MobileApi.instance.adminProductionMapQueueSnapshot();
    expect(snapshot.queuePolicies[scanApparatus]!.policy,
        ApparatusQueuePolicy.freePick);
    expect(snapshot.queuePolicies[scanApparatus]!.locked, isFalse);
  });
}
