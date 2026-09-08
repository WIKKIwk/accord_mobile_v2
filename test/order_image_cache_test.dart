import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_base.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _Disk implements OrderImageDiskStore {
  final values = <String, Uint8List>{};
  @override
  Future<Uint8List?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Uint8List bytes) async {
    values[key] = bytes;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async {
    values.clear();
  }
}

void main() {
  test(
      'same image shares downloads; server/account/version/variant stay separate',
      () async {
    final cache = OrderImageCache(disk: _Disk());
    var reads = 0;
    Future<Uint8List?> get(String key, {bool thumb = true}) => cache.load(
        key: key,
        thumbnail: thumb,
        immutable: true,
        fetch: (_) async {
          reads++;
          return http.Response.bytes([1, 2, 3], 200);
        });
    expect(
        await Future.wait([get('a/me/image1/thumb'), get('a/me/image1/thumb')]),
        [
          [1, 2, 3],
          [1, 2, 3]
        ]);
    expect(reads, 1);
    await get('a/me/image1/thumb');
    expect(reads, 1);
    for (final key in [
      'a/me/image1/full',
      'a/me/image2/thumb',
      'a/other/image1/thumb',
      'b/me/image1/thumb'
    ]) {
      await get(key);
    }
    expect(reads, 5);
  });

  test(
      'expired mutable order links use ETag and 304 without downloading pixels',
      () async {
    var now = DateTime(2026);
    final cache = OrderImageCache(disk: _Disk(), now: () => now);
    var reads = 0;
    Future<Uint8List?> get() => cache.load(
        key: 'mutable-order',
        thumbnail: true,
        immutable: false,
        fetch: (etag) async {
          reads++;
          if (reads == 1) {
            expect(etag, isNull);
            return http.Response.bytes([4, 5, 6], 200,
                headers: {'etag': '"v1"'});
          }
          expect(etag, '"v1"');
          return http.Response('', 304);
        });
    expect(await get(), [4, 5, 6]);
    now = now.add(const Duration(seconds: 31));
    expect(await get(), [4, 5, 6]);
    expect(await get(), [4, 5, 6]);
    expect(reads, 2);
  });

  test('failures and no-store responses do not poison the cache', () async {
    final disk = _Disk();
    final cache = OrderImageCache(disk: disk);
    var status = 503;
    var reads = 0;
    Future<Uint8List?> get() => cache.load(
        key: 'retry',
        thumbnail: true,
        immutable: true,
        fetch: (_) async {
          reads++;
          return http.Response.bytes([1], status,
              headers: {'cache-control': 'no-store'});
        });
    await expectLater(get(), throwsA(isA<http.ClientException>()));
    status = 200;
    expect(await get(), [1]);
    expect(await get(), [1]);
    expect(reads, 3);
    expect(disk.values, isEmpty);
    status = 403;
    expect(await get(), isNull);
    status = 200;
    expect(await get(), [1]);
  });

  test('logout drops an in-flight result and cannot repopulate cleared disk',
      () async {
    final disk = _Disk();
    final cache = OrderImageCache(disk: disk);
    final entered = Completer<void>();
    final response = Completer<http.Response>();
    final pending = cache.load(
        key: 'old-account',
        thumbnail: false,
        immutable: true,
        fetch: (_) {
          entered.complete();
          return response.future;
        });
    await entered.future;
    await cache.clear();
    response.complete(http.Response.bytes([1, 2, 3], 200));
    expect(await pending, isNull);
    expect(disk.values, isEmpty);
  });

  test('missing images avoid request storms but recover after a short TTL',
      () async {
    var now = DateTime(2026);
    var reads = 0;
    var missing = true;
    final cache = OrderImageCache(disk: _Disk(), now: () => now);
    Future<Uint8List?> get() => cache.load(
        key: 'missing-image',
        thumbnail: true,
        immutable: true,
        fetch: (_) async {
          reads++;
          return missing
              ? http.Response('not found', 404)
              : http.Response.bytes([1, 2, 3], 200);
        });
    expect(await get(), isNull);
    missing = false;
    expect(await get(), isNull);
    expect(reads, 1);
    now = now.add(const Duration(seconds: 16));
    expect(await get(), [1, 2, 3]);
    expect(reads, 2);
  });

  test(
      'full-size view bypasses thumbnail backlog and thumbnails have bounded concurrency',
      () async {
    final cache = OrderImageCache(disk: _Disk());
    final release = Completer<http.Response>();
    var thumbnailReads = 0;
    final thumbs = [
      for (var i = 0; i < 12; i++)
        cache.load(
            key: 'thumb-$i',
            thumbnail: true,
            immutable: true,
            fetch: (_) {
              thumbnailReads++;
              return release.future;
            })
    ];
    await Future<void>.delayed(Duration.zero);
    expect(thumbnailReads, 4);
    expect(
        await cache.load(
            key: 'full',
            thumbnail: false,
            immutable: true,
            fetch: (_) async => http.Response.bytes([9, 8, 7], 200)),
        [9, 8, 7]);
    expect(thumbnailReads, 4);
    release.complete(http.Response.bytes([1], 200));
    await Future.wait(thumbs);
    expect(thumbnailReads, 12);
  });

  test(
      'disk survives memory eviction/restart and stores full and thumbnail separately',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('accord-image-cache-test-');
    addTearDown(() => directory.delete(recursive: true));
    final disk = FileOrderImageDiskStore(directory: directory);
    var reads = 0;
    Future<Uint8List?> get(OrderImageCache cache, String key) => cache.load(
        key: key,
        thumbnail: key == 'thumb',
        immutable: true,
        fetch: (_) async {
          reads++;
          return http.Response.bytes(key == 'thumb' ? [1, 2] : [9, 8, 7], 200);
        });
    final first = OrderImageCache(disk: disk, maxMemoryBytes: 1);
    await get(first, 'thumb');
    await get(first, 'full');
    // A read is serialized behind the pending writes, just as a later launch is.
    await disk.read(''.padLeft(64, 'a'));
    final restarted =
        OrderImageCache(disk: FileOrderImageDiskStore(directory: directory));
    expect(await get(restarted, 'thumb'), [1, 2]);
    expect(await get(restarted, 'full'), [9, 8, 7]);
    expect(reads, 2);
    await restarted.clear();
    expect(await directory.list().toList(), isEmpty);
  });

  test('disk budget evicts managed files only and rejects path traversal',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('accord-image-budget-test-');
    addTearDown(() => directory.delete(recursive: true));
    final unrelated = File('${directory.path}/keep.txt');
    await unrelated.writeAsString('keep');
    final disk = FileOrderImageDiskStore(directory: directory, maxBytes: 5);
    final a = ''.padLeft(64, 'a');
    final b = ''.padLeft(64, 'b');
    await disk.write(a, Uint8List.fromList([1, 2, 3]));
    await disk.write(b, Uint8List.fromList([4, 5, 6]));
    expect(await disk.read(a), isNull);
    expect(await disk.read(b), [4, 5, 6]);
    await expectLater(disk.read('../keep.txt'), throwsArgumentError);
    await disk.clear();
    expect(await unrelated.readAsString(), 'keep');
  });
}
