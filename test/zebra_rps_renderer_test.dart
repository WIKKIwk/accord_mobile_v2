import 'dart:convert';

import 'package:accord_mobile_v2/src/core/native_usb_printer.dart';
import 'package:accord_mobile_v2/src/core/zebra_rps_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const epc = '3034257BF7194E406994036B';

  test('matches the r-ps Zebra RFID command layout', () {
    final command = utf8.decode(
      ZebraRpsRenderer.render(
        const UsbRpsPrintRequest(
          epc: epc,
          itemCode: 'ITEM-1',
          itemName: 'Green Tea',
          warehouse: 'Stores - A',
          printer: 'zebra',
          printMode: 'rfid',
          grossQty: 2.5,
          unit: 'kg',
          tareEnabled: true,
          tareKg: 0.78,
        ),
      ),
    );

    expect(command, startsWith('~PS\n^XA\n^LH0,0\n^RS8,,,1,N\n'));
    expect(command, contains('^RFW,H,,,A^FD$epc^FS'));
    expect(command, contains('^FDMAHSULOT: Green Tea^FS'));
    expect(command, contains('^FDNETTO: 1.7 kg^FS'));
    expect(command, contains('^FDBRUTTO: 2.5 kg^FS'));
    expect(command, contains('^FO8,220^A0N,24,20^FB760,1,0,L,0'));
    expect(command, contains('^FO8,272^BY3,2,44^BCN,44,N,N,N'));
    expect(command, endsWith('^PQ1\n^XZ\n'));
  });

  test('uses the r-ps Zebra label-only mode without RFID write', () {
    final command = utf8.decode(
      ZebraRpsRenderer.render(
        const UsbRpsPrintRequest(
          epc: epc,
          itemCode: 'ITEM-1',
          itemName: 'Green Tea',
          warehouse: 'Stores - A',
          printer: 'zebra',
          printMode: 'label',
          grossQty: 2,
          unit: 'kg',
        ),
      ),
    );

    expect(command, contains('^MMT'));
    expect(command, isNot(contains('^RFW')));
    expect(command, isNot(contains('^RS8')));
    expect(command, contains('^FDVAZNI: 2 kg^FS'));
  });

  test('renders Qolip cell QR large and below the label center', () {
    final zpl = String.fromCharCodes(
      ZebraRpsRenderer.render(
        const UsbRpsPrintRequest(
          epc: 'CELL-QR-A1',
          itemCode: 'A1',
          itemName: 'A1',
          warehouse: 'Qolip ombor',
          printer: 'zebra',
          printMode: 'rfid',
          grossQty: 1,
          labelKind: 'qolip_cell',
        ),
      ),
    );

    expect(zpl, contains('^FO8,16^A0N,88,76^FB784,1,0,C,0'));
    expect(zpl, contains('^FDLA,CELL-QR-A1^FS'));
    expect(zpl, contains('^FO120,124^BQN,2,11'));
    expect(zpl, isNot(contains('^RFW')));
  });

  test('renders Qolip code with small name and code around a large QR', () {
    final zpl = String.fromCharCodes(
      ZebraRpsRenderer.render(
        const UsbRpsPrintRequest(
          epc: 'QOLIP-0007',
          itemCode: 'QOLIP-0007',
          itemName: 'Kross qolip',
          warehouse: '',
          printer: 'zebra',
          printMode: 'label',
          grossQty: 1,
          labelKind: 'qolip_code',
        ),
      ),
    );

    expect(zpl, contains('^FO8,2^A0N,24,20^FB784,2,28,C,0'));
    expect(zpl, contains('^FO120,56^BQN,2,11'));
    expect(zpl, contains('^FO8,352^A0N,18,16^FB784,1,0,C,0'));
    expect(zpl, isNot(contains('^RFW')));
  });

  test('renders material batch as QR-only without RFID or barcode', () {
    final zpl = String.fromCharCodes(
      ZebraRpsRenderer.render(
        const UsbRpsPrintRequest(
          epc: 'RPS-BATCH:BATCH-HISTORY-92',
          itemCode: 'CPP 1030/25',
          itemName: 'CPP 1030/25 B:92 N:92 KG',
          warehouse: 'Kalidor',
          printer: 'zebra',
          printMode: 'label',
          grossQty: 92,
          labelKind: 'qolip_code',
        ),
      ),
    );

    expect(zpl, contains('^FDLA,RPS-BATCH:BATCH-HISTORY-92^FS'));
    expect(zpl, isNot(contains('^RFW')));
    expect(zpl, isNot(contains('^BCN')));
  });
}
