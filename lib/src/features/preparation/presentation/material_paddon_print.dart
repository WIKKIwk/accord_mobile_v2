import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/mobile_api.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_service.dart';
import '../../../core/print_transport.dart';
import '../../admin/presentation/progress_printer_picker.dart';
import '../models/preparation_models.dart';

UsbRpsPrintRequest materialPaddonPrintRequest(
  PreparationMaterialPaddon paddon,
  ProgressPrinterOption printer,
) =>
    _qrLabel(
      printer,
      payload: paddon.qrPayload,
      code: paddon.code,
      warehouse: paddon.warehouse,
      lines: [paddon.title],
    );

UsbRpsPrintRequest materialPaddonUnitPrintRequest(
  PreparationPaddonIssue issue,
  PreparationPaddonLabel unit,
  ProgressPrinterOption printer,
) {
  final kg = double.parse(unit.kg);
  if (!printer.transport.isBluetooth) {
    return _qrLabel(
      printer,
      payload: unit.barcode,
      code: unit.barcode,
      warehouse: issue.labelWarehouse,
      lines: [
        '${preparationDisplay(unit.kg)} kg',
        [
          unit.itemName,
          if (unit.widthMm case final width?) '${preparationDisplay(width)} mm',
          if (unit.micron case final micron?) '${preparationDisplay(micron)} mkm',
        ].join(' - '),
        if (unit.lotNumber.isNotEmpty) 'Partiya: ${unit.lotNumber}',
      ],
      kg: kg,
    );
  }

  final dimensions = switch ((unit.widthMm, unit.micron)) {
    (final width?, final micron?) =>
      '${preparationDisplay(width)}/${preparationDisplay(micron)}',
    (final width?, null) => '${preparationDisplay(width)} mm',
    (null, final micron?) => '${preparationDisplay(micron)} mkm',
    (null, null) => '',
  };
  final name = unit.itemName.trim();
  final itemName = dimensions.isEmpty || name.endsWith(' $dimensions')
      ? name
      : '$name $dimensions';
  return UsbRpsPrintRequest(
    epc: unit.barcode,
    itemCode: unit.itemCode,
    itemName: itemName,
    warehouse: issue.labelWarehouse,
    printer: printer.printer,
    printMode: 'label',
    grossQty: kg,
    labelKind: 'material_product',
    materialLotNumber: unit.lotNumber,
  );
}

UsbRpsPrintRequest _qrLabel(
  ProgressPrinterOption printer, {
  required String payload,
  required String code,
  required String warehouse,
  required List<String> lines,
  double kg = 1,
}) =>
    UsbRpsPrintRequest(
      epc: payload,
      itemCode: code,
      itemName: lines.join(' - '),
      warehouse: warehouse,
      printer: printer.printer,
      printMode: 'label',
      grossQty: kg,
      // The pallet and non-Bluetooth issue labels accept textual identifiers.
      labelKind: 'paddon_code',
      paddonLabelLines: lines,
    );

Future<void> printMaterialPaddonQr(
  ProgressPrinterOption printer,
  UsbRpsPrintRequest request,
) async {
  if (printer.transport.isLocal) {
    final result = await PrintService.printRps(
      request,
      printerProfile: printer.offlinePrinter,
      bluetoothPrinter: printer.bluetoothPrinter,
      transport: printer.transport,
      bluetoothQrCode: request.isPaddonCodeLabel,
    );
    if (result.ok) return;
  } else {
    final server = printer.server;
    if (server == null) throw StateError('Printer serveri tanlanmadi');
    final response = await http
        .post(
          Uri.parse('${server.endpoint.baseUrl}/v1/mobile/driver/print'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(request.toJson()),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final payload = jsonDecode(response.body);
      if (payload is Map && payload['ok'] == true) return;
    }
  }
  throw StateError('QR yorliq chop etilmadi');
}
