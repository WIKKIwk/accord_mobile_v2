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
      'http://mini-rs-erp-test.wspace.sbs/v1/mobile/auth/login',
      'https://mini-rs-erp-test.wspace.sbs:8443/v1/mobile/auth/login',
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

  test('Flutter proxy config agrees with the allowlisted API origin', () {
    final config = File('web_dev_config.yaml').readAsStringSync();
    expect(config, contains('prefix: /__accord_api/'));
    expect(config, contains('target: $devApiProxyTarget/'));
    expect(config, contains('replace: /'));
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
