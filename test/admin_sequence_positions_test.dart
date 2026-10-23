import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_order_page_cache.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'production_snapshot_test_backend.dart';

Map<String, dynamic> _page() => {
      'version': 'v1',
      'epoch': 'server',
      'rev': 1,
      'offset': 0,
      'total': 2,
      'next_cursor': null,
      'order_ids': ['dosti', 'far-order'],
      'sequence_positions': {'dosti': 4, 'far-order': 28},
      'sequences': {},
      'visible_order_ids': {},
      'queue_states': {},
      'queue_action_controls': {},
      'queue_policies': [],
      'stage_states': {},
      'order_controls': {},
      'order_statuses': {},
      'frozen_orders_by_apparatus': {},
      'order_customers': {},
      'maps': [
        for (final id in ['dosti', 'far-order'])
          {
            'map': ProductionMapDefinition(
                id: id,
                productCode: id,
                title: id,
                nodes: const [],
                edges: const []).toJson(),
            'program': <String, dynamic>{},
          }
      ],
    };

AdminProductionMapPageWindowMessage _event(String type, int rev,
        {List<Map<String, Object?>> ops = const []}) =>
    AdminProductionMapPageWindowMessage.fromJson({
      'type': type,
      'window': 'w1',
      'epoch': 'server',
      'rev': rev,
      'base_version': 'v${rev - 1}',
      'version': 'v$rev',
      if (type == 'page_window_checkpoint')
        'next_cursors': [null]
      else ...{
        'page_count': 1,
        'changes': [
          {
            'index': 0,
            'ops': [
              {
                'op': 'set',
                'path': ['version'],
                'value': 'v$rev'
              },
              {
                'op': 'set',
                'path': ['rev'],
                'value': rev
              },
              ...ops,
            ]
          }
        ],
      },
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('server search preserves noncontiguous ranks before pagination',
      () async {
    final page = await AdminProductionOrderPage.fromJson(_page());
    expect(page.sequencePositions, {'dosti': 4, 'far-order': 28});
    expect(() => page.sequencePositions['dosti'] = 1, throwsUnsupportedError);
    final legacy = _page()..remove('sequence_positions');
    expect((await AdminProductionOrderPage.fromJson(legacy)).sequencePositions,
        isEmpty);
  });

  test('malformed sequence positions reject instead of showing false ranks',
      () async {
    for (final value in [
      null,
      [],
      {'dosti': 0, 'far-order': 28},
      {'dosti': -1, 'far-order': 28},
      {'dosti': 4.5, 'far-order': 28},
      {'dosti': '4', 'far-order': 28},
      {'unknown': 4, 'far-order': 28},
      {'dosti': 4},
      {'dosti': 4, 'far-order': 4}
    ]) {
      await expectLater(
          AdminProductionOrderPage.fromJson(
              {..._page(), 'sequence_positions': value}),
          throwsA(isA<MobileApiException>()));
    }
  });

  test('rank-only delta and checkpoint retain baseline and row identities',
      () async {
    final before = await AdminProductionOrderPage.fromJson(_page());
    final next = (await applyAdminOrderPageWindow(
            [before],
            _event('page_window_delta', 2, ops: [
              {
                'op': 'set',
                'path': ['sequence_positions', 'dosti'],
                'value': 5
              },
            ])))
        .single;
    expect(next.sequencePositions, {'dosti': 5, 'far-order': 28});
    expect(before.sequencePositions['dosti'], 4);
    expect(before.wireValue!['sequence_positions']['dosti'], 4);
    expect(identical(next.snapshot!.maps, before.snapshot!.maps), isTrue);
    expect(identical(next.orderIds, before.orderIds), isTrue);
    final checkpoint = (await applyAdminOrderPageWindow(
            [next], _event('page_window_checkpoint', 3)))
        .single;
    expect(identical(checkpoint.sequencePositions, next.sequencePositions),
        isTrue);
    expect(checkpoint.sequencePositions['dosti'], 5);
    expect(identical(checkpoint.snapshot!.maps, before.snapshot!.maps), isTrue);
    await expectLater(
        applyAdminOrderPageWindow(
            [before],
            _event('page_window_delta', 2, ops: [
              {
                'op': 'set',
                'path': ['sequence_positions', 'dosti'],
                'value': 0
              },
            ])),
        throwsA(isA<MobileApiException>()));
    expect(before.sequencePositions['dosti'], 4);
  });

  test('sequence ranks survive memory cache and durable raw-page restore',
      () async {
    final backend = MemoryProductionSnapshotBackend();
    final cache = AdminOrderPageCache(
        persistence: ProductionSnapshotStore(backend: backend));
    final page = await AdminProductionOrderPage.fromJson(_page());
    cache.save(
        visit: cache.open('account'),
        apparatus: const [
          AdminApparatus(
              id: 'apparatus:default:bosma_7',
              name: 'Machine',
              sourceRevision: 6,
              sourceAasxSha256:
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              operation: 'print',
              technology: 'flexographic'),
        ],
        selectedApparatusId: 'apparatus:default:bosma_7',
        persistentScope: 'account',
        windows: [
          AdminOrderPageCacheWindow(
              const AdminProductionOrderPageRequest(
                  view: 'sequence', apparatus: 'apparatus:default:bosma_7'),
              [page]),
        ]);
    await cache.flush();
    expect(
        cache
            .open('account')
            .snapshot!
            .windows
            .single
            .pages
            .single
            .sequencePositions,
        {'dosti': 4, 'far-order': 28});
    final restarted = AdminOrderPageCache(
        persistence: ProductionSnapshotStore(backend: backend));
    final snapshot = await restarted.restore(
        visit: restarted.open('account'), persistentScope: 'account');
    expect(snapshot!.windows.single.pages.single.sequencePositions,
        {'dosti': 4, 'far-order': 28});
    expect(
        snapshot.windows.single.pages.single.wireValue!['sequence_positions'],
        {'dosti': 4, 'far-order': 28});
  });

  test(
      'benchmark: 5000 sparse rank deltas retain rows without losing revisions',
      () async {
    var pages = [await AdminProductionOrderPage.fromJson(_page())];
    final maps = pages.single.snapshot!.maps;
    final timings = <int>[];
    var applied = 0;
    final totalWatch = Stopwatch()..start();
    for (var revision = 2; revision <= 5001; revision++) {
      final position = revision.isEven ? 5 : 4;
      final event = _event('page_window_delta', revision, ops: [
        {
          'op': 'set',
          'path': ['sequence_positions', 'dosti'],
          'value': position
        },
      ]);
      final watch = Stopwatch()..start();
      pages = await applyAdminOrderPageWindow(pages, event);
      timings.add(watch.elapsedMicroseconds);
      expect(pages.single.revision, revision);
      expect(pages.single.sequencePositions['dosti'], position);
      expect(identical(pages.single.snapshot!.maps, maps), isTrue);
      applied++;
    }
    totalWatch.stop();
    timings.sort();
    expect(applied, 5000);
    expect(pages.single.version, 'v5001');
    // Diagnostic microbenchmark, intentionally without hardware-dependent gates.
    // ignore: avoid_print
    print('sequence_rank_delta_benchmark frames=$applied dropped=0 '
        'total_ms=${totalWatch.elapsedMilliseconds} '
        'p50_us=${timings[2500]} p95_us=${timings[4750]} '
        'p99_us=${timings[4950]} maps_redecoded=0');
  });
}
