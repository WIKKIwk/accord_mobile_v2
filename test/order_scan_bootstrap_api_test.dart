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
    expect(result.queueContext, isNull);
    expect(result.validatedProgress, isNull);
  });
  test('bootstrap context and QR proof retain current scoped data', () {
    final body = _contextBootstrap();
    final result = AdminOrderScanBootstrap.fromJson(body,
        apparatus: scanApparatus, orderId: scanOrder, qrPayload: _scanQr);
    expect(result.queueContext!.maps.single.map.id, scanOrder);
    expect(result.queueContext!.revision, result.controlState.revision);
    expect(result.validatedProgress!.qrPayload, _scanQr);
    expect(result.validatedProgress!.inputRoute!.stageNodeId, 'apparatus');
    expect(result.validatedProgress!.hasInputRouteMetadata, isTrue);
    expect(result.validatedProgress!.producedQty, 484);
    expect(result.validatedProgress!.payloadJson['next_stage_node_id'],
        'historical-next');
  });
  test('bootstrap context accepts equivalent reordered control keys', () {
    final body = _contextBootstrap();
    final raw = body['queue_context']['queue_action_controls'][scanApparatus]
        [scanOrder] as Map;
    body['queue_context']['queue_action_controls'][scanApparatus][scanOrder] =
        Map<String, dynamic>.from(
            Map.fromEntries(raw.entries.toList().reversed));
    expect(
        AdminOrderScanBootstrap.fromJson(body,
                apparatus: scanApparatus,
                orderId: scanOrder,
                qrPayload: _scanQr)
            .queueContext,
        isNotNull);
  });
  test('bootstrap proof accepts backend case-insensitive QR identity', () {
    final result = AdminOrderScanBootstrap.fromJson(_contextBootstrap(),
        apparatus: scanApparatus,
        orderId: scanOrder,
        qrPayload: '  ${_scanQr.toLowerCase()}  ');
    expect(result.validatedProgress!.qrPayload, _scanQr);
  });
  test('thin bootstrap proof accepts backend null route error without context',
      () {
    final body = _contextBootstrap()..remove('queue_context');
    body['validated_progress']['input_route_error'] = null;
    body['sections'] = {};
    final result = AdminOrderScanBootstrap.fromJson(body,
        apparatus: scanApparatus, orderId: scanOrder, qrPayload: _scanQr);
    expect(result.queueContext, isNull);
    expect(result.materials, isNull);
    expect(result.qolips, isNull);
    expect(result.validatedProgress!.qrPayload, _scanQr);
  });
  for (final invalid in [
    'null',
    'epoch',
    'revision',
    'scope',
    'queue state',
    'stage states',
    'order control',
    'control',
    'missing target map',
    'empty map id',
    'duplicate map',
    'malformed map',
  ]) {
    test('bootstrap rejects supplied invalid queue context: $invalid', () {
      final body = _contextBootstrap();
      final context = body['queue_context'] as Map;
      switch (invalid) {
        case 'null':
          body['queue_context'] = null;
        case 'epoch':
          context['epoch'] = 'old-server';
        case 'revision':
          context['rev'] = 6;
        case 'scope':
          context['scope'] = 'other-worker';
        case 'queue state':
          context['queue_states'][scanApparatus][scanOrder] = 'paused';
        case 'stage states':
          context['stage_states'][scanOrder] = {'apparatus': 'completed'};
        case 'order control':
          context['order_controls'][scanOrder] = {'state': 'frozen'};
        case 'control':
          context['queue_action_controls'][scanApparatus][scanOrder]
              ['previous_stage'] = 'other-stage';
        case 'missing target map':
          context['maps'] = <Object>[];
        case 'empty map id':
          context['maps'][0]['map']['id'] = '';
        case 'duplicate map':
          context['maps'].add(context['maps'][0]);
        case 'malformed map':
          context['maps'].add({
            'map': {'id': 'other'},
            'program': null
          });
      }
      expect(
          () => AdminOrderScanBootstrap.fromJson(body,
              apparatus: scanApparatus, orderId: scanOrder, qrPayload: _scanQr),
          throwsA(isA<MobileApiException>()));
    });
  }
  for (final invalid in [
    'null',
    'ok',
    'active validation',
    'apparatus',
    'order',
    'batch order',
    'QR',
    'empty batch',
    'unknown status',
    'in use',
    'processed',
    'void',
    'route missing',
    'route error',
    'route wrong apparatus',
    'route incomplete',
    'request QR missing',
  ]) {
    test('bootstrap rejects supplied invalid progress proof: $invalid', () {
      final body = _contextBootstrap();
      final proof = body['validated_progress'] as Map;
      switch (invalid) {
        case 'null':
          body['validated_progress'] = null;
        case 'ok':
          proof['ok'] = false;
        case 'active validation':
          proof.remove('active_order_validated');
        case 'apparatus':
          proof['validated_apparatus'] = 'apparatus:default:asset-008';
        case 'order':
          proof['validated_order_id'] = 'other';
        case 'batch order':
          proof['batch']['order_id'] = 'other';
        case 'QR':
          proof['batch']['qr_payload'] = 'OTHER-QR';
        case 'empty batch':
          proof['batch']['batch_id'] = '';
        case 'unknown status':
          proof['batch']['wip_status'] = 'unknown';
        case 'in use':
          proof['batch']['wip_status'] = 'in_use';
        case 'processed':
          proof['batch']['wip_status'] = 'processed';
        case 'void':
          proof['batch']['wip_status'] = 'void';
        case 'route missing':
          proof.remove('input_route');
        case 'route error':
          proof['input_route_error'] = 'wip_route_ambiguous';
        case 'route wrong apparatus':
          proof['input_route']
              ['consumer_apparatus_ids'] = ['apparatus:default:asset-008'];
        case 'route incomplete':
          proof['input_route'].remove('map_fingerprint');
        case 'request QR missing':
          break;
      }
      expect(
          () => AdminOrderScanBootstrap.fromJson(body,
              apparatus: scanApparatus,
              orderId: scanOrder,
              qrPayload: invalid == 'request QR missing' ? '' : _scanQr),
          throwsA(isA<MobileApiException>()));
    });
  }
  test('bootstrap context and QR flags remain additive for older servers',
      () async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      final result = await MobileApi.instance.adminOrderScanBootstrap(
          apparatus: scanApparatus,
          orderId: scanOrder,
          includeContext: true,
          includeSections: false,
          qrPayload: '  $_scanQr  ');
      expect(result!.queueContext, isNull);
      expect(result.validatedProgress, isNull);
      expect(requests, hasLength(1));
      expect(requests.single.url.queryParameters, {
        'apparatus': scanApparatus,
        'order_id': scanOrder,
        'include_context': 'true',
        'include_sections': 'false',
        'qr_payload': _scanQr,
      });
    },
        () => MockClient((request) async {
              requests.add(request);
              return http.Response(jsonEncode(scanBootstrap()), 200);
            }));
  });
  test('bootstrap decodes context and QR proof in one authorized request',
      () async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      final result = await MobileApi.instance.adminOrderScanBootstrap(
          apparatus: scanApparatus,
          orderId: scanOrder,
          includeContext: true,
          qrPayload: _scanQr);
      expect(result!.queueContext!.maps.single.map.id, scanOrder);
      expect(result.validatedProgress!.batchId, 'scan-roll');
      expect(requests, hasLength(1));
      expect(requests.single.headers['Authorization'], 'Bearer scan-token');
    },
        () => MockClient((request) async {
              requests.add(request);
              return http.Response(jsonEncode(_contextBootstrap()), 200);
            }));
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

const _scanQr = '400118DF489A8D297E68163A';

Map<String, dynamic> _contextBootstrap() {
  final context = scanSequence();
  context['scope'] = 'scan-read-scope';
  context['maps'] = [
    {
      'map': {
        'id': scanOrder,
        'product_code': 'TEST',
        'title': 'Test',
        'nodes': [],
        'edges': []
      },
      'program': <String, dynamic>{}
    }
  ];
  return (jsonDecode(jsonEncode({
    ...scanBootstrap(),
    'queue_context': context,
    'validated_progress': {
      'ok': true,
      'active_order_validated': true,
      'validated_apparatus': scanApparatus,
      'validated_order_id': scanOrder,
      'can_resume': true,
      'batch': {
        'batch_id': 'scan-roll',
        'order_id': scanOrder,
        'qr_payload': _scanQr,
        'apparatus': 'apparatus:default:asset-008',
        'wip_status': 'waiting',
        'produced_qty': 484,
        'uom': 'm',
        'payload_json': {'next_stage_node_id': 'historical-next'},
      },
      'input_route': {
        'source_stage_node_id': 'previous',
        'stage_node_id': 'apparatus',
        'consumer_apparatus_ids': [scanApparatus],
        'map_fingerprint': 'scan-map',
        'remapped': true,
      },
      'input_route_error': '',
    },
  })) as Map)
      .cast<String, dynamic>();
}
