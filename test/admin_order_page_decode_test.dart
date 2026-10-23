import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'order_scan_bootstrap_fixtures.dart';

Map<String, dynamic> _pageWire() => {
      ...scanSequence(),
      'version': 'page-7',
      'total': 1,
      'offset': 0,
      'next_cursor': null,
      'order_ids': [scanOrder],
      'sequence_positions': {scanOrder: 9},
      'sequence_positions_by_apparatus': {
        scanApparatus: {scanOrder: 9},
      },
      'sequence_versions': {scanApparatus: 'sequence-7'},
      'sequence_revisions': {scanApparatus: 3},
      'stage_order_controls': [
        {
          'order_id': scanOrder,
          'stage_node_id': 'apparatus',
          'state': 'frozen',
          'freeze_request': {'target_apparatus': scanApparatus},
        },
      ],
      'maps': [
        {
          'map': {
            'id': scanOrder,
            'title': 'Buyurtma — ўзбек 😀',
            'product_code': 'P1',
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

AdminProductionMapPageWindowMessage _delta(List<Map<String, dynamic>> ops) =>
    AdminProductionMapPageWindowMessage.fromJson({
      'type': 'page_window_delta',
      'window': 'sequence-window',
      'epoch': 'scan-server',
      'base_version': 'page-7',
      'version': 'page-8',
      'rev': 8,
      'page_count': 1,
      'changes': [
        {
          'index': 0,
          'ops': [
            {
              'op': 'set',
              'path': ['version'],
              'value': 'page-8',
            },
            {
              'op': 'set',
              'path': ['rev'],
              'value': 8,
            },
            ...ops,
          ],
        },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('raw and decoded page paths preserve snapshot contracts and ranks',
      () async {
    final wire = _pageWire();
    final source = jsonEncode(wire);
    final expected = await decodeProductionMapQueueSnapshotPayload(source,
        backgroundThresholdCodeUnits: source.length + 1);
    final pages = [
      await AdminProductionOrderPage.fromPayload(source,
          backgroundThresholdCodeUnits: source.length + 1),
      await AdminProductionOrderPage.fromPayload(source,
          backgroundThresholdCodeUnits: 0),
      await AdminProductionOrderPage.fromJson(wire,
          backgroundThresholdCodeUnits: source.length * 2),
      await AdminProductionOrderPage.fromJson(wire,
          backgroundThresholdCodeUnits: 0),
    ];
    for (final page in pages) {
      expect(page.version, 'page-7');
      expect(page.revision, 7);
      expect(page.length, 1);
      expect(page.orderIds, [scanOrder]);
      expect(page.sequencePositions, {scanOrder: 9});
      expect(page.wireValue, wire);
      expect(encodeProductionMapQueueSnapshot(page.snapshot!),
          encodeProductionMapQueueSnapshot(expected));
      expect(page.snapshot!.stageFreezeSupported, isTrue);
      expect(page.snapshot!.stageOrderControls.single.state,
          AdminOrderControlState.frozen);
      expect(page.snapshot!.sequencePositionsByApparatus[scanApparatus],
          {scanOrder: 9});
      expect(
          page.snapshot!.queueActionControls[scanApparatus]![scanOrder]!
              .allows('start'),
          isTrue);
    }
    // Sparse patch identity checks require the original decoded wire baseline.
    expect(identical(pages[2].wireValue, wire), isTrue);
    expect(identical(pages[3].wireValue, wire), isTrue);
  });

  test('large page uses the same contracts at automatic thresholds', () async {
    final wire = _pageWire();
    ((wire['maps'] as List).single['map'] as Map)['title'] = 'ўзбек 😀' * 25000;
    final source = jsonEncode(wire);
    final raw = await AdminProductionOrderPage.fromPayload(source);
    final decoded = await AdminProductionOrderPage.fromJson(wire);
    expect(raw.snapshot!.maps.single.map.title,
        decoded.snapshot!.maps.single.map.title);
    expect(raw.wireValue, wire);
    expect(identical(decoded.wireValue, wire), isTrue);
    expect(decoded.snapshot!.stageFreezeSupported, isTrue);
  });

  test('all decoding paths still reject malformed page and action contracts',
      () async {
    final invalid = [
      {..._pageWire(), 'version': ''},
      {..._pageWire(), 'epoch': ''},
      {..._pageWire(), 'rev': -1},
      {..._pageWire(), 'total': 2},
      {
        ..._pageWire(),
        'order_ids': [scanOrder, scanOrder]
      },
      {
        ..._pageWire(),
        'sequence_positions': {scanOrder: 0}
      },
      {..._pageWire(), 'visible_order_ids': null},
      {..._pageWire(), 'queue_action_controls': null},
    ];
    for (final wire in invalid) {
      for (final threshold in [0, 1 << 30]) {
        await expectLater(
            AdminProductionOrderPage.fromPayload(jsonEncode(wire),
                backgroundThresholdCodeUnits: threshold),
            throwsA(isA<MobileApiException>()));
        await expectLater(
            AdminProductionOrderPage.fromJson(wire,
                backgroundThresholdCodeUnits: threshold),
            throwsA(isA<MobileApiException>()));
      }
    }
    for (final source in ['{', '[]', 'null']) {
      await expectLater(
          AdminProductionOrderPage.fromPayload(source), throwsA(anything));
    }
  });

  test('single-pass page remains an atomic sparse delta baseline', () async {
    final before =
        await AdminProductionOrderPage.fromPayload(jsonEncode(_pageWire()));
    final next = (await applyAdminOrderPageWindow(
            [before],
            _delta([
              {
                'op': 'set',
                'path': ['maps', 0, 'map', 'title'],
                'value': 'Updated title',
              },
              {
                'op': 'set',
                'path': ['stage_order_controls'],
                'value': [],
              },
            ])))
        .single;
    expect(next.snapshot!.maps.single.map.title, 'Updated title');
    expect(next.snapshot!.stageFreezeSupported, isTrue);
    expect(next.snapshot!.stageOrderControls, isEmpty);
    expect(next.sequencePositions, {scanOrder: 9});
    expect(before.snapshot!.maps.single.map.title, 'Buyurtma — ўзбек 😀');
    expect(before.snapshot!.stageOrderControls, hasLength(1));

    await expectLater(
        applyAdminOrderPageWindow(
            [before],
            _delta([
              {
                'op': 'set',
                'path': ['queue_action_controls'],
                'value': null,
              },
            ])),
        throwsA(isA<MobileApiException>()));
    expect(before.revision, 7);
    expect(before.wireValue!['queue_action_controls'], isNotNull);
  });

  test('HTTP page body reaches the same fully validated model', () async {
    AppSession.instance.token = 'page-decode-test';
    addTearDown(() => AppSession.instance.token = null);
    await http.runWithClient(() async {
      final page = await MobileApi.instance.adminProductionOrderPage(
          const AdminProductionOrderPageRequest(
              view: 'sequence', apparatus: scanApparatus));
      expect(page!.snapshot!.stageFreezeSupported, isTrue);
      expect(page.sequencePositions, {scanOrder: 9});
      expect(page.wireValue, _pageWire());
    },
        () => MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode(_pageWire())), 200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
