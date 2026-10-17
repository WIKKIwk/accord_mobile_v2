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
          requestId: 'request-intermediate',
          sessionId: 'session-intermediate',
          stageNodeId: 'cut-before-lamination',
          totalWasteOnly: true,
          totalWaste: waste,
        ),
        () => MockClient((request) async {
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload, {
            'apparatus': 'apparatus:default:asset-010',
            'order_id': 'zakaz-intermediate',
            'request_id': 'request-intermediate',
            'session_id': 'session-intermediate',
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
          requestId: 'request-final',
          sessionId: 'session-final',
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
        'request_id': 'request-final',
        'session_id': 'session-final',
        'total_waste': waste,
        'rezka_bosma_waste': waste,
        'rezka_lamination_waste': waste,
        'rezka_edge_waste': waste,
      });
    });
  }
  test('rezka astatka snapshot binds session and reconciles saved receipt',
      () async {
    const apparatus = 'apparatus:default:asset-010';
    for (final committed in [false, true]) {
      final snapshot = await http.runWithClient(
          () => MobileApi.instance.adminRezkaAstatkaSnapshot(
              apparatus: apparatus, orderId: 'order-a', requestId: 'request-a'),
          () => MockClient((request) async {
                expect(request.method, 'GET');
                expect(request.url.queryParameters, {
                  'apparatus': apparatus,
                  'order_id': 'order-a',
                  'request_id': 'request-a'
                });
                return http.Response(
                    jsonEncode(committed
                        ? {
                            'ok': true,
                            'request_result': {
                              'ok': true,
                              'report': {
                                'report_id': 'saved-a',
                                'order_id': 'order-a',
                                'apparatus': apparatus,
                                'total_waste': 2.5,
                              }
                            },
                          }
                        : {
                            'ok': true,
                            'session_id': 'session-a',
                            'stage_node_id': 'cut-stage-a',
                            'request_result': null
                          }),
                    200);
              }));
      if (committed) {
        expect(snapshot.requestResult?.reportId, 'saved-a');
        expect(snapshot.requestResult?.totalWaste, 2.5);
      } else {
        expect(snapshot.sessionId, 'session-a');
        expect(snapshot.stageNodeId, 'cut-stage-a');
        expect(snapshot.requestResult, isNull);
      }
    }
  });
  test('rezka astatka rejects malformed success without a report identity',
      () async {
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.adminRezkaAstatkaReport(
              apparatus: 'apparatus:default:asset-010',
              orderId: 'order-a',
              requestId: 'request-a',
              sessionId: 'session-a',
              totalWasteOnly: true,
              totalWaste: 2.5),
          throwsA(isA<MobileApiException>().having((error) => error.code,
              'code', 'rezka_astatka_invalid_response')));
    },
        () => MockClient((request) async => http.Response(
            jsonEncode({
              'ok': true,
              'report': {
                'order_id': 'order-a',
                'apparatus': 'apparatus:default:asset-010',
                'total_waste': 2.5
              }
            }),
            200)));
  });
  test('full rezka report still requires all waste categories', () async {
    await expectLater(
      MobileApi.instance.adminRezkaAstatkaReport(
        apparatus: 'apparatus:default:asset-010',
        orderId: 'zakaz-final',
        requestId: 'request-final',
        sessionId: 'session-final',
        totalWaste: 1,
      ),
      throwsA(isA<MobileApiException>().having(
          (error) => error.code, 'code', 'rezka_astatka_metrics_required')),
    );
  });
}
