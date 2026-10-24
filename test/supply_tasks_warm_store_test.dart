import 'dart:async';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/core/production/supply_tasks_warm_store.dart';
import 'package:accord_mobile_v2/src/core/session/session_read_scope.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _station = 'apparatus:default:bosma_7';
SupplyTaskWindow _window({int revision = 7, String version = 'v7'}) =>
    SupplyTaskWindow(
      kind: 'material',
      scope: 'authorized-material-scope',
      epoch: 'server',
      revision: revision,
      version: version,
      apparatusId: _station,
      limit: 10,
      search: '',
      checkedCount: 1,
      missingCount: 1,
      rows: const [
        SupplyTaskRow(
            id: 'order',
            code: '42',
            orderNumber: '42',
            title: 'Product',
            productCode: 'product',
            customerName: 'Customer',
            imageId: 'metadata-only',
            position: 0,
            apparatusCount: 2,
            taskState: 'missing')
      ],
      apparatus: const [
        AdminApparatus(
            id: _station,
            name: 'Bosma',
            sourceRevision: 1,
            sourceAasxSha256:
                '1111111111111111111111111111111111111111111111111111111111111111',
            operation: 'print',
            technology: 'flexographic')
      ],
    );

class _MemoryBackend implements ProductionSnapshotBackend {
  final data = <String, Uint8List>{};
  var writes = 0;
  @override
  Future<Uint8List?> read(String id, {required int maxBytes}) async => data[id];
  @override
  Future<void> write(String id, Uint8List bytes,
      {required int savedAtMs}) async {
    data[id] = bytes;
    writes++;
  }

  @override
  Future<List<ProductionSnapshotStoredEntry>> entries() async => [];
  @override
  Future<void> remove(String id) async {
    data.remove(id);
  }

  @override
  Future<void> clear() async {
    data.clear();
  }
}

void _session({String ref = 'supplier'}) {
  AppSession.instance.token = 'test-$ref';
  AppSession.instance.profile = SessionProfile(
      role: UserRole.materialTaminotchi,
      ref: ref,
      displayName: ref,
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: const ['raw_material.assign']);
  AppSession.instance.revision.value++;
}

Future<void> _drain(ProductionSnapshotStore snapshots) async {
  // The durable store serializes writes with reads. This read is a fence.
  await snapshots.read(scope: currentSessionReadScope(), key: 'flush-fence');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({'test_mode_enabled': false});
    _session();
  });
  tearDown(() {
    AppSession.instance.profile = null;
    AppSession.instance.token = null;
    AppSession.instance.revision.value++;
  });

  test('one-shot preparation shares page read and never loads details/images',
      () async {
    final gate = Completer<SupplyTaskWindow>();
    final entered = Completer<void>();
    var reads = 0;
    final snapshots = ProductionSnapshotStore(backend: _MemoryBackend());
    final store = SupplyTasksWarmStore(
        snapshots: snapshots,
        selectionLoader: () async => _station,
        loader: (
            {required kind,
            required apparatus,
            required limit,
            required search}) {
          reads++;
          expect(
              [kind, apparatus, limit, search], ['material', _station, 10, '']);
          if (!entered.isCompleted) entered.complete();
          return gate.future;
        });
    final preparing = store.prepare(kind: 'material');
    await entered.future;
    final foreground = store.read(
        kind: 'material', apparatus: _station, limit: 10, search: '');
    await store.prepare(kind: 'material');
    gate.complete(_window());
    await preparing;
    expect((await foreground).rows.single.imageId, 'metadata-only');
    expect(reads, 1);
    expect(store.peek(scope: currentSessionReadScope(), kind: 'material'),
        isNotNull);
  });

  test('disk baseline restores without HTTP, fresh read bypasses it', () async {
    final backend = _MemoryBackend();
    final snapshots = ProductionSnapshotStore(backend: backend);
    var reads = 0;
    Future<SupplyTaskWindow> loader(
        {required String kind,
        required String apparatus,
        required int limit,
        required String search}) async {
      reads++;
      return _window();
    }

    final first = SupplyTasksWarmStore(loader: loader, snapshots: snapshots);
    await first.read(
        kind: 'material', apparatus: _station, limit: 10, search: '');
    await _drain(snapshots);
    final second = SupplyTasksWarmStore(loader: loader, snapshots: snapshots);
    expect(
        (await second.read(
                kind: 'material', apparatus: _station, limit: 10, search: ''))
            .revision,
        7);
    expect(reads, 1);
    await second.read(
        kind: 'material',
        apparatus: _station,
        limit: 10,
        search: '',
        fresh: true);
    expect(reads, 2);
  });

  test('cursor-only updates stay in memory without disk rewrites', () async {
    final backend = _MemoryBackend();
    final snapshots = ProductionSnapshotStore(backend: backend);
    final store = SupplyTasksWarmStore(snapshots: snapshots);
    store.remember(_window());
    await _drain(snapshots);
    final writes = backend.writes;
    store.remember(_window(revision: 8));
    await _drain(snapshots);
    expect(backend.writes, writes);
    expect(
        store
            .peek(scope: currentSessionReadScope(), kind: 'material')!
            .revision,
        8);
    store.remember(_window(revision: 9, version: 'new-content'));
    await _drain(snapshots);
    expect(backend.writes, writes + 1);
  });

  test('account change fences pending reads and clears decoded rows', () async {
    final gate = Completer<SupplyTaskWindow>();
    final entered = Completer<void>();
    final store = SupplyTasksWarmStore(
        snapshots: ProductionSnapshotStore(backend: _MemoryBackend()),
        loader: (
            {required kind,
            required apparatus,
            required limit,
            required search}) {
          entered.complete();
          return gate.future;
        });
    final pending = store.read(
        kind: 'material', apparatus: _station, limit: 10, search: '');
    final rejected = expectLater(pending, throwsA(isA<MobileApiException>()));
    await entered.future;
    _session(ref: 'other');
    gate.complete(_window());
    await rejected;
    expect(
        store.peek(scope: currentSessionReadScope(), kind: 'material'), isNull);
  });

  test('terminal denial evicts memory/disk and next read must ask server',
      () async {
    final snapshots = ProductionSnapshotStore(backend: _MemoryBackend());
    var denied = false;
    var reads = 0;
    final store = SupplyTasksWarmStore(
        snapshots: snapshots,
        loader: (
            {required kind,
            required apparatus,
            required limit,
            required search}) async {
          reads++;
          if (denied) {
            throw const MobileApiException(
                code: 'forbidden', message: '', statusCode: 403);
          }
          return _window();
        });
    await store.read(
        kind: 'material', apparatus: _station, limit: 10, search: '');
    denied = true;
    await expectLater(
        store.read(
            kind: 'material',
            apparatus: _station,
            limit: 10,
            search: '',
            fresh: true),
        throwsA(isA<MobileApiException>()));
    expect(
        store.peek(scope: currentSessionReadScope(), kind: 'material'), isNull);
    await expectLater(
        store.read(
            kind: 'material', apparatus: _station, limit: 10, search: ''),
        throwsA(isA<MobileApiException>()));
    expect(reads, 3);
  });
}
