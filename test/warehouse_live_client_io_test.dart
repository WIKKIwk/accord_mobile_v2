import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/realtime/warehouse_live_client_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  final sockets = <WebSocket>[];
  final rawSockets = <Socket>[];
  Uri uri() => Uri.parse('ws://127.0.0.1:${server.port}/live');

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });
  tearDown(() async {
    for (final socket in sockets) {
      unawaited(socket.close());
    }
    for (final socket in rawSockets) {
      socket.destroy();
    }
    sockets.clear();
    rawSockets.clear();
    await server.close(force: true);
  });

  test('quiet queue stays connected through repeated transport heartbeats',
      () async {
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
      socket.add('{"ok":true,"rev":1}');
    });
    final first = Completer<void>();
    var done = false;
    final errors = <Object>[];
    final events = <Map<String, dynamic>>[];
    final sub = connectWarehouseLivePlatform(uri(),
            pingInterval: const Duration(milliseconds: 60))
        .listen((event) {
      events.add(event);
      if (!first.isCompleted) first.complete();
    }, onError: errors.add, onDone: () => done = true);
    await first.future.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(events, [
      {'ok': true, 'rev': 1}
    ]);
    expect(done, isFalse);
    expect(errors, isEmpty);
    await sub.cancel().timeout(const Duration(seconds: 1));
  });

  test('remote close finishes stream so worker can reconnect', () async {
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
      socket.add('{"ok":true}');
      unawaited(socket.close());
    });
    await expectLater(
        connectWarehouseLivePlatform(uri()),
        emitsInOrder([
          {'ok': true},
          emitsDone
        ]));
  });

  test('handshake timeout is bounded and completes the stream', () async {
    server.listen((_) {}); // TCP/HTTP is reachable, but upgrade never replies.
    await expectLater(
        connectWarehouseLivePlatform(uri(),
            connectTimeout: const Duration(milliseconds: 80)),
        emitsInOrder([emitsError(isA<TimeoutException>()), emitsDone]));
  });

  test('cancel during handshake returns promptly and suppresses late errors',
      () async {
    final accepted = Completer<void>();
    server.listen((_) {
      if (!accepted.isCompleted) accepted.complete();
    });
    final errors = <Object>[];
    final sub = connectWarehouseLivePlatform(uri(),
            connectTimeout: const Duration(milliseconds: 150))
        .listen((_) => fail('cancelled connection must not publish'),
            onError: errors.add);
    await accepted.future.timeout(const Duration(seconds: 2));
    await sub.cancel().timeout(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(errors, isEmpty);
  });

  test(
      'half-open peer missing pong terminates without waiting for queue changes',
      () async {
    server.listen((request) async {
      final key = request.headers.value('sec-websocket-key')!;
      request.response.statusCode = HttpStatus.switchingProtocols;
      request.response.headers
        ..set('connection', 'Upgrade')
        ..set('upgrade', 'websocket')
        ..set(
            'sec-websocket-accept',
            base64.encode(sha1
                .convert(
                    utf8.encode('$key' '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'))
                .bytes));
      final raw = await request.response.detachSocket();
      rawSockets.add(raw);
      raw.listen((_) {}); // Consume ping bytes, deliberately never send pong.
    });
    final done = Completer<void>();
    final sub = connectWarehouseLivePlatform(uri(),
            pingInterval: const Duration(milliseconds: 60))
        .listen((_) => fail('no snapshots sent'), onDone: done.complete);
    await done.future.timeout(const Duration(seconds: 2));
    await sub.cancel();
  });

  test('malformed stream payload reports error then releases connection',
      () async {
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((_) {});
      socket.add('not-json');
    });
    await expectLater(connectWarehouseLivePlatform(uri()),
        emitsInOrder([emitsError(isA<FormatException>()), emitsDone]));
  });

  test(
      'monitor keeps its application ping contract on the shared WSS transport',
      () async {
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((message) {
        final ping = jsonDecode(message as String) as Map<String, dynamic>;
        expect(ping['type'], 'ping');
        socket.add(jsonEncode({...ping, 'type': 'pong'}));
      });
    });
    final pong = await connectSystemMonitorLivePlatform(uri())
        .first
        .timeout(const Duration(seconds: 2));
    expect(pong['type'], 'pong');
    expect(pong['id'], 1);
    expect(pong['sent_at_ms'], isA<int>());
  });
}
