import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/native_usb_printer.dart';
import 'package:accord_mobile_v2/src/core/print_service.dart';
import 'package:accord_mobile_v2/src/core/print_transport.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('accord/bluetooth_printer');
  const discoveryChannel = EventChannel('accord/bluetooth_printer/discovery');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(discoveryChannel, null);
  });

  test('reads XP-P323B profiles from the native Bluetooth channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'pairedPrinters');
      return <Object?>[
        <String, Object?>{
          'name': 'XP-P323B',
          'address': '00:11:22:33:44:55',
        },
      ];
    });

    final printers = await NativeBluetoothPrinter.pairedPrinters();

    expect(printers, hasLength(1));
    expect(printers.single.displayName, 'XP-P323B');
    expect(printers.single.printer, 'xp-p323b');
    expect(printers.single.printMode, 'label');
  });

  test('routes the shared local print request through Bluetooth', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call;
      return <String, Object?>{
        'ok': true,
        'status': 'done',
        'printer_status': 'Bluetooth OK',
        'bytes': 128,
      };
    });
    const printer = BluetoothPrinterProfile(
      name: 'XP-P323B',
      address: '00:11:22:33:44:55',
    );

    final response = await PrintService.printRps(
      const UsbRpsPrintRequest(
        epc: '303132333435363738394142',
        itemCode: 'ITEM-1',
        itemName: 'Green Tea',
        warehouse: 'Stores - A',
        printer: 'xp-p323b',
        printMode: 'label',
        grossQty: 2.5,
      ),
      bluetoothPrinter: printer,
      transport: PrintTransport.bluetooth,
    );

    expect(response.ok, isTrue);
    expect(response.printerStatus, 'Bluetooth OK');
    expect(captured?.method, 'printLabel');
    expect(captured?.arguments, containsPair('mac_address', printer.address));
    expect(captured?.arguments, containsPair('print_count', 1));
    expect(
      captured?.arguments,
      containsPair('epc', '303132333435363738394142'),
    );
    expect(captured?.arguments, isNot(contains('bytes')));
  });

  test('receives iOS printers incrementally and then receives scan completion',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      discoveryChannel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          events.success(<String, Object?>{
            'type': 'printer',
            'name': 'XP-P323B',
            'address': 'ios-printer-1',
          });
          events.success(<String, Object?>{'type': 'complete'});
          events.endOfStream();
        },
      ),
    );

    final events = await NativeBluetoothPrinter.discoverPrinters().toList();

    expect(events, hasLength(2));
    expect(events.first.printer?.displayName, 'XP-P323B');
    expect(events.first.printer?.address, 'ios-printer-1');
    expect(events.last.completed, isTrue);
  });

  test('uses a new native discovery session for every scan', () async {
    final sessions = <Object?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
      discoveryChannel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          sessions.add(arguments);
          events.success(<String, Object?>{'type': 'complete'});
        },
      ),
    );

    await NativeBluetoothPrinter.discoverPrinters().first;
    await NativeBluetoothPrinter.discoverPrinters().first;

    expect(sessions, hasLength(2));
    expect(sessions[0], isA<int>());
    expect(sessions[1], isA<int>());
    expect(sessions[1], isNot(sessions[0]));
  });

  test('maps Bluetooth to the unchanged backend client-print contract', () {
    expect(PrintTransport.bluetooth.isLocal, isTrue);
    expect(PrintTransport.bluetooth.clientApiValue, 'offline');
    expect(PrintTransport.wifi.clientApiValue, 'wifi');
  });
}
