import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
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
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'worker-token';
  });
  tearDown(() {
    AppSession.instance.token = null;
  });

  Future<Map<String, dynamic>> submit({double waste = 0}) =>
      MobileApi.instance.adminBosmaAstatkaReport(
        apparatus: 'apparatus:default:bosma_8',
        orderId: 'zakaz-bosma-astatka',
        totalWaste: waste,
        finishedGoodsMeter: 80,
        finishedGoodsKg: 12,
        bobinaKg: 1,
        returnedPaintItems: const [],
        returnedPaintImageId: 'paint-image',
        description: 'Hisobot',
      );

  test(
      'bosma astatka sends only standalone report endpoint and validates response',
      () async {
    final requests = <http.Request>[];
    final report = await http.runWithClient(
        submit,
        () => MockClient((request) async {
              requests.add(request);
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'report': {'report_id': 'astatka-1'}
                  }),
                  200);
            }));
    expect(report['report_id'], 'astatka-1');
    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/v1/mobile/admin/production-maps/bosma-astatka');
    expect(request.headers['authorization'], contains('worker-token'));
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect(body['total_waste'], 0);
    expect(body['finished_goods_meter'], 80);
    expect(body['finished_goods_kg'], 12);
    expect(body['bobina_kg'], 1);
    expect(body['returned_paint_image_id'], 'paint-image');
    for (final field in [
      'action',
      'complete_without_output',
      'progress_batch_id',
      'produced_qty',
      'printer'
    ]) {
      expect(body.containsKey(field), isFalse, reason: field);
    }
  });

  test('bosma astatka backend rejection never falls back to complete or pause',
      () async {
    final requests = <http.Request>[];
    await expectLater(
        http.runWithClient(
            submit,
            () => MockClient((request) async {
                  requests.add(request);
                  return http.Response('{"error":"order_not_started"}', 409);
                })),
        throwsA(isA<MobileApiException>()));
    expect(requests, hasLength(1));
    expect(requests.single.url.path,
        '/v1/mobile/admin/production-maps/bosma-astatka');
  });

  test('bosma astatka rejects negative waste before sending', () async {
    await expectLater(
        http.runWithClient(
            () => submit(waste: -1),
            () => MockClient((request) async {
                  fail('Invalid report must not be sent');
                })),
        throwsA(isA<MobileApiException>()));
  });
}
