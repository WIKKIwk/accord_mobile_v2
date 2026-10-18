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
  final token = List.filled(64, 'a').join();
  Map<String, dynamic> payload() => {
        'session_id': 'unstarted-continuation',
        'stage_node_id': 'exact-stage',
        'token': token,
        'worker_role': 'aparatchi',
        'worker_ref': 'reclose-worker'
      };
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Worker',
        legalName: '',
        ref: 'reclose-worker',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.manage'],
        assignedApparatus: [scanApparatus]);
    await TestModeController.instance.setEnabled(false);
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('reclose sends only exact execution identity without production metrics',
      () async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      final control = AdminReactivationRecloseControl.tryFromJson(payload())!;
      await MobileApi.instance.adminRecloseReactivatedWork(
          apparatus: scanApparatus, orderId: scanOrder, control: control);
    },
        () => MockClient((request) async {
              requests.add(request);
              return http.Response('{"ok":true}', 200);
            }));
    expect(requests, hasLength(1));
    expect(requests.single.url.path, endsWith('/reactivation/reclose'));
    expect(jsonDecode(requests.single.body), {
      'apparatus': scanApparatus,
      'order_id': scanOrder,
      'session_id': 'unstarted-continuation',
      'stage_node_id': 'exact-stage',
      'token': token
    });
  });
  for (final raw in [
    null,
    {},
    {'worker_role': 'admin'},
    {'session_id': 2},
    {'token': 'invalid'}
  ]) {
    test('missing or malformed reclose permission is hidden: $raw', () {
      final value = raw == null ? null : {...payload(), ...raw};
      if (raw is Map && raw.isEmpty) {
        expect(AdminReactivationRecloseControl.tryFromJson(raw), isNull);
      } else {
        expect(AdminReactivationRecloseControl.tryFromJson(value), isNull);
      }
    });
  }
  for (final situation in [
    'account-switch',
    'other-worker',
    'training',
    'test-mode'
  ]) {
    test('reclose fails locally for $situation', () async {
      var requests = 0;
      final json = payload();
      if (situation == 'other-worker') json['worker_ref'] = 'other';
      final control = AdminReactivationRecloseControl.tryFromJson(json)!;
      if (situation == 'account-switch') AppSession.instance.profile = null;
      if (situation == 'test-mode') {
        await TestModeController.instance.setEnabled(true);
      }
      await http.runWithClient(() async {
        await expectLater(
            MobileApi.instance.adminRecloseReactivatedWork(
                apparatus: scanApparatus,
                orderId: situation == 'training' ? 'training-order' : scanOrder,
                control: control),
            throwsA(isA<MobileApiException>()));
      },
          () => MockClient((request) async {
                requests++;
                return http.Response('{"ok":true}', 200);
              }));
      expect(requests, 0);
    });
  }
  for (final status in [409, 500, 200]) {
    test('reclose failure is not replayed: $status', () async {
      var writes = 0;
      await http.runWithClient(() async {
        await expectLater(
            MobileApi.instance.adminRecloseReactivatedWork(
                apparatus: scanApparatus,
                orderId: scanOrder,
                control:
                    AdminReactivationRecloseControl.tryFromJson(payload())!),
            throwsA(isA<MobileApiException>()));
      },
          () => MockClient((_) async {
                writes++;
                return http.Response('{"ok":false}', status);
              }));
      expect(writes, 1);
    });
  }
  test('lost reclose response is not replayed', () async {
    var writes = 0;
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.adminRecloseReactivatedWork(
              apparatus: scanApparatus,
              orderId: scanOrder,
              control: AdminReactivationRecloseControl.tryFromJson(payload())!),
          throwsA(anything));
    },
        () => MockClient((_) async {
              writes++;
              throw http.ClientException('response lost');
            }));
    expect(writes, 1);
  });
}
