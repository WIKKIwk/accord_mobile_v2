import 'dart:async';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/core/production/preparation_orders_warm_store.dart';
import 'package:accord_mobile_v2/src/core/session/session_read_scope.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _apparatus = 'apparatus:default:bosma_7';

PreparationOrderListRow _row(int number) => PreparationOrderListRow(
      id: 'zakaz-$number',
      code: '$number',
      orderNumber: '$number',
      title: 'Product $number',
      customerName: 'Customer $number',
      imageId: 'image-$number',
      position: number,
    );

PreparationOrderListWindow _window({
  String version = 'v7',
  int revision = 7,
  int count = 2,
  String search = '',
  String? nextCursor,
}) =>
    PreparationOrderListWindow(
      scope: 'preparation-$_apparatus-$search',
      epoch: 'server',
      revision: revision,
      version: version,
      apparatusId: _apparatus,
      apparatus: const [AdminApparatus(id: _apparatus, name: 'Bosma')],
      rows: List.generate(count, (index) => _row(index + 1)),
      total: nextCursor == null ? count : count + 30,
      nextCursor: nextCursor,
      search: search,
    );

class _MemoryBackend implements ProductionSnapshotBackend {
  final data = <String, Uint8List>{};
  Completer<void>? readGate;
  int writes = 0;

  @override
  Future<Uint8List?> read(String id, {required int maxBytes}) async {
    await readGate?.future;
    return data[id];
  }

  @override
  Future<void> write(String id, Uint8List bytes,
      {required int savedAtMs}) async {
    writes++;
    data[id] = bytes;
  }

  @override
  Future<List<ProductionSnapshotStoredEntry>> entries() async => [];

  @override
  Future<void> remove(String id) async => data.remove(id);

  @override
  Future<void> clear() async => data.clear();
}

void _session({String ref = 'master', List<String> warehouses = const []}) {
  AppSession.instance.token = 'token-$ref';
  AppSession.instance.profile = SessionProfile(
    role: UserRole.tayyorlovMasteri,
    ref: ref,
    displayName: ref,
    legalName: '',
    phone: '',
    avatarUrl: '',
    capabilities: const ['preparation.access'],
    assignedWarehouses: warehouses,
  );
  AppSession.instance.revision.value++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'test_mode_enabled': false});
    _session();
  });
  tearDown(() {
    PreparationOrdersWarmStore.debugOverride = null;
    AppSession.instance.profile = null;
    AppSession.instance.token = null;
    AppSession.instance.revision.value++;
  });

  test('preload and route share one read and retain the loaded prefix',
      () async {
    final entered = Completer<void>();
    final response = Completer<PreparationOrderListWindow>();
    final snapshots = ProductionSnapshotStore(backend: _MemoryBackend());
    var reads = 0;
    final store = PreparationOrdersWarmStore(
      snapshots: snapshots,
      selectionLoader: () async => _apparatus,
      loader: (
          {required apparatus,
          required search,
          cursor,
          baseline,
          required refresh}) {
        reads++;
        if (!entered.isCompleted) entered.complete();
        return response.future;
      },
    );
    final preparing = store.prepare();
    await entered.future;
    final foreground = store.read(apparatus: _apparatus, fresh: true);
    response.complete(_window());
    await preparing;
    await foreground;
    await store.prepare();
    expect(reads, 1);
    final prefix = _window(count: 60, nextCursor: 'after-60');
    store.remember(prefix);
    expect(store.peek(apparatus: _apparatus)!.rows.length, 60);
    await snapshots.flush();
    final restored = await PreparationOrdersWarmStore(snapshots: snapshots)
        .restore(apparatus: _apparatus);
    expect(restored!.rows.length, 60);
    expect(restored.nextCursor, 'after-60');
  });

  test('slow storage never gates HTTP or replaces its newer response',
      () async {
    final backend = _MemoryBackend();
    final snapshots = ProductionSnapshotStore(backend: backend);
    final seed = PreparationOrdersWarmStore(snapshots: snapshots);
    seed.remember(_window());
    await snapshots.flush();
    backend.readGate = Completer<void>();
    final fresh = _window(version: 'v8', revision: 8);
    final store = PreparationOrdersWarmStore(
      snapshots: snapshots,
      loader: (
              {required apparatus,
              required search,
              cursor,
              baseline,
              required refresh}) async =>
          fresh,
    );
    final restoring = store.restore(apparatus: _apparatus);
    final result = await store.read(apparatus: _apparatus, fresh: true);
    expect(result.version, 'v8');
    expect(store.peek(apparatus: _apparatus)!.version, 'v8');
    backend.readGate!.complete();
    expect((await restoring)!.version, 'v8');
    await snapshots.flush();
  });

  test('unchanged live checkpoints update RAM without repeated disk writes',
      () async {
    final backend = _MemoryBackend();
    final snapshots = ProductionSnapshotStore(backend: backend);
    final store = PreparationOrdersWarmStore(snapshots: snapshots);
    store.remember(_window());
    await snapshots.flush();
    final writes = backend.writes;
    store.remember(_window(revision: 8));
    await snapshots.flush();
    expect(store.peek(apparatus: _apparatus)!.revision, 8);
    expect(backend.writes, writes);
  });

  test('a confirmed live prefix wins over an earlier HTTP request', () async {
    final response = Completer<PreparationOrderListWindow>();
    final snapshots = ProductionSnapshotStore(backend: _MemoryBackend());
    final store = PreparationOrdersWarmStore(
      snapshots: snapshots,
      loader: (
              {required apparatus,
              required search,
              cursor,
              baseline,
              required refresh}) =>
          response.future,
    );
    final pending = store.read(apparatus: _apparatus, fresh: true);
    store.remember(_window(version: 'v9', revision: 9, count: 60));
    response.complete(_window());
    expect((await pending).version, 'v9');
    await snapshots.flush();
    expect(store.peek(apparatus: _apparatus)!.rows.length, 60);
    final restored = await PreparationOrdersWarmStore(snapshots: snapshots)
        .restore(apparatus: _apparatus);
    expect(restored!.version, 'v9');
  });

  test('permission scope changes and account switches isolate cached labels',
      () async {
    final snapshots = ProductionSnapshotStore(backend: _MemoryBackend());
    final store = PreparationOrdersWarmStore(snapshots: snapshots);
    store.remember(_window());
    await snapshots.flush();
    final scope = currentSessionReadScope();
    _session(warehouses: const ['new warehouse']);
    expect(currentSessionReadScope(), isNot(scope));
    expect(store.peek(apparatus: _apparatus), isNull);
    expect(await store.restore(apparatus: _apparatus), isNull);
    _session(ref: 'another-master');
    expect(await store.restore(apparatus: _apparatus), isNull);
  });

  test('late response after account switch is discarded', () async {
    final response = Completer<PreparationOrderListWindow>();
    final store = PreparationOrdersWarmStore(
      snapshots: ProductionSnapshotStore(backend: _MemoryBackend()),
      loader: (
              {required apparatus,
              required search,
              cursor,
              baseline,
              required refresh}) =>
          response.future,
    );
    final pending = store.read(apparatus: _apparatus, fresh: true);
    _session(ref: 'other-master');
    response.complete(_window());
    await expectLater(pending, throwsA(isA<MobileApiException>()));
    expect(store.peek(apparatus: _apparatus), isNull);
  });

  test('terminal authorization failure removes RAM and stored prefixes',
      () async {
    final backend = _MemoryBackend();
    final snapshots = ProductionSnapshotStore(backend: backend);
    final store = PreparationOrdersWarmStore(
      snapshots: snapshots,
      loader: (
              {required apparatus,
              required search,
              cursor,
              baseline,
              required refresh}) async =>
          throw const MobileApiException(
              code: 'forbidden', message: 'Forbidden', statusCode: 403),
    );
    store.remember(_window());
    await snapshots.flush();
    expect(backend.data, isNotEmpty);
    await expectLater(store.read(apparatus: _apparatus, fresh: true),
        throwsA(isA<MobileApiException>()));
    await snapshots.flush();
    expect(store.peek(apparatus: _apparatus), isNull);
    expect(await store.restore(apparatus: _apparatus), isNull);
    expect(backend.data, isEmpty);
  });

  test('conditional HTTP preserves an entire prefix and updates its revision',
      () async {
    final baseline = _window(count: 60, nextCursor: 'after-60');
    final result = await http.runWithClient(
      () => MobileApi.instance
          .preparationOrders(apparatus: _apparatus, baseline: baseline),
      () => MockClient((request) async {
        expect(request.url.queryParameters['if_version'], baseline.version);
        expect(request.url.queryParameters['length'], '60');
        return http.Response('', 304, headers: {
          'x-production-epoch': baseline.epoch,
          'x-production-revision': '8',
          'x-preparation-scope': baseline.scope,
          'x-preparation-version': baseline.version,
        });
      }),
    );
    expect(result.rows.length, 60);
    expect(result.nextCursor, 'after-60');
    expect(result.revision, 8);
  });

  test('conditional HTTP rejects reuse for a different search or cursor',
      () async {
    for (final cursor in <String?>[null, 'after-30']) {
      await http.runWithClient(
        () => expectLater(
          MobileApi.instance.preparationOrders(
              apparatus: _apparatus,
              search: cursor == null ? 'different' : '',
              cursor: cursor,
              baseline: _window()),
          throwsA(isA<MobileApiException>()),
        ),
        () => MockClient((request) async {
          expect(
              request.url.queryParameters.containsKey('if_version'), isFalse);
          return http.Response('', 304);
        }),
      );
    }
  });

  test('live delta changes only its exact baseline and validates prefix rows',
      () {
    final baseline = _window();
    final next = _window(version: 'v8', revision: 8);
    final delta = {
      ...next.toJson(),
      'type': 'list_delta',
      'base_version': baseline.version,
      'order_ids': ['zakaz-2', 'zakaz-3'],
      'upserts': [_row(3).toJson()],
      'removed_ids': ['zakaz-1'],
    }..remove('rows');
    final updated = baseline.applyLiveDelta(delta);
    expect(updated.rows.map((row) => row.id), ['zakaz-2', 'zakaz-3']);
    expect(identical(updated.rows.first, baseline.rows.last), isTrue);
    expect(updated.rows.first.title, baseline.rows.last.title);
    expect(() => baseline.applyLiveDelta({...delta, 'base_version': 'other'}),
        throwsA(isA<MobileApiException>()));
    expect(
        () => baseline.applyLiveDelta({
              ...delta,
              'order_ids': ['zakaz-2', 'missing']
            }),
        throwsA(isA<MobileApiException>()));
    expect(
        () => baseline.applyLiveCheckpoint({
              'epoch': baseline.epoch,
              'scope': baseline.scope,
              'version': 'other',
              'rev': 8,
            }),
        throwsA(isA<MobileApiException>()));
    expect(
        baseline.applyLiveCheckpoint({
          'epoch': baseline.epoch,
          'scope': baseline.scope,
          'version': baseline.version,
          'rev': 8,
        }).revision,
        8);
  });
}
