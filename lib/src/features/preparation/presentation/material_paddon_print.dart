import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/api/mobile_api.dart';
import '../../../core/native_usb_printer.dart';
import '../../../core/print_service.dart';
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
) =>
    _qrLabel(
      printer,
      payload: unit.barcode,
      code: unit.barcode,
      warehouse: issue.labelWarehouse,
      lines: [
        '${preparationDisplay(unit.kg)} kg',
        [
          unit.itemName,
          if (unit.widthMm != null) '${preparationDisplay(unit.widthMm!)} mm',
          if (unit.micron != null) '${preparationDisplay(unit.micron!)} mkm'
        ].join(' • '),
        if (unit.lotNumber.isNotEmpty) 'Partiya: ${unit.lotNumber}',
      ],
      kg: double.parse(unit.kg),
    );

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
      itemName: lines.join(' • '),
      warehouse: warehouse,
      printer: printer.printer,
      printMode: 'label',
      grossQty: kg,
      // The QR-only layout supports both standard EPCs and the existing
      // PREP-PADDON unit identifiers, as well as the typed parent payload.
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
      bluetoothQrCode: true,
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
