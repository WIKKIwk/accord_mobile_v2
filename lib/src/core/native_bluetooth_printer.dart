import 'package:flutter/services.dart';

import 'native_usb_printer.dart';

class NativeBluetoothPrinter {
  const NativeBluetoothPrinter._();

  static const MethodChannel _channel = MethodChannel(
    'accord/bluetooth_printer',
  );

  static Future<List<BluetoothPrinterProfile>> pairedPrinters() async {
    final raw = await _channel.invokeListMethod<Object?>('pairedPrinters');
    return [
      for (final entry in raw ?? const <Object?>[])
        if (entry is Map)
          BluetoothPrinterProfile.fromMap(
            entry.map<String, Object?>(
              (key, value) => MapEntry(key.toString(), value),
            ),
          ),
    ];
  }

  static Future<Map<String, Object?>> printLabel(
    UsbRpsPrintRequest request, {
    required BluetoothPrinterProfile printer,
  }) async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'printLabel',
      {
        ...request.toJson(),
        'mac_address': printer.address,
      },
    );
    return raw ?? const {};
  }
}

class BluetoothPrinterProfile {
  const BluetoothPrinterProfile({
    required this.name,
    required this.address,
  });

  factory BluetoothPrinterProfile.fromMap(Map<String, Object?> map) {
    return BluetoothPrinterProfile(
      name: map['name']?.toString().trim() ?? '',
      address: map['address']?.toString().trim() ?? '',
    );
  }

  final String name;
  final String address;

  String get printer => 'xp-p323b';
  String get printMode => 'label';

  String get displayName {
    final cleanName = name.trim();
    return cleanName.isEmpty ? 'XP-P323B' : cleanName;
  }
}
