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

  static Future<UsbPrinterProfile> detectPrinter() async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'detectPrinter',
    );
    return UsbPrinterProfile.fromMap(raw ?? const {});
  }

  static Future<Map<String, Object?>> printRaw(
    Uint8List bytes, {
    required UsbPrinterKind printerKind,
  }) async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'printRaw',
      {
        'bytes': bytes,
        'print_count': 1,
        'printer_kind': printerKind.apiValue,
      },
    );
    return raw ?? const {};
  }
}

enum UsbPrinterKind {
  godex('godex'),
  zebra('zebra');

  const UsbPrinterKind(this.apiValue);

  final String apiValue;

  static UsbPrinterKind parse(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'godex':
      case 'go-dex':
      case 'g500':
        return UsbPrinterKind.godex;
      case 'zebra':
      case 'zpl':
      case 'rfid':
        return UsbPrinterKind.zebra;
      default:
        throw StateError('USB printer is neither GoDEX nor Zebra');
    }
  }
}

class UsbPrinterProfile {
  const UsbPrinterProfile({
    required this.kind,
    required this.deviceName,
    required this.vendorId,
    required this.productId,
    required this.manufacturerName,
    required this.productName,
  });

  factory UsbPrinterProfile.fromMap(Map<String, Object?> map) {
    return UsbPrinterProfile(
      kind: UsbPrinterKind.parse(map['printer']),
      deviceName: map['deviceName']?.toString() ?? '',
      vendorId: (map['vendorId'] as num?)?.toInt() ?? 0,
      productId: (map['productId'] as num?)?.toInt() ?? 0,
      manufacturerName: map['manufacturerName']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
    );
  }

  final UsbPrinterKind kind;
  final String deviceName;
  final int vendorId;
  final int productId;
  final String manufacturerName;
  final String productName;

  String get printer => kind.apiValue;
  String get printMode => kind == UsbPrinterKind.zebra ? 'rfid' : 'label';
  bool get supportsRfid => kind == UsbPrinterKind.zebra;

  String get displayName {
    final model = productName.trim();
    final brand = kind == UsbPrinterKind.zebra ? 'Zebra' : 'GoDEX';
    return model.isEmpty ? brand : '$brand • $model';
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
    this.labelKind = '',
    this.executorName = '',
    this.progressQty,
    this.progressUnit = '',
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

  factory UsbRpsPrintRequest.fromPrintJson(Map<String, dynamic> json) {
    final executorName = json['executor_name']?.toString().trim() ?? '';
    final grossQty = (json['gross_qty'] as num?)?.toDouble() ??
        (json['qty'] as num?)?.toDouble() ??
        0;
    return UsbRpsPrintRequest(
      epc: (json['epc'] ?? json['qr_payload'])?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      warehouse: json['warehouse']?.toString() ??
          (executorName.isEmpty ? 'ACCORD' : 'Ijrochi: $executorName'),
      printer: json['printer']?.toString() ?? 'godex',
      printMode: (json['print_mode'] ?? json['mode'])?.toString() ?? 'label',
      grossQty: grossQty,
      unit: json['unit']?.toString() ?? 'kg',
      tareEnabled: json['tare_enabled'] == true || json['tare'] == true,
      tareKg: (json['tare_kg'] as num?)?.toDouble() ?? 0,
      printCount: (json['print_count'] as num?)?.toInt() ?? 1,
      labelKind: json['label_kind']?.toString() ?? '',
      executorName: executorName,
      progressQty: (json['progress_qty'] as num?)?.toDouble() ??
          (json['qty'] as num?)?.toDouble(),
      progressUnit: json['progress_unit']?.toString() ?? '',
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
  final String labelKind;
  final String executorName;
  final double? progressQty;
  final String progressUnit;

  double get netQty => (grossQty - tareKg).clamp(0, double.infinity).toDouble();

  bool get isProgressLabel => labelKind.trim().toLowerCase() == 'progress';

  bool get isQolipCellLabel {
    final kind = labelKind.trim().toLowerCase();
    return kind == 'qolip_cell' || kind == 'qr_center';
  }

  bool get isQolipCodeLabel => labelKind.trim().toLowerCase() == 'qolip_code';

  double get effectiveProgressQty => progressQty ?? netQty;

  UsbRpsPrintRequest forPrinter(UsbPrinterProfile profile) {
    return UsbRpsPrintRequest(
      epc: epc,
      itemCode: itemCode,
      itemName: itemName,
      warehouse: warehouse,
      printer: profile.printer,
      printMode: profile.printMode,
      grossQty: grossQty,
      unit: unit,
      tareEnabled: tareEnabled,
      tareKg: tareKg,
      printCount: printCount,
      labelKind: labelKind,
      executorName: executorName,
      progressQty: progressQty,
      progressUnit: progressUnit,
    );
  }

  UsbRpsPrintRequest forQolipCell(String cellLabel) {
    return UsbRpsPrintRequest(
      epc: epc,
      itemCode: itemCode,
      itemName: cellLabel.trim(),
      warehouse: warehouse,
      printer: printer,
      printMode: printMode,
      grossQty: grossQty,
      unit: unit,
      tareEnabled: tareEnabled,
      tareKg: tareKg,
      printCount: printCount,
      labelKind: 'qolip_cell',
      executorName: executorName,
      progressQty: progressQty,
      progressUnit: progressUnit,
    );
  }

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
      if (labelKind.trim().isNotEmpty)
        'label_kind': labelKind.trim().toLowerCase(),
      if (executorName.trim().isNotEmpty) 'executor_name': executorName.trim(),
      if (progressQty != null) 'progress_qty': progressQty!,
      if (progressUnit.trim().isNotEmpty) 'progress_unit': progressUnit.trim(),
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
