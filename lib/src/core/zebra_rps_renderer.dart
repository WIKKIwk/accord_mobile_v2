import 'dart:convert';
import 'dart:typed_data';

import 'native_usb_printer.dart';

/// Produces the Zebra ZPL stream used by r-ps_core.
class ZebraRpsRenderer {
  const ZebraRpsRenderer._();

  static Uint8List render(UsbRpsPrintRequest request) {
    if (request.isQolipCellLabel) {
      return _renderQolipCell(request);
    }
    if (request.isQolipCodeLabel ||
        request.isPaddonCodeLabel ||
        request.isMaterialProductLabel) {
      return _renderQolipCode(request);
    }
    final epc = _normalizeEpc(request.epc);
    final unit = request.unit.trim().isEmpty ? 'kg' : request.unit.trim();
    final item = _sanitize(
      request.itemName.trim().isEmpty ? request.itemCode : request.itemName,
      fallback: '-',
    );
    final hasTare = request.tareEnabled && request.tareKg > 0;
    final net = '${_rounded(request.netQty)} $unit';
    final gross = '${_rounded(request.grossQty)} $unit';
    final weightBlock = hasTare
        ? '^FO8,112^A0N,36,32\n'
            '^FDNETTO: $net^FS\n'
            '^FO8,158^A0N,36,32\n'
            '^FDBRUTTO: $gross^FS\n'
        : '^FO8,118^A0N,44,38\n^FDVAZNI: $gross^FS\n';
    final epcY = hasTare ? 220 : 184;
    final barcodeY = hasTare ? 272 : 236;
    final rfidBlock = request.printMode.trim().toLowerCase() == 'rfid'
        ? '^RS8,,,1,N\n^RFW,H,,,A^FD$epc^FS\n'
        : '^MMT\n';
    final zpl = '~PS\n'
        '^XA\n'
        '^LH0,0\n'
        '$rfidBlock'
        '^FO8,52^A0N,38,32^FB760,1,0,L,0\n'
        '^FDMAHSULOT: $item^FS\n'
        '$weightBlock'
        '^FO8,$epcY^A0N,24,20^FB760,1,0,L,0\n'
        '^FDEPC: $epc^FS\n'
        '^FO8,$barcodeY^BY3,2,44^BCN,44,N,N,N\n'
        '^FD$epc^FS\n'
        '^PQ1\n'
        '^XZ\n';
    return Uint8List.fromList(utf8.encode(zpl));
  }

  static Uint8List _renderQolipCell(UsbRpsPrintRequest request) {
    final payload = _sanitize(request.epc, fallback: '-');
    final cellName = _sanitize(
      request.itemName.trim().isEmpty ? request.itemCode : request.itemName,
      fallback: '-',
    );
    final zpl = '~PS\n'
        '^XA\n'
        '^LH0,0\n'
        '^FO8,16^A0N,88,76^FB784,1,0,C,0\n'
        '^FD$cellName^FS\n'
        '^FO120,124^BQN,2,11^FDLA,$payload^FS\n'
        '^PQ1\n'
        '^XZ\n';
    return Uint8List.fromList(utf8.encode(zpl));
  }

  static Uint8List _renderQolipCode(UsbRpsPrintRequest request) {
    final payload = request.isMaterialProductLabel
        ? _normalizeEpc(request.epc)
        : _sanitize(request.epc, fallback: '-');
    final name = _sanitize(
      request.isMaterialProductLabel
          ? request.materialProductLabelTitle
          : request.itemName.trim().isEmpty
              ? request.itemCode
              : request.itemName,
      fallback: '-',
    );
    final footer = _sanitize(
      request.largeQrLabelFooter(payload),
      fallback: '-',
    );
    final footerFont = footer.length > 43 ? '^A0N,14,12' : '^A0N,18,16';
    final rfidBlock = request.isMaterialProductLabel &&
            request.printMode.trim().toLowerCase() == 'rfid'
        ? '^RS8,,,1,N\n^RFW,H,,,A^FD$payload^FS\n'
        : '';
    final zpl = '~PS\n'
        '^XA\n'
        '^LH0,0\n'
        '$rfidBlock'
        '^FO8,2^A0N,24,20^FB784,2,28,C,0\n'
        '^FD$name^FS\n'
        '^FO120,56^BQN,2,11^FDLA,$payload^FS\n'
        '^FO8,352$footerFont^FB784,1,0,C,0\n'
        '^FD$footer^FS\n'
        '^PQ1\n'
        '^XZ\n';
    return Uint8List.fromList(utf8.encode(zpl));
  }

  static Uint8List renderRepeated(UsbRpsPrintRequest request) {
    final label = render(request);
    final output = BytesBuilder(copy: false);
    final count = request.printCount > 0 ? request.printCount : 1;
    for (var index = 0; index < count; index++) {
      output.add(label);
    }
    return output.takeBytes();
  }

  static String _normalizeEpc(String value) {
    var epc = value.trim().toUpperCase();
    if (epc.startsWith('0X')) {
      epc = epc.substring(2);
    }
    epc = epc.replaceAll(RegExp(r'[\s-]'), '');
    if (epc.isEmpty || !RegExp(r'^[0-9A-F]+$').hasMatch(epc)) {
      throw StateError('Zebra EPC faqat hex bo‘lishi kerak');
    }
    if (epc.length < 8 || epc.length > 64 || epc.length % 4 != 0) {
      throw StateError('Zebra EPC uzunligi 8..64 va 4 ga bo‘linishi kerak');
    }
    return epc;
  }

  static String _sanitize(String value, {required String fallback}) {
    final text = value.replaceAll(RegExp(r'[\r\n\^~]'), ' ').trim();
    return text.isEmpty ? fallback : text;
  }

  static String _rounded(double value) {
    final rounded = (value * 10).round() / 10;
    return rounded == rounded.truncateToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1);
  }
}
