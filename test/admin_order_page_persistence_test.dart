import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_models.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_order_page_cache.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'production_snapshot_test_backend.dart';

const _apparatus = AdminApparatus(
  id: 'apparatus:default:bosma_7',
  name: 'Bosma 7',
  sourceRevision: 6,
  sourceAasxSha256:
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  operation: 'print',
  technology: 'flexographic',
  capabilities: ['print'],
  capabilityProfiles: [
    AdminApparatusCapabilityProfile(code: 'print', level: 2),
  ],
);

Map<String, dynamic> _pageWire() => {
      'ok': true,
      'version': 'v7',
      'epoch': 'server',
      'rev': 7,
      'total': 0,
      'offset': 0,
      'next_cursor': null,
      'order_ids': [],
      'pending_orders': [],
      'closed_orders': [],
      'future_server_field': {
        'value': [true, null, 'exact']
      },
    };

Future<void> _save(AdminOrderPageCache cache,
    {String scope = 'runtime', String durableScope = 'account'}) async {
  final page = await AdminProductionOrderPage.fromJson(_pageWire());
  cache.save(
      visit: cache.open(scope),
      apparatus: [_apparatus],
      selectedApparatusId: _apparatus.id,
      persistentScope: durableScope,
      windows: [
        AdminOrderPageCacheWindow(
            AdminProductionOrderPageRequest(
                view: 'sequence', apparatus: _apparatus.id),
            [page])
      ]);
  await cache.flush();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('durable admin pages restore into fresh cache and fresh store instances',
      () async {
    final backend = MemoryProductionSnapshotBackend();
    final first = AdminOrderPageCache(
        persistence: ProductionSnapshotStore(backend: backend));
    await _save(first);
    expect(backend.values, hasLength(1));
    final restarted = AdminOrderPageCache(
        persistence: ProductionSnapshotStore(backend: backend));
    final visit = restarted.open('new-process-runtime');
    final snapshot =
        await restarted.restore(visit: visit, persistentScope: 'account');
    expect(snapshot, isNotNull);
    expect(snapshot!.selectedApparatusId, _apparatus.id);
    expect(snapshot.windows.single.pages.single.wireValue, _pageWire());
    expect(encodeCachedApparatus(snapshot.apparatus.single),
        encodeCachedApparatus(_apparatus));
    expect(() => snapshot.windows.clear(), throwsUnsupportedError);
  });

  test('durable admin pages cannot cross server account or permission scope',
      () async {
    final backend = MemoryProductionSnapshotBackend();
    await _save(AdminOrderPageCache(
        persistence: ProductionSnapshotStore(backend: backend)));
    for (final scope in [
      'another-account',
      'another-server',
      'new-permissions'
    ]) {
      final cache = AdminOrderPageCache(
          persistence: ProductionSnapshotStore(backend: backend));
      expect(
          await cache.restore(visit: cache.open(scope), persistentScope: scope),
          isNull);
    }
  });

  test('old asynchronous disk restore cannot populate a newer visit', () async {
    final backend = MemoryProductionSnapshotBackend();
    await _save(AdminOrderPageCache(
        persistence: ProductionSnapshotStore(backend: backend)));
    final waiting = Completer<void>();
    backend.beforeRead = () => waiting.future;
    final cache = AdminOrderPageCache(
        persistence: ProductionSnapshotStore(backend: backend));
    final restoring = cache.restore(
        visit: cache.open('old-runtime'), persistentScope: 'account');
    await Future<void>.delayed(Duration.zero);
    cache.open('new-runtime');
    waiting.complete();
    expect(await restoring, isNull);
    expect(cache.open('new-runtime').snapshot, isNull);
  });

  test(
      'schema or malformed page data is discarded instead of partially restored',
      () async {
    for (final bad in [
      <String, dynamic>{'schema': 999},
      <String, dynamic>{
        'schema': 1,
        'confirmed_at': DateTime.now().millisecondsSinceEpoch,
        'apparatus': [encodeCachedApparatus(_apparatus)],
        'selected_apparatus_id': _apparatus.id,
        'windows': [
          {
            'request': {
              'view': 'sequence',
              'apparatus': _apparatus.id,
              'target': '',
              'search': ''
            },
            'pages': [
              {..._pageWire(), 'offset': 20}
            ]
          }
        ]
      },
    ]) {
      final backend = MemoryProductionSnapshotBackend();
      final store = ProductionSnapshotStore(backend: backend);
      await store.write(scope: 'account', key: 'admin-pages-v2', value: bad);
      final cache = AdminOrderPageCache(persistence: store);
      expect(
          await cache.restore(
              visit: cache.open('runtime'), persistentScope: 'account'),
          isNull);
      expect(backend.values, isEmpty);
    }
  });

  test(
      'confirmed timestamp survives restart and unconfirmed visits do not renew it',
      () async {
    var now = DateTime.utc(2026, 10, 22);
    final backend = MemoryProductionSnapshotBackend();
    final store = ProductionSnapshotStore(backend: backend, now: () => now);
    await _save(AdminOrderPageCache(persistence: store, now: () => now));
    now = now.add(const Duration(days: 6));
    final cache = AdminOrderPageCache(persistence: store, now: () => now);
    final visit = cache.open('runtime');
    final snapshot =
        await cache.restore(visit: visit, persistentScope: 'account');
    expect(snapshot, isNotNull);
    cache.save(
        visit: visit,
        apparatus: snapshot!.apparatus,
        selectedApparatusId: snapshot.selectedApparatusId,
        windows: snapshot.windows,
        refreshAge: false,
        persistentScope: 'account');
    await cache.flush();
    now = now.add(const Duration(days: 1));
    final restarted = AdminOrderPageCache(persistence: store, now: () => now);
    expect(
        await restarted.restore(
            visit: restarted.open('runtime'), persistentScope: 'account'),
        isNull);
  });

  test(
      'permission invalidation removes durable entry and stale visit cannot save',
      () async {
    final backend = MemoryProductionSnapshotBackend();
    final store = ProductionSnapshotStore(backend: backend);
    final cache = AdminOrderPageCache(persistence: store);
    await _save(cache);
    final visit = cache.open('runtime');
    await cache.restore(visit: visit, persistentScope: 'account');
    cache.invalidate(visit);
    await store.flush();
    expect(backend.values, isEmpty);
    cache.save(
        visit: visit,
        apparatus: [_apparatus],
        selectedApparatusId: _apparatus.id,
        persistentScope: 'account',
        windows: [
          AdminOrderPageCacheWindow(
              const AdminProductionOrderPageRequest(view: 'sequence'),
              [await AdminProductionOrderPage.fromJson(_pageWire())])
        ]);
    await cache.flush();
    expect(backend.values, isEmpty);
  });

  test(
      'only exact wire baselines are durable; typed legacy pages remain memory-only',
      () async {
    final backend = MemoryProductionSnapshotBackend();
    final cache = AdminOrderPageCache(
        persistence: ProductionSnapshotStore(backend: backend));
    cache.save(
        visit: cache.open('runtime'),
        apparatus: [_apparatus],
        selectedApparatusId: _apparatus.id,
        persistentScope: 'account',
        windows: [
          AdminOrderPageCacheWindow(
              const AdminProductionOrderPageRequest(view: 'sequence'), [
            const AdminProductionOrderPage(
                version: 'v7',
                epoch: 'server',
                revision: 7,
                total: 0,
                offset: 0)
          ])
        ]);
    await cache.flush();
    expect(cache.open('runtime').snapshot, isNotNull);
    expect(backend.values, isEmpty);
  });

  test('disk entry omits runtime scope and raw token', () async {
    final backend = MemoryProductionSnapshotBackend();
    await _save(
        AdminOrderPageCache(
            persistence: ProductionSnapshotStore(backend: backend)),
        scope: 'raw-secret-token-in-runtime-scope');
    expect(utf8.decode(backend.values.values.single),
        isNot(contains('raw-secret-token')));
  });
  test(
      'durable admin writes debounce changed pages and skip unchanged baselines',
      () async {
    final backend = MemoryProductionSnapshotBackend();
    final store = ProductionSnapshotStore(backend: backend);
    final cache = AdminOrderPageCache(persistence: store);
    final visit = cache.open('runtime');
    late AdminProductionOrderPage latest;
    void save() => cache.save(
        visit: visit,
        apparatus: [_apparatus],
        selectedApparatusId: _apparatus.id,
        persistentScope: 'account',
        windows: [
          AdminOrderPageCacheWindow(
              const AdminProductionOrderPageRequest(view: 'sequence'), [latest])
        ]);
    for (var revision = 7; revision <= 9; revision++) {
      latest = await AdminProductionOrderPage.fromJson(
          {..._pageWire(), 'version': 'v$revision', 'rev': revision});
      save();
    }
    expect(backend.writeCount, 0);
    await cache.flush();
    expect(backend.writeCount, 1);
    final durable = await store.read(scope: 'account', key: 'admin-pages-v2');
    expect(durable!['windows'][0]['pages'][0]['version'], 'v9');
    save();
    await cache.flush();
    expect(backend.writeCount, 1);
  });

  test(
      'logout store generation blocks a debounced admin save before serialization',
      () async {
    final backend = MemoryProductionSnapshotBackend();
    final store = ProductionSnapshotStore(backend: backend);
    final cache = AdminOrderPageCache(persistence: store);
    final page = await AdminProductionOrderPage.fromJson(_pageWire());
    cache.save(
        visit: cache.open('runtime'),
        apparatus: [_apparatus],
        selectedApparatusId: _apparatus.id,
        persistentScope: 'account',
        windows: [
          AdminOrderPageCacheWindow(
              const AdminProductionOrderPageRequest(view: 'sequence'), [page])
        ]);
    await store.clear();
    await cache.flush();
    expect(backend.writeCount, 0);
    expect(backend.values, isEmpty);
  });
  test(
      'slow optional admin storage times out and cannot replace a fresh baseline',
      () async {
    final backend = MemoryProductionSnapshotBackend();
    await _save(AdminOrderPageCache(
        persistence: ProductionSnapshotStore(backend: backend)));
    final blockedRead = Completer<void>();
    backend.beforeRead = () => blockedRead.future;
    final store = ProductionSnapshotStore(backend: backend);
    final cache = AdminOrderPageCache(persistence: store);
    final visit = cache.open('runtime');
    final clock = Stopwatch()..start();
    expect(
        await cache.restore(visit: visit, persistentScope: 'account'), isNull);
    expect(clock.elapsedMilliseconds, greaterThanOrEqualTo(450));
    expect(clock.elapsedMilliseconds, lessThan(1500));
    // The caller's canonical HTTP fallback can install rows while the
    // abandoned optional read remains pending in the storage backend.
    final fresh = await AdminProductionOrderPage.fromJson(
        {..._pageWire(), 'version': 'v8', 'rev': 8});
    cache.save(
        visit: visit,
        apparatus: [_apparatus],
        selectedApparatusId: _apparatus.id,
        windows: [
          AdminOrderPageCacheWindow(
              const AdminProductionOrderPageRequest(view: 'sequence'), [fresh])
        ]);
    blockedRead.complete();
    await store.flush();
    expect(cache.open('runtime').snapshot!.windows.single.pages.single.version,
        'v8');
  });
}
