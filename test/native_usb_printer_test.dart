import 'package:accord_mobile_v2/src/core/native_usb_printer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds rps usb test request like driver print contract', () {
    final request = UsbRpsPrintRequest.test(epc: ' rps-usb-test ');

    expect(request.toJson(), {
      'epc': 'RPS-USB-TEST',
      'item_code': 'USB-TEST',
      'item_name': 'USB printer test',
      'warehouse': 'RPS USB TEST',
      'printer': 'godex',
      'print_mode': 'label',
      'gross_qty': 1.0,
      'unit': 'kg',
      'tare_enabled': false,
      'tare_kg': 0.0,
      'print_count': 1,
    });
  });

  test('parses rps usb print response', () {
    final response = UsbRpsPrintResponse.fromMap({
      'ok': true,
      'status': 'done',
      'epc': 'RPS-USB-TEST',
      'item_code': 'USB-TEST',
      'item_name': 'USB printer test',
      'warehouse': 'RPS USB TEST',
      'printer': 'godex',
      'mode': 'label',
      'gross_qty': 1.0,
      'net_qty': 1.0,
      'unit': 'kg',
      'printer_status': 'USB OK',
      'print_count': 1,
      'bytes': 256,
      'deviceName': '/dev/bus/usb/001/002',
      'vendorId': 1234,
      'productId': 5678,
    });

    expect(response.ok, isTrue);
    expect(response.status, 'done');
    expect(response.epc, 'RPS-USB-TEST');
    expect(response.itemCode, 'USB-TEST');
    expect(response.printerStatus, 'USB OK');
    expect(response.bytes, 256);
    expect(response.vendorId, 1234);
    expect(response.productId, 5678);
  });

  test('parses backend progress label into the shared USB print request', () {
    final request = UsbRpsPrintRequest.fromPrintJson(const {
      'ok': true,
      'qr_payload': '303132333435363738394142',
      'item_code': 'ORDER-2',
      'item_name': 'Progress label',
      'customer_name': 'Customer One',
      'executor_name': 'Ali',
      'gross_qty': 10.0,
      'qty': 35.75,
      'tare_enabled': true,
      'tare_kg': 1.0,
      'unit': 'kg',
      'progress_unit': 'm',
      'label_kind': 'progress',
      'printer': 'godex',
      'print_mode': 'label',
      'print_count': 2,
    });

    expect(request.epc, '303132333435363738394142');
    expect(request.warehouse, 'Ijrochi: Ali');
    expect(request.isProgressLabel, isTrue);
    expect(request.effectiveProgressQty, 35.75);
    expect(request.customerName, 'Customer One');
    expect(request.netQty, 9.0);
    expect(request.progressUnit, 'm');
    expect(request.printCount, 2);
  });

  test('parses detected Zebra USB profile and applies its defaults', () {
    final profile = UsbPrinterProfile.fromMap(const {
      'printer': 'zebra',
      'deviceName': '/dev/bus/usb/001/002',
      'vendorId': 0x0a5f,
      'productId': 0x0164,
      'manufacturerName': 'Zebra Technologies',
      'productName': 'ZT411R',
    });
    final request = UsbRpsPrintRequest.test(
      epc: '303132333435363738394142',
    ).forPrinter(profile);

    expect(profile.kind, UsbPrinterKind.zebra);
    expect(profile.printMode, 'rfid');
    expect(profile.displayName, 'Zebra • ZT411R');
    expect(request.printer, 'zebra');
    expect(request.printMode, 'rfid');
  });

  test('forwards GoDEX cleanup metadata to the Android USB channel', () async {
    const channel = MethodChannel('accord/usb_printer');
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return <String, Object?>{'ok': true};
    });
    try {
      await NativeUsbPrinter.printRaw(
        Uint8List.fromList([1, 2, 3]),
        printerKind: UsbPrinterKind.godex,
        godexGraphicNames: const ['TPRINT001', 'QPRINT001'],
        labelCount: 2,
      );
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }

    expect(captured?.method, 'printRaw');
    expect(captured?.arguments, containsPair('print_count', 1));
    expect(captured?.arguments, containsPair('label_count', 2));
    expect(
      captured?.arguments,
      containsPair(
        'godex_graphic_names',
        const ['TPRINT001', 'QPRINT001'],
      ),
    );
  });
}
