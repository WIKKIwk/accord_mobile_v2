import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tools/runtime/dev_api_proxy.dart';

void main() {
  Future<(HttpServer, HttpServer, HttpClient)> setup(
    void Function(HttpRequest) handle, {
    Duration readTimeout = const Duration(seconds: 2),
  }) async {
    final upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    upstream.listen(handle);
    final bridge = await startDevApiProxy(
      port: 0,
      upstreamPort: upstream.port,
      readTimeout: readTimeout,
    );
    final client = HttpClient()..autoUncompress = false;
    addTearDown(() async {
      client.close(force: true);
      await bridge.close(force: true);
      await upstream.close(force: true);
    });
    return (upstream, bridge, client);
  }

  test('forwards method, credentials, query and body without replaying writes',
      () async {
    var calls = 0;
    final (_, bridge, client) = await setup((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.uri.toString(), '/v1/mobile/items?q=a%2Bb');
      expect(request.headers.value('authorization'), 'Bearer synthetic');
      expect(await utf8.decoder.bind(request).join(), 'payload');
      request.response.statusCode = 201;
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"saved":true}');
      await request.response.close();
    });
    final request = await client.postUrl(
        Uri.parse('http://127.0.0.1:${bridge.port}/v1/mobile/items?q=a%2Bb'));
    request.headers.set('authorization', 'Bearer synthetic');
    request.write('payload');
    final response = await request.close();
    expect(response.statusCode, 201);
    expect(
        jsonDecode(await utf8.decoder.bind(response).join()), {'saved': true});
    expect(calls, 1);
  });

  test('a reset is JSON 502 rather than successful HTML, with no POST retry',
      () async {
    var calls = 0;
    final (_, bridge, client) = await setup((request) async {
      calls++;
      await request.drain<void>();
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
    });
    final request = await client
        .postUrl(Uri.parse('http://127.0.0.1:${bridge.port}/v1/mobile/action'));
    request.headers.set('origin', 'http://127.0.0.1:58455');
    final response = await request.close();
    expect(response.statusCode, 502);
    expect(response.headers.value('access-control-allow-origin'),
        'http://127.0.0.1:58455');
    expect(response.headers.contentType?.mimeType, 'application/json');
    expect(jsonDecode(await utf8.decoder.bind(response).join()),
        {'error': 'upstream_unavailable'});
    expect(calls, 1);
  });

  test('a timed out read returns JSON 504', () async {
    final (_, bridge, client) = await setup((request) {},
        readTimeout: const Duration(milliseconds: 40));
    final request = await client
        .getUrl(Uri.parse('http://127.0.0.1:${bridge.port}/v1/mobile/items'));
    final response = await request.close();
    expect(response.statusCode, 504);
    expect(jsonDecode(await utf8.decoder.bind(response).join()),
        {'error': 'upstream_timeout'});
  });

  test(
      'a reset during a chunked body aborts instead of succeeding with partial JSON',
      () async {
    final (_, bridge, client) = await setup((request) async {
      final socket = await request.response.detachSocket(writeHeaders: false);
      const prefix = '{"items":[';
      socket.write('HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n'
          'Transfer-Encoding: chunked\r\n\r\n'
          '${prefix.length.toRadixString(16)}\r\n$prefix\r\n');
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      socket.destroy();
    });
    final request = await client
        .getUrl(Uri.parse('http://127.0.0.1:${bridge.port}/v1/mobile/items'));
    final response = await request.close();
    expect(response.statusCode, 200);
    await expectLater(
        utf8.decoder.bind(response).join(), throwsA(isA<HttpException>()));
  });

  test('preflight only allows local preview origins without querying core',
      () async {
    var calls = 0;
    final (_, bridge, client) = await setup((request) {
      calls++;
    });
    for (final (origin, status) in [
      ('http://127.0.0.1:58455', 204),
      ('http://localhost:58455', 204),
      ('https://outside.example', 403),
      ('null', 403),
    ]) {
      final request = await client.openUrl('OPTIONS',
          Uri.parse('http://127.0.0.1:${bridge.port}/v1/mobile/items'));
      request.headers.set('origin', origin);
      request.headers.set('access-control-request-method', 'POST');
      final response = await request.close();
      expect(response.statusCode, status);
      expect(response.headers.value('access-control-allow-origin'),
          status == 204 ? origin : isNull);
      if (status == 204) {
        expect(response.headers.value('access-control-allow-headers'),
            contains('x-backup-filename'));
        expect(response.headers.value('access-control-expose-headers'),
            contains('content-disposition'));
        expect(response.headers.value('access-control-expose-headers'),
            contains('x-request-id'));
      }
      await response.drain<void>();
    }
    expect(calls, 0);
  });

  test('preserves gzip bytes and encoding', () async {
    final bytes = gzip.encode(utf8.encode('{"items":[1,2,3]}'));
    final (_, bridge, client) = await setup((request) async {
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set('content-encoding', 'gzip');
      request.response.contentLength = bytes.length;
      request.response.add(bytes);
      await request.response.close();
    });
    final request = await client
        .getUrl(Uri.parse('http://127.0.0.1:${bridge.port}/v1/mobile/items'));
    final response = await request.close();
    expect(response.headers.value('content-encoding'), 'gzip');
    final received =
        await response.fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    expect(received, bytes);
    expect(jsonDecode(utf8.decode(gzip.decode(received))), {
      'items': [1, 2, 3]
    });
  });

  test(
      'bridge health is separate from core health and other paths are rejected',
      () async {
    var calls = 0;
    final (_, bridge, client) = await setup((request) async {
      calls++;
      expect(request.uri.path, '/healthz');
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"ok":true}');
      await request.response.close();
    });
    for (final (path, status, payload) in [
      ('/__accord_proxy_healthz', 200, {'service': devApiProxyService}),
      ('/healthz', 200, {'ok': true}),
      ('/outside', 404, {'error': 'not_found'}),
    ]) {
      final request = await client
          .getUrl(Uri.parse('http://127.0.0.1:${bridge.port}$path'));
      final response = await request.close();
      expect(response.statusCode, status);
      expect(jsonDecode(await utf8.decoder.bind(response).join()), payload);
    }
    expect(calls, 1);
  });
}
