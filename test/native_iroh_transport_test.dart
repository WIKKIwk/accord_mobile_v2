import 'dart:convert';
import 'dart:async';
import 'package:accord_mobile_v2/src/core/native_iroh_transport.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('accord/iroh_transport');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final ticket = base64Url
      .encode(utf8.encode(jsonEncode({
        'id': List.filled(64, '1').join(),
        'addrs': <dynamic>[],
      })))
      .replaceAll('=', '');
  final cached =
      jsonEncode({'ticket': ticket, 'supports_connection_reuse': true});
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  if (!NativeIrohTransport.autoConnectEnabled) {
    for (final method in ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE']) {
      test('default HTTPS $method bypasses even a healthy cached Iroh route',
          () async {
        SharedPreferences.setMockInitialValues(
            {'iroh_endpoint_v2:https://test.invalid': cached});
        var nativeCalls = 0;
        var httpCalls = 0;
        messenger.setMockMethodCallHandler(channel, (_) async {
          nativeCalls++;
          return true;
        });
        final uri = Uri.parse('https://test.invalid/v1/mobile/test');
        await http.runWithClient(() async {
          await NativeIrohTransport.warmUp(uri);
          final response = await NativeIrohTransport.send(
              method: method,
              uri: uri,
              headers: {'authorization': 'Bearer fixture'},
              body: 'fixture');
          expect(response.statusCode, 200);
        },
            () => MockClient((request) async {
                  httpCalls++;
                  expect(request.url, uri); // No discovery/probe requests.
                  expect(request.method, method);
                  expect(request.body, 'fixture');
                  expect(request.headers['authorization'], 'Bearer fixture');
                  return http.Response('{}', 200);
                }));
        expect(httpCalls, 1);
        expect(nativeCalls, 0);
      });
    }
    test('default live path never starts cached native transport', () async {
      SharedPreferences.setMockInitialValues(
          {'iroh_endpoint_v2:https://test.invalid': cached});
      var nativeCalls = 0;
      messenger.setMockMethodCallHandler(channel, (_) async {
        nativeCalls++;
        return true;
      });
      final uri = Uri.parse('wss://test.invalid/v1/mobile/live');
      expect(NativeIrohTransport.canUseFor(uri), isFalse);
      await expectLater(NativeIrohTransport.liveEvents(uri: uri),
          emitsInOrder([emitsError(isA<MissingPluginException>()), emitsDone]));
      expect(nativeCalls, 0);
    });
    return; // The existing opt-in suite is also run with --dart-define=IROH_AUTO_CONNECT=true.
  }

  test('missing bridge reports unsupported', () async {
    expect(await NativeIrohTransport.isSupported(), isFalse);
  });

  test('saved HTTPS endpoint still permits its origin-scoped native route',
      () async {
    final store = ServerEndpointStore.instance;
    await store.setBaseUrl('https://selected-erp.invalid');
    try {
      expect(store.isRuntimeOverride, isTrue);
      expect(
          NativeIrohTransport.canUseFor(
              Uri.parse('${store.baseUrl}/v1/mobile/test')),
          isTrue);
      expect(
          NativeIrohTransport.canUseFor(
              Uri.parse('wss://selected-erp.invalid/v1/mobile/live')),
          isTrue);
      expect(
          NativeIrohTransport.canUseFor(Uri.parse('http://192.168.1.4:18081')),
          isFalse);
      expect(
          NativeIrohTransport.canUseFor(
              Uri.parse('https://user:pass@selected-erp.invalid')),
          isFalse);
    } finally {
      await store.clearOverride();
    }
  });

  for (final method in ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE']) {
    test('missing bridge preserves direct HTTP $method', () async {
      var requests = 0;
      final uri = Uri.parse('https://test.invalid/orders?limit=1');
      final body = method == 'GET' || method == 'HEAD' ? '' : '{"id":1}';
      final result = await http.runWithClient(
          () => NativeIrohTransport.send(
              method: method,
              uri: uri,
              headers: {'authorization': 'Bearer test-token'},
              body: body),
          () => MockClient((request) async {
                requests++;
                expect(request.method, method);
                expect(request.url, uri);
                expect(request.headers['authorization'], 'Bearer test-token');
                expect(request.body, body);
                return http.Response('{"ok":true}', 200);
              }));
      expect(requests, 1);
      expect(result.statusCode, 200);
    });
  }

  for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
    test('native $method reply loss is not replayed after pinned health gate',
        () async {
      SharedPreferences.setMockInitialValues(
          {'iroh_endpoint_v2:https://test.invalid': cached});
      var requests = 0, httpRequests = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isSupported') return true;
        if (call.method == 'request') {
          final args = call.arguments as Map;
          if (args['path'] == '/healthz') {
            expect((args['headers'] as Map)['authorization'], isNull);
            return {'statusCode': 200, 'body': utf8.encode('{"ok":true}')};
          }
          requests++;
          throw PlatformException(code: 'reply_lost_after_commit');
        }
        return null;
      });
      final uri = Uri.parse('https://test.invalid/v1/mobile/queue-action');
      await http.runWithClient(() async {
        await NativeIrohTransport.warmUp(uri);
        await expectLater(
            NativeIrohTransport.send(method: method, uri: uri, body: '{}'),
            throwsA(isA<PlatformException>()));
      },
          () => MockClient((_) async {
                httpRequests++;
                return http.Response('{}', 200);
              }));
      expect(requests, 1);
      expect(httpRequests, 0);
    });
  }

  test('foreign and legacy unscoped cache never establishes trust', () async {
    SharedPreferences.setMockInitialValues({
      'iroh_endpoint_ticket': ticket,
      'iroh_endpoint_v2:https://foreign.invalid': cached,
    });
    var nativeCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      nativeCalls++;
      return null;
    });
    await http.runWithClient(
        () => NativeIrohTransport.warmUp(Uri.parse('https://test.invalid')),
        () => MockClient((request) async {
              expect(request.url.toString(),
                  'https://test.invalid/v1/mobile/iroh-ticket');
              expect(request.followRedirects, isFalse);
              expect(request.headers['authorization'], isNull);
              return http.Response('{}', 503);
            }));
    expect(nativeCalls, 0);
  });

  test('stalled native live handshake raises an error for WSS fallback',
      () async {
    SharedPreferences.setMockInitialValues(
        {'iroh_endpoint_v2:https://test.invalid': cached});
    var stopped = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'request') {
        return {'statusCode': 200, 'body': utf8.encode('{"ok":true}')};
      }
      if (call.method == 'stopLive') stopped++;
      return null; // startLive succeeds, but its connection never emits a frame
    });
    await http.runWithClient(() async {
      await NativeIrohTransport.warmUp(Uri.parse('https://test.invalid'));
      await expectLater(
          NativeIrohTransport.liveEvents(
            uri: Uri.parse('wss://test.invalid/v1/mobile/live'),
          ),
          emitsInOrder([emitsError(isA<TimeoutException>()), emitsDone]));
    }, () => MockClient((_) async => http.Response('{}', 503)));
    expect(stopped, 1);
  });

  test('native chunked responses are decoded before API consumption', () async {
    SharedPreferences.setMockInitialValues(
        {'iroh_endpoint_v2:https://test.invalid': cached});
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'request') {
        expect(((call.arguments as Map)['headers'] as Map)['accept-encoding'],
            'identity');
        return {
          'statusCode': 200,
          'headers': {'transfer-encoding': 'chunked'},
          'body': utf8.encode('b\r\n{"ok":true}\r\n0\r\n\r\n')
        };
      }
      return null;
    });
    final uri = Uri.parse('https://test.invalid/v1/mobile/test');
    await http.runWithClient(() async {
      await NativeIrohTransport.warmUp(uri);
      final result = await NativeIrohTransport.send(method: 'GET', uri: uri);
      expect(result.body, '{"ok":true}');
      expect(result.headers['transfer-encoding'], isNull);
    },
        () => MockClient(
            (_) async => throw StateError('must use ready native route')));
  });

  for (final enabled in [false, true]) {
    test('server opt-in $enabled controls first bootstrap', () async {
      var probes = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isSupported') return true;
        if (call.method == 'request') {
          probes++;
          expect((call.arguments as Map)['ticket'], ticket);
          return {'statusCode': 200, 'body': utf8.encode('{"ok":true}')};
        }
        return null;
      });
      await http.runWithClient(
          () => NativeIrohTransport.warmUp(Uri.parse('https://test.invalid')),
          () => MockClient((_) async => http.Response(
              jsonEncode({
                'ticket': ticket,
                'supports_connection_reuse': true,
                'auto_connect': enabled,
              }),
              200)));
      expect(probes, enabled ? 1 : 0);
    });
  }

  test('plaintext override never starts native discovery', () async {
    var calls = 0;
    messenger.setMockMethodCallHandler(channel, (_) async {
      calls++;
      return true;
    });
    await NativeIrohTransport.warmUp(Uri.parse('http://192.168.1.4:18081'));
    expect(calls, 0);
  });
  test('automatic transport enabled with per-server health gate', () {
    expect(NativeIrohTransport.autoConnectEnabled, isTrue);
    expect(NativeIrohTransport.hasEndpointTicket, isTrue);
  });
  test('parses health result and errors', () {
    final result = IrohHealthCheckResult.fromMap({
      'ok': true,
      'statusCode': 200,
      'runs': 3,
      'bytes': 324,
      'totalMs': 12.5,
      'pathInfo': 'direct'
    });
    expect(result.ok, isTrue);
    expect(result.runs, 3);
    expect(result.totalMs, 12.5);
    expect(
        irohTransportErrorText(PlatformException(
            code: 'iroh_invalid_ticket', message: 'Ticket xato')),
        'Iroh ticket xato');
  });
  test('requires explicit connection reuse capability', () {
    expect(
        IrohTicketDiscoveryResponse.fromBody(
                '{"ticket":" abc ","supports_connection_reuse":true}')
            .supportsConnectionReuse,
        isTrue);
    expect(
        IrohTicketDiscoveryResponse.fromBody('{"ticket":"abc"}')
            .supportsConnectionReuse,
        isFalse);
    expect(() => IrohTicketDiscoveryResponse.fromBody('{"ticket":"  "}'),
        throwsFormatException);
  });
}
