import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apparatus = 'apparatus:default:asset-010';
const _order = 'zakaz-rezka-report-read';

Map<String, dynamic> _reportReadFixture() => {
      'ok': true,
      'apparatus': _apparatus,
      'order_id': _order,
      'rezka_output_report': {
        'cycle_id': 'active-cycle',
        'frames': [
          {
            'frame_index': 2,
            'batch_id': 'saved-roll-2',
            'qr_payload': '40011890022F235A0000A1B2',
            'input': {
              'produced_qty': 125.5,
              'gross_qty': 12.75,
              'bobina_kg': 0.75,
              'diameter': 45.5,
            },
          },
          {
            'frame_index': 1,
            'batch_id': '',
            'qr_payload': '',
            'input': {'issue_note': 'Kadr yirtilgan'},
          },
        ],
      },
      'kadr_counts': [1, 2],
      'session_status': 'active',
      'order_control': 'active',
      'epoch': 'report-server',
      'rev': 27,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'report-token';
    await TestModeController.instance.setEnabled(false);
  });
  tearDown(() => AppSession.instance.token = null);

  test('narrow report uses one scoped GET and preserves saved rolls and issues',
      () async {
    final requests = <http.Request>[];
    final result = await http.runWithClient(
      () => MobileApi.instance.adminRezkaOutputReport(
        apparatus: _apparatus,
        orderId: _order,
      ),
      () => MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(_reportReadFixture()), 200);
      }),
    );
    expect(requests, hasLength(1));
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, endsWith('/rezka-output-report'));
    expect(requests.single.url.queryParameters,
        {'apparatus': _apparatus, 'order_id': _order});
    expect(result!.revision, 27);
    expect(result.epoch, 'report-server');
    expect(result.kadrCounts, [1, 2]);
    expect(result.report.cycleId, 'active-cycle');
    expect(result.report.frameAt(0)!.isIssue, isTrue);
    expect(result.report.frameAt(1)!.batchId, 'saved-roll-2');
    expect(result.report.frameAt(1)!.input['gross_qty'], 12.75);
  });

  test('only bare unsupported 404 permits the old control reader', () async {
    final result = await http.runWithClient(
      () => MobileApi.instance.adminRezkaOutputReport(
        apparatus: _apparatus,
        orderId: _order,
      ),
      () => MockClient((_) async => http.Response('', 404)),
    );
    expect(result, isNull);
  });

  for (final status in [400, 403, 404, 409, 503]) {
    test('report domain status $status never falls back', () async {
      var requests = 0;
      await http.runWithClient(() async {
        await expectLater(
          MobileApi.instance.adminRezkaOutputReport(
            apparatus: _apparatus,
            orderId: _order,
          ),
          throwsA(isA<MobileApiException>()),
        );
      },
          () => MockClient((_) async {
                requests++;
                return http.Response(
                    '{"error":"rezka_output_cycle_conflict"}', status);
              }));
      expect(requests, 1);
    });
  }

  for (final changed in <String, dynamic>{
    'apparatus': 'apparatus:default:asset-007',
    'order_id': 'another-order',
    'session_status': 'paused',
    'order_control': 'frozen',
    'epoch': '',
    'rev': -1,
    'kadr_counts': [1, 0],
    'rezka_output_report': {'cycle_id': '', 'frames': []},
  }.entries) {
    test('report rejects invalid ${changed.key}', () {
      final body = _reportReadFixture()..[changed.key] = changed.value;
      expect(
        () => AdminRezkaOutputSnapshot.fromJson(
          body,
          apparatus: _apparatus,
          orderId: _order,
        ),
        throwsA(isA<MobileApiException>()),
      );
    });
  }

  test('report rejects a saved slot outside the current frame layout', () {
    final body = _reportReadFixture();
    body['rezka_output_report']['frames'][0]['frame_index'] = 3;
    expect(
      () => AdminRezkaOutputSnapshot.fromJson(
        body,
        apparatus: _apparatus,
        orderId: _order,
      ),
      throwsA(isA<MobileApiException>()),
    );
  });
}
