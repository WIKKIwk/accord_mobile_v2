import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/native_usb_printer.dart';
import 'package:accord_mobile_v2/src/core/print_service.dart';
import 'package:accord_mobile_v2/src/core/print_transport.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_scan_bootstrap_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('accord/bluetooth_printer');
  const epcA = '400118DF777A61655B58863F';
  const epcB = '400118DE52D377560B196C52';
  final completedA =
      DateTime(2026, 10, 18, 14, 37).millisecondsSinceEpoch ~/ 1000;
  final completedB =
      DateTime(2026, 10, 17, 9, 12).millisecondsSinceEpoch ~/ 1000;
  final captured = <Map<Object?, Object?>>[];

  Map<String, dynamic> batch(String epc, int completedAt) => {
        'batch_id': 'batch-$epc',
        'order_id': scanOrder,
        'apparatus': scanApparatus,
        'qr_payload': epc,
        'label_item_code': 'ZIZI',
        'label_item_name': 'ZIZI SPONGE YARIM TAYYOR',
        'produced_qty': 6500,
        'uom': 'm',
        'completed_at_unix': completedAt,
      };
  Map<String, dynamic> printJob(String epc) => {
        'ok': true,
        'status': 'prepared',
        'epc': epc,
        'item_code': 'ZIZI',
        'item_name': 'ZIZI SPONGE YARIM TAYYOR',
        'label_kind': 'progress',
        'gross_qty': 107,
        'progress_qty': 6500,
        'progress_unit': 'm',
      };

  Future<void> printBluetooth(UsbRpsPrintRequest request) async {
    await PrintService.printRps(
      request,
      transport: PrintTransport.bluetooth,
      bluetoothPrinter: const BluetoothPrinterProfile(
        name: 'XP-P323B',
        address: 'wip-test-printer',
      ),
    );
  }

  setUp(() async {
    captured.clear();
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'wip-print-token';
    await TestModeController.instance.setEnabled(false);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'printLabel');
      captured.add(Map<Object?, Object?>.from(call.arguments as Map));
      return <String, Object?>{'ok': true};
    });
  });
  tearDown(() {
    AppSession.instance.token = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
      'queue labels keep each WIP completion time through saved Bluetooth jobs',
      () async {
    await http.runWithClient(() async {
      final result = await MobileApi.instance.adminApparatusQueueActionResult(
        apparatus: scanApparatus,
        orderId: scanOrder,
        action: 'complete',
        printTransport: PrintTransport.bluetooth,
      );
      expect(result.printJob!.completedAtUnix, completedA);
      expect(result.printJobs.map((job) => job.completedAtUnix),
          [completedB, completedA]);
      for (final job in result.printJobs) {
        // Print retries restore the saved job; the original completion survives.
        await printBluetooth(UsbRpsPrintRequest.fromPrintJson(job.toJson()));
      }
    },
        () => MockClient((request) async {
              expect(request.url.path.endsWith('/queue-action'), isTrue);
              return http.Response(
                  jsonEncode({
                    'states': {scanOrder: 'completed'},
                'progress_batch': batch(epcA, 0),
                    'progress_batches': [
                      batch(epcA, completedA),
                      batch(epcB, completedB)
                    ],
                    'print': printJob(epcA),
                    'prints': [printJob(epcB), printJob(epcA)],
                  }),
                  200);
            }));
    expect(captured[0]['completed_at_unix'], completedB);
    expect(captured[0]['completed_at_label'], '17.10.2026 09:12');
    expect(captured[1]['completed_at_unix'], completedA);
    expect(captured[1]['completed_at_label'], '18.10.2026 14:37');
  });

  test('WIP reprint uses the saved production completion date', () async {
    await http.runWithClient(() async {
      final result = await MobileApi.instance.adminProgressQrReprint(
        qrPayload: epcB,
        printTransport: PrintTransport.bluetooth,
      );
      expect(result.printJob!.completedAtUnix, completedB);
      await printBluetooth(result.printJob!);
    },
        () => MockClient((request) async {
              expect(request.url.path.endsWith('/progress-qr/reprint'), isTrue);
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'batch': batch(epcB, completedB),
                    'print': printJob(epcB),
                  }),
                  200);
            }));
    expect(captured.single['completed_at_label'], '17.10.2026 09:12');
  });

  test('legacy WIP without a completion timestamp does not invent a date',
      () async {
    await printBluetooth(UsbRpsPrintRequest.fromPrintJson(printJob(epcA)));
    expect(captured.single, isNot(contains('completed_at_unix')));
    expect(captured.single, isNot(contains('completed_at_label')));
  });
}
