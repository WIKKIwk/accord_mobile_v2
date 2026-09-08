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

  for (final quantity in [0.0, 2.5]) {
    test('laminatsiya astatka sends only remainders and waste $quantity',
        () async {
      const apparatus = 'apparatus:default:asset-007';
      const orderId = 'zakaz-laminatsiya-astatka';
      final requests = <http.Request>[];
      final report = await http.runWithClient(
        () => MobileApi.instance.adminLaminatsiyaAstatkaReport(
          apparatus: apparatus,
          orderId: orderId,
          laminationPrintLeftoverRolls: quantity,
          laminationFilmLeftoverRolls: quantity,
          totalWaste: quantity,
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
      expect(report.totalWaste, quantity);
      expect(report.finishedGoodsMeter, isNull);
      expect(report.finishedGoodsKg, isNull);
      expect(report.bobinaKg, isNull);
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.path,
          '/v1/mobile/admin/production-maps/laminatsiya-astatka');
      expect(jsonDecode(request.body), {
        'apparatus': apparatus,
        'order_id': orderId,
        'lamination_print_leftover_rolls': quantity,
        'lamination_film_leftover_rolls': quantity,
        'total_waste': quantity,
      });
    });
  }
}
