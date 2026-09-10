import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/network/resilient_iroh_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final origin = Uri.parse('https://erp.example');
final action = origin.resolve('/v1/mobile/worker/start');
IrohEndpointConfig config([String hex = '11']) => IrohEndpointConfig(
      ticket: base64Url
          .encode(utf8.encode(jsonEncode({
            'id': List.filled(32, hex).join(),
            'addrs': <dynamic>[],
          })))
          .replaceAll('=', ''),
      supportsConnectionReuse: true,
    );

class Harness {
  int reads = 0, writes = 0, discoveries = 0, probes = 0, nativeCalls = 0;
  DateTime clock = DateTime(2026);
  bool supported = true;
  IrohEndpointConfig? cached;
  Future<IrohEndpointConfig?> Function()? discover;
  Future<http.Response> Function(http.Request)? httpAction;
  IrohSend? nativeAction;
  List<Map<String, dynamic>> local = [];
  late final route = ResilientIrohRoute(
    origin: origin,
    httpClient: MockClient((request) async {
      if (request.method == 'GET' || request.method == 'HEAD') {
        reads++;
      } else {
        writes++;
      }
      return httpAction?.call(request) ?? http.Response('https', 200);
    }),
    isSupported: () async => supported,
    loadCached: () async => cached,
    discoverTrusted: () async {
      discoveries++;
      return discover?.call() ?? config();
    },
    discoverLocal: () async => local,
    saveCached: (value) async {
      cached = value;
    },
    sendNative: (value, method, uri, headers, body) async {
      if (uri.path == '/healthz') {
        probes++;
      } else {
        nativeCalls++;
      }
      if (nativeAction != null) {
        return nativeAction!(value, method, uri, headers, body);
      }
      return http.Response(
          uri.path == '/healthz' ? '{"ok":true}' : 'iroh', 200);
    },
    now: () => clock,
    probeTimeout: const Duration(milliseconds: 100),
    requestTimeout: const Duration(milliseconds: 100),
    recoveryGrace: const Duration(milliseconds: 5),
  );
}

void main() {
  test('cold HTTPS request does not wait for discovery or native readiness',
      () async {
    final pending = Completer<IrohEndpointConfig?>();
    final h = Harness()..discover = () => pending.future;
    final response = await h.route
        .send(method: 'POST', uri: action)
        .timeout(const Duration(milliseconds: 50));
    expect(response.body, 'https');
    expect(h.writes, 1);
    pending.complete(null);
    await h.route.warmUp();
  });

  test('unsupported native leaves HTTPS untouched', () async {
    final h = Harness()..supported = false;
    await h.route.warmUp();
    await h.route.send(method: 'GET', uri: action);
    expect(h.reads, 1);
    expect(h.discoveries, 0);
    expect(h.probes, 0);
  });

  test('unavailable ticket keeps HTTPS usable', () async {
    final h = Harness()..discover = () async => null;
    await h.route.warmUp();
    expect(h.route.ready, isNull);
    await h.route.send(method: 'POST', uri: action);
    expect(h.writes, 1);
  });

  test('one warm-up for concurrent callers', () async {
    final h = Harness();
    await Future.wait(List.generate(20, (_) => h.route.warmUp()));
    expect(h.discoveries, 1);
    expect(h.probes, 1);
  });

  test('ready route preserves token, method, query, body; probes are tokenless',
      () async {
    final h = Harness();
    h.nativeAction = (config, method, uri, headers, body) async {
      if (uri.path == '/healthz') {
        expect(headers, isNull);
        expect(body, isEmpty);
        return http.Response('{"ok":true}', 200);
      }
      expect(method, 'PATCH');
      expect(uri.query, 'id=3');
      expect(headers?['authorization'], 'Bearer scoped-token');
      expect(utf8.decode(body), '{"x":1}');
      return http.Response('native', 200);
    };
    await h.route.warmUp();
    final result = await h.route.send(
        method: 'PATCH',
        uri: action.replace(query: 'id=3'),
        headers: {'authorization': 'Bearer scoped-token'},
        body: utf8.encode('{"x":1}'));
    expect(result.body, 'native');
    expect(h.writes, 0);
  });

  for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
    for (final code in ['reply_lost_after_commit', 'iroh_request_failed']) {
      test('$method $code NEVER replays through HTTPS', () async {
        final h = Harness();
        await h.route.warmUp();
        h.nativeAction = (_, method, uri, headers, body) async =>
            throw PlatformException(code: code);
        await expectLater(h.route.send(method: method, uri: action),
            throwsA(isA<PlatformException>()));
        expect(h.nativeCalls, 1);
        expect(h.writes, 0);
        await h.route.send(method: method, uri: action);
        expect(h.writes, 1);
        expect(h.nativeCalls, 1); // next distinct operation uses HTTPS
      });
    }
    test('$method may fall back only on explicit pre-write failure', () async {
      final h = Harness();
      await h.route.warmUp();
      h.nativeAction = (_, method, uri, headers, body) async =>
          throw PlatformException(code: 'iroh_not_sent');
      expect((await h.route.send(method: method, uri: action)).body, 'https');
      expect(h.nativeCalls, 1);
      expect(h.writes, 1);
    });
    test('$method HTTP reply loss NEVER replays through ready native route',
        () async {
      final h = Harness()
        ..httpAction = (_) async => throw StateError('reply lost');
      await expectLater(
          h.route.send(method: method, uri: action), throwsStateError);
      await h.route.warmUp();
      expect(h.writes, 1);
      expect(h.nativeCalls, 0);
    });
  }

  test('native mutation timeout does not trigger a second write', () async {
    final h = Harness();
    await h.route.warmUp();
    final pending = Completer<http.Response>();
    h.nativeAction = (_, method, uri, headers, body) => pending.future;
    await expectLater(h.route.send(method: 'POST', uri: action),
        throwsA(isA<TimeoutException>()));
    expect(h.writes, 0);
    expect(h.nativeCalls, 1);
    pending.complete(http.Response('committed', 200));
  });

  for (final method in ['GET', 'HEAD']) {
    test('$method native failure falls back once', () async {
      final h = Harness();
      await h.route.warmUp();
      h.nativeAction = (_, method, uri, headers, body) async =>
          throw StateError('connection lost');
      expect((await h.route.send(method: method, uri: action)).body, 'https');
      expect(h.reads, 1);
      expect(h.nativeCalls, 1);
    });
  }

  for (final status in [401, 403, 409, 500]) {
    test('server $status is returned without transport retry', () async {
      final h = Harness();
      await h.route.warmUp();
      h.nativeAction = (_, method, uri, headers, body) async =>
          http.Response('rejected', status);
      expect(
          (await h.route.send(method: 'POST', uri: action)).statusCode, status);
      expect(h.writes, 0);
      expect(h.nativeCalls, 1);
    });
  }

  test('cooldown avoids repeated failing route and recovers later', () async {
    final h = Harness();
    await h.route.warmUp();
    h.route.nativeFailed();
    await h.route.warmUp();
    expect(h.probes, 1);
    h.clock = h.clock.add(const Duration(seconds: 16));
    await h.route.warmUp();
    expect(h.route.ready, isNotNull);
    expect(h.probes, 2);
  });

  test('late probe cannot resurrect invalidated route', () async {
    final pending = Completer<http.Response>();
    final h = Harness()
      ..nativeAction = (_, method, uri, headers, body) => pending.future;
    final warming = h.route.warmUp();
    while (h.probes == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    h.route.nativeFailed();
    pending.complete(http.Response('{"ok":true}', 200));
    await warming;
    expect(h.route.ready, isNull);
  });

  test('cached identity plus new LAN address works without internet', () async {
    final h = Harness()..cached = config();
    h.local = [
      {
        'server_ref': config().endpointId,
        'host': '192.168.1.8',
        'http_port': 1234
      }
    ];
    h.discover = () async => throw StateError('offline');
    h.nativeAction = (config, method, uri, headers, body) async {
      final json =
          utf8.decode(base64Url.decode(base64Url.normalize(config.ticket)));
      if (!json.contains('192.168.1.8:1234')) {
        throw StateError('old DHCP address');
      }
      return http.Response('{"ok":true}', 200);
    };
    await h.route.warmUp();
    expect(h.route.ready, isNotNull);
    expect(h.discoveries, 0);
  });

  test('stale cached identity can only rotate through trusted discovery',
      () async {
    final h = Harness()..cached = config('22');
    h.nativeAction = (candidate, method, uri, headers, body) async {
      if (candidate.endpointId == config('22').endpointId) {
        throw StateError('old server');
      }
      return http.Response('{"ok":true}', 200);
    };
    await h.route.warmUp();
    expect(h.route.ready?.endpointId, config().endpointId);
    expect(h.discoveries, 1);
  });

  test('large upload stays on established HTTP path', () async {
    final h = Harness();
    await h.route.warmUp();
    await h.route.send(
        method: 'POST', uri: action, body: List.filled(1024 * 1024 + 1, 1));
    expect(h.writes, 1);
    expect(h.nativeCalls, 0);
  });

  test('origin mismatch cannot send cached credentials to another ERP',
      () async {
    final h = Harness();
    await expectLater(
        h.route.send(
            method: 'GET',
            uri: Uri.parse('https://other.example/v1/mobile/me')),
        throwsArgumentError);
    expect(h.reads, 0);
    expect(h.nativeCalls, 0);
  });

  test('Bonjour only accepts pinned identity and private IPv4 socket hints',
      () {
    final pinned = config();
    for (final host in [
      'evil.example',
      '8.8.8.8',
      '127.0.0.1',
      '192.168.1.999',
      '10.0.0.1/path'
    ]) {
      expect(
          pinned.withLocalServices([
            {'server_ref': pinned.endpointId, 'host': host, 'http_port': 1234}
          ]).ticket,
          pinned.ticket);
    }
    expect(
        pinned.withLocalServices([
          {
            'server_ref': config('22').endpointId,
            'host': '192.168.1.1',
            'http_port': 80
          }
        ]).ticket,
        pinned.ticket);
    expect(
        pinned.withLocalServices([
          {
            'server_ref': pinned.endpointId,
            'host': '192.168.1.1',
            'http_port': 1234
          }
        ]).endpointId,
        pinned.endpointId);
  });

  test('LAN hint survives a VPN address being listed first', () {
    final pinned = config();
    final result = pinned.withLocalServices([
      {
        'server_ref': pinned.endpointId,
        'host': '100.88.145.52',
        'hosts': ['100.88.145.52', '192.168.0.200'],
        'http_port': 1234,
      }
    ]);
    final decoded =
        utf8.decode(base64Url.decode(base64Url.normalize(result.ticket)));
    expect(decoded, contains('192.168.0.200:1234'));
    expect(decoded, isNot(contains('100.88.145.52')));
  });
}
