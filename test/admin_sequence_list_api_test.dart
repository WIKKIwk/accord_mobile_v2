import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'order_scan_bootstrap_fixtures.dart';

Map<String, dynamic> _summary() => {
      'projection': 'sequence_list_v1',
      'ok': true,
      'version': 'v1',
      'epoch': 'server',
      'rev': 1,
      'scope': 'selected-scope',
      'offset': 0,
      'total': 2,
      'next_cursor': null,
      'order_ids': ['zakaz-1', 'training-zakaz-2'],
      'sequence_positions': {'zakaz-1': 4, 'training-zakaz-2': 12},
      'sequence_versions': {scanApparatus: 's1'},
      'sequence_revisions': {scanApparatus: 1},
      'queue_policies': [
        {
          'apparatus_id': scanApparatus,
          'apparatus': '7 rang',
          'policy': 'strict_sequence',
          'locked': false,
          'reason': ''
        },
      ],
      'rows': {
        for (final id in ['zakaz-1', 'training-zakaz-2'])
          id: {
            'id': id,
            'code': id,
            'title': 'O‘zbek 😀',
            'customer_name': 'Xaridor',
            'image_id': 'photo-1',
            'queue_state': 'pending',
            'display_state': 'pending',
            'can_reorder': true,
          },
      },
    };

Map<String, dynamic> _fullDetail() => {
      ...scanSequence(),
      'scope': 'detail-scope',
      'sequence_versions': {scanApparatus: 's7'},
      'sequence_revisions': {scanApparatus: 7},
      'maps': [
        {
          'map': {
            'id': scanOrder,
            'product_code': 'P1',
            'title': 'Full order',
            'nodes': [],
            'edges': []
          },
          'program': {
            'map_id': scanOrder,
            'product_code': 'P1',
            'operations': []
          },
        }
      ],
    };

AdminProductionMapPageWindowMessage _delta(List<Map<String, Object?>> ops) =>
    AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_delta',
      'window': 'w',
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
          ]
        }
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AppSession.instance.token = 'sequence-list-token');
  tearDown(() => AppSession.instance.token = null);

  test('summary decodes independently from canonical maps on both paths',
      () async {
    final wire = _summary();
    for (final page in [
      await AdminProductionOrderPage.fromJson(wire),
      await AdminProductionOrderPage.fromPayload(jsonEncode(wire)),
      await AdminProductionOrderPage.fromPayload(jsonEncode(wire),
          backgroundThresholdCodeUnits: 0),
    ]) {
      expect(page.isSequenceList, isTrue);
      expect(page.snapshot, isNull);
      expect(page.scope, 'selected-scope');
      expect(page.sequenceRows.length, 2);
      expect(page.sequencePositions['training-zakaz-2'], 12);
      expect(page.sequenceVersions[scanApparatus], 's1');
      expect(page.sequenceRevisions[scanApparatus], 1);
      expect(page.queuePolicies[scanApparatus]!.apparatus, '7 rang');
      final row = page.sequenceRows['zakaz-1']!;
      expect(row.title, 'O‘zbek 😀');
      expect(row.toPresentationOrder().map.nodes, isEmpty);
      expect(row.toPresentationOrder().map.imageId, 'photo-1');
      expect(() => page.sequenceRows.clear(), throwsUnsupportedError);
    }
  });

  test('all semantic display states remain distinct from queue states',
      () async {
    for (final state in adminSequenceListDisplayStates) {
      final wire = _summary();
      wire['rows']['zakaz-1']['display_state'] = state;
      final page = await AdminProductionOrderPage.fromJson(wire);
      expect(page.sequenceRows['zakaz-1']!.displayState, state);
      expect(page.sequenceRows['zakaz-1']!.queueState, 'pending');
    }
  });

  test('malformed summary rows, authority, ranks and mixed payloads reject',
      () async {
    final mutations = <void Function(Map<String, dynamic>)>[
      (wire) => wire['rows'].remove('zakaz-1'),
      (wire) => wire['rows']['zakaz-1'].remove('customer_name'),
      (wire) => wire['rows']['zakaz-1']['id'] = 'other',
      (wire) => wire['rows']['zakaz-1']['queue_state'] = 'unknown',
      (wire) => wire['rows']['zakaz-1']['display_state'] = 'unknown',
      (wire) => wire['rows']['zakaz-1']['can_reorder'] = 'true',
      (wire) => wire['sequence_positions'].remove('zakaz-1'),
      (wire) => wire['order_ids'] = ['zakaz-1', 'zakaz-1'],
      (wire) => wire['scope'] = '',
      (wire) => wire['rev'] = 1.5,
      (wire) => wire['sequence_versions'] = {},
      (wire) => wire['sequence_revisions'] = {scanApparatus: -1},
      (wire) => wire['queue_policies'] = [],
      (wire) => wire['queue_policies'][0]['policy'] = 'future_policy',
      (wire) => wire['queue_policies'].add(wire['queue_policies'].first),
      (wire) => wire['maps'] = [],
      (wire) => wire['projection'] = 'future_projection',
    ];
    for (final mutate in mutations) {
      final wire = _summary();
      mutate(wire);
      await expectLater(AdminProductionOrderPage.fromJson(wire),
          throwsA(isA<MobileApiException>()));
    }
  });

  test('sparse row update preserves untouched rows and original baseline',
      () async {
    final before = await AdminProductionOrderPage.fromJson(_summary());
    final after = (await applyAdminOrderPageWindow(
            [before],
            _delta([
              {
                'op': 'set',
                'path': ['rows', 'zakaz-1', 'display_state'],
                'value': 'issue'
              },
              {
                'op': 'set',
                'path': ['sequence_revisions', scanApparatus],
                'value': 2
              },
              {
                'op': 'set',
                'path': ['sequence_versions', scanApparatus],
                'value': 's2'
              },
            ])))
        .single;
    expect(after.sequenceRows['zakaz-1']!.displayState, 'issue');
    expect(before.sequenceRows['zakaz-1']!.displayState, 'pending');
    expect(after.sequenceVersions[scanApparatus], 's2');
    expect(
        identical(after.sequenceRows['training-zakaz-2'],
            before.sequenceRows['training-zakaz-2']),
        isTrue);
    final roundTrip = await AdminProductionOrderPage.fromJson(after.wireValue!);
    expect(roundTrip.sequenceRows['zakaz-1']!.displayState, 'issue');
    expect(roundTrip.snapshot, isNull);
  });

  test('checkpoint retains summary authority and row identity', () async {
    final before = await AdminProductionOrderPage.fromJson(_summary());
    final after = (await applyAdminOrderPageWindow(
            [before],
            AdminProductionMapPageWindowMessage.fromJson({
              'type': 'page_window_checkpoint',
              'window': 'w',
              'epoch': 'server',
              'base_version': 'v1',
              'version': 'v2',
              'rev': 2,
              'next_cursors': [null],
            })))
        .single;
    expect(identical(before.sequenceRows, after.sequenceRows), isTrue);
    expect(after.sequenceVersions[scanApparatus], 's1');
    expect(after.scope, 'selected-scope');
    expect(after.revision, 2);
  });

  test('malformed delta and scope replacement reject atomically', () async {
    final before = await AdminProductionOrderPage.fromJson(_summary());
    for (final ops in [
      [
        {
          'op': 'remove',
          'path': ['rows', 'zakaz-1']
        }
      ],
      [
        {
          'op': 'set',
          'path': ['scope'],
          'value': 'other-scope'
        }
      ],
      [
        {
          'op': 'set',
          'path': ['rows', 'zakaz-1', 'display_state'],
          'value': 'bad'
        }
      ],
    ]) {
      await expectLater(applyAdminOrderPageWindow([before], _delta(ops)),
          throwsA(isA<MobileApiException>()));
      expect(before.sequenceRows['zakaz-1']!.displayState, 'pending');
    }
  });

  test('old server complete page remains a canonical full-page fallback',
      () async {
    final page = await AdminProductionOrderPage.fromJson({
      ..._fullDetail(),
      'version': 'old',
      'offset': 0,
      'total': 1,
      'next_cursor': null,
      'order_ids': [scanOrder],
    });
    expect(page.isSequenceList, isFalse);
    expect(page.sequenceRows, isEmpty);
    expect(page.snapshot!.maps.single.map.id, scanOrder);
    expect(page.sequenceVersions[scanApparatus], 's7');
  });

  test('identity experiment is scoped and old server full pages still decode',
      () async {
    await http.runWithClient(() async {
      final sequence = await MobileApi.instance.adminProductionOrderPage(
          const AdminProductionOrderPageRequest(
              view: 'sequence', apparatus: scanApparatus));
      expect(sequence!.isSequenceList, isFalse);
      expect(sequence.snapshot!.maps.single.map.id, scanOrder);
      await MobileApi.instance.adminProductionOrderPage(
          const AdminProductionOrderPageRequest(view: 'closed'));
    },
        () => MockClient((request) async {
              expect(
                  request.headers.keys
                      .any((key) => key.toLowerCase() == 'accept-encoding'),
                  isFalse);
              if (request.url.queryParameters['view'] == 'sequence') {
                expect(request.url.queryParameters['compression'],
                    adminProductionReadIdentityCompression ? 'identity' : null);
                return http.Response(
                    jsonEncode({
                      ..._fullDetail(),
                      'version': 'old',
                      'offset': 0,
                      'total': 1,
                      'next_cursor': null,
                      'order_ids': [scanOrder]
                    }),
                    200);
              }
              expect(request.url.queryParameters.containsKey('compression'),
                  isFalse);
              return http.Response(
                  jsonEncode({
                    'version': 'closed',
                    'epoch': 'server',
                    'rev': 1,
                    'offset': 0,
                    'total': 0,
                    'next_cursor': null,
                    'closed_orders': []
                  }),
                  200);
            }));
  });

  test('detail requests exactly one stable order ID with full canonical data',
      () async {
    await http.runWithClient(() async {
      final detail = await MobileApi.instance.adminProductionOrderDetail(
          apparatus: scanApparatus, orderId: scanOrder);
      expect(detail.maps.single.map.title, 'Full order');
      expect(
          detail.queueActionControls[scanApparatus]![scanOrder]!.contractValid,
          isTrue);
    },
        () => MockClient((request) async {
              expect(request.url.path,
                  '/v1/mobile/admin/production-maps/sequence');
              expect(request.url.queryParameters, {
                'apparatus': scanApparatus,
                'order_id': scanOrder,
                'detail': 'true',
                if (adminProductionReadIdentityCompression)
                  'compression': 'identity',
              });
              return http.Response(jsonEncode(_fullDetail()), 200);
            }));
  });

  test('detail rejects omitted, wrong or multiple maps and missing authority',
      () async {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (wire) => wire['maps'] = [],
      (wire) => wire['maps'][0]['map']['id'] = 'wrong',
      (wire) => wire['maps'].add(wire['maps'].first),
      (wire) => wire['scope'] = '',
      (wire) => wire['epoch'] = '',
    ]) {
      final wire = _fullDetail();
      mutate(wire);
      await http.runWithClient(() async {
        await expectLater(
            MobileApi.instance.adminProductionOrderDetail(
                apparatus: scanApparatus, orderId: scanOrder),
            throwsA(isA<MobileApiException>()));
      }, () => MockClient((_) async => http.Response(jsonEncode(wire), 200)));
    }
  });
}
