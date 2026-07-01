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
