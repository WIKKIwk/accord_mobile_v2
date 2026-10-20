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

  test('page-window protocol carries only local subscription descriptors', () async {
    final descriptor = <String, Object?>{'id': 'w1', 'view': 'sequence',
      'apparatus': 'press', 'target': '', 'search': 'label', 'length': 40, 'version': 'v1'};
    server.listen((request) async {
      expect(request.uri.queryParameters['protocol'], 'page_delta_v1');
      expect(jsonDecode(request.uri.queryParameters['pages']!), [descriptor]);
      expect(request.uri.queryParameters['pages'], isNot(contains('socket-test-token')));
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
      socket.add(jsonEncode({'ok': true, 'type': 'page_window_ready',
        'window': 'w1', 'epoch': 'server', 'rev': 1, 'version': 'v1', 'resync': false}));
    });
    final message = await MobileApi.instance.adminProductionMapLiveStream(
      paged: true, pageWindows: [descriptor]).first.timeout(const Duration(seconds: 5));
    expect(message, isA<AdminProductionMapPageWindowMessage>());
  });

  test('nonworker state protocol retains global scope and recovery cursor', () async {
    server.listen((request) async {
      expect(request.uri.queryParameters['protocol'], 'state_delta_v1');
      expect(request.uri.queryParameters['worker_scope'], 'false');
      expect(request.uri.queryParameters['scope'], '');
      expect(request.uri.queryParameters['rev'], '8');
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
      socket.add(jsonEncode({'ok': true, 'type': 'state_ready',
        'epoch': 'server', 'rev': 8, 'scope': '', 'resync': false,
        'recovered': true, 'recovery_supported': true}));
    });
    final message = await MobileApi.instance.adminProductionMapLiveStream(
      stateDelta: true, workerScope: false, epoch: 'server', revision: 8).first
      .timeout(const Duration(seconds: 5));
    expect((message as AdminProductionMapLiveStateReady).recovered, isTrue);
    expect(message.recoverySupported, isTrue);
  });

  test('notification protocol decodes only request list', () async {
    server.listen((request) async {
      expect(request.uri.queryParameters['protocol'], 'notifications_v1');
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
      socket.add(jsonEncode({'ok': true, 'type': 'notifications_snapshot',
        'epoch': 'server', 'rev': 9, 'completion_requests': []}));
    });
    final requests = await MobileApi.instance.adminProductionMapNotificationEvents()
      .first.timeout(const Duration(seconds: 5));
    expect(requests, isEmpty);
  });


  test('concurrent notification consumers share socket and replay latest list', () async {
    var connections = 0;
    final closed = Completer<void>();
    server.listen((request) async {
      connections++;
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {}, onDone: () { if (!closed.isCompleted) closed.complete(); });
      socket.add(jsonEncode({'ok': true, 'type': 'notifications_snapshot',
        'epoch': 'server', 'rev': 9, 'completion_requests': []}));
    });
    final first = Completer<void>();
    final one = MobileApi.instance.adminProductionMapNotificationEvents().listen((_) {
      if (!first.isCompleted) first.complete();
    });
    await first.future.timeout(const Duration(seconds: 5), onTimeout: () => throw StateError('first signal timed out'));
    final replay = Completer<void>();
    var secondEvents = 0;
    final changed = Completer<void>();
    final two = MobileApi.instance.adminProductionMapNotificationEvents().listen((_) {
      secondEvents++;
      if (!replay.isCompleted) replay.complete();
      if (secondEvents == 2) changed.complete();
    });
    await replay.future.timeout(const Duration(seconds: 5), onTimeout: () => throw StateError('replay signal timed out'));
    expect(connections, 1);
    await one.cancel();
    sockets.single.add(jsonEncode({'ok': true, 'type': 'notifications_snapshot',
      'epoch': 'server', 'rev': 10, 'completion_requests': []}));
    await changed.future.timeout(const Duration(seconds: 5), onTimeout: () => throw StateError('changed signal timed out'));
    expect(connections, 1);
    await two.cancel();
    await closed.future.timeout(const Duration(seconds: 5), onTimeout: () => throw StateError('closed signal timed out'));
  });


  for (final started in [false, true]) {
    test('retained notification stream refuses changed account (started=$started)', () async {
      var connections = 0;
      server.listen((request) async {
        connections++;
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((_) {});
        socket.add(jsonEncode({'ok': true, 'type': 'notifications_snapshot',
          'epoch': 'server', 'rev': 9, 'completion_requests': []}));
      });
      final retained = MobileApi.instance.adminProductionMapNotificationEvents();
      if (started) await retained.first.timeout(const Duration(seconds: 5));
      AppSession.instance.token = 'different-account';
      await expectLater(retained, emitsError(isA<MobileApiException>()
          .having((error) => error.code, 'code', 'session_changed')));
      expect(connections, started ? 1 : 0);
    });
  }


  test('notification account change during setup opens no cross-account socket', () async {
    var connections = 0;
    server.listen((request) async { connections++; await request.response.close(); });
    final first = MobileApi.instance.adminProductionMapNotificationEvents().first;
    AppSession.instance.token = 'account-changed-before-connect';
    await expectLater(first, throwsA(isA<MobileApiException>()
        .having((error) => error.code, 'code', 'session_changed')));
    expect(connections, 0);
  });

}
