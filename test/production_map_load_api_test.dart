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
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'map-load-test';
  });

  tearDown(() {
    AppSession.instance.token = null;
  });

  for (final status in [403, 404, 500, 502, 503]) {
    test('HTTP $status without domain error does not mean map missing',
        () async {
      await http.runWithClient(() async {
        await expectLater(
          MobileApi.instance.adminProductionMap('template-existing'),
          throwsA(isA<MobileApiException>()
              .having(
                  (error) => error.code, 'code', 'production_map_load_failed')
              .having((error) => error.statusCode, 'status', status)),
        );
      },
          () => MockClient((request) async {
                expect(request.method, 'GET');
                expect(request.url.queryParameters['id'], 'template-existing');
                return http.Response('<html>Proxy error</html>', status);
              }));
    });
  }

  test('explicit map_not_found response preserves the HTTP status', () async {
    await http.runWithClient(() async {
      await expectLater(
        MobileApi.instance.adminProductionMap('template-missing'),
        throwsA(isA<MobileApiException>()
            .having((error) => error.code, 'code', 'map_not_found')
            .having((error) => error.statusCode, 'status', 404)),
      );
    },
        () => MockClient(
            (_) async => http.Response('{"error":"map_not_found"}', 404)));
  });
}
