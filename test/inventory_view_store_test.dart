import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/inventory/inventory_view_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/inventory_movement_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _asset(String ref,
        {String name = 'Material', String? order, String control = 'active'}) =>
    {
      'kind': 'raw_material',
      'asset_ref': ref,
      'item_name': name,
      'identifier': ref,
      'status': 'available',
      'qty': 10,
      'physical_location': {'id': 'warehouse-a', 'name': 'A'},
      'order_assignment': order == null
          ? null
          : {
              'order_id': order,
              'order_label': 'Order $order',
              'order_control': control,
            },
    };

Map<String, dynamic> _snapshot(List<Map<String, dynamic>> rows,
        {String epoch = 'epoch-1', String version = 'version-1'}) =>
    {
      'event': 'inventory.snapshot',
      'id': 'window',
      'epoch': epoch,
      'revision': 0,
      'version': version,
      'rows': rows,
    };

Map<String, dynamic> _delta({
  List<Map<String, dynamic>> upserts = const [],
  List<String> removed = const [],
  required List<String> order,
  int base = 0,
  int revision = 1,
}) =>
    {
      'event': 'inventory.delta',
      'id': 'window',
      'epoch': 'epoch-1',
      'base_revision': base,
      'revision': revision,
      'version': 'version-$revision-new',
      'upserts': upserts,
      'removed': removed,
      'order': order,
    };

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late InventoryViewStore store;
  late String scope;
  late List<StreamController<Map<String, dynamic>>> sockets;
  late List<String?> versions;
  late int reads;

  setUp(() {
    scope = 'account-a';
    sockets = [];
    versions = [];
    reads = 0;
    store = InventoryViewStore(
      scopeReader: () => scope,
      liveEnabled: () => true,
      snapshotLoader: (_) async {
        reads++;
        return [InventoryAsset.fromJson(_asset('fallback'))];
      },
      liveLoader: (_, version) {
        versions.add(version);
        final socket = StreamController<Map<String, dynamic>>(sync: true);
        sockets.add(socket);
        return socket.stream;
      },
      reconnectDelay: (_) => const Duration(milliseconds: 5),
    );
  });

  tearDown(() async {
    store.reset();
    await Future.wait(sockets.map((socket) => socket.close()));
  });

  test('window subscriptions encode query numbers and flags as typed JSON', () {
    final query = InventoryViewQuery.assets(
        currentUserStatesOnly: true, limit: 500, offset: 100);
    expect(query.subscription()['query'], {
      'current_user_states_only': true,
      'include_order_assignment': true,
      'limit': 500,
      'offset': 100,
    });
  });

  test('joins initial read and maintains deltas while route is disposed',
      () async {
    final first = store.assets();
    final joined = store.assets();
    expect(sockets, hasLength(1));
    sockets.single.add(_snapshot([_asset('a'), _asset('b')]));
    await Future.wait([first.ready, joined.ready]);
    final original = first.rows!;
    first.dispose();
    joined.dispose();
    expect(sockets.single.hasListener, isTrue);

    sockets.single.add(_delta(
        upserts: [_asset('c', order: 'o', control: 'frozen')],
        removed: ['raw_material:b'],
        order: ['raw_material:c', 'raw_material:a']));
    final reentered = store.assets();
    await reentered.ready;
    expect(reads, 0);
    expect(sockets, hasLength(1));
    expect(reentered.rows!.map((row) => row.assetRef), ['c', 'a']);
    expect(reentered.rows!.first.orderAssignment!.orderControl, 'frozen');
    expect(reentered.rows!.last, same(original.first));
    reentered.dispose();
  });

  test('authoritative known-null delta clears a removed order badge', () async {
    final lease = store.assets();
    sockets.single.add(_snapshot([_asset('a', order: 'o')]));
    await lease.ready;
    sockets.single
        .add(_delta(upserts: [_asset('a')], order: ['raw_material:a']));
    expect(lease.rows!.single.orderAssignmentKnown, isTrue);
    expect(lease.rows!.single.orderAssignment, isNull);
    lease.dispose();
  });

  test(
      'duplicate delta is ignored; gap preserves rows and validates on reconnect',
      () async {
    final lease = store.assets();
    sockets.single.add(_snapshot([_asset('a')]));
    await lease.ready;
    sockets.single.add(_delta(
        upserts: [_asset('b')], order: ['raw_material:a', 'raw_material:b']));
    final current = lease.rows;
    sockets.single.add(_delta(order: []));
    expect(lease.rows, same(current));
    expect(lease.trusted, isTrue);
    sockets.single.add(_delta(base: 2, revision: 3, order: []));
    expect(lease.trusted, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(sockets, hasLength(2));
    // A continuity loss permits one bounded HTTP reconciliation. Retries
    // afterwards are sockets only; they do not poll the full inventory.
    expect(reads, 1);
    sockets.last.add(_snapshot([_asset('a')], epoch: 'epoch-2'));
    expect(lease.trusted, isTrue);
    lease.dispose();
  });

  test('resume sends version and unchanged ready reuses exact decoded rows',
      () async {
    final lease = store.assets();
    sockets.single.add(_snapshot([_asset('a')]));
    await lease.ready;
    final original = lease.rows;
    store.configure(foreground: false);
    store.configure(foreground: true);
    expect(versions, [null, 'version-1']);
    sockets.last.add({
      'event': 'inventory.ready',
      'id': 'window',
      'epoch': 'epoch-2',
      'revision': 0,
      'version': 'version-1',
    });
    expect(lease.rows, same(original));
    expect(lease.trusted, isTrue);
    expect(reads, 0);
    lease.dispose();
  });

  test('scope reset clears mounted leases and rejects late account HTTP',
      () async {
    final pending = Completer<List<Object>>();
    store = InventoryViewStore(
        scopeReader: () => scope,
        liveEnabled: () => false,
        snapshotLoader: (_) => pending.future);
    final lease = store.assets();
    scope = 'account-b';
    store.configure(foreground: true);
    pending.complete([InventoryAsset.fromJson(_asset('private-a'))]);
    await lease.ready;
    await _flush();
    expect(lease.rows, isNull);
    lease.dispose();
  });

  test('committed write cancels stale HTTP; concurrent repairs are joined',
      () async {
    final pending = <Completer<List<Object>>>[];
    store = InventoryViewStore(
        scopeReader: () => scope,
        liveEnabled: () => false,
        snapshotLoader: (_) {
          final read = Completer<List<Object>>();
          pending.add(read);
          return read.future;
        });
    final lease = store.assets();
    expect(pending, hasLength(1));
    final repair = store.reconcileAfterWrite();
    final joined = store.reconcileAfterWrite();
    expect(pending, hasLength(2));
    pending.first.complete([InventoryAsset.fromJson(_asset('stale'))]);
    await _flush();
    expect(lease.rows, isNull);
    pending.last.complete([InventoryAsset.fromJson(_asset('committed'))]);
    await Future.wait([repair, joined]);
    expect(lease.rows!.single.assetRef, 'committed');
    lease.dispose();
  });

  test('healthy committed write leaves stream and canonical rows intact',
      () async {
    final lease = store.assets();
    sockets.single.add(_snapshot([_asset('a')]));
    await lease.ready;
    final original = lease.rows;
    await store.reconcileAfterWrite();
    expect(lease.rows, same(original));
    expect(sockets, hasLength(1));
    expect(reads, 0);
    lease.dispose();
  });

  test('old searches are evicted and disconnected instead of kept live',
      () async {
    final first = store.assets(query: 'old');
    sockets.single.add(_snapshot([_asset('a')]));
    await first.ready;
    first.dispose();
    final second = store.assets(query: 'new');
    expect(sockets.first.hasListener, isFalse);
    sockets.last.add(_snapshot([_asset('b')]));
    await second.ready;
    second.dispose();
  });

  test('authorization reset clears all windows and blocks same-scope reuse',
      () async {
    final lease = store.assets();
    sockets.single.add(_snapshot([_asset('a')]));
    await lease.ready;
    sockets.single.add({'event': 'inventory.reset'});
    expect(lease.rows, isNull);
    expect(lease.error, isNotNull);
    final blocked = store.assets();
    await blocked.ready;
    expect(blocked.rows, isNull);
    expect(blocked.error, isNotNull);
    expect(sockets, hasLength(1));
    lease.dispose();
    blocked.dispose();
  });

  test('HTTP403 after a failed handshake removes previously cached rows',
      () async {
    var denied = false;
    store = InventoryViewStore(
        scopeReader: () => scope,
        liveEnabled: () => true,
        liveLoader: (_, __) {
          final socket = StreamController<Map<String, dynamic>>(sync: true);
          sockets.add(socket);
          return socket.stream;
        },
        snapshotLoader: (_) async {
          if (denied) {
            throw const MobileApiException(
                code: 'forbidden', message: 'Denied', statusCode: 403);
          }
          return [InventoryAsset.fromJson(_asset('a'))];
        });
    final lease = store.assets();
    sockets.single.add(_snapshot([_asset('a')]));
    await lease.ready;
    denied = true;
    sockets.single.addError(StateError('socket rejected'));
    await _flush();
    expect(lease.rows, isNull);
    expect(lease.error, isNotNull);
    lease.dispose();
  });

  test('older backend fallback does one read per visit; retries never poll',
      () async {
    final first = store.assets();
    sockets.single.addError(StateError('404'));
    await first.ready;
    expect(reads, 1);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    sockets.last.addError(StateError('404'));
    await _flush();
    expect(reads, 1);
    first.dispose();
    final second = store.assets();
    sockets.last.addError(StateError('404'));
    await second.ready;
    expect(reads, 2);
    expect(second.rows!.single.assetRef, 'fallback');
    second.dispose();
  });
}
