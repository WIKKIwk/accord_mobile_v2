@TestOn('browser')
library;

import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/realtime/live_upgrade_failure.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const route = '/v1/mobile/admin/warehouses/live';

  for (final probeStatus in [401, 400]) {
    test(
        'opaque browser upgrade error retries once and checks the ticket ($probeStatus)',
        () async {
      SharedPreferences.setMockInitialValues({});
      // The Flutter test asset server has no ERP WebSocket upgrade route.
      await ServerEndpointStore.instance.setBaseUrl(Uri.base.origin);
      AppSession.instance.token = 'browser-session';
      addTearDown(() async {
        AppSession.instance.token = null;
        await ServerEndpointStore.instance.clearOverride();
      });
      var issued = 0;
      var probes = 0;
      await http.runWithClient(() async {
        final stream =
            MobileApi.instance.connectPrivateLive(privateLiveUri(route));
        await expectLater(
            stream,
            emitsInOrder([
              emitsError(probeStatus == 401
                  ? isA<MobileApiException>()
                      .having((e) => e.statusCode, 'status', 401)
                  : isA<LiveUpgradeFailure>()),
              emitsDone,
            ]));
      },
          () => MockClient((request) async {
                if (request.method == 'POST') {
                  expect(request.url.path, '/v1/mobile/auth/live-ticket');
                  expect(jsonDecode(request.body), {'path': route});
                  expect(request.headers['authorization'],
                      'Bearer browser-session');
                  return http.Response(
                      jsonEncode({'ticket': 'new-${++issued}'}), 200);
                }
                probes++;
                expect(request.method, 'GET');
                expect(request.url.path, route);
                expect(request.url.queryParameters, {'ticket': 'new-2'});
                expect(request.headers['authorization'], isNull);
                return http.Response('', probeStatus);
              }));
      expect(issued, 2);
      expect(probes, 1);
      expect(AppSession.instance.token,
          probeStatus == 401 ? isNull : 'browser-session');
    });
  }
}
