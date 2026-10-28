import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/resilient_api_read.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final uri = Uri.parse('https://mes.example/v1/mobile/items?token=private');

  for (final failure in ['reset', 'timeout', 'gateway', 'html']) {
    test('GET recovers from one $failure without changing its endpoint',
        () async {
      var attempts = 0;
      final response = await resilientApiRead(uri, (_) async {
        attempts++;
        if (attempts == 1) {
          switch (failure) {
            case 'reset':
              throw http.ClientException('Connection reset', uri);
            case 'timeout':
              throw TimeoutException('read timed out');
            case 'gateway':
              return http.Response('{}', 502);
            case 'html':
              return http.Response('<!doctype html><html></html>', 200,
                  headers: {'content-type': 'text/html'});
          }
        }
        return http.Response('{"ok":true}', 200);
      }, retryDelay: Duration.zero);
      expect(attempts, 2);
      expect(response.body, '{"ok":true}');
    });
  }

  test('failed GET is bounded and HTML never reaches the JSON decoder',
      () async {
    var attempts = 0;
    await expectLater(
        resilientApiRead(uri, (_) async {
          attempts++;
          return http.Response('<html>preview</html>', 200,
              headers: {'content-type': 'text/html'});
        }, retryDelay: Duration.zero),
        throwsA(isA<http.ClientException>()));
    expect(attempts, 2);
  });

  test(
      'diagnostics identify reset and endpoint without query or credential text',
      () async {
    final messages = <String?>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) => messages.add(message);
    addTearDown(() => debugPrint = previous);
    await expectLater(
        resilientApiRead(uri, (_) async {
          throw http.ClientException(
              'Connection reset by peer: token=private', uri);
        }, retryDelay: Duration.zero),
        throwsA(isA<http.ClientException>()));
    expect(messages, hasLength(2));
    expect(messages.join(), contains('GET /v1/mobile/items'));
    expect(messages.join(), contains('connection_reset'));
    expect(messages.join(), isNot(contains('private')));
    expect(messages.join(), isNot(contains('token=')));
  });

  test('deadline aborts the first HTTP attempt before retrying', () async {
    var attempts = 0;
    var aborted = false;
    final response = await resilientApiRead(uri, (abortTrigger) async {
      attempts++;
      if (attempts == 1) {
        abortTrigger.then((_) => aborted = true);
        return Completer<http.Response>().future;
      }
      expect(aborted, isTrue);
      return http.Response('{}', 200);
    },
        attemptTimeout: const Duration(milliseconds: 2),
        totalTimeout: const Duration(seconds: 1),
        retryDelay: Duration.zero);
    expect(response.statusCode, 200);
    expect(attempts, 2);
  });

  for (final status in [401, 403, 409, 500]) {
    test('HTTP $status is left to authentication or domain error handling',
        () async {
      var attempts = 0;
      final result = await resilientApiRead(uri, (_) async {
        attempts++;
        return http.Response('{}', status);
      }, retryDelay: Duration.zero);
      expect(result.statusCode, status);
      expect(attempts, 1);
    });
  }

  test('MobileApi retries GET but never repeats an assignment mutation',
      () async {
    SharedPreferences.setMockInitialValues({'test_mode_enabled': false});
    AppSession.instance.token = 'synthetic-token';
    addTearDown(() => AppSession.instance.token = null);
    var reads = 0;
    var mutations = 0;
    await http.runWithClient(() async {
      final value =
          await MobileApi.instance.adminRawMaterialLookup(barcode: '30AA');
      expect(value.barcode, '30AA');
      await expectLater(
          MobileApi.instance.adminUnlinkRawMaterialAssignment(
            orderId: 'order-1',
            barcode: '30AA',
          ),
          throwsA(isA<MobileApiException>()));
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                reads++;
                if (reads == 1) throw http.ClientException('Connection reset');
                return http.Response(
                    '{"barcode":"30AA","assignment":null}', 200);
              }
              mutations++;
              return http.Response('{"error":"upstream_unavailable"}', 503);
            }));
    expect(reads, 2);
    expect(mutations, 1);
  });
}
