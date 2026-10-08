import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/network/mobile_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real mobile HTTP client negotiates gzip and preserves every byte',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final original = utf8.encode(jsonEncode({
      'rev': 17,
      'epoch': 'fixture',
      'orders': List.generate(100, (i) => {'id': '$i', 'name': 'O‘zbek 字'}),
    }));
    final compressed = gzip.encode(original);
    final serving = server.first.then((request) async {
      expect(request.headers.value(HttpHeaders.acceptEncodingHeader),
          contains('gzip'));
      request.response.headers.contentType = ContentType.json;
      request.response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      request.response.contentLength = compressed.length;
      request.response.add(compressed);
      await request.response.close();
    });
    final client = createMobileHttpClient();
    addTearDown(client.close);
    final response = await client
        .get(Uri.parse('http://127.0.0.1:${server.port}/snapshot'))
        .timeout(const Duration(seconds: 3));
    await serving;
    expect(response.bodyBytes, original);
    expect(jsonDecode(response.body)['orders'], hasLength(100));
    expect(compressed.length, lessThan(original.length));
  });
}
