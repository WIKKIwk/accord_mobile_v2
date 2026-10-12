import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/print_transport.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apparatus = 'apparatus:default:asset-007';
const source = AdminLayerRemainderSource(
  sourceKind: 'progress_batch',
  sourceId: 'original-50kg',
  sessionId: 'lamination-session',
  revision: 7,
  qrPayload: 'original-qr',
  itemCode: 'PET',
  itemName: 'Printed PET',
  sourceNetKg: 50,
  sourceMeter: 1500,
  tareKg: 2,
  producerName: 'Original printer',
);

Map<String, dynamic> remainderPayload() => {
      'operation_id': 'remainder-operation',
      'request_id': 'stable-request',
      'source_kind': 'progress_batch',
      'source_id': source.sourceId,
      'qr_payload': 'remaining-qr',
      'remaining_net_kg': 20,
      'remaining_meter': 600,
      'producer_name': source.producerName,
      'recorded_by': {'display_name': 'Lamination operator'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'worker-token';
  });
  tearDown(() => AppSession.instance.token = null);

  test('net weight ratio estimates 600 m without counting the core', () {
    expect(source.estimateMeter(20), 600);
    expect(source.estimateMeter(0), isNull);
    expect(source.estimateMeter(51), isNull);
    expect(source.estimateMeter(double.nan), isNull);
    expect(source.estimateMeter(double.infinity), isNull);
    final netSource = AdminLayerRemainderSource.fromJson({
      ...source.toJson(),
      'source_net_kg': 48,
    });
    expect(netSource.estimateMeter(18), 562.5);
  });

  test('lists WIP and film rolls plus auditable remainders', () async {
    final requests = <http.Request>[];
    final result = await http.runWithClient(
      () => MobileApi.instance
          .adminLayerRemainders(apparatus: apparatus, orderId: 'order-1'),
      () => MockClient((request) async {
        requests.add(request);
        return http.Response(
            jsonEncode({
              'sources': [
                source.toJson(),
                {...source.toJson(), 'source_kind': 'raw_material'},
              ],
              'remainders': [remainderPayload()],
            }),
            200);
      }),
    );
    expect(result.sources.map((item) => item.sourceKind),
        ['progress_batch', 'raw_material']);
    expect(result.remainders.single.producerName, 'Original printer');
    expect(result.remainders.single.recordedByName, 'Lamination operator');
    expect(requests.single.method, 'GET');
    expect(requests.single.url.queryParameters,
        {'apparatus': apparatus, 'order_id': 'order-1'});
  });

  test('records only net kg with revision and stable request identity',
      () async {
    final requests = <http.Request>[];
    final result = await http.runWithClient(
      () => MobileApi.instance.adminRecordLayerRemainder(
        apparatus: apparatus,
        orderId: 'order-1',
        source: source,
        remainingNetKg: 20,
        requestId: 'stable-request',
        printTransport: PrintTransport.offline,
        printer: 'godex',
      ),
      () => MockClient((request) async {
        requests.add(request);
        return http.Response(
            jsonEncode({
              'ok': true,
              'remainder': remainderPayload(),
              'print': {
                'ok': true,
                'status': 'prepared',
                'epc': 'remaining-qr',
                'gross_qty': 22,
                'tare_kg': 2,
                'tare_enabled': true,
                'progress_qty': 600,
                'label_kind': 'progress',
                'executor_name': 'Original printer',
              },
            }),
            200);
      }),
    );
    expect(jsonDecode(requests.single.body), {
      'apparatus': apparatus,
      'order_id': 'order-1',
      'source_kind': 'progress_batch',
      'source_id': 'original-50kg',
      'session_id': 'lamination-session',
      'expected_revision': 7,
      'remaining_net_kg': 20,
      'request_id': 'stable-request',
      'printer': 'godex',
      'print_transport': 'offline',
      'print_count': 1,
    });
    expect(result.remainder.remainingMeter, 600);
    expect(result.printJob!.executorName, 'Original printer');
    expect(result.printJob!.grossQty, 22);
    expect(result.printJob!.progressQty, 600);
  });

  test('printing failure retains persisted business operation', () async {
    final result = await http.runWithClient(
      () => MobileApi.instance.adminRecordLayerRemainder(
          apparatus: apparatus,
          orderId: 'order-1',
          source: source,
          remainingNetKg: 20,
          requestId: 'stable-request'),
      () => MockClient((request) async => http.Response(
          jsonEncode({
            'ok': true,
            'remainder': remainderPayload(),
            'print': {'ok': false, 'status': 'print_failed'},
          }),
          200)),
    );
    expect(result.remainder.operationId, 'remainder-operation');
    expect(result.printOk, isFalse);
    expect(result.printJob, isNull);
  });

  test('raw film label retains net weight, core and estimated length', () {
    final result = AdminLayerRemainderResult.fromJson({
      'ok': true,
      'remainder': {...remainderPayload(), 'source_kind': 'raw_material'},
      'print': {
        'ok': true,
        'status': 'prepared',
        'epc': 'remaining-qr',
        'apparatus': '',
        'warehouse': 'Film warehouse',
        'item_name': 'PET 12 micron',
        'gross_qty': 22,
        'tare_kg': 2,
        'tare_enabled': true,
        'progress_qty': 600,
        'progress_unit': 'm',
        'label_kind': 'material_product',
        'executor_name': 'Original supplier',
      },
    });
    expect(result.printJob!.isMaterialProductLabel, isTrue);
    expect(result.printJob!.netQty, 20);
    expect(result.printJob!.progressQty, 600);
    expect(result.printJob!.executorName, 'Original supplier');
    expect(result.printJob!.warehouse, 'Film warehouse');
  });

  test('reprinting refers to saved operation without creating stock', () async {
    final requests = <http.Request>[];
    await http.runWithClient(
      () => MobileApi.instance.adminLayerRemainderReprint(
          apparatus: apparatus,
          orderId: 'order-1',
          operationId: 'remainder-operation'),
      () => MockClient((request) async {
        requests.add(request);
        return http.Response(
            jsonEncode({
              'ok': true,
              'remainder': remainderPayload(),
              'print': {'ok': false, 'status': 'print_failed'},
            }),
            200);
      }),
    );
    expect(requests.single.url.path,
        '/v1/mobile/admin/production-maps/layer-remainders/reprint');
    expect(jsonDecode(requests.single.body), {
      'apparatus': apparatus,
      'order_id': 'order-1',
      'operation_id': 'remainder-operation',
      'print_count': 1,
    });
  });
}
