import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'order_scan_bootstrap_fixtures.dart';

Map<String, dynamic> _orders() => {
      'projection': 'orders_list_v1',
      'version': 'v1',
      'epoch': 'server',
      'rev': 1,
      'scope': 'orders-scope',
      'offset': 0,
      'total': 3,
      'next_cursor': null,
      'order_ids': ['zakaz-1', 'zakaz-2'],
      'pending_ids': ['pending-3'],
      'pending_rows': {
        'pending-3': {
          'id': 'pending-3',
          'code': '3',
          'title': 'Pending product',
          'customer_name': 'Pending customer',
          'image_id': 'pending-image',
          'kg': 500.5,
        },
      },
      'rows': {
        for (final id in ['zakaz-1', 'zakaz-2'])
          id: {
            'id': id,
            'code': id,
            'title': 'O‘zbek 😀',
            'customer_name': 'Xaridor',
            'image_id': 'photo-1',
            'display_state': 'in_progress',
            'watermarks': [
              {'apparatus_id': scanApparatus, 'kind': 'active'},
            ],
          },
      },
    };

Map<String, dynamic> _detail() => {
      ...scanSequence(),
      'scope': 'generic-detail-scope',
      'calculation_templates': {
        scanOrder: {'kg': 500, 'width_mm': 650, 'frame_count': 2},
      },
      'maps': [
        {
          'map': {
            'id': scanOrder,
            'product_code': 'P1',
            'title': 'Full order',
            'nodes': [],
            'edges': [],
          },
          'program': {
            'map_id': scanOrder,
            'product_code': 'P1',
            'operations': [],
          },
        },
      ],
    };

AdminProductionMapPageWindowMessage _delta(List<Map<String, Object?>> ops) =>
    AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_delta',
      'window': 'orders-w',
      'epoch': 'server',
      'base_version': 'v1',
      'version': 'v2',
      'rev': 2,
      'page_count': 1,
      'changes': [
        {
          'index': 0,
          'ops': [
            {
              'op': 'set',
              'path': ['version'],
              'value': 'v2'
            },
            {
              'op': 'set',
              'path': ['rev'],
              'value': 2
            },
            ...ops,
          ],
        },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AppSession.instance.token = 'orders-list-token');
  tearDown(() => AppSession.instance.token = null);

  test('Orders rows decode on every path without canonical maps or templates',
      () async {
    final wire = _orders();
    for (final page in [
      await AdminProductionOrderPage.fromJson(wire),
      await AdminProductionOrderPage.fromJson(wire,
          backgroundThresholdCodeUnits: 0),
      await AdminProductionOrderPage.fromPayload(jsonEncode(wire)),
      await AdminProductionOrderPage.fromPayload(jsonEncode(wire),
          backgroundThresholdCodeUnits: 0),
    ]) {
      expect(page.isOrdersList, isTrue);
      expect(page.isList, isTrue);
      expect(page.isSequenceList, isFalse);
      expect(page.length, 3);
      expect(page.snapshot, isNull);
      expect(page.sequenceRows, isEmpty);
      expect(page.queuePolicies, isEmpty);
      expect(page.sequenceVersions, isEmpty);
      expect(page.sequenceRevisions, isEmpty);
      expect(page.calculationTemplates, isEmpty);
      expect(page.pendingOrders, isEmpty);
      expect(page.pendingIds, ['pending-3']);
      expect(page.pendingRows['pending-3']!.kg, 500.5);
      expect(page.orderRows['zakaz-1']!.title, 'O‘zbek 😀');
      final row = page.orderRows['zakaz-1']!;
      expect(row.watermarks.single.kind, 'active');
      expect(row.watermarks.single.apparatusId, scanApparatus);
      expect(identical(row.toPresentationOrder(), row.toPresentationOrder()),
          isTrue);
      expect(row.toPresentationOrder().map.nodes, isEmpty);
      expect(row.toPresentationOrder().program.operations, isEmpty);
      expect(() => page.orderRows.clear(), throwsUnsupportedError);
      expect(() => page.pendingRows.clear(), throwsUnsupportedError);
      expect(() => page.pendingIds.clear(), throwsUnsupportedError);
      expect(() => row.watermarks.clear(), throwsUnsupportedError);
    }
  });

  test('empty Orders page retains the compact typed contract', () async {
    final page = await AdminProductionOrderPage.fromJson({
      ..._orders(),
      'total': 0,
      'order_ids': [],
      'rows': {},
      'pending_ids': [],
      'pending_rows': {},
    });
    expect(page.length, 0);
    expect(page.isList, isTrue);
    expect(page.snapshot, isNull);
  });

  test('Orders presentation states and generic watermark kinds remain readable',
      () async {
    for (final state in adminSequenceListDisplayStates) {
      final wire = _orders();
      wire['rows']['zakaz-1']['display_state'] = state;
      wire['rows']['zakaz-1']['watermarks'] = [
        for (final kind in ['active', 'paused', 'frozen', 'issue', 'waiting'])
          {'apparatus_id': '', 'kind': kind},
      ];
      final page = await AdminProductionOrderPage.fromJson(wire);
      expect(page.orderRows['zakaz-1']!.displayState, state);
      expect(page.orderRows['zakaz-1']!.watermarks.length, 5);
    }
  });

  test('Orders rejects malformed labels, mixed authority, pending and paging',
      () async {
    final mutations = <void Function(Map<String, dynamic>)>[
      (w) => w['rows'].remove('zakaz-1'),
      (w) => w['rows']['zakaz-1']['id'] = 'wrong',
      (w) => w['rows']['zakaz-1'].remove('title'),
      (w) => w['rows']['zakaz-1']['display_state'] = 'unknown',
      (w) => w['rows']['zakaz-1']['watermarks'] = 'bad',
      (w) => w['rows']['zakaz-1']['watermarks'] = [null],
      (w) => w['rows']['zakaz-1']['watermarks'][0]['kind'] = 'unknown',
      (w) => w['rows']['zakaz-1']['watermarks'][0]['apparatus_id'] = 'bad',
      (w) => w['pending_ids'] = ['pending-3', 'pending-3'],
      (w) => w['pending_ids'] = ['zakaz-1'],
      (w) => w['pending_ids'] = [null],
      (w) => w.remove('pending_ids'),
      (w) => w['pending_rows']['pending-3']['id'] = 'other',
      (w) => w['pending_rows']['pending-3']['kg'] = '500',
      (w) => w['pending_rows']['pending-3']['kg'] = double.infinity,
      (w) => w['pending_rows']['pending-3'].remove('image_id'),
      (w) => w['pending_rows'].clear(),
      (w) => w['rows']['extra'] = w['rows']['zakaz-1'],
      (w) => w['order_ids'] = ['zakaz-1', 'zakaz-1'],
      (w) => w['scope'] = '',
      (w) => w['rev'] = 1.5,
      (w) => w['total'] = 2,
      (w) => w['next_cursor'] = 'unexpected',
      (w) => w['sequence_positions'] = {'zakaz-1': 1, 'zakaz-2': 2},
      for (final key in [
        'maps',
        'sequence_versions',
        'queue_policies',
        'order_controls',
        'calculation_templates',
        'pending_orders',
        'stage_states',
      ])
        (w) => w[key] = {},
    ];
    for (var i = 0; i < mutations.length; i++) {
      final wire = _orders();
      mutations[i](wire);
      await expectLater(AdminProductionOrderPage.fromJson(wire),
          throwsA(isA<MobileApiException>()),
          reason: 'mutation $i');
    }
  });

  test('sparse Orders updates retain untouched active and pending row identity',
      () async {
    final before = await AdminProductionOrderPage.fromJson(_orders());
    final after = (await applyAdminOrderPageWindow(
            [before],
            _delta([
              {
                'op': 'set',
                'path': ['rows', 'zakaz-1', 'title'],
                'value': 'New'
              },
            ])))
        .single;
    expect(after.orderRows['zakaz-1']!.title, 'New');
    expect(before.orderRows['zakaz-1']!.title, 'O‘zbek 😀');
    expect(identical(before.orderRows['zakaz-2'], after.orderRows['zakaz-2']),
        isTrue);
    expect(
        identical(
            before.pendingRows['pending-3'], after.pendingRows['pending-3']),
        isTrue);
    expect(after.snapshot, isNull);
    final restored = await AdminProductionOrderPage.fromJson(after.wireValue!);
    expect(restored.orderRows['zakaz-1']!.title, 'New');
    expect(restored.pendingRows['pending-3']!.kg, 500.5);
  });

  test('sparse pending change does not reallocate active card models',
      () async {
    final before = await AdminProductionOrderPage.fromJson(_orders());
    final after = (await applyAdminOrderPageWindow(
            [before],
            _delta([
              {
                'op': 'set',
                'path': ['pending_rows', 'pending-3', 'kg'],
                'value': 200
              },
            ])))
        .single;
    expect(after.pendingRows['pending-3']!.kg, 200);
    expect(before.pendingRows['pending-3']!.kg, 500.5);
    expect(identical(before.orderRows['zakaz-1'], after.orderRows['zakaz-1']),
        isTrue);
  });

  test('metadata checkpoint retains Orders row collections', () async {
    final before = await AdminProductionOrderPage.fromJson(_orders());
    final after = (await applyAdminOrderPageWindow(
            [before],
            AdminProductionMapPageWindowMessage.fromJson({
              'type': 'page_window_checkpoint',
              'window': 'orders-w',
              'epoch': 'server',
              'base_version': 'v1',
              'version': 'v2',
              'rev': 2,
              'next_cursors': [null],
            })))
        .single;
    expect(identical(before.orderRows, after.orderRows), isTrue);
    expect(identical(before.pendingRows, after.pendingRows), isTrue);
    expect(identical(before.pendingIds, after.pendingIds), isTrue);
    expect(after.revision, 2);
  });

  test('malformed sparse Orders updates reject without changing baseline',
      () async {
    final before = await AdminProductionOrderPage.fromJson(_orders());
    for (final ops in [
      [
        {
          'op': 'set',
          'path': ['scope'],
          'value': 'other'
        }
      ],
      [
        {
          'op': 'set',
          'path': ['rows', 'zakaz-1', 'display_state'],
          'value': 'bad'
        }
      ],
      [
        {
          'op': 'set',
          'path': ['pending_rows', 'pending-3', 'kg'],
          'value': null
        }
      ],
      [
        {
          'op': 'set',
          'path': ['maps'],
          'value': []
        }
      ],
    ]) {
      await expectLater(applyAdminOrderPageWindow([before], _delta(ops)),
          throwsA(isA<MobileApiException>()));
      expect(before.orderRows['zakaz-1']!.displayState, 'in_progress');
      expect(before.pendingRows['pending-3']!.kg, 500.5);
    }
  });

  test('Orders requests opt-in summary and keeps conditional scope parameters',
      () async {
    await http.runWithClient(() async {
      final page = await MobileApi.instance.adminProductionOrderPage(
          const AdminProductionOrderPageRequest(
              view: 'orders', search: 'x', cursor: 'next', ifVersion: 'v0'));
      expect(page!.isOrdersList, isTrue);
    },
        () => MockClient((request) async {
              expect(request.url.queryParameters, {
                'view': 'orders',
                'limit': '20',
                'projection': 'orders_list_v1',
                'search': 'x',
                'cursor': 'next',
                'if_version': 'v0',
                if (adminProductionReadIdentityCompression)
                  'compression': 'identity',
              });
              expect(
                  request.headers.keys
                      .any((k) => k.toLowerCase() == 'accept-encoding'),
                  isFalse);
              return http.Response(jsonEncode(_orders()), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });

  test('old server full Orders pages remain a compatible fallback', () async {
    await http.runWithClient(() async {
      final page = await MobileApi.instance.adminProductionOrderPage(
          const AdminProductionOrderPageRequest(view: 'orders'));
      expect(page!.isList, isFalse);
      expect(page.snapshot!.maps.single.map.id, scanOrder);
      expect(page.calculationTemplates[scanOrder]!.kg, 500);
      expect(
          identical(
              page.calculationTemplates, page.snapshot!.calculationTemplates),
          isTrue);
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({
              ..._detail(),
              'version': 'legacy',
              'offset': 0,
              'total': 1,
              'order_ids': [scanOrder],
              'next_cursor': null,
            }),
            200)));
  });

  test('Orders accepts conditional 304 without decoding an empty body',
      () async {
    await http.runWithClient(() async {
      expect(
          await MobileApi.instance.adminProductionOrderPage(
              const AdminProductionOrderPageRequest(
                  view: 'orders', ifVersion: 'v1')),
          isNull);
    }, () => MockClient((_) async => http.Response('', 304)));
  });

  test('generic detail omits apparatus and fetches exactly one canonical order',
      () async {
    await http.runWithClient(() async {
      final snapshot = await MobileApi.instance
          .adminProductionOrderDetail(apparatus: '', orderId: scanOrder);
      expect(snapshot.maps.single.map.id, scanOrder);
      expect(snapshot.maps.single.map.title, 'Full order');
      expect(snapshot.scope, 'generic-detail-scope');
      expect(snapshot.calculationTemplates[scanOrder]!.kg, 500);
      final restored = decodeCachedProductionMapQueueSnapshot(
          encodeProductionMapQueueSnapshot(snapshot));
      expect(restored.calculationTemplates[scanOrder]!.widthMm, 650);
      expect(restored.calculationTemplates[scanOrder]!.frameCount, 2);
      expect(
          () => snapshot.calculationTemplates.clear(), throwsUnsupportedError);
    },
        () => MockClient((request) async {
              expect(request.url.path,
                  '/v1/mobile/admin/production-maps/sequence');
              expect(request.url.queryParameters, {
                'order_id': scanOrder,
                'detail': 'true',
                if (adminProductionReadIdentityCompression)
                  'compression': 'identity',
              });
              return http.Response(jsonEncode(_detail()), 200);
            }));
  });

  test('full detail rejects templates for another order or invalid shape',
      () async {
    for (final value in [
      {
        'wrong-order': {'kg': 100}
      },
      {
        '': {'kg': 100}
      },
      {scanOrder: 'bad'},
      [],
    ]) {
      await http.runWithClient(() async {
        await expectLater(
            MobileApi.instance
                .adminProductionOrderDetail(apparatus: '', orderId: scanOrder),
            throwsA(isA<MobileApiException>()));
      },
          () => MockClient((_) async => http.Response(
              jsonEncode({
                ..._detail(),
                'calculation_templates': value,
              }),
              200)));
    }
  });

  test('invalid nonempty apparatus and empty IDs never issue detail GET',
      () async {
    await http.runWithClient(() async {
      for (final (apparatus, id) in [('bad', scanOrder), ('', ' ')]) {
        await expectLater(
            MobileApi.instance
                .adminProductionOrderDetail(apparatus: apparatus, orderId: id),
            throwsA(isA<MobileApiException>()));
      }
      await expectLater(MobileApi.instance.pendingOrderDetail(' '),
          throwsA(isA<MobileApiException>()));
    }, () => MockClient((_) async => fail('Unexpected request')));
  });

  test('pending detail requests one ID and retains complete calculation data',
      () async {
    await http.runWithClient(() async {
      final pending =
          await MobileApi.instance.pendingOrderDetail(' pending-3 ');
      expect(pending.id, 'pending-3');
      expect(pending.template.kg, 500);
      expect(pending.template.frameCount, 2);
      expect(pending.template.productionOptions, isNotNull);
    },
        () => MockClient((request) async {
              expect(request.url.path, '/v1/mobile/admin/pending-orders');
              expect(request.url.queryParameters, {'id': 'pending-3'});
              return http.Response(
                  jsonEncode({
                    'id': 'pending-3',
                    'manager_name': 'Manager',
                    'template': {
                      'kg': 500,
                      'frame_count': 2,
                      'production_options': {}
                    },
                  }),
                  200);
            }));
  });

  test('pending detail rejects wrong IDs, list responses and HTTP errors',
      () async {
    for (final response in [
      http.Response(jsonEncode({'id': 'wrong', 'template': {}}), 200),
      http.Response(jsonEncode([]), 200),
      http.Response(jsonEncode({'error': 'missing'}), 404),
    ]) {
      await http.runWithClient(() async {
        await expectLater(MobileApi.instance.pendingOrderDetail('pending-3'),
            throwsA(isA<MobileApiException>()));
      }, () => MockClient((_) async => response));
    }
  });
}
