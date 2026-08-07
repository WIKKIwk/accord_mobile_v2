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
        ..._bluetoothLabelPayload(request),
        'mac_address': printer.address,
      },
    );
    return raw ?? const {};
  }
}

Map<String, Object> _bluetoothLabelPayload(UsbRpsPrintRequest request) {
  final payload = request.toJson();
  for (final key in const <String>[
    'item_code',
    'item_name',
    'apparatus',
    'warehouse',
    'unit',
    'executor_name',
    'customer_name',
    'qolip_color',
    'progress_unit',
  ]) {
    final value = payload[key];
    if (value is String) {
      final displayValue =
          key == 'qolip_color' ? qolipColorDisplayName(value) : value;
      payload[key] = bluetoothPrinterText(displayValue);
    }
  }
  return payload;
}

/// XP-P323B's built-in TSPL fonts are ASCII-oriented. Keep the Bluetooth
/// payload printable even when the source item name is Uzbek Cyrillic.
String bluetoothPrinterText(String value) {
  final normalized = value
      .replaceAll('‘', "'")
      .replaceAll('’', "'")
      .replaceAll('ʼ', "'")
      .replaceAll('ʻ', "'")
      .replaceAll('`', "'")
      .replaceAll('"', "'")
      .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
      .trim()
      .toUpperCase();
  final out = StringBuffer();
  for (final rune in normalized.runes) {
    final character = String.fromCharCode(rune);
    out.write(switch (character) {
      'А' => 'A',
      'Б' => 'B',
      'В' => 'V',
      'Г' => 'G',
      'Ғ' => "G'",
      'Д' => 'D',
      'Е' => 'E',
      'Ё' => 'YO',
      'Ж' => 'J',
      'З' => 'Z',
      'И' => 'I',
      'Й' => 'Y',
      'К' => 'K',
      'Қ' => 'Q',
      'Л' => 'L',
      'М' => 'M',
      'Н' => 'N',
      'О' => 'O',
      'П' => 'P',
      'Р' => 'R',
      'С' => 'S',
      'Т' => 'T',
      'У' => 'U',
      'Ў' => "O'",
      'Ф' => 'F',
      'Х' => 'X',
      'Ҳ' => 'H',
      'Ц' => 'TS',
      'Ч' => 'CH',
      'Ш' => 'SH',
      'Щ' => 'SHCH',
      'Ъ' || 'Ь' => '',
      'Ы' => 'Y',
      'Э' => 'E',
      'Ю' => 'YU',
      'Я' => 'YA',
      'Ә' => 'A',
      'Ҷ' => 'J',
      'Җ' => 'J',
      'Ҡ' => 'Q',
      'Ң' => 'N',
      'Ө' => 'O',
      'Ү' || 'Ұ' => 'U',
      'Һ' => 'H',
      'І' || 'Ї' => 'I',
      'Є' => 'E',
      'Ґ' => 'G',
      'Ӣ' => 'I',
      'Ӯ' => 'U',
      _ => rune >= 0x20 && rune <= 0x7e ? character : '?',
    });
  }
  return out.toString().replaceAll(RegExp(r'\s+'), ' ');
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
