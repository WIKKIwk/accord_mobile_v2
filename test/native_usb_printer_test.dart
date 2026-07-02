import 'package:accord_mobile_v2/src/core/native_usb_printer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
