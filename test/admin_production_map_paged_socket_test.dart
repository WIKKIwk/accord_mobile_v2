import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  final sockets = <WebSocket>[];
  setUp(() async {
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues({'test_mode_enabled': false});
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    await ServerEndpointStore.instance
        .setBaseUrl('http://127.0.0.1:${server.port}');
    AppSession.instance.token = 'socket-test-token';
  });
  tearDown(() async {
    for (final socket in sockets) {
      unawaited(socket.close());
    }
    sockets.clear();
    await server.close(force: true);
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = null;
  });

  test(
      'paged admin uses the original delta socket with bounded cursor messages',
      () async {
    server.listen((request) async {
      expect(request.uri.path, '/v1/mobile/admin/production-maps/live');
      expect(request.uri.queryParameters['protocol'], 'delta');
      expect(request.uri.queryParameters['paged'], 'true');
      expect(request.uri.queryParameters.containsKey('worker_scope'), isFalse);
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
      for (final packet in [
        {'ok': true, 'type': 'page_ready', 'epoch': 'server', 'rev': 1},
        {
          'ok': true,
          'type': 'delta',
          'epoch': 'server',
          'apparatus': 'apparatus:default:bosma_8',
          'base_revision': 1,
          'revision': 2,
          'snapshot_rev': 9,
          'base_version': '0' * 64,
          'version': '1' * 64,
          'ops': [
            {'type': 'move', 'id': 'first', 'after_id': 'second'}
          ]
        },
        {'ok': true, 'type': 'page_invalidated', 'epoch': 'server', 'rev': 10},
      ]) {
        socket.add(jsonEncode(packet));
      }
    });
    final messages = await MobileApi.instance
        .adminProductionMapLiveStream(paged: true)
        .take(3)
        .toList()
        .timeout(const Duration(seconds: 5));
    expect((messages[0] as AdminProductionMapPageChange).ready, isTrue);
    final delta = messages[1] as AdminProductionMapLiveDelta;
    expect(delta.ops.single.afterId, 'second');
    expect(delta.snapshotRevision, 9);
    expect((messages[2] as AdminProductionMapPageChange).revision, 10);
  });

  test('paged admin refuses an incompatible full snapshot', () async {
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
      socket.add(jsonEncode({'ok': true, 'type': 'snapshot', 'maps': []}));
    });
    await expectLater(
      MobileApi.instance.adminProductionMapLiveStream(paged: true),
      emitsError(isA<MobileApiException>()
          .having((e) => e.code, 'code', 'paged_live_required')),
    );
  });
}
