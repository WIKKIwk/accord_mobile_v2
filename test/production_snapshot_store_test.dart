import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';
import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store_native.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryBackend implements ProductionSnapshotBackend {
  final values = <String, Uint8List>{};
  final dates = <String, int>{};
  Completer<void>? writeGate;
  Completer<void>? writeStarted;
  Completer<void>? readGate;
  Completer<void>? readStarted;
  bool fail = false;

  void _check() {
    if (fail) throw const FileSystemException('unavailable');
  }

  @override
  Future<Uint8List?> read(String id, {required int maxBytes}) async {
    _check();
    if (readStarted?.isCompleted == false) readStarted!.complete();
    await readGate?.future;
    final value = values[id];
    return value != null && value.length <= maxBytes
        ? Uint8List.fromList(value)
        : null;
  }

  @override
  Future<void> write(String id, Uint8List bytes,
      {required int savedAtMs}) async {
    _check();
    if (writeStarted?.isCompleted == false) writeStarted!.complete();
    await writeGate?.future;
    values[id] = Uint8List.fromList(bytes);
    dates[id] = savedAtMs;
  }

  @override
  Future<List<ProductionSnapshotStoredEntry>> entries() async {
    _check();
    return [
      for (final entry in values.entries)
        ProductionSnapshotStoredEntry(
            id: entry.key,
            bytes: entry.value.length,
            savedAtMs: dates[entry.key]!),
    ];
  }

  @override
  Future<void> remove(String id) async {
    _check();
    values.remove(id);
    dates.remove(id);
  }

  @override
  Future<void> clear() async {
    _check();
    values.clear();
    dates.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const scope = 'https://server.example/|worker-01|apparatus:001';
  const key = 'worker-window-10';
  const snapshot = {
    'epoch': 'server-epoch',
    'scope': 'authorization-scope',
    'rev': 123,
    'sequences': {
      'apparatus:001': ['zakaz-1', 'zakaz-2'],
    },
    'customer': 'O‘zbekiston — 日本語',
  };

  test('fresh store instance restores exact baseline from native disk',
      () async {
    final root = await Directory.systemTemp.createTemp('production-snapshot-');
    addTearDown(() => root.delete(recursive: true));
    final first = ProductionSnapshotStore(
        backend: FileProductionSnapshotBackend(directory: root));
    await first.write(scope: scope, key: key, value: snapshot);
    await first.flush();
    final files = await root.list().toList();
    expect(files, hasLength(1));
    expect(files.single.uri.pathSegments.last,
        matches(RegExp(r'^[a-f0-9]{64}\.snapshot$')));
    final raw = await (files.single as File).readAsString();
    expect(raw, isNot(contains('worker-01')));
    expect(raw, isNot(contains('server.example')));
    final restarted = ProductionSnapshotStore(
        backend: FileProductionSnapshotBackend(directory: root));
    expect(await restarted.read(scope: scope, key: key), snapshot);
    await restarted
        .write(scope: scope, key: key, value: {...snapshot, 'rev': 124});
    final restartedAgain = ProductionSnapshotStore(
        backend: FileProductionSnapshotBackend(directory: root));
    expect((await restartedAgain.read(scope: scope, key: key))?['rev'], 124);
    final unrelated =
        await File('${root.path}/unrelated.txt').writeAsString('x');
    await restartedAgain.clear();
    expect(await unrelated.exists(), isTrue);
    expect(await restartedAgain.read(scope: scope, key: key), isNull);
  });

  test('server, account, permission and query identities remain isolated',
      () async {
    final store = ProductionSnapshotStore(backend: _MemoryBackend());
    await store.write(scope: scope, key: key, value: snapshot);
    for (final otherScope in [
      scope.replaceFirst('server.example', 'other.example'),
      scope.replaceFirst('worker-01', 'worker-02'),
      scope.replaceFirst('apparatus:001', 'apparatus:002'),
    ]) {
      expect(await store.read(scope: otherScope, key: key), isNull);
    }
    expect(await store.read(scope: scope, key: 'worker-window-20'), isNull);
    expect(await store.read(scope: scope, key: key), snapshot);
  });

  test('empty identities do not write and invalid limits fail immediately',
      () async {
    final backend = _MemoryBackend();
    final store = ProductionSnapshotStore(backend: backend);
    await store.write(scope: '', key: key, value: snapshot);
    await store.write(scope: scope, key: '', value: snapshot);
    expect(backend.values, isEmpty);
    expect(await store.read(scope: '', key: key), isNull);
    expect(() => ProductionSnapshotStore(maxEntries: 0), throwsArgumentError);
    expect(() => ProductionSnapshotStore(maxAge: Duration.zero),
        throwsArgumentError);
    expect(() => ProductionSnapshotStore(maxEntryBytes: 10, maxTotalBytes: 9),
        throwsArgumentError);
  });

  test('expiry and backwards clocks safely discard old baseline', () async {
    var now = DateTime.utc(2026, 10, 22);
    final backend = _MemoryBackend();
    final store = ProductionSnapshotStore(
        backend: backend, now: () => now, maxAge: const Duration(hours: 1));
    await store.write(scope: scope, key: key, value: snapshot);
    now = now.add(const Duration(minutes: 59));
    expect(await store.read(scope: scope, key: key), snapshot);
    now = now.add(const Duration(minutes: 1));
    expect(await store.read(scope: scope, key: key), isNull);
    expect(backend.values, isEmpty);
    await store.write(scope: scope, key: key, value: snapshot);
    now = now.subtract(const Duration(seconds: 1));
    expect(await store.read(scope: scope, key: key), isNull);
    expect(backend.values, isEmpty);
  });

  test('corrupt, truncated and unknown-schema entries safely miss', () async {
    final backend = _MemoryBackend();
    final store = ProductionSnapshotStore(backend: backend);
    for (final corrupt in [
      (Map<String, dynamic> value) => value['schema'] = 99,
      (Map<String, dynamic> value) => value['sha256'] = 'invalid',
      (Map<String, dynamic> value) => value['scope'] = 'different-account',
      (Map<String, dynamic> value) => value['key'] = 'different-query',
      (Map<String, dynamic> value) => value['saved_at_ms'] = 'not-an-int',
      (Map<String, dynamic> value) => value['value'] = ['not-an-object'],
      (Map<String, dynamic> value) => (value['value'] as Map)['rev'] = 999,
    ]) {
      await store.write(scope: scope, key: key, value: snapshot);
      final id = backend.values.keys.single;
      final decoded = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(backend.values[id]!)));
      corrupt(decoded);
      // Keep the valid envelope boundary so every mutation exercises the
      // metadata/checksum validator rather than only the outer format check.
      final changedValue = decoded.remove('value');
      backend.values[id] = Uint8List.fromList(
          utf8.encode('{"value":${jsonEncode(changedValue)},\n'
              '${jsonEncode(decoded).substring(1)}'));
      expect(await store.read(scope: scope, key: key), isNull);
      expect(backend.values, isEmpty);
    }
    await store.write(scope: scope, key: key, value: snapshot);
    backend.values[backend.values.keys.single] = Uint8List.fromList([123]);
    expect(await store.read(scope: scope, key: key), isNull);
    await store.write(scope: scope, key: key, value: snapshot);
    backend.values[backend.values.keys.single] = Uint8List.fromList([255]);
    expect(await store.read(scope: scope, key: key), isNull);
  });

  test('scope-swapped disk contents fail envelope validation', () async {
    final backend = _MemoryBackend();
    final store = ProductionSnapshotStore(backend: backend);
    await store.write(scope: scope, key: key, value: snapshot);
    final source = backend.values.values.single;
    await store.write(scope: 'another-account', key: key, value: snapshot);
    final other = backend.values.keys.last;
    backend.values[other] = source;
    expect(await store.read(scope: 'another-account', key: key), isNull);
    expect(await store.read(scope: scope, key: key), snapshot);
  });

  test('entry count is bounded with oldest saved entries evicted first',
      () async {
    var now = DateTime.utc(2026, 10, 22);
    final backend = _MemoryBackend();
    final store = ProductionSnapshotStore(
        backend: backend, now: () => now, maxEntries: 2);
    for (var i = 0; i < 3; i++) {
      await store.write(scope: scope, key: '$i', value: {'rev': i});
      now = now.add(const Duration(seconds: 1));
    }
    expect(backend.values, hasLength(2));
    expect(await store.read(scope: scope, key: '0'), isNull);
    expect(await store.read(scope: scope, key: '1'), {'rev': 1});
    expect(await store.read(scope: scope, key: '2'), {'rev': 2});
  });

  test('total encoded bytes and maximum individual entry are bounded',
      () async {
    var now = DateTime.utc(2026, 10, 22);
    final backend = _MemoryBackend();
    final store = ProductionSnapshotStore(
      backend: backend,
      now: () => now,
      maxEntryBytes: 700,
      maxTotalBytes: 1000,
    );
    for (var i = 0; i < 3; i++) {
      await store.write(scope: scope, key: '$i', value: {'data': 'x' * 100});
      now = now.add(const Duration(seconds: 1));
      expect(backend.values.values.fold<int>(0, (n, bytes) => n + bytes.length),
          lessThanOrEqualTo(1000));
    }
    await store
        .write(scope: scope, key: 'oversized', value: {'data': 'x' * 1000});
    expect(await store.read(scope: scope, key: 'oversized'), isNull);
    // Replacing a single entry does not double-count the old stored bytes.
    await store.write(scope: scope, key: '2', value: {'data': 'y' * 100});
    expect((await store.read(scope: scope, key: '2'))?['data'], 'y' * 100);
  });

  test('queued writes capture immutable JSON immediately', () async {
    final backend = _MemoryBackend()
      ..writeGate = Completer<void>()
      ..writeStarted = Completer<void>();
    final store = ProductionSnapshotStore(backend: backend);
    final first = store.write(scope: scope, key: 'first', value: snapshot);
    await backend.writeStarted!.future;
    final values = ['original'];
    final second = store.write(scope: scope, key: key, value: {'ids': values});
    values.add('later mutation');
    backend.writeGate!.complete();
    await Future.wait([first, second]);
    expect(await store.read(scope: scope, key: key), {
      'ids': ['original'],
    });
  });

  test('logout clear defeats an in-flight save and queued stale saves',
      () async {
    final backend = _MemoryBackend()
      ..writeGate = Completer<void>()
      ..writeStarted = Completer<void>();
    final store = ProductionSnapshotStore(backend: backend);
    final inFlight = store.write(scope: scope, key: 'first', value: snapshot);
    await backend.writeStarted!.future;
    final queued = store.write(scope: scope, key: key, value: snapshot);
    final cleared = store.clear();
    final newSession =
        store.write(scope: 'new-session', key: key, value: {'rev': 2});
    backend.writeGate!.complete();
    await Future.wait([inFlight, queued, cleared, newSession]);
    expect(await store.read(scope: scope, key: 'first'), isNull);
    expect(await store.read(scope: scope, key: key), isNull);
    expect(await store.read(scope: 'new-session', key: key), {'rev': 2});
    expect(backend.values, hasLength(1));
  });

  test('clear synchronously invalidates the captured screen generation',
      () async {
    final backend = _MemoryBackend()
      ..writeGate = Completer<void>()
      ..writeStarted = Completer<void>();
    final store = ProductionSnapshotStore(backend: backend);
    final before = store.generation;
    final saving = store.write(scope: scope, key: key, value: snapshot);
    await backend.writeStarted!.future;
    final cleared = store.clear();
    expect(store.generation, greaterThan(before));
    backend.writeGate!.complete();
    await Future.wait([saving, cleared]);
  });

  test('logout invalidates an in-flight read before it is returned', () async {
    final backend = _MemoryBackend();
    final store = ProductionSnapshotStore(backend: backend);
    await store.write(scope: scope, key: key, value: snapshot);
    backend
      ..readGate = Completer<void>()
      ..readStarted = Completer<void>();
    final read = store.read(scope: scope, key: key);
    await backend.readStarted!.future;
    final clear = store.clear();
    backend.readGate!.complete();
    expect(await read, isNull);
    await clear;
    expect(backend.values, isEmpty);
  });

  test('remove invalidates target queued saves without cancelling other keys',
      () async {
    final backend = _MemoryBackend()
      ..writeGate = Completer<void>()
      ..writeStarted = Completer<void>();
    final store = ProductionSnapshotStore(backend: backend);
    final initial = store.write(scope: scope, key: 'blocker', value: snapshot);
    await backend.writeStarted!.future;
    final target = store.write(scope: scope, key: key, value: snapshot);
    final other = store.write(scope: scope, key: 'other', value: snapshot);
    final remove = store.remove(scope: scope, key: key);
    backend.writeGate!.complete();
    await Future.wait([initial, target, other, remove]);
    expect(await store.read(scope: scope, key: key), isNull);
    expect(await store.read(scope: scope, key: 'other'), snapshot);
  });

  test('optional storage failures do not poison subsequent operations',
      () async {
    final backend = _MemoryBackend()..fail = true;
    final store = ProductionSnapshotStore(backend: backend);
    await store.write(scope: scope, key: key, value: snapshot);
    expect(await store.read(scope: scope, key: key), isNull);
    await store.remove(scope: scope, key: key);
    await store.clear();
    backend.fail = false;
    await store.write(scope: scope, key: key, value: snapshot);
    expect(await store.read(scope: scope, key: key), snapshot);
  });

  test('a failed logout deletion blocks old reads until a new safe save',
      () async {
    final backend = _MemoryBackend();
    final store = ProductionSnapshotStore(backend: backend);
    await store.write(scope: scope, key: key, value: snapshot);
    backend.fail = true;
    await store.clear();
    backend.fail = false;
    expect(await store.read(scope: scope, key: key), isNull);
    await store.write(scope: scope, key: 'new', value: {'rev': 200});
    expect(await store.read(scope: scope, key: key), isNull);
    expect(await store.read(scope: scope, key: 'new'), {'rev': 200});
  });

  test('non-JSON values are ignored safely', () async {
    final backend = _MemoryBackend();
    final store = ProductionSnapshotStore(backend: backend);
    await store.write(scope: scope, key: key, value: {'object': Object()});
    expect(await store.read(scope: scope, key: key), isNull);
    expect(backend.values, isEmpty);
  });

  test('encoded JSON accepts exact object whitespace and rejects other values',
      () async {
    final store = ProductionSnapshotStore(backend: _MemoryBackend());
    await store.writeEncoded(
        scope: scope,
        key: key,
        valueJson: ' {\n "rev" : 7, "label": "日本語"\n } ');
    expect(await store.read(scope: scope, key: key), {
      'rev': 7,
      'label': '日本語',
    });
    for (final value in ['[1,2]', 'null', '1', '"hello"', '{"broken":']) {
      await store.writeEncoded(scope: scope, key: 'bad', valueJson: value);
      expect(await store.read(scope: scope, key: 'bad'), isNull);
    }
  });

  test('encoded large Unicode values roundtrip through background codecs',
      () async {
    final backend = _MemoryBackend();
    final store = ProductionSnapshotStore(backend: backend);
    final value = {'rev': 8, 'label': 'O‘zbekiston 日本語 🤭' * 10000};
    await store.writeEncoded(
        scope: scope, key: key, valueJson: jsonEncode(value));
    expect(backend.values.values.single.length, greaterThan(64 * 1024));
    final restarted = ProductionSnapshotStore(backend: backend);
    expect(await restarted.read(scope: scope, key: key), value);
  });

  test('logout rejects a delayed encoded result from an old generation',
      () async {
    final backend = _MemoryBackend();
    final store = ProductionSnapshotStore(backend: backend);
    final owner = store.generation;
    await store.clear();
    await store.writeEncoded(
      scope: scope,
      key: key,
      valueJson: jsonEncode(snapshot),
      expectedGeneration: owner,
    );
    expect(backend.values, isEmpty);
    await store.writeEncoded(
      scope: scope,
      key: key,
      valueJson: jsonEncode(snapshot),
      expectedGeneration: store.generation,
    );
    expect(await store.read(scope: scope, key: key), snapshot);
  });

  test('clear during a large background encode cannot resurrect an entry',
      () async {
    final backend = _MemoryBackend();
    final store = ProductionSnapshotStore(backend: backend);
    final pending = store.writeEncoded(
      scope: scope,
      key: key,
      valueJson: jsonEncode({'text': 'x' * 1024 * 1024}),
    );
    await Future<void>.delayed(Duration.zero);
    final clear = store.clear();
    await Future.wait([pending, clear]);
    expect(backend.values, isEmpty);
  });

  test('native interrupted atomic writes are cleaned and deleted root recovers',
      () async {
    final root = await Directory.systemTemp.createTemp('production-snapshot-');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final orphan = await root.createTemp('.pending-');
    await File('${orphan.path}/value').writeAsString('interrupted-data');
    final unrelated = await Directory('${root.path}/unrelated').create();
    final store = ProductionSnapshotStore(
        backend: FileProductionSnapshotBackend(directory: root));
    await store.write(scope: scope, key: key, value: snapshot);
    expect(await orphan.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
    await root.delete(recursive: true);
    await store.write(scope: scope, key: key, value: snapshot);
    expect(await store.read(scope: scope, key: key), snapshot);
  });

  test('native permission failure keeps failed logout reads quarantined',
      () async {
    final root = await Directory.systemTemp.createTemp('production-snapshot-');
    addTearDown(() async {
      await Process.run('chmod', ['700', root.path]);
      await root.delete(recursive: true);
    });
    final backend = FileProductionSnapshotBackend(directory: root);
    final store = ProductionSnapshotStore(backend: backend);
    await store.write(scope: scope, key: key, value: snapshot);
    final entry = (await backend.entries()).single;
    expect((await Process.run('chmod', ['500', root.path])).exitCode, 0);
    await expectLater(
        backend.remove(entry.id), throwsA(isA<FileSystemException>()));
    await store.clear();
    expect((await Process.run('chmod', ['700', root.path])).exitCode, 0);
    expect((await backend.entries()), hasLength(1));
    expect(await store.read(scope: scope, key: key), isNull);
    await store.write(scope: scope, key: 'new', value: {'rev': 9});
    expect(await store.read(scope: scope, key: key), isNull);
    expect(await store.read(scope: scope, key: 'new'), {'rev': 9});
  }, skip: Platform.isWindows);

  test('truncated native file is removed and a later write recovers', () async {
    final root = await Directory.systemTemp.createTemp('production-snapshot-');
    addTearDown(() => root.delete(recursive: true));
    final store = ProductionSnapshotStore(
        backend: FileProductionSnapshotBackend(directory: root));
    await store.write(scope: scope, key: key, value: snapshot);
    final file = (await root.list().toList()).single as File;
    await file.writeAsString('{"schema":');
    expect(await store.read(scope: scope, key: key), isNull);
    expect(await file.exists(), isFalse);
    await store.write(scope: scope, key: key, value: snapshot);
    expect(await store.read(scope: scope, key: key), snapshot);
  });
}
