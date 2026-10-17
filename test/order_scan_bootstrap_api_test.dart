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
    expect(result.materialAssignments, isNull);
    expect(result.inputProgressBatches, isNull);
  });
  test('bootstrap scoped candidate sections match independent decoders',
      () async {
    final body = _candidateSectionsBootstrap();
    final sections = body['sections'] as Map;
    final result = AdminOrderScanBootstrap.fromJson(body,
        apparatus: scanApparatus, orderId: scanOrder);
    await http.runWithClient(() async {
      final assignments = await MobileApi.instance.adminRawMaterialAssignments(
          orderId: scanOrder, apparatus: scanApparatus);
      final batches = await MobileApi.instance.adminWipBatches(
          orderId: scanOrder, status: 'waiting', limit: 500);
      final assignment = result.materialAssignments!.single;
      expect(assignment.orderId, assignments.single.orderId);
      expect(assignment.apparatus, assignments.single.apparatus);
      expect(assignment.barcode, assignments.single.barcode);
      expect(assignment.itemName, assignments.single.itemName);
      expect(assignment.stockQty, assignments.single.stockQty);
      expect(assignment.receivedQty, assignments.single.receivedQty);
      expect(assignment.consumedQty, assignments.single.consumedQty);
      expect(assignment.remainingQty, assignments.single.remainingQty);
      final batch = result.inputProgressBatches!.single;
      expect(batch.batchId, batches.single.batchId);
      expect(batch.orderId, batches.single.orderId);
      expect(batch.apparatus, batches.single.apparatus);
      expect(batch.nextApparatus, batches.single.nextApparatus);
      expect(batch.producedQty, batches.single.producedQty);
      expect(batch.uom, batches.single.uom);
      expect(batch.qrPayload, batches.single.qrPayload);
      expect(batch.payloadJson, batches.single.payloadJson);
      expect(batch.hasInputRouteMetadata, isFalse);
    }, () => MockClient((request) async {
      final section = request.url.path.endsWith('/wip-batches')
          ? 'input_progress' : 'material_assignments';
      return http.Response(jsonEncode(sections[section]['data']), 200);
    }));
  });
  test('bootstrap explicit empty scoped candidate pages can be reused', () {
    final body = _candidateSectionsBootstrap();
    body['sections']['material_assignments']['data'] = <Object>[];
    body['sections']['input_progress']['data'] = {'batches': <Object>[]};
    final result = AdminOrderScanBootstrap.fromJson(body,
        apparatus: scanApparatus, orderId: scanOrder);
    expect(result.materialAssignments, isEmpty);
    expect(result.inputProgressBatches, isEmpty);
  });
  for (final section in ['material_assignments', 'input_progress']) {
    for (final invalid in [
      'missing', 'null', 'not required', 'failed', 'partial', 'missing status',
      'wrong apparatus', 'wrong order', 'wrong stage', 'missing stage',
      'missing data', 'malformed data',
    ]) {
      test('bootstrap $section independently falls back for $invalid', () {
        final body = _candidateSectionsBootstrap();
        final sections = body['sections'] as Map;
        final raw = sections[section] as Map;
        switch (invalid) {
          case 'missing': sections.remove(section);
          case 'null': sections[section] = null;
          case 'not required': raw['status'] = 'not_required';
          case 'failed': raw['status'] = 'failed';
          case 'partial': raw['status'] = 'partial';
          case 'missing status': raw.remove('status');
          case 'wrong apparatus': raw['apparatus'] = 'apparatus:default:other';
          case 'wrong order': raw['order_id'] = 'other-order';
          case 'wrong stage': raw['stage_node_id'] = 'other-occurrence';
          case 'missing stage': raw.remove('stage_node_id');
          case 'missing data': raw.remove('data');
          case 'malformed data': raw['data'] = 'not-a-list';
        }
        final result = AdminOrderScanBootstrap.fromJson(body,
            apparatus: scanApparatus, orderId: scanOrder);
        expect(section == 'material_assignments'
            ? result.materialAssignments : result.inputProgressBatches, isNull);
        expect(section == 'material_assignments'
            ? result.inputProgressBatches : result.materialAssignments,
            hasLength(1));
        expect(result.materials, isNotNull);
        expect(result.qolips, isNotNull);
      });
    }
  }
  for (final invalid in [
    'non row', 'order', 'apparatus', 'empty barcode', 'barcode type',
    'duplicate barcode', 'missing item name', 'quantity type',
  ]) {
    test('bootstrap rejects incomplete material assignment page: $invalid', () {
      final body = _candidateSectionsBootstrap();
      final rows = body['sections']['material_assignments']['data'] as List;
      final row = rows.single as Map;
      switch (invalid) {
        case 'non row': rows.add(null);
        case 'order': row['order_id'] = 'other';
        case 'apparatus': row['apparatus'] = 'Bosma 7';
        case 'empty barcode': row['barcode'] = '  ';
        case 'barcode type': row['barcode'] = 1;
        case 'duplicate barcode':
          rows.add({...row, 'barcode': ' roll1 '});
        case 'missing item name': row.remove('item_name');
        case 'quantity type': row['stock_qty'] = '10';
      }
      final result = AdminOrderScanBootstrap.fromJson(body,
          apparatus: scanApparatus, orderId: scanOrder);
      expect(result.materialAssignments, isNull);
      expect(result.inputProgressBatches, hasLength(1));
    });
  }
  for (final invalid in [
    'missing limit', 'wrong limit', 'non integer limit', 'wrong filter',
    'missing batches', 'too many rows', 'non row', 'wrong order',
    'used status', 'batch id type', 'empty batch id', 'QR type', 'empty QR',
    'duplicate id', 'duplicate QR', 'apparatus', 'quantity type', 'payload type',
  ]) {
    test('bootstrap rejects incomplete input candidate page: $invalid', () {
      final body = _candidateSectionsBootstrap();
      final section = body['sections']['input_progress'] as Map;
      final rows = section['data']['batches'] as List;
      final row = rows.single as Map;
      switch (invalid) {
        case 'missing limit': section.remove('limit');
        case 'wrong limit': section['limit'] = 50;
        case 'non integer limit': section['limit'] = 500.0;
        case 'wrong filter': section['status_filter'] = 'all';
        case 'missing batches': section['data'] = <String, dynamic>{};
        case 'too many rows':
          section['data']['batches'] = List.generate(501, (index) => {
            ...row, 'batch_id': 'batch-$index', 'qr_payload': 'qr-$index',
          });
        case 'non row': rows.add(null);
        case 'wrong order': row['order_id'] = 'other';
        case 'used status': row['wip_status'] = 'in_use';
        case 'batch id type': row['batch_id'] = 123;
        case 'empty batch id': row['batch_id'] = ' ';
        case 'QR type': row['qr_payload'] = 123;
        case 'empty QR': row['qr_payload'] = ' ';
        case 'duplicate id': rows.add({...row, 'qr_payload': 'other-qr'});
        case 'duplicate QR': rows.add({
          ...row, 'batch_id': 'other-batch', 'qr_payload': ' ${_scanQr.toLowerCase()} ',
        });
        case 'apparatus': row['apparatus'] = 'Bosma 7';
        case 'quantity type': row['produced_qty'] = '484';
        case 'payload type': row['payload_json'] = [1, 2];
      }
      final result = AdminOrderScanBootstrap.fromJson(body,
          apparatus: scanApparatus, orderId: scanOrder);
      expect(result.inputProgressBatches, isNull);
      expect(result.materialAssignments, hasLength(1));
    });
  }
  test('bootstrap retains full bounded page without filtering or claiming proof',
      () {
    final body = _candidateSectionsBootstrap();
    final raw = body['sections']['input_progress']['data']['batches'][0] as Map;
    body['sections']['input_progress']['data']['batches'] =
        List.generate(500, (index) => {
      ...raw, 'batch_id': 'batch-$index', 'qr_payload': 'qr-$index',
      'next_apparatus': 'apparatus:default:alternative',
    });
    final result = AdminOrderScanBootstrap.fromJson(body,
        apparatus: scanApparatus, orderId: scanOrder);
    expect(result.inputProgressBatches, hasLength(500));
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

Map<String, dynamic> _candidateSectionsBootstrap() {
  final body = scanBootstrap();
  final scope = {
    'status': 'ready',
    'apparatus': scanApparatus,
    'order_id': scanOrder,
    'stage_node_id': 'apparatus',
  };
  body['sections']['material_assignments'] = {
    ...scope,
    'data': <Object?>[{
      ...scanAssignment(),
      'received_qty': 12,
      'consumed_qty': 2,
      'remaining_qty': 10,
    }],
  };
  body['sections']['input_progress'] = {
    ...scope,
    'limit': 500,
    'status_filter': 'waiting',
    'data': {'batches': [
      _contextBootstrap()['validated_progress']['batch'],
    ]},
  };
  return body;
}

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
