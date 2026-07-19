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
}
