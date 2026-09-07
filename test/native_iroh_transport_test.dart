import 'package:accord_mobile_v2/src/core/native_iroh_transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('accord/iroh_transport');
  for (final method in ['POST', 'PUT', 'PATCH', 'DELETE']) {
    test('native $method failure is not silently replayed', () async {
      SharedPreferences.setMockInitialValues(
          {'iroh_endpoint_ticket': 'test-ticket'});
      var requests = 0;
      var resets = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'isSupported') return true;
        if (call.method == 'reset') {
          resets++;
          return null;
        }
        if (call.method == 'request') {
          requests++;
          throw PlatformException(code: 'reply_lost_after_commit');
        }
        return null;
      });
      try {
        await expectLater(
            NativeIrohTransport.send(
                method: method,
                uri: Uri.parse('https://test.invalid/queue-action'),
                body: '{}'),
            throwsA(isA<PlatformException>()));
        expect(requests, 1);
        expect(resets, 0);
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  }
  test('native GET still rediscovers and retries a failed read once', () async {
    SharedPreferences.setMockInitialValues(
        {'iroh_endpoint_ticket': 'test-ticket'});
    var requests = 0;
    var resets = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isSupported') return true;
      if (call.method == 'reset') {
        resets++;
        return null;
      }
      if (call.method == 'request') {
        if (++requests == 1) throw PlatformException(code: 'stale_endpoint');
        return {
          'statusCode': 200,
          'body': <int>[],
          'headers': <String, String>{}
        };
      }
      return null;
    });
    try {
      final response = await NativeIrohTransport.send(
          method: 'GET', uri: Uri.parse('https://test.invalid/sequence'));
      expect(response.statusCode, 200);
      expect(requests, 2);
      expect(resets, 1);
    } finally {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });
  test('does not enable native iroh transport by default', () {
    expect(NativeIrohTransport.endpointTicketFromEnvironment, isEmpty);
    expect(NativeIrohTransport.endpointTicketDiscoveryUrl, isEmpty);
    expect(NativeIrohTransport.hasEndpointTicket, isFalse);
  });

  test('parses native health check result', () {
    final result = IrohHealthCheckResult.fromMap({
      'ok': true,
      'statusCode': 200,
      'runs': 3,
      'bytes': 324,
      'totalMs': 12.5,
      'pathInfo': 'direct 192.168.0.10:1234 8ms',
    });

    expect(result.ok, isTrue);
    expect(result.statusCode, 200);
    expect(result.runs, 3);
    expect(result.bytes, 324);
    expect(result.totalMs, 12.5);
    expect(result.pathInfo, 'direct 192.168.0.10:1234 8ms');
  });

  test('formats native iroh platform errors', () {
    final error = PlatformException(
      code: 'iroh_invalid_ticket',
      message: 'Ticket xato',
    );

    expect(irohTransportErrorText(error), 'Iroh ticket xato');
  });

  test('parses ticket discovery response', () {
    final response = IrohTicketDiscoveryResponse.fromBody(
      '{"ticket":" abc-123 ","source":"file","supports_connection_reuse":true}',
    );

    expect(response.ticket, 'abc-123');
    expect(response.supportsConnectionReuse, isTrue);
  });

  test('defaults ticket discovery connection reuse to false', () {
    final response = IrohTicketDiscoveryResponse.fromBody(
      '{"ticket":" abc-123 ","source":"file"}',
    );

    expect(response.supportsConnectionReuse, isFalse);
  });

  test('rejects blank ticket discovery response', () {
    expect(
      () => IrohTicketDiscoveryResponse.fromBody('{"ticket":"  "}'),
      throwsFormatException,
    );
  });
}
