import 'package:flutter/services.dart';

import '../features/shared/models/app_models.dart';

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
    List<String> godexGraphicNames = const [],
    int labelCount = 1,
  }) async {
    final raw = await _channel.invokeMapMethod<String, Object?>(
      'printRaw',
      {
        'bytes': bytes,
        'print_count': 1,
        'printer_kind': printerKind.apiValue,
        'godex_graphic_names': godexGraphicNames,
        'label_count': labelCount > 0 ? labelCount : 1,
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
    this.apparatus = '',
    this.apparatusDisplayName = '',
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
    this.customerName = '',
    this.qolipColor = '',
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
    final apparatus = json['apparatus']?.toString().trim() ?? '';
    if (apparatus.isNotEmpty && !canonicalApparatusIdIsValid(apparatus)) {
      throw const FormatException('Canonical apparatus ID is required');
    }
    final grossQty = (json['gross_qty'] as num?)?.toDouble() ??
        (json['qty'] as num?)?.toDouble() ??
        0;
    return UsbRpsPrintRequest(
      epc: (json['epc'] ?? json['qr_payload'])?.toString() ?? '',
      itemCode: json['item_code']?.toString() ?? '',
      itemName: json['item_name']?.toString() ?? '',
      apparatus: apparatus,
      apparatusDisplayName:
          json['apparatus_display_name']?.toString().trim() ?? '',
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
      customerName: json['customer_name']?.toString() ?? '',
      qolipColor: json['qolip_color']?.toString() ?? '',
      progressQty: (json['progress_qty'] as num?)?.toDouble() ??
          (json['qty'] as num?)?.toDouble(),
      progressUnit: json['progress_unit']?.toString() ?? '',
    );
  }

  final String epc;
  final String itemCode;
  final String itemName;
  final String apparatus;
  final String apparatusDisplayName;
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
  final String customerName;
  final String qolipColor;
  final double? progressQty;
  final String progressUnit;

  double get netQty => (grossQty - tareKg).clamp(0, double.infinity).toDouble();

  bool get isProgressLabel => labelKind.trim().toLowerCase() == 'progress';

  bool get isQolipCellLabel {
    final kind = labelKind.trim().toLowerCase();
    return kind == 'qolip_cell' || kind == 'qr_center';
  }

  bool get isQolipCodeLabel => labelKind.trim().toLowerCase() == 'qolip_code';

  bool get isPaddonCodeLabel => labelKind.trim().toLowerCase() == 'paddon_code';

  bool get isMaterialProductLabel =>
      labelKind.trim().toLowerCase() == 'material_product';

  String get materialProductLabelTitle {
    final name = itemName.trim().isEmpty ? itemCode.trim() : itemName.trim();
    final normalizedUnit = unit.trim().isEmpty ? 'kg' : unit.trim();
    final net = _compactPrintQty(netQty);
    if (tareEnabled && tareKg > 0) {
      return '$name  B:${_compactPrintQty(grossQty)} $normalizedUnit '
          'N:$net $normalizedUnit';
    }
    return '$name  $net $normalizedUnit';
  }

  String largeQrLabelFooter(String qrPayload) {
    final payload = qrPayload.trim();
    if (isMaterialProductLabel) {
      return 'EPC: $payload';
    }
    if (isQolipCodeLabel && payload.toUpperCase().startsWith('RPS-BATCH:')) {
      return 'BATCH ID: ${payload.substring('RPS-BATCH:'.length)}';
    }
    return itemCode.trim().isEmpty ? payload : itemCode.trim();
  }

  double get effectiveProgressQty => progressQty ?? netQty;

  UsbRpsPrintRequest forPrinter(UsbPrinterProfile profile) {
    return UsbRpsPrintRequest(
      epc: epc,
      itemCode: itemCode,
      itemName: itemName,
      apparatus: apparatus,
      apparatusDisplayName: apparatusDisplayName,
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
      customerName: customerName,
      qolipColor: qolipColor,
      progressQty: progressQty,
      progressUnit: progressUnit,
    );
  }

  UsbRpsPrintRequest forQolipCell(String cellLabel) {
    return UsbRpsPrintRequest(
      epc: epc,
      itemCode: itemCode,
      itemName: cellLabel.trim(),
      apparatus: apparatus,
      apparatusDisplayName: apparatusDisplayName,
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
      customerName: customerName,
      qolipColor: qolipColor,
      progressQty: progressQty,
      progressUnit: progressUnit,
    );
  }

  UsbRpsPrintRequest forQolipCode({
    required String name,
    required String code,
    required String payload,
    String customerName = '',
    String qolipColor = '',
  }) {
    return UsbRpsPrintRequest(
      epc: payload.trim(),
      itemCode: code.trim(),
      itemName: name.trim(),
      apparatus: apparatus,
      apparatusDisplayName: apparatusDisplayName,
      warehouse: warehouse,
      printer: printer,
      printMode: printMode,
      grossQty: grossQty,
      unit: unit,
      tareEnabled: tareEnabled,
      tareKg: tareKg,
      printCount: printCount,
      labelKind: 'qolip_code',
      executorName: executorName,
      customerName:
          customerName.trim().isEmpty ? this.customerName : customerName.trim(),
      qolipColor:
          qolipColor.trim().isEmpty ? this.qolipColor : qolipColor.trim(),
      progressQty: progressQty,
      progressUnit: progressUnit,
    );
  }

  Map<String, Object> toJson() {
    return {
      'epc': _cleanEpc(epc),
      'item_code': _cleanText(itemCode, fallback: 'USB-TEST'),
      'item_name': _cleanText(itemName, fallback: 'USB printer test'),
      if (apparatus.trim().isNotEmpty)
        'apparatus': _cleanText(apparatus, fallback: ''),
      if (apparatusDisplayName.trim().isNotEmpty)
        'apparatus_display_name':
            _cleanText(apparatusDisplayName, fallback: ''),
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
      if (customerName.trim().isNotEmpty)
        'customer_name': _cleanText(customerName, fallback: ''),
      if (qolipColor.trim().isNotEmpty)
        'qolip_color': _cleanText(qolipColor, fallback: ''),
      if (progressQty != null) 'progress_qty': progressQty!,
      if (progressUnit.trim().isNotEmpty) 'progress_unit': progressUnit.trim(),
    };
  }
}

String _compactPrintQty(double value) {
  var text = value.toStringAsFixed(3);
  while (text.contains('.') && text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
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

String qolipColorDisplayName(String value) {
  final normalized = value.trim().replaceFirst('#', '').toUpperCase();
  const defaultColorNames = <String, String>{
    'E53935': 'Qizil',
    'FB8C00': 'To‘q sariq',
    'FDD835': 'Sariq',
    '43A047': 'Yashil',
    '00ACC1': 'Moviy',
    '1E88E5': 'Ko‘k',
    '3949AB': 'To‘q ko‘k',
    '8E24AA': 'Binafsha',
    'D81B60': 'Pushti',
    '6D4C41': 'Jigarrang',
    'D4A72C': 'Tilla',
    '757575': 'Kulrang',
    'B7BCC2': 'Matlak',
    '212121': 'Qora',
    'FFFFFF': 'Oq',
  };
  return defaultColorNames[normalized] ?? value.trim();
}
