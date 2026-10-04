import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_scan_bootstrap_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'scan-token';
    await TestModeController.instance.setEnabled(false);
  });
  tearDown(() {
    AppSession.instance.token = null;
  });
  test('bootstrap strict complete sections retain existing decoder values', () {
    final result = AdminOrderScanBootstrap.fromJson(
      scanBootstrap(),
      apparatus: scanApparatus,
      orderId: scanOrder,
    );
    expect(result.controlState.revision, 7);
    expect(result.materials!.startAssignments.single.barcode, 'ROLL1');
    expect(result.materials!.scanSatisfied, isFalse);
    expect(result.qolips!.requiredQolipCodes, ['MOLD1']);
  });
  for (final section in ['materials', 'qolips']) {
    for (final invalid in [
      null,
      {},
      {'status': 'error'},
      {'status': 'ready', 'data': {}},
      {'status': 'not_required'},
    ]) {
      test(
        'bootstrap incomplete $section $invalid requires independent reader',
        () {
          final body = scanBootstrap();
          (body['sections'] as Map)[section] = invalid;
          final result = AdminOrderScanBootstrap.fromJson(
            body,
            apparatus: scanApparatus,
            orderId: scanOrder,
          );
          expect(
            section == 'materials' ? result.materials : result.qolips,
            isNull,
          );
          expect(
            section == 'materials' ? result.qolips : result.materials,
            isNotNull,
          );
        },
      );
    }
  }
  for (final field in [
    'scope',
    'rev',
    'epoch',
    'control',
    'stage_states',
    'order_control',
  ]) {
    test('bootstrap rejects incomplete control $field', () {
      final body = scanBootstrap();
      (body['control_state'] as Map).remove(field);
      expect(
        () => AdminOrderScanBootstrap.fromJson(
          body,
          apparatus: scanApparatus,
          orderId: scanOrder,
        ),
        throwsA(isA<MobileApiException>()),
      );
    });
  }
  test(
    'bootstrap rejects cross-order/apparatus and malformed requirement rows',
    () {
      expect(
        () => AdminOrderScanBootstrap.fromJson(
          scanBootstrap(),
          apparatus: scanApparatus,
          orderId: 'other',
        ),
        throwsA(isA<MobileApiException>()),
      );
      final body = scanBootstrap();
      body['sections']['materials']['data']['assignments'][0]['order_id'] =
          'other';
      body['sections']['qolips']['data']['qolip']['required_qolip_count'] = 2;
      final result = AdminOrderScanBootstrap.fromJson(
        body,
        apparatus: scanApparatus,
        orderId: scanOrder,
      );
      expect(result.materials, isNull);
      expect(result.qolips, isNull);
    },
  );
  test('bootstrap sends one scoped GET and passes scanned barcodes', () async {
    final requests = <http.Request>[];
    await http.runWithClient(
      () async {
        final result = await MobileApi.instance.adminOrderScanBootstrap(
          apparatus: scanApparatus,
          orderId: scanOrder,
          materialBarcodes: ['ROLL1', 'ROLL2'],
        );
        expect(result!.controlState.orderId, scanOrder);
        expect(requests, hasLength(1));
        expect(requests.single.method, 'GET');
        expect(requests.single.url.queryParameters, {
          'apparatus': scanApparatus,
          'order_id': scanOrder,
          'material_barcodes': 'ROLL1,ROLL2',
        });
      },
      () => MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode(scanBootstrap()), 200);
      }),
    );
  });
  for (final aggregate in [false, true]) {
    testWidgets('scan bootstrap synthetic 250ms RTT aggregate=$aggregate', (
      tester,
    ) async {
      var requests = 0;
      var bytes = 0;
      var complete = false;
      await http.runWithClient(
        () async {
          Future<void> load() async {
            if (aggregate) {
              await MobileApi.instance.adminOrderScanBootstrap(
                apparatus: scanApparatus,
                orderId: scanOrder,
              );
            } else {
              await MobileApi.instance.adminProductionMapQueueSnapshot(
                apparatus: scanApparatus,
                orderId: scanOrder,
              );
              await Future.wait([
                MobileApi.instance.adminRawMaterialStartRequirements(
                  apparatus: scanApparatus,
                  orderId: scanOrder,
                ),
                MobileApi.instance.adminProductionMapQolipRequirements(
                  apparatus: scanApparatus,
                  orderId: scanOrder,
                ),
              ]);
            }
            complete = true;
          }

          final future = load();
          await tester.pump();
          expect(requests, 1);
          await tester.pump(const Duration(milliseconds: 249));
          expect(complete, isFalse);
          await tester.pump(const Duration(milliseconds: 1));
          if (!aggregate) {
            expect(requests, 3);
            expect(complete, isFalse);
            await tester.pump(const Duration(milliseconds: 250));
          }
          await future;
          expect(complete, isTrue);
          expect(requests, aggregate ? 1 : 3);
          // Fake-time network fixture; this is not production latency or CPU.
          debugPrint(
            'synthetic scan bootstrap aggregate=$aggregate requests=$requests '
            'response_json_bytes=$bytes critical_path_ms=${aggregate ? 250 : 500}',
          );
        },
        () => MockClient((request) async {
          requests++;
          await Future<void>.delayed(const Duration(milliseconds: 250));
          final body = request.url.path.endsWith('/order-scan-bootstrap')
              ? scanBootstrap()
              : request.url.path.endsWith('/sequence')
                  ? scanSequence()
                  : request.url.path.endsWith('/qolip-validate')
                      ? scanQolips()
                      : scanMaterials();
          final response = http.Response(jsonEncode(body), 200);
          bytes += response.bodyBytes.length;
          return response;
        }),
      );
    });
  }
  for (final code in [404, 405]) {
    test('bootstrap empty route $code allows legacy reader', () async {
      await http.runWithClient(() async {
        expect(
          await MobileApi.instance.adminOrderScanBootstrap(
            apparatus: scanApparatus,
            orderId: scanOrder,
          ),
          isNull,
        );
      }, () => MockClient((_) async => http.Response('', code)));
    });
  }
  for (final code in [400, 403, 404, 409, 503]) {
    test(
      'bootstrap domain $code remains failure without legacy fallback',
      () async {
        await http.runWithClient(
          () async {
            await expectLater(
              MobileApi.instance.adminOrderScanBootstrap(
                apparatus: scanApparatus,
                orderId: scanOrder,
              ),
              throwsA(isA<MobileApiException>()),
            );
          },
          () => MockClient(
            (_) async => http.Response('{"error":"order_not_available"}', code),
          ),
        );
      },
    );
  }
}
