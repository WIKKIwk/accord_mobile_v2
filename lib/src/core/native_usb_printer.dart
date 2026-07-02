import 'package:flutter/services.dart';

class NativeUsbPrinter {
  const NativeUsbPrinter._();

  static const MethodChannel _channel = MethodChannel('accord/usb_printer');

  static Future<UsbPrinterTestResult> printTest({
    required String title,
    required String payload,
  }) async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'printTest',
      {
        'title': title,
        'payload': payload,
      },
    );
    return UsbPrinterTestResult.fromMap(raw ?? const {});
  }

  static Future<UsbRpsPrintResponse> printRpsTest(
    UsbRpsPrintRequest request,
  ) async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'printRpsTest',
      request.toJson(),
    );
    return UsbRpsPrintResponse.fromMap(raw ?? const {});
  }
}

class UsbPrinterTestResult {
  const UsbPrinterTestResult({
    required this.ok,
    required this.bytes,
    required this.deviceName,
    required this.vendorId,
    required this.productId,
  });

  final bool ok;
  final int bytes;
  final String deviceName;
  final int vendorId;
  final int productId;

  factory UsbPrinterTestResult.fromMap(Map<String, Object?> map) {
    return UsbPrinterTestResult(
      ok: map['ok'] == true,
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
      deviceName: map['deviceName']?.toString() ?? '',
      vendorId: (map['vendorId'] as num?)?.toInt() ?? 0,
      productId: (map['productId'] as num?)?.toInt() ?? 0,
    );
  }
}

class UsbRpsPrintRequest {
  const UsbRpsPrintRequest({
    required this.epc,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.printer,
    required this.printMode,
    required this.grossQty,
    this.unit = 'kg',
    this.tareEnabled = false,
    this.tareKg = 0,
    this.printCount = 1,
  });

  factory UsbRpsPrintRequest.test({required String epc}) {
    return UsbRpsPrintRequest(
      epc: epc,
      itemCode: 'USB-TEST',
      itemName: 'USB printer test',
      warehouse: 'RPS USB TEST',
      printer: 'godex',
      printMode: 'label',
      grossQty: 1,
    );
  }

  final String epc;
  final String itemCode;
  final String itemName;
  final String warehouse;
  final String printer;
  final String printMode;
  final double grossQty;
  final String unit;
  final bool tareEnabled;
  final double tareKg;
  final int printCount;

  Map<String, Object> toJson() {
    return {
      'epc': _cleanEpc(epc),
      'item_code': _cleanText(itemCode, fallback: 'USB-TEST'),
      'item_name': _cleanText(itemName, fallback: 'USB printer test'),
      'warehouse': _cleanText(warehouse, fallback: 'RPS USB TEST'),
      'printer': _cleanText(printer, fallback: 'godex').toLowerCase(),
      'print_mode': _cleanText(printMode, fallback: 'label').toLowerCase(),
      'gross_qty': grossQty.isFinite && grossQty > 0 ? grossQty : 1.0,
      'unit': _cleanText(unit, fallback: 'kg').toLowerCase(),
      'tare_enabled': tareEnabled || tareKg > 0,
      'tare_kg': tareKg.isFinite && tareKg > 0 ? tareKg : 0.0,
      'print_count': printCount > 1 ? printCount : 1,
    };
  }
}

class UsbRpsPrintResponse {
  const UsbRpsPrintResponse({
    required this.ok,
    required this.status,
    required this.epc,
    required this.itemCode,
    required this.itemName,
    required this.warehouse,
    required this.printer,
    required this.mode,
    required this.grossQty,
    required this.netQty,
    required this.unit,
    required this.printerStatus,
    required this.printCount,
    required this.bytes,
    required this.deviceName,
    required this.vendorId,
    required this.productId,
  });

  final bool ok;
  final String status;
  final String epc;
  final String itemCode;
  final String itemName;
  final String warehouse;
  final String printer;
  final String mode;
  final double grossQty;
  final double netQty;
  final String unit;
  final String printerStatus;
  final int printCount;
  final int bytes;
  final String deviceName;
  final int vendorId;
  final int productId;

  factory UsbRpsPrintResponse.fromMap(Map<String, Object?> map) {
    return UsbRpsPrintResponse(
      ok: map['ok'] == true,
      status: map['status']?.toString() ?? '',
      epc: map['epc']?.toString() ?? '',
      itemCode: map['item_code']?.toString() ?? '',
      itemName: map['item_name']?.toString() ?? '',
      warehouse: map['warehouse']?.toString() ?? '',
      printer: map['printer']?.toString() ?? '',
      mode: map['mode']?.toString() ?? '',
      grossQty: (map['gross_qty'] as num?)?.toDouble() ?? 0,
      netQty: (map['net_qty'] as num?)?.toDouble() ?? 0,
      unit: map['unit']?.toString() ?? '',
      printerStatus: map['printer_status']?.toString() ?? '',
      printCount: (map['print_count'] as num?)?.toInt() ?? 1,
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
      deviceName: map['deviceName']?.toString() ?? '',
      vendorId: (map['vendorId'] as num?)?.toInt() ?? 0,
      productId: (map['productId'] as num?)?.toInt() ?? 0,
    );
  }
}

String _cleanEpc(String value) {
  final text = value.trim().toUpperCase();
  return text.isEmpty ? 'RPS-USB-TEST' : text;
}

String _cleanText(String value, {required String fallback}) {
  final text = value.trim();
  return text.isEmpty ? fallback : text;
}
