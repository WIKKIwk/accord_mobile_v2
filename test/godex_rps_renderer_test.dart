import 'package:accord_mobile_v2/src/core/godex_rps_renderer.dart';
import 'package:accord_mobile_v2/src/core/native_usb_printer.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('matches the current Android Godex test label byte stream', () {
    final bytes = GodexRpsRenderer.render(
      UsbRpsPrintRequest.test(epc: 'RPS-USB-TEST'),
    );

    expect(bytes.length, 3840);
    expect(sha256.convert(bytes).toString(),
        'be4474f9a34003f97a44d18270d635c7bfc55a88c241a06657916452af4407f0');
  });

  test('renders the RPS progress layout with kg and metraj fields', () {
    final bytes = GodexRpsRenderer.render(
      const UsbRpsPrintRequest(
        epc: '303132333435363738394142',
        itemCode: 'ORDER-2',
        itemName: 'Progress label',
        warehouse: 'Ijrochi: Ali',
        printer: 'godex',
        printMode: 'label',
        grossQty: 12.5,
        unit: 'kg',
        labelKind: 'progress',
        executorName: 'Ali',
        progressQty: 35.75,
        progressUnit: 'm',
      ),
    );
    final stream = String.fromCharCodes(bytes);

    expect(stream, contains('AB,16,264,1,1,0,0,KG: 12.5\r\n'));
    expect(stream, contains('AB,16,304,1,1,0,0,METRAJ: 35.8 M\r\n'));
    expect(stream, isNot(contains('NETTO:')));
    expect(stream, contains('BA,0,24,1,2,42,0,0,303132333435363738394142'));
    expect(stream, contains('Y224,224,QRLBL'));
  });

  test('renders Qolip cell QR large and below the label center', () {
    final bytes = GodexRpsRenderer.render(
      const UsbRpsPrintRequest(
        epc: 'CELL-QR-A1',
        itemCode: 'A1',
        itemName: 'A1',
        warehouse: 'Qolip ombor',
        printer: 'godex',
        printMode: 'label',
        grossQty: 1,
        labelKind: 'qolip_cell',
      ),
    );
    final output = String.fromCharCodes(bytes);

    expect(output, contains('~EB,QRLBL,'));
    expect(output, contains('Y0,0,TEXTLBL'));
    expect(output, contains('Y56,96,QRLBL'));
    expect(output, isNot(contains('Y224,224,QRLBL')));
  });

  test('renders Qolip code with small name and code around a large QR', () {
    final output = String.fromCharCodes(
      GodexRpsRenderer.render(
        const UsbRpsPrintRequest(
          epc: 'QOLIP-0007',
          itemCode: 'QOLIP-0007',
          itemName: 'Kross qolip',
          warehouse: '',
          printer: 'godex',
          printMode: 'label',
          grossQty: 1,
          labelKind: 'qolip_code',
        ),
      ),
    );

    expect(output, contains('~EB,QRLBL,'));
    expect(output, contains('Y0,0,TEXTLBL'));
    expect(output, contains('Y56,56,QRLBL'));
    expect(output, isNot(contains('Y224,224,QRLBL')));
  });

  test('renders Paddon code as a large QR label', () {
    final output = String.fromCharCodes(
      GodexRpsRenderer.render(
        const UsbRpsPrintRequest(
          epc: '00001',
          itemCode: '00001',
          itemName: 'Paddon 00001',
          warehouse: '',
          printer: 'godex',
          printMode: 'label',
          grossQty: 1,
          labelKind: 'paddon_code',
        ),
      ),
    );

    expect(output, contains('Y56,56,QRLBL'));
    expect(output, isNot(contains('BA,')));
    expect(output, isNot(contains('Y224,224,QRLBL')));
  });

  test('renders material batch as QR-only without a product barcode', () {
    final output = String.fromCharCodes(
      GodexRpsRenderer.render(
        const UsbRpsPrintRequest(
          epc: 'RPS-BATCH:BATCH-HISTORY-92',
          itemCode: 'CPP 1030/25',
          itemName: 'CPP 1030/25 B:92 N:92 KG',
          warehouse: 'Kalidor',
          printer: 'godex',
          printMode: 'label',
          grossQty: 92,
          labelKind: 'qolip_code',
        ),
      ),
    );

    expect(output, contains('Y56,56,QRLBL'));
    expect(output, isNot(contains('BA,')));
    expect(output, isNot(contains('Y224,224,QRLBL')));
  });

  test('renders ordinary material product with the reused large QR layout', () {
    final output = String.fromCharCodes(
      GodexRpsRenderer.render(
        const UsbRpsPrintRequest(
          epc: '303132333435363738394142',
          itemCode: 'CPP 1030/25',
          itemName: 'CPP 1030/25',
          warehouse: 'Kalidor',
          printer: 'godex',
          printMode: 'label',
          grossQty: 23,
          labelKind: 'material_product',
        ),
      ),
    );

    expect(output, contains('Y56,56,QRLBL'));
    expect(output, isNot(contains('BA,')));
    expect(output, isNot(contains('Y224,224,QRLBL')));
  });

  test('renders Android material labels with per-print graphic names', () {
    const request = UsbRpsPrintRequest(
      epc: '303132333435363738394142',
      itemCode: 'CPP 1030/25',
      itemName: 'CPP 1030/25',
      warehouse: 'Kalidor',
      printer: 'godex',
      printMode: 'label',
      grossQty: 23,
      labelKind: 'material_product',
    );

    final first = GodexRpsRenderer.renderAndroid(
      request,
      graphicToken: 'print-001',
    );
    final second = GodexRpsRenderer.renderAndroid(
      request,
      graphicToken: 'print-002',
    );
    final firstOutput = String.fromCharCodes(first.bytes);
    final secondOutput = String.fromCharCodes(second.bytes);

    expect(first.graphicNames, ['TPRINT001', 'QPRINT001']);
    expect(second.graphicNames, ['TPRINT002', 'QPRINT002']);
    expect(firstOutput, contains('~EB,TPRINT001,'));
    expect(firstOutput, contains('~EB,QPRINT001,'));
    expect(firstOutput, contains('Y0,0,TPRINT001'));
    expect(firstOutput, contains('Y56,56,QPRINT001'));
    expect(firstOutput, isNot(contains('~MDELG,')));
    expect(secondOutput, isNot(contains('TPRINT001')));
    expect(secondOutput, isNot(contains('QPRINT001')));
  });

  test('Android repeated jobs use unique names and one final status query', () {
    const request = UsbRpsPrintRequest(
      epc: '303132333435363738394142',
      itemCode: 'ORDER-2',
      itemName: 'Progress label',
      warehouse: 'Ijrochi: Ali',
      printer: 'godex',
      printMode: 'label',
      grossQty: 12.5,
      unit: 'kg',
      labelKind: 'progress',
      printCount: 2,
      executorName: 'Ali',
      progressQty: 35.75,
      progressUnit: 'm',
    );

    final rendered = GodexRpsRenderer.renderAndroidRepeated(request);
    final output = String.fromCharCodes(rendered.bytes);

    expect(rendered.labelCount, 2);
    expect(rendered.graphicNames, hasLength(4));
    expect(rendered.graphicNames.toSet(), hasLength(4));
    expect(
      rendered.graphicNames.every(
        (name) => RegExp(r'^[A-Z0-9]{1,20}$').hasMatch(name),
      ),
      isTrue,
    );
    expect(RegExp(r'~S,STATUS\r\n').allMatches(output), hasLength(1));
    expect(output, isNot(contains('~MDELG,')));
    expect(output, isNot(contains('TEXTLBL')));
    expect(output, isNot(contains('QRLBL')));
  });
}
