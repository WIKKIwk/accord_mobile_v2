import 'package:flutter/services.dart';

import 'native_usb_printer.dart';

class NativeBluetoothPrinter {
  const NativeBluetoothPrinter._();

  static const MethodChannel _channel = MethodChannel(
    'accord/bluetooth_printer',
  );
  static const EventChannel _discoveryChannel = EventChannel(
    'accord/bluetooth_printer/discovery',
  );
  static int _discoverySession = 0;

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

  static Stream<BluetoothPrinterScanEvent> discoverPrinters() {
    final session = ++_discoverySession;
    return _discoveryChannel.receiveBroadcastStream(session).map(
          BluetoothPrinterScanEvent.fromMap,
        );
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

class BluetoothPrinterScanEvent {
  const BluetoothPrinterScanEvent({this.printer, this.completed = false});

  const BluetoothPrinterScanEvent.completed()
      : printer = null,
        completed = true;

  final BluetoothPrinterProfile? printer;
  final bool completed;

  factory BluetoothPrinterScanEvent.fromMap(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('Bluetooth printer scan event is invalid');
    }
    final map = raw.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
    if (map['type']?.toString() == 'complete') {
      return const BluetoothPrinterScanEvent.completed();
    }
    if (map['type']?.toString() == 'printer') {
      return BluetoothPrinterScanEvent(
        printer: BluetoothPrinterProfile.fromMap(map),
      );
    }
    throw const FormatException('Bluetooth printer scan event type is invalid');
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
