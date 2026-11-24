import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/live_ticket_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  const token = 'test-session';
  const path = '/v1/mobile/admin/warehouses/live';
  final api = MobileApi.instance;

  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({});
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    await ServerEndpointStore.instance
        .setBaseUrl('http://127.0.0.1:${server.port}');
    AppSession.instance.token = token;
  });

  tearDown(() async {
    await server.close(force: true);
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = null;
  });

  for (final route in [
    path,
    '/v1/mobile/admin/system/monitor/live',
    '/v1/mobile/admin/inventory/live',
    '/v1/mobile/admin/production-maps/live',
    '/v1/mobile/production-tasks/live',
    '/v1/mobile/preparation/orders/live'
  ]) {
    test('each connect to $route uses a fresh ticket and preserves all filters',
        () async {
      const filters = {
        'protocol': 'state_delta_v2',
        'rev': '7',
        'cursor': 'a/b',
        'kind': 'material',
        'subscriptions': '[{"id":"x+y"}]',
        'all_apparatus': 'true',
        'search': 'A & B'
      };
      var count = 0;
      liveUpgrades(server, route, token).listen((request) async {
        expect(request.uri.queryParameters,
            {...filters, 'ticket': 'ticket-${++count}'});
        final socket = await WebSocketTransformer.upgrade(request);
        socket.add(jsonEncode({'ready': true}));
        await socket.close();
      });
      for (var connection = 0; connection < 2; connection++) {
        final events = await api
            .connectPrivateLive(privateLiveUri(route, filters))
            .toList();
        expect(events.single['ready'], isTrue);
      }
      expect(count, 2);
    });
  }

  for (final deniedAgain in [false, true]) {
    test('upgrade 401 gets one fresh ticket (denied again = $deniedAgain)',
        () async {
      var count = 0;
      liveUpgrades(server, path, token).listen((request) async {
        if (++count == 1 || deniedAgain) {
          request.response.statusCode = 401;
          await request.response.close();
        } else {
          final socket = await WebSocketTransformer.upgrade(request);
          socket.add('{"ok":true}');
          await socket.close();
        }
      });
      final stream = api.connectPrivateLive(api.adminWarehouseLiveUri());
      if (deniedAgain) {
        await expectLater(
            stream,
            emitsInOrder([
              emitsError(isA<MobileApiException>()
                  .having((e) => e.statusCode, 'status', 401)),
              emitsDone
            ]));
        expect(AppSession.instance.token, isNull);
      } else {
        expect((await stream.toList()).single['ok'], isTrue);
        expect(AppSession.instance.token, token);
      }
      expect(count, 2);
    });
  }

  test('a revocation notice ends the session without another upgrade',
      () async {
    var upgrades = 0;
    liveUpgrades(server, path, token).listen((request) async {
      upgrades++;
      final socket = await WebSocketTransformer.upgrade(request);
      socket.add('{"type":"tasks_error","error":"unauthorized","status":401}');
      await socket.close();
    });
    await expectLater(api.connectPrivateLive(api.adminWarehouseLiveUri()),
        emitsInOrder([emitsError(isA<MobileApiException>()), emitsDone]));
    expect(AppSession.instance.token, isNull);
    expect(upgrades, 1);
  });

  test('a changed account is not logged out by an older ticket request',
      () async {
    server.listen((request) async {
      AppSession.instance.token = 'replacement';
      request.response.statusCode = 401;
      await request.response.close();
    });
    await expectLater(
        api.connectPrivateLive(api.adminWarehouseLiveUri()),
        emitsError(isA<MobileApiException>()
            .having((e) => e.code, 'code', 'session_changed')));
    expect(AppSession.instance.token, 'replacement');
  });
}
