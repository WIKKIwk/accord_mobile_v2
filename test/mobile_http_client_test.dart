import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/network/mobile_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final preview = Uri.parse('http://127.0.0.1:52218/#/login');

  test('login keeps its POST body and headers through the local proxy',
      () async {
    final client = DevApiProxyClient(MockClient((request) async {
      expect(request.url.toString(),
          'http://127.0.0.1:52218/__accord_api/v1/mobile/auth/login');
      expect(request.method, 'POST');
      expect(request.headers['content-type'], contains('application/json'));
      expect(jsonDecode(request.body),
          {'phone': 'test-phone', 'code': 'test-code'});
      return http.Response('{"token":"test-token"}', 200);
    }), previewOrigin: preview);
    addTearDown(client.close);

    final response = await client.post(
      Uri.parse('$devApiProxyTarget/v1/mobile/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': 'test-phone', 'code': 'test-code'}),
    );
    expect(response.statusCode, 200);
    expect(jsonDecode(response.body)['token'], 'test-token');
  });

  test('retains query, auth, request options and upstream failure', () async {
    final inner = _InspectingClient((request) async {
      expect(request.url.toString(),
          'http://127.0.0.1:52218/__accord_api/v1/mobile/items?q=a%2Bb&page=2');
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.followRedirects, isFalse);
      expect(request.maxRedirects, 2);
      expect(request.persistentConnection, isFalse);
      await request.finalize().drain<void>();
      return http.StreamedResponse(
          Stream.value(utf8.encode('unauthorized')), 401);
    });
    final client = DevApiProxyClient(inner, previewOrigin: preview);
    final request = http.Request(
        'GET', Uri.parse('$devApiProxyTarget/v1/mobile/items?q=a%2Bb&page=2'))
      ..headers['Authorization'] = 'Bearer test-token'
      ..followRedirects = false
      ..maxRedirects = 2
      ..persistentConnection = false;
    expect((await client.send(request)).statusCode, 401);
    client.close();
    expect(inner.closed, isTrue);
  });

  test('never forwards other servers or the printer bridge to the test API',
      () async {
    for (final url in [
      'https://other.example/v1/mobile/auth/login',
      'http://127.0.0.1:18081/v1/mobile/auth/login',
      'http://127.0.0.1:39118/print',
      'http://accord-test.wspace.sbs/v1/mobile/auth/login',
      'https://accord-test.wspace.sbs:8443/v1/mobile/auth/login',
    ]) {
      final client = DevApiProxyClient(MockClient((request) async {
        expect(request.url.toString(), url);
        return http.Response('', 200);
      }), previewOrigin: preview);
      await client.get(Uri.parse(url));
      client.close();
    }
  });

  test('multipart bodies and generated boundary survive forwarding', () async {
    final client = DevApiProxyClient(MockClient((request) async {
      expect(request.headers['content-type'],
          startsWith('multipart/form-data; boundary='));
      expect(request.body, contains('sample-file-content'));
      expect(request.body, contains('name="file"; filename="sample.txt"'));
      return http.Response('', 201);
    }), previewOrigin: preview);
    addTearDown(client.close);
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$devApiProxyTarget/v1/mobile/upload'),
    )..files.add(http.MultipartFile.fromString('file', 'sample-file-content',
        filename: 'sample.txt'));
    expect((await client.send(request)).statusCode, 201);
  });

  test(
      'native client keeps the original endpoint even when dev flag is enabled',
      () async {
    await http.runWithClient(() async {
      final client = createMobileHttpClient();
      await client.get(Uri.parse('$devApiProxyTarget/healthz'));
      client.close();
    },
        () => MockClient((request) async {
              expect(request.url.toString(), '$devApiProxyTarget/healthz');
              return http.Response('ok', 200);
            }));
  });

  test('Flutter preview reaches the local core while accounts keep HTTPS', () {
    final config = File('web_dev_config.yaml').readAsStringSync();
    expect(devApiProxyTarget, 'https://accord-test.wspace.sbs');
    expect(config, contains('prefix: /__accord_api/'));
    expect(config, contains('target: http://127.0.0.1:8081/'));
    expect(config, contains('replace: /'));
  });

  test('API client rejects cleartext before sending credentials', () async {
    var sent = false;
    final client = SecureMobileApiClient(MockClient((request) async {
      sent = true;
      return http.Response('', 200);
    }));
    addTearDown(client.close);
    await expectLater(
        client.post(
          Uri.parse('http://erp.example.com/v1/mobile/auth/login'),
          body: '{"phone":"synthetic","code":"synthetic"}',
        ),
        throwsA(isA<http.ClientException>()));
    expect(sent, isFalse);
  });

  test('API client refuses an HTTPS to HTTP redirect without sending the token',
      () async {
    var requests = 0;
    final client = SecureMobileApiClient(MockClient((request) async {
      requests++;
      expect(request.url.scheme, 'https');
      expect(request.followRedirects, isFalse);
      return http.Response('', 302, headers: {
        'location': 'http://erp.example.com/v1/mobile/me',
      });
    }));
    addTearDown(client.close);
    await expectLater(
        client.get(
          Uri.parse('https://erp.example.com/v1/mobile/me'),
          headers: {'Authorization': 'Bearer synthetic-token'},
        ),
        throwsA(isA<http.ClientException>()));
    expect(requests, 1);
  });

  test('HTTPS media redirects retain access without forwarding API credentials',
      () async {
    var requests = 0;
    final client = SecureMobileApiClient(MockClient((request) async {
      expect(request.followRedirects, isFalse);
      requests++;
      if (requests == 1) {
        expect(request.headers['Authorization'], 'Bearer synthetic-token');
        return http.Response('', 302, headers: {
          'location': 'https://media.example.com/signed-media',
        });
      }
      expect(request.url.host, 'media.example.com');
      expect(request.headers.keys.map((key) => key.toLowerCase()),
          isNot(contains('authorization')));
      return http.Response('synthetic-media', 200);
    }));
    addTearDown(client.close);
    final response = await client.get(
      Uri.parse('https://erp.example.com/v1/mobile/chat/media/id/content'),
      headers: {'Authorization': 'Bearer synthetic-token'},
    );
    expect(response.body, 'synthetic-media');
    expect(requests, 2);
  });
}

class _InspectingClient extends http.BaseClient {
  _InspectingClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);

  @override
  void close() => closed = true;
}
