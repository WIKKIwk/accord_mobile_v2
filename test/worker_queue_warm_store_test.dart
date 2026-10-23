import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/production/production_data_revision.dart';
import 'package:accord_mobile_v2/src/core/production/worker_queue_warm_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';

const _apparatus = 'apparatus:default:bosma_9';
const _catalog = [AdminApparatus(id: _apparatus, name: 'Bosma')];

AdminProductionMapLiveSnapshot _snapshot(
        {int revision = 10,
        String scope = 'server-worker-scope',
        String epoch = 'epoch'}) =>
    AdminProductionMapLiveSnapshot(
      maps: const [],
      epoch: epoch,
      revision: revision,
      scope: scope,
      sequences: const {},
      visibleOrderIds: const {},
      queueStates: const {},
      queuePolicies: const {},
      orderControls: const {},
      completedOrders: const [
        AdminCompletedQueueOrder(
            apparatus: _apparatus,
            orderId: 'completed-order',
            completedAtUnix: 1)
      ],
      completionRequests: const [],
      completionRequestDecisions: const [],
    );

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late String scope;
  late WorkerQueueWarmStore store;
  late List<StreamController<AdminProductionMapLiveMessage>> streams;
  late List<WorkerQueueWarmSnapshot> baselines;
  late List<(int, String)> requests;
  late int apparatusReads;

  setUp(() {
    scope = 'account-a';
    streams = [];
    baselines = [];
    requests = [];
    apparatusReads = 0;
    store = WorkerQueueWarmStore(
      scopeReader: () => scope,
      limitLoader: (_) async => 10,
      snapshotLoader: (limit, search) async {
        requests.add((limit, search));
        return _snapshot();
      },
      apparatusLoader: () async {
        apparatusReads++;
        return _catalog;
      },
      liveLoader: (baseline, _, __) {
        baselines.add(baseline);
        final controller =
            StreamController<AdminProductionMapLiveMessage>(sync: true);
        streams.add(controller);
        return controller.stream;
      },
      reconnectDelay: (_) => const Duration(milliseconds: 5),
    );
  });

  tearDown(() async {
    store.reset();
    await Future.wait(streams.map((stream) => stream.close()));
  });

  Future<void> start() =>
      store.start(scope: scope, preferenceAccount: 'worker');
  WorkerQueueWarmSnapshot? peek({int limit = 10, String search = ''}) =>
      store.peek(scope: scope, queueLimit: limit, search: search);

  test('prepares decoded queue and catalog once; ready claim does no HTTP',
      () async {
    await start();
    expect(requests, [(10, '')]);
    expect(apparatusReads, 1);
    expect(streams, hasLength(1));
    final ready = peek();
    expect(ready?.apparatus.single.id, _apparatus);
    expect(await store.claim(scope: scope, queueLimit: 10), same(ready));
    expect(streams.single.hasListener, isFalse);
    await start();
    expect(requests, hasLength(1));
    expect(streams, hasLength(1));
  });

  test('navigation joins both pending initial reads with exact saved limit',
      () async {
    final queue = Completer<AdminApparatusQueueSnapshot>();
    final catalog = Completer<List<AdminApparatus>>();
    store = WorkerQueueWarmStore(
      scopeReader: () => scope,
      limitLoader: (_) async => 20,
      snapshotLoader: (limit, search) {
        requests.add((limit, search));
        return queue.future;
      },
      apparatusLoader: () {
        apparatusReads++;
        return catalog.future;
      },
      liveLoader: (_, __, ___) => throw StateError('Page owns the socket'),
    );
    final warming = start();
    await _flush();
    var completed = false;
    final claiming = store.claim(scope: scope, queueLimit: 20).then((value) {
      completed = true;
      return value;
    });
    queue.complete(_snapshot());
    await _flush();
    expect(completed, isFalse);
    catalog.complete(_catalog);
    await warming;
    expect((await claiming)?.snapshot.revision, 10);
    expect(requests, [(20, '')]);
    expect(apparatusReads, 1);
  });

  test('wrong limit, search or account can never reuse prepared rows',
      () async {
    await start();
    expect(peek(limit: 5), isNull);
    expect(peek(search: 'another order'), isNull);
    expect(store.peek(scope: 'account-b', queueLimit: 10), isNull);
    expect(await store.claim(scope: scope, queueLimit: 50), isNull);
    expect(requests, hasLength(1));
  });

  test('a direct worker route reserves ownership before runtime starts',
      () async {
    final claiming = store.claim(scope: scope, queueLimit: 10);
    final lease = store.pageLease;
    expect(lease, isNotNull);
    expect(await claiming, isNull);
    await start();
    expect(requests, isEmpty);
    expect(streams, isEmpty);
    store.release(
        scope: scope,
        queueLimit: 10,
        expectedLease: lease,
        latest: WorkerQueueWarmSnapshot(
            snapshot: _snapshot(), apparatus: _catalog));
    expect(streams, hasLength(1));
    expect(requests, isEmpty);
  });

  test(
      'a disposed old page cannot release a newer claim after same-account reset',
      () async {
    await start();
    await store.claim(scope: scope, queueLimit: 10);
    final oldLease = store.pageLease;
    store.reset();
    await start();
    await store.claim(scope: scope, queueLimit: 10);
    final currentLease = store.pageLease;
    final count = streams.length;
    store.release(
        scope: scope,
        queueLimit: 10,
        expectedLease: oldLease,
        latest: WorkerQueueWarmSnapshot(
            snapshot: _snapshot(revision: 99), apparatus: _catalog));
    expect(store.pageLease, same(currentLease));
    expect(peek()?.snapshot.revision, 10);
    store.resume();
    await start();
    expect(streams, hasLength(count));
    expect(requests, hasLength(2));
  });

  test('applies 1000 successive compact cursor deltas while page is closed',
      () async {
    await start();
    for (var revision = 10; revision < 1010; revision++) {
      streams.single.add(AdminProductionMapLiveStateDelta(
        epoch: 'epoch',
        scope: 'server-worker-scope',
        baseRevision: revision,
        revision: revision + 1,
        protocol: 'state_delta_v2',
        patch: const {},
      ));
    }
    expect(peek()?.snapshot.revision, 1010);
    expect(requests, hasLength(1));
    final snapshot = peek()!.snapshot as AdminProductionMapLiveSnapshot;
    expect(snapshot.completedOrders.single.orderId, 'completed-order');
  });

  test('only accepted live revisions notify other production views', () async {
    var notifications = 0;
    void changed() => notifications++;
    ProductionDataRevision.revision.addListener(changed);
    addTearDown(() => ProductionDataRevision.revision.removeListener(changed));
    await start();
    expect(notifications, 0, reason: 'HTTP preparation is not a live proof');
    streams.single.add(_snapshot(epoch: 'notify-worker-epoch', revision: 70));
    expect(notifications, 1);
    const delta = AdminProductionMapLiveStateDelta(
      epoch: 'notify-worker-epoch',
      scope: 'server-worker-scope',
      baseRevision: 70,
      revision: 71,
      patch: {},
    );
    streams.single.add(delta);
    expect(notifications, 2);
    streams.single.add(delta);
    streams.single.add(_snapshot(epoch: 'notify-worker-epoch', revision: 69));
    expect(notifications, 2, reason: 'Covered/stale state never publishes');
    streams.single.add(const AdminProductionMapLiveStateReady(
      epoch: 'notify-worker-epoch',
      scope: 'server-worker-scope',
      revision: 71,
      resync: true,
    ));
    await _flush();
    expect(notifications, 2, reason: 'Resync and its HTTP read do not publish');
  });

  test('delta actor extras replace and retain without extra section reads',
      () async {
    await start();
    streams.single.add(const AdminProductionMapLiveStateDelta(
      epoch: 'epoch',
      scope: 'server-worker-scope',
      baseRevision: 10,
      revision: 11,
      patch: {'completed_orders': []},
    ));
    expect((peek()!.snapshot as AdminProductionMapLiveSnapshot).completedOrders,
        isEmpty);
    expect(requests, hasLength(1));
  });

  test('duplicate deltas do not reset or overwrite a newer baseline', () async {
    await start();
    const delta = AdminProductionMapLiveStateDelta(
      epoch: 'epoch',
      scope: 'server-worker-scope',
      baseRevision: 10,
      revision: 11,
      patch: {},
    );
    streams.single.add(delta);
    streams.single.add(delta);
    expect(peek()?.snapshot.revision, 11);
    expect(requests, hasLength(1));
  });

  test('a real delta gap causes one canonical reconciliation', () async {
    await start();
    streams.single.add(const AdminProductionMapLiveStateDelta(
      epoch: 'epoch',
      scope: 'server-worker-scope',
      baseRevision: 12,
      revision: 13,
      patch: {},
    ));
    await _flush();
    expect(requests, hasLength(2));
    expect(streams, hasLength(2));
  });

  test('state-ready matching cursor does not refetch list', () async {
    await start();
    streams.single.add(const AdminProductionMapLiveStateReady(
      epoch: 'epoch',
      scope: 'server-worker-scope',
      revision: 10,
      resync: false,
      recovered: true,
      recoverySupported: true,
    ));
    await _flush();
    expect(requests, hasLength(1));
    expect(streams, hasLength(1));
  });

  test('resync hint requests the canonical read once, never a periodic timer',
      () async {
    await start();
    streams.single.add(const AdminProductionMapLiveStateReady(
      epoch: 'epoch',
      scope: 'server-worker-scope',
      revision: 10,
      resync: true,
    ));
    await _flush();
    expect(requests, hasLength(2));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(requests, hasLength(2));
  });

  test('closed socket reconnects with latest cursor without HTTP polling',
      () async {
    await start();
    streams.single.add(const AdminProductionMapLiveStateDelta(
      epoch: 'epoch',
      scope: 'server-worker-scope',
      baseRevision: 10,
      revision: 11,
      patch: {},
    ));
    await streams.single.close();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(streams, hasLength(2));
    expect(baselines.last.snapshot.revision, 11);
    expect(requests, hasLength(1));
  });

  test('repeated server resync cannot turn socket reconnects into HTTP polling',
      () async {
    await start();
    const resync = AdminProductionMapLiveStateReady(
      epoch: 'epoch',
      scope: 'server-worker-scope',
      revision: 10,
      resync: true,
    );
    streams.last.add(resync);
    await _flush();
    expect(requests, hasLength(2));
    streams.last.add(resync);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    streams.last.add(resync);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(requests, hasLength(2));
    streams.last.add(const AdminProductionMapLiveStateReady(
      epoch: 'epoch',
      scope: 'server-worker-scope',
      revision: 10,
      resync: false,
      recovered: true,
    ));
    streams.last.add(resync);
    await _flush();
    expect(requests, hasLength(3));
  });

  test('pause stops socket; resume recovers prepared cursor without HTTP',
      () async {
    await start();
    store.pause();
    expect(streams.single.hasListener, isFalse);
    store.resume();
    expect(streams, hasLength(2));
    expect(requests, hasLength(1));
  });

  test('a safe page release hands the latest cursor back to background',
      () async {
    await start();
    await store.claim(scope: scope, queueLimit: 10);
    store.release(
        scope: scope,
        queueLimit: 10,
        latest: WorkerQueueWarmSnapshot(
          snapshot: _snapshot(revision: 42),
          apparatus: _catalog,
        ));
    expect(baselines.last.snapshot.revision, 42);
    expect(peek()?.snapshot.revision, 42);
    expect(requests, hasLength(1));
  });

  test('pending page writes discard the pre-navigation baseline on release',
      () async {
    await start();
    await store.claim(scope: scope, queueLimit: 10);
    store.release(scope: scope, queueLimit: 20);
    expect(peek(limit: 20), isNull);
    await _flush();
    expect(requests, [(10, ''), (20, '')]);
  });

  test('scope changes reject late reads and never repopulate an old account',
      () async {
    final pending = Completer<AdminApparatusQueueSnapshot>();
    store = WorkerQueueWarmStore(
      scopeReader: () => scope,
      limitLoader: (_) async => 10,
      snapshotLoader: (_, __) => pending.future,
      apparatusLoader: () async => _catalog,
    );
    final warming = start();
    await _flush();
    scope = 'account-b';
    store.reset();
    pending.complete(_snapshot());
    await warming;
    expect(peek(), isNull);
    expect(await store.claim(scope: 'account-a', queueLimit: 10), isNull);
  });

  test('permission loss clears rows and prevents socket reconnect', () async {
    await start();
    streams.single.addError(const MobileApiException(
        code: 'forbidden', message: 'Forbidden', statusCode: 403));
    await _flush();
    store.resume();
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(peek(), isNull);
    expect(streams, hasLength(1));
    expect(requests, hasLength(1));
  });

  test(
      'explicit unbounded preference retains query identity without widening default',
      () async {
    await start();
    expect(requests.single.$1, 10);
    expect(peek(limit: 0), isNull);
    await store.claim(scope: scope, queueLimit: 10);
    store.release(scope: scope, queueLimit: 0);
    await _flush();
    expect(requests.last.$1, 0);
  });
}
