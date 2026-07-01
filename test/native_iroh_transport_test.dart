import 'package:accord_mobile_v2/src/core/native_iroh_transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      '{"ticket":" abc-123 ","source":"file"}',
    );

    expect(response.ticket, 'abc-123');
  });

  test('rejects blank ticket discovery response', () {
    expect(
      () => IrohTicketDiscoveryResponse.fromBody('{"ticket":"  "}'),
      throwsFormatException,
    );
  });
}
