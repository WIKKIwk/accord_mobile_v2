import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/print_service.dart';
import 'package:accord_mobile_v2/src/core/print_transport.dart';
import 'package:accord_mobile_v2/src/core/printing/material_data_matrix.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('accord/bluetooth_printer');
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = 'qolip-print-test';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        displayName: 'Qolipchi',
        legalName: '',
        ref: 'print-clerk',
        phone: '',
        avatarUrl: '',
        capabilities: ['qolip.manage']);
    AppSession.instance.revision.value++;
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Bluetooth mold pallet label includes its current count and typed QR',
      () async {
    final calls = <http.Request>[];
    Map? printed;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      printed = call.arguments as Map;
      return {'ok': true};
    });
    await http.runWithClient(() async {
      final job = await MobileApi.instance.qolipPrintPaddonQr(
          code: 'qp-00012', driverUrl: '', transport: PrintTransport.bluetooth);
      expect(job.paddonLabelLines,
          ['Qolip paddoni: QP-00012', 'Qoliplar soni: 104']);
      expect(job.toJson(), isNot(contains('paddon_label_lines')));
      final result = await PrintService.printRps(job,
          bluetoothPrinter: const BluetoothPrinterProfile(
              name: 'XP-P323B', address: 'test-only'),
          transport: PrintTransport.bluetooth);
      expect(result.ok, isTrue);
      expect(printed!['paddon_label_lines'],
          ['QOLIP PADDONI: QP-00012', 'QOLIPLAR SONI: 104']);
      expect(printed!['label_kind'], 'paddon_code');
      expect(printed!['epc'], 'qolip-paddon:QP-00012');
      expect(qolipPaddonCodeFromQr(printed!['epc'] as String), 'QP-00012');
      expect(printed!['material_data_matrix'], isTrue);
      expect(printed!['material_data_matrix_bars'],
          materialDataMatrixBars('qolip-paddon:QP-00012'));
      expect(calls, hasLength(1));
      expect(jsonDecode(calls.single.body)['print_transport'], 'offline');
    },
        () => MockClient((request) async {
              calls.add(request);
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'paddon': {'code': 'QP-00012', 'item_count': 104},
                    'qr_payload': 'qolip-paddon:QP-00012',
                    'print': {
                      'qr_payload': 'qolip-paddon:QP-00012',
                      'label_kind': 'paddon_code',
                      'item_code': 'QP-00012',
                      'item_name': 'Qolip paddoni QP-00012',
                    }
                  }),
                  200);
            }));
  });

  for (final scenario in [
    (count: 0, expected: '0'),
    (count: 3, expected: '3'),
    (count: -1, expected: '—'),
    (count: 1.5, expected: '—'),
    (count: '104', expected: '—'),
    (count: null, expected: '—'),
  ]) {
    test('Bluetooth mold pallet count uses a valid server value: $scenario',
        () async {
      await http.runWithClient(() async {
        final job = await MobileApi.instance.qolipPrintPaddonQr(
            code: 'QP-00012',
            driverUrl: '',
            transport: PrintTransport.bluetooth);
        expect(
            job.paddonLabelLines.last, 'Qoliplar soni: ${scenario.expected}');
      },
          () => MockClient((_) async => http.Response(
              jsonEncode({
                'ok': true,
                'paddon': {'code': 'QP-00012', 'item_count': scenario.count},
                'qr_payload': 'qolip-paddon:QP-00012',
                'print': {
                  'qr_payload': 'qolip-paddon:QP-00012',
                  'label_kind': 'paddon_code'
                }
              }),
              200)));
    });
  }

  test('Bluetooth pallet refuses a different response pallet identity',
      () async {
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.qolipPrintPaddonQr(
              code: 'QP-00012',
              driverUrl: '',
              transport: PrintTransport.bluetooth),
          throwsFormatException);
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({
              'ok': true,
              'paddon': {'code': 'QP-00013', 'item_count': 12},
              'qr_payload': 'qolip-paddon:QP-00012',
              'print': {
                'qr_payload': 'qolip-paddon:QP-00012',
                'label_kind': 'paddon_code'
              }
            }),
            200)));
  });

  test('Bluetooth pallet does not infer a count from a missing summary',
      () async {
    await http.runWithClient(() async {
      final job = await MobileApi.instance.qolipPrintPaddonQr(
          code: 'QP-00012', driverUrl: '', transport: PrintTransport.bluetooth);
      expect(job.paddonLabelLines,
          ['Qolip paddoni: QP-00012', 'Qoliplar soni: —']);
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({
              'ok': true,
              'paddon': {'item_count': 104},
              'qr_payload': 'qolip-paddon:QP-00012',
              'print': {
                'qr_payload': 'qolip-paddon:QP-00012',
                'label_kind': 'paddon_code'
              }
            }),
            200)));
  });

  for (final transport in [PrintTransport.offline, PrintTransport.wifi]) {
    test('$transport keeps the existing mold pallet print contract', () async {
      await http.runWithClient(() async {
        final job = await MobileApi.instance.qolipPrintPaddonQr(
            code: 'QP-00012',
            driverUrl: 'http://printer',
            transport: transport);
        expect(job.paddonLabelLines, isEmpty);
        expect(job.toJson(), isNot(contains('paddon_label_lines')));
      },
          () => MockClient((request) async {
                expect(jsonDecode(request.body).containsKey('print_transport'),
                    transport.isLocal);
                return http.Response(
                    jsonEncode({
                      'ok': true,
                      'paddon': {'code': 'QP-00012', 'item_count': 104},
                      'qr_payload': 'qolip-paddon:QP-00012',
                      'print': {
                        'qr_payload': 'qolip-paddon:QP-00012',
                        'label_kind': 'paddon_code'
                      }
                    }),
                    200);
              }));
    });
  }
  test('printing uses scoped mold pallet endpoint without lifecycle writes',
      () async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      final job = await MobileApi.instance.qolipPrintPaddonQr(
          code: ' qp-00012 ',
          driverUrl: 'http://printer/',
          transport: PrintTransport.offline);
      expect(job.epc, 'qolip-paddon:QP-00012');
      expect(job.isPaddonCodeLabel, isTrue);
      expect(job.paddonLabelLines, isEmpty);
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/v1/mobile/qolip/paddons/qr/print');
      final payload = jsonDecode(requests.single.body) as Map;
      expect(payload['print_transport'], 'offline');
      expect(payload['qolip_code'], 'QP-00012');
      expect(payload.containsKey('action'), isFalse);
    },
        () => MockClient((request) async {
              requests.add(request);
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'qr_payload': 'qolip-paddon:QP-00012',
                    'print': {
                      'qr_payload': 'qolip-paddon:QP-00012',
                      'label_kind': 'paddon_code'
                    }
                  }),
                  200);
            }));
  });
  test('mismatched QR response cannot be printed', () async {
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance
              .qolipPrintPaddonQr(code: 'QP-00012', driverUrl: ''),
          throwsFormatException);
    },
        () => MockClient((_) async => http.Response(
            '{"ok":true,"qr_payload":"QP-OTHER","print":{}}', 200)));
  });
}
