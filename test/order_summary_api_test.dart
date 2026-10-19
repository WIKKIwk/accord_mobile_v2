import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'admin-token';
  });
  tearDown(() => AppSession.instance.token = null);

  test('order summary reads authenticated order snapshot and all saved layers',
      () async {
    await http.runWithClient(() async {
      final summary =
          await MobileApi.instance.adminProductionMapOrderSummary('zakaz-0309');
      expect(summary.frameCount, 3);
      expect(
          summary.effectiveLayers.map((layer) => layer.micron), ['12', '40']);
    },
        () => MockClient((request) async {
              expect(request.method, 'GET');
              expect(request.url.path,
                  '/v1/mobile/admin/production-maps/order-summary');
              expect(request.url.queryParameters, {'id': 'zakaz-0309'});
              expect(request.headers['authorization'], 'Bearer admin-token');
              return http.Response(
                  jsonEncode({
                    'template': {
                      'source_map_id': 'zakaz-0309',
                      'frame_count': 3,
                      'layers': [
                        {'material': 'PET', 'micron': '12'},
                        {'material': 'PE', 'micron': '40'}
                      ],
                    }
                  }),
                  200);
            }));
  });

  test('order summary rejects another order snapshot', () async {
    await http.runWithClient(() async {
      await expectLater(
        MobileApi.instance.adminProductionMapOrderSummary('zakaz-0309'),
        throwsFormatException,
      );
    },
        () => MockClient((_) async => http.Response(
              jsonEncode({
                'template': {'source_map_id': 'zakaz-other'}
              }),
              200,
            )));
  });
}
