import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final host = Platform.environment['ACCORD_PRINT_BRIDGE_HOST'] ?? '127.0.0.1';
  final port = int.tryParse(
        Platform.environment['ACCORD_PRINT_BRIDGE_PORT'] ?? '39118',
      ) ??
      39118;
  final helper = Platform.environment['ACCORD_MAC_USB_HELPER'] ??
      '${Directory.current.path}/garbage/accord_mac_usb_raw_write';

  final server = await HttpServer.bind(host, port);
  stdout.writeln('Accord Mac print bridge listening on http://$host:$port');
  stdout.writeln('USB helper: $helper');

  await for (final request in server) {
    await _handle(request, helper);
  }
}

Future<void> _handle(HttpRequest request, String helper) async {
  request.response.headers
    ..set('access-control-allow-origin', '*')
    ..set('access-control-allow-headers', 'content-type')
    ..set('access-control-allow-methods', 'GET,POST,OPTIONS');

  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }
  if (request.method == 'GET' && request.uri.path == '/healthz') {
    await _json(request, HttpStatus.ok, const {
      'ok': true,
      'service': 'accord_mac_print_bridge',
      'version': 2,
    });
    return;
  }
  if (request.method == 'GET' && request.uri.path == '/printer') {
    await _printer(request, helper);
    return;
  }
  if (request.method == 'POST' && request.uri.path == '/print') {
    await _print(request, helper);
    return;
  }
  await _json(request, HttpStatus.notFound, const {'error': 'route_not_found'});
}

Future<void> _printer(HttpRequest request, String helper) async {
  try {
    final result = await Process.run(helper, const ['--detect']);
    if (result.exitCode != 0) {
      final diagnostic = [result.stdout, result.stderr]
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .join('\n');
      throw StateError(
        diagnostic.isEmpty ? 'USB printer not found' : diagnostic,
      );
    }
    final fields = result.stdout.toString().trim().split(RegExp(r'\s+'));
    if (fields.length != 3) {
      throw const FormatException('USB helper returned an invalid profile');
    }
    final kind = fields[0].trim().toLowerCase();
    final vendorId = int.parse(fields[1], radix: 16);
    final productId = int.parse(fields[2], radix: 16);
    await _json(request, HttpStatus.ok, {
      'ok': true,
      'printer': kind,
      'print_mode': kind == 'zebra' ? 'rfid' : 'label',
      'rfid_epc_write': kind == 'zebra',
      'deviceName': 'macOS USB',
      'vendorId': vendorId,
      'productId': productId,
      'manufacturerName': kind == 'zebra' ? 'Zebra' : 'GoDEX',
      'productName': '',
    });
  } catch (error) {
    await _json(request, HttpStatus.notFound, {
      'ok': false,
      'error': error.toString(),
    });
  }
}

Future<void> _print(HttpRequest request, String helper) async {
  try {
    final body = await utf8.decoder.bind(request).join();
    final payload = jsonDecode(body);
    if (payload is! Map) {
      throw const FormatException('JSON object is required');
    }
    final encoded = payload['bytes_base64']?.toString() ?? '';
    if (encoded.isEmpty) throw const FormatException('bytes_base64 is empty');
    final bytes = base64Decode(encoded);
    if (bytes.isEmpty) throw const FormatException('print payload is empty');

    final vendorId = _number(payload['vendor_id'], 0x195f);
    final productId = _number(payload['product_id'], 0x0001);
    final printerKind = payload['printer_kind']?.toString().trim() ?? '';
    final tempDir = await Directory.systemTemp.createTemp('accord-print-');
    final payloadFile = File('${tempDir.path}/payload.bin');
    try {
      await payloadFile.writeAsBytes(bytes, flush: true);
      final result = await Process.run(
        helper,
        [
          vendorId.toRadixString(16),
          productId.toRadixString(16),
          payloadFile.path
        ],
      );
      if (result.exitCode != 0) {
        final diagnostic = [result.stdout, result.stderr]
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .join('\n');
        throw StateError(
          diagnostic.isEmpty
              ? 'USB helper failed with exit code ${result.exitCode}'
              : diagnostic,
        );
      }
    } finally {
      await tempDir.delete(recursive: true);
    }
    await _json(request, HttpStatus.ok, {
      'ok': true,
      'status': 'done',
      'printer_status': 'USB OK',
      'bytes': bytes.length,
      'vendorId': vendorId,
      'productId': productId,
      'printer': printerKind,
    });
  } catch (error) {
    await _json(request, HttpStatus.badGateway, {
      'ok': false,
      'status': 'error',
      'error': error.toString(),
    });
  }
}

int _number(Object? value, int fallback) {
  if (value is num && value.isFinite) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

Future<void> _json(
  HttpRequest request,
  int statusCode,
  Map<String, Object?> body,
) async {
  request.response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body));
  await request.response.close();
}
