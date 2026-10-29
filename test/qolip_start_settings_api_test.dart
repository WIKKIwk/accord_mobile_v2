import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_scan_bootstrap_fixtures.dart';

const _setId = '950100000001';
final _fingerprint = List.filled(64, 'a').join();

Map<String, dynamic> _automaticQolips() => {
      'ok': true,
      'qolip': {
        'qolip_code': '',
        'automatic_confirmation_enabled': true,
        'policy_revision': 3,
        'blocking_reason_code': '',
        'sets': [
          {
            'set_id': _setId,
            'fingerprint': _fingerprint,
            'ready': true,
            'blocking_reason_code': '',
          }
        ],
        'required_qolip_count': 2,
        'required_qolip_codes': ['MOLD1', 'EXTRA'],
        'required_qolips': [
          {
            'qolip_code': 'MOLD1',
            'color': 'blue',
            'qolip_set_id': _setId,
            'is_extension': false,
            'ready': true,
            'blocking_reason_code': '',
          },
          {
            'qolip_code': 'EXTRA',
            'color': 'black',
            'qolip_set_id': '950100000002',
            'is_extension': true,
            'ready': true,
            'blocking_reason_code': '',
          }
        ],
      }
    };

Map<String, dynamic> _automaticBootstrap() {
  final body = scanBootstrap();
  body['control_state']['control']['interaction']
    ..['qolip_automatic_confirmation'] = true
    ..['qolip_policy_revision'] = 3;
  body['sections']['qolips']['data'] = _automaticQolips();
  return body;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = MobileApi.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'qolip-start-token';
  });
  tearDown(() => AppSession.instance.token = null);

  test('mold setting read and writes preserve the server revision', () async {
    var enabled = false;
    var revision = 0;
    final writes = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      final initial = await api.qolipStartSettings();
      expect(initial.automaticConfirmationEnabled, isFalse);
      expect(initial.revision, 0);
      final on = await api.setQolipAutomaticConfirmationEnabled(true);
      expect(on.automaticConfirmationEnabled, isTrue);
      expect(on.revision, 1);
      final off = await api.setQolipAutomaticConfirmationEnabled(false);
      expect(off.automaticConfirmationEnabled, isFalse);
      expect(off.revision, 2);
    },
        () => MockClient((request) async {
              expect(request.url.path,
                  '/v1/mobile/admin/production-maps/qolip-start-settings');
              expect(
                  request.headers['Authorization'], 'Bearer qolip-start-token');
              if (request.method == 'PUT') {
                final body =
                    (jsonDecode(request.body) as Map).cast<String, dynamic>();
                writes.add(body);
                enabled = body['automatic_confirmation_enabled'] as bool;
                revision++;
              } else {
                expect(request.method, 'GET');
              }
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'settings': {
                      'automatic_confirmation_enabled': enabled,
                      'revision': revision,
                    }
                  }),
                  200);
            }));
    expect(writes, [
      {'automatic_confirmation_enabled': true},
      {'automatic_confirmation_enabled': false}
    ]);
  });

  test('unacknowledged or malformed settings cannot enable bypass', () async {
    for (final settings in [
      {'automatic_confirmation_enabled': true},
      {'automatic_confirmation_enabled': 'true', 'revision': 1},
      {'automatic_confirmation_enabled': true, 'revision': -1},
      {'automatic_confirmation_enabled': false, 'revision': 1},
    ]) {
      await http.runWithClient(() async {
        await expectLater(api.setQolipAutomaticConfirmationEnabled(true),
            throwsA(isA<MobileApiException>()));
      },
          () => MockClient((_) async => http.Response(
              jsonEncode({'ok': true, 'settings': settings}), 200)));
    }
  });

  test('requirements explicitly opt in and retain physical readiness',
      () async {
    await http.runWithClient(() async {
      final validation = await api.adminProductionMapQolipRequirements(
          apparatus: scanApparatus,
          orderId: scanOrder,
          automaticConfirmation: true);
      expect(validation.automaticConfirmationEnabled, isTrue);
      expect(validation.policyRevision, 3);
      expect(validation.requiredQolips.every((mold) => mold.ready), isTrue);
      expect(validation.sets.single.confirmation(3).toJson(), {
        'method': 'automatic',
        'set_id': _setId,
        'fingerprint': _fingerprint,
        'policy_revision': 3,
      });
    },
        () => MockClient((request) async {
              expect(jsonDecode(request.body), {
                'apparatus': scanApparatus,
                'order_id': scanOrder,
                'qolip_code': '',
                'automatic_confirmation': true,
              });
              return http.Response(jsonEncode(_automaticQolips()), 200);
            }));
  });

  test('automatic requirements reject incomplete readiness and fingerprints',
      () {
    for (final invalid in [
      'revision',
      'fingerprint',
      'ready',
      'member ready',
      'unavailable extension',
      'duplicate set',
      'duplicate mold',
    ]) {
      final json = _automaticQolips()['qolip'] as Map<String, dynamic>;
      final set = (json['sets'] as List).single as Map;
      final molds = json['required_qolips'] as List;
      switch (invalid) {
        case 'revision':
          json.remove('policy_revision');
        case 'fingerprint':
          set['fingerprint'] = 'unverified';
        case 'ready':
          set['ready'] = 'true';
        case 'member ready':
          (molds.first as Map).remove('ready');
        case 'unavailable extension':
          molds.last['ready'] = false;
          molds.last['blocking_reason_code'] = 'qolip_in_rework';
        case 'duplicate set':
          (json['sets'] as List).add(Map<String, Object>.from(set));
        case 'duplicate mold':
          molds.add(Map<String, Object>.from(molds.first as Map));
      }
      expect(() => AdminProductionMapQolipValidation.fromJson(json),
          throwsA(isA<MobileApiException>()),
          reason: invalid);
    }
  });

  test('rework blocks the set while healthy molds retain their check marks',
      () {
    final json = _automaticQolips()['qolip'] as Map<String, dynamic>;
    json['blocking_reason_code'] = 'qolip_in_rework';
    json['sets'][0]['ready'] = false;
    json['sets'][0]['blocking_reason_code'] = 'qolip_in_rework';
    json['required_qolips'][1]['ready'] = false;
    json['required_qolips'][1]['blocking_reason_code'] = 'qolip_in_rework';
    final validation = AdminProductionMapQolipValidation.fromJson(json);
    expect(validation.requiredQolips.first.ready, isTrue);
    expect(validation.requiredQolips.last.ready, isFalse);
    expect(validation.sets.single.ready, isFalse);
    expect(() => validation.sets.single.confirmation(3),
        throwsA(isA<MobileApiException>()));
  });

  test('bootstrap opts in and binds automatic readiness to the policy contract',
      () async {
    await http.runWithClient(() async {
      final result = await api.adminOrderScanBootstrap(
          apparatus: scanApparatus,
          orderId: scanOrder,
          automaticQolipConfirmation: true);
      expect(result!.qolips!.automaticConfirmationEnabled, isTrue);
      expect(result.qolips!.policyRevision,
          result.controlState.control.interaction!.qolipPolicyRevision);
    },
        () => MockClient((request) async {
              expect(
                  request.url.queryParameters['automatic_qolip_confirmation'],
                  'true');
              return http.Response(jsonEncode(_automaticBootstrap()), 200);
            }));
    for (final mismatch in [
      'revision',
      'missing metadata',
      'unexpected auto'
    ]) {
      final body = _automaticBootstrap();
      if (mismatch == 'revision') {
        body['sections']['qolips']['data']['qolip']['policy_revision'] = 2;
      } else if (mismatch == 'missing metadata') {
        body['sections']['qolips']['data']['qolip'].remove('sets');
      } else {
        body['control_state']['control']['interaction']
          ..remove('qolip_automatic_confirmation')
          ..remove('qolip_policy_revision');
      }
      final result = AdminOrderScanBootstrap.fromJson(body,
          apparatus: scanApparatus, orderId: scanOrder);
      expect(result.qolips, isNull, reason: mismatch);
    }
  });

  test('automatic start and resume send confirmation without inventing QR scans',
      () async {
    final confirmation = AdminQolipAutomaticConfirmation(
        setId: _setId, fingerprint: _fingerprint, policyRevision: 3);
    await http.runWithClient(() async {
      for (final action in ['start', 'resume']) {
        await api.adminApparatusQueueAction(
          apparatus: scanApparatus,
          orderId: scanOrder,
          action: action,
          qolipConfirmation: confirmation);
      }
    },
        () => MockClient((request) async {
              final body = jsonDecode(request.body) as Map;
              expect(body['qolip_confirmation'], confirmation.toJson());
              expect(body.containsKey('qolip_code'), isFalse);
              expect(body.containsKey('qolip_codes'), isFalse);
              return http.Response('{"states":{}}', 200);
            }));
    for (final action in ['pause', 'complete']) {
      await expectLater(
          api.adminApparatusQueueActionResult(
              apparatus: scanApparatus,
              orderId: scanOrder,
              action: action,
              qolipConfirmation: confirmation),
          throwsA(isA<MobileApiException>()));
    }
  });
}
