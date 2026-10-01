import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/native_usb_printer.dart';
import 'package:accord_mobile_v2/src/core/print_service.dart';
import 'package:accord_mobile_v2/src/core/print_transport.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('accord/bluetooth_printer');
  const printer =
      BluetoothPrinterProfile(name: 'XP-P323B', address: 'test-only');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'token';
  });
  tearDown(() {
    AppSession.instance.token = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<AdminPaddonQrPrintResult> prepare(
    Map<String, Object?> totals, {
    PrintTransport transport = PrintTransport.bluetooth,
  }) =>
      http.runWithClient(
        () => MobileApi.instance.adminPaddonPrintQr(
            code: '00001', printTransport: transport, printCount: 2),
        () => MockClient((request) async {
          expect(request.url.path,
              '/v1/mobile/admin/production-maps/paddons/qr/print');
          expect(jsonDecode(request.body)['code'], '00001');
          return http.Response(
              jsonEncode({
                'ok': true,
                'paddon': {'code': '00001', ...totals},
                // Legacy numeric placeholders must never become printed weights.
                'print': {
                  'qr_payload': '00001',
                  'item_code': '00001',
                  'item_name': 'Paddon 00001',
                  'label_kind': 'paddon_code',
                  'gross_qty': 1,
                  'qty': 1,
                  'unit': 'dona',
                  'print_count': 2,
                },
              }),
              200);
        }),
      );

  for (final scenario in [
    (
      'known',
      <String, Object?>{
        'item_count': 7,
        'total_gross_kg': 24.375,
        'total_net_kg': 23.125,
      },
      ['MAHSULOT SONI: 7', 'BRUTTO: 24.375 KG', 'NETTO: 23.125 KG']
    ),
    (
      'unknown',
      <String, Object?>{'item_count': 7},
      ['MAHSULOT SONI: 7', 'BRUTTO: - KG', 'NETTO: - KG']
    ),
    (
      'empty',
      <String, Object?>{
        'item_count': 0,
        'total_gross_kg': 0,
        'total_net_kg': 0,
      },
      ['MAHSULOT SONI: 0', 'BRUTTO: 0 KG', 'NETTO: 0 KG']
    ),
    (
      'partial',
      <String, Object?>{
        'item_count': 3,
        'total_gross_kg': 12.123456,
        'total_net_kg': -1,
      },
      ['MAHSULOT SONI: 3', 'BRUTTO: 12.123456 KG', 'NETTO: - KG']
    ),
    (
      'legacy',
      <String, Object?>{},
      ['MAHSULOT SONI: -', 'BRUTTO: - KG', 'NETTO: - KG']
    ),
  ]) {
    test('Bluetooth pallet ${scenario.$1} uses authoritative summary',
        () async {
      Map? captured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        captured = call.arguments as Map;
        return {'ok': true, 'bytes': 1};
      });
      final prepared = await prepare(scenario.$2);
      final job = prepared.printJob!;
      expect(job.paddonLabelLines, hasLength(4));
      expect(job.toJson(), isNot(contains('paddon_label_lines')));
      final result = await PrintService.printRps(job,
          bluetoothPrinter: printer, transport: PrintTransport.bluetooth);
      expect(result.ok, isTrue);
      expect(captured!['paddon_label_lines'], ['PADDON 00001', ...scenario.$3]);
      expect(captured!['epc'], '00001');
      expect(captured!['label_kind'], 'paddon_code');
      expect(captured!['print_count'], 2);
      final previewDir = Platform.environment['PALLET_LABEL_PREVIEW_DIR'];
      if (previewDir != null) {
        Directory(previewDir).createSync(recursive: true);
        File('$previewDir/${scenario.$1}-header.txt').writeAsStringSync(
            (captured!['paddon_label_lines'] as List).join('\n'));
      }
    });
  }

  for (final transport in [PrintTransport.offline, PrintTransport.wifi]) {
    test('$transport retains previous pallet print contract', () async {
      final result = await prepare({
        'item_count': 7,
        'total_gross_kg': 24.375,
        'total_net_kg': 23.125,
      }, transport: transport);
      expect(result.printJob!.paddonLabelLines, isEmpty);
      expect(result.printJob!.toJson(), isNot(contains('paddon_label_lines')));
    });
  }

  test('nonpallet Bluetooth label ignores pallet header data', () async {
    Map? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      captured = call.arguments as Map;
      return {'ok': true};
    });
    await NativeBluetoothPrinter.printLabel(
      const UsbRpsPrintRequest(
          epc: 'RPS-BATCH:B1',
          itemCode: 'B1',
          itemName: 'Roll',
          warehouse: '',
          printer: 'xp-p323b',
          printMode: 'label',
          grossQty: 1,
          labelKind: 'qolip_code',
          paddonLabelLines: ['not used']),
      printer: printer,
    );
    expect(captured!, isNot(contains('paddon_label_lines')));
  });
}
