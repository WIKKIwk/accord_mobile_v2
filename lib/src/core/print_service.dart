import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'godex_rps_renderer.dart';
import 'native_usb_printer.dart';
import 'zebra_rps_renderer.dart';

class PrintService {
  const PrintService._();

  static const _bridgeUrl = String.fromEnvironment(
    'ACCORD_PRINT_BRIDGE_URL',
    defaultValue: 'http://127.0.0.1:39118',
  );

  static Future<UsbRpsPrintResponse> printRps(
    UsbRpsPrintRequest request, {
    UsbPrinterProfile? printerProfile,
  }) async {
    final profile = printerProfile ?? await detectOfflinePrinter();
    final effectiveRequest = request.forPrinter(profile);
    final bytes = switch (profile.kind) {
      UsbPrinterKind.godex => GodexRpsRenderer.renderRepeated(effectiveRequest),
      UsbPrinterKind.zebra => ZebraRpsRenderer.renderRepeated(effectiveRequest),
    };
    final transport = kIsWeb
        ? await _printThroughMacBridge(bytes, profile)
        : await NativeUsbPrinter.printRaw(bytes, printerKind: profile.kind);
    return UsbRpsPrintResponse.fromMap({
      ...effectiveRequest.toJson(),
      ...transport,
      'status': transport['status'] ?? 'done',
      'ok': transport['ok'] == true,
      'mode': effectiveRequest.printMode,
      'net_qty': effectiveRequest.netQty,
      'gross_qty': effectiveRequest.grossQty,
      'printer_status': transport['printer_status'] ?? 'USB OK',
      'print_count': effectiveRequest.printCount,
      'bytes': transport['bytes'] ?? bytes.length,
    });
  }

  static Future<UsbPrinterProfile> detectOfflinePrinter() {
    return kIsWeb
        ? _detectThroughMacBridge()
        : NativeUsbPrinter.detectPrinter();
  }

  static Future<UsbRpsPrintResponse> printRpsTest(
    UsbRpsPrintRequest request,
  ) {
    return printRps(request);
  }

  static Future<Map<String, Object?>> _printThroughMacBridge(
    Uint8List bytes,
    UsbPrinterProfile profile,
  ) async {
    final response = await http.post(
      Uri.parse('$_bridgeUrl/print'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({
        'bytes_base64': base64Encode(bytes),
        'vendor_id': profile.vendorId,
        'product_id': profile.productId,
        'printer_kind': profile.printer,
      }),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['error'] : null;
      throw StateError(message?.toString() ?? 'Mac print bridge failed');
    }
    if (decoded is! Map) {
      throw StateError('Mac print bridge returned an invalid response');
    }
    return decoded.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
  }

  static Future<UsbPrinterProfile> _detectThroughMacBridge() async {
    final response = await http.get(Uri.parse('$_bridgeUrl/printer'));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['error'] : null;
      throw StateError(message?.toString() ?? 'Mac USB printer not found');
    }
    if (decoded is! Map) {
      throw StateError('Mac print bridge returned an invalid printer profile');
    }
    return UsbPrinterProfile.fromMap(
      decoded.map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      ),
    );
  }
}
