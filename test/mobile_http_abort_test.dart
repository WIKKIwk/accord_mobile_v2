import 'dart:async';

import 'package:accord_mobile_v2/src/core/network/mobile_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('preview forwarding retains cancellation of a timed out GET', () async {
    final abort = Completer<void>();
    final seen = Completer<void>();
    final client = DevApiProxyClient(_AbortAwareClient((request) async {
      expect(request.url.toString(), '$devApiBridgeOrigin/v1/mobile/items');
      expect(request, isA<http.Abortable>());
      expect((request as http.Abortable).abortTrigger, same(abort.future));
      seen.complete();
      await request.abortTrigger;
      throw http.RequestAbortedException(request.url);
    }), previewOrigin: Uri.parse('http://127.0.0.1:12345'));
    final request = http.AbortableRequest(
        'GET', Uri.parse('$devApiProxyTarget/v1/mobile/items'),
        abortTrigger: abort.future);
    final pending = client.send(request);
    final failure =
        expectLater(pending, throwsA(isA<http.RequestAbortedException>()));
    await seen.future;
    abort.complete();
    await failure;
  });

  test('secure redirects retain the original cancellation trigger', () async {
    final abort = Completer<void>();
    final redirected = Completer<void>();
    var attempts = 0;
    final client = SecureMobileApiClient(_AbortAwareClient((request) async {
      attempts++;
      if (attempts == 1) {
        return http.StreamedResponse(const Stream.empty(), 302,
            headers: {'location': '/v1/mobile/items/redirected'});
      }
      expect(request, isA<http.Abortable>());
      expect((request as http.Abortable).abortTrigger, same(abort.future));
      redirected.complete();
      await request.abortTrigger;
      throw http.RequestAbortedException(request.url);
    }));
    final pending = client.send(http.AbortableRequest(
        'GET', Uri.parse('https://mes.example/v1/mobile/items'),
        abortTrigger: abort.future));
    final failure =
        expectLater(pending, throwsA(isA<http.RequestAbortedException>()));
    await redirected.future;
    abort.complete();
    await failure;
    expect(attempts, 2);
  });
}

class _AbortAwareClient extends http.BaseClient {
  _AbortAwareClient(this.handler);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
