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

  for (final waste in [0.0, 2.5]) {
    test('intermediate rezka astatka sends only waste $waste and its stage',
        () async {
      final report = await http.runWithClient(
        () => MobileApi.instance.adminRezkaAstatkaReport(
          apparatus: 'apparatus:default:asset-010',
          orderId: 'zakaz-intermediate',
          stageNodeId: 'cut-before-lamination',
          totalWasteOnly: true,
          totalWaste: waste,
        ),
        () => MockClient((request) async {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload, {
            'apparatus': 'apparatus:default:asset-010',
            'order_id': 'zakaz-intermediate',
            'stage_node_id': 'cut-before-lamination',
            'total_waste': waste,
          });
          return http.Response(
              jsonEncode({
                'ok': true,
                'report': {
                  ...payload,
                  'report_id': 'intermediate-report',
                  'rezka_bosma_waste': 0,
                  'rezka_lamination_waste': 0,
                  'rezka_edge_waste': 0,
                },
              }),
              200);
        }),
      );
      expect(report.totalWaste, waste);
      expect(report.rezkaBosmaWaste, 0);
    });
    test('rezka astatka sends waste $waste without roll output metrics',
        () async {
      const apparatus = 'apparatus:default:asset-010';
      const orderId = 'zakaz-rezka-astatka';
      final requests = <http.Request>[];
      final report = await http.runWithClient(
        () => MobileApi.instance.adminRezkaAstatkaReport(
          apparatus: apparatus,
          orderId: orderId,
          totalWaste: waste,
          rezkaBosmaWaste: waste,
          rezkaLaminationWaste: waste,
          rezkaEdgeWaste: waste,
        ),
        () => MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'ok': true,
              'report': {
                ...jsonDecode(request.body) as Map<String, dynamic>,
                'report_id': 'astatka-1',
              },
            }),
            200,
          );
        }),
      );
      expect(report.reportId, 'astatka-1');
      expect(report.totalWaste, waste);
      expect(report.finishedGoodsMeter, isNull);
      expect(report.finishedGoodsKg, isNull);
      expect(report.bobinaKg, isNull);
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(
          request.url.path, '/v1/mobile/admin/production-maps/rezka-astatka');
      expect(jsonDecode(request.body), {
        'apparatus': apparatus,
        'order_id': orderId,
        'total_waste': waste,
        'rezka_bosma_waste': waste,
        'rezka_lamination_waste': waste,
        'rezka_edge_waste': waste,
      });
    });
  }
  test('full rezka report still requires all waste categories', () async {
    await expectLater(
      MobileApi.instance.adminRezkaAstatkaReport(
        apparatus: 'apparatus:default:asset-010',
        orderId: 'zakaz-final',
        totalWaste: 1,
      ),
      throwsA(isA<MobileApiException>().having(
          (error) => error.code, 'code', 'rezka_astatka_metrics_required')),
    );
  });
}
