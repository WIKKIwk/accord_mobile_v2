import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'order_image_disk_store_base.dart';
import 'order_image_disk_store_stub.dart'
    if (dart.library.io) 'order_image_disk_store_io.dart';

/// Shared by order lists, calculate previews, bottom sheets and full-size zoom.
/// Callers include server + account/session + image version + variant in [key].
class OrderImageCache {
  OrderImageCache(
      {OrderImageDiskStore? disk,
      this.maxMemoryBytes = 24 * 1024 * 1024,
      DateTime Function()? now})
      : _disk = disk ?? createOrderImageDiskStore(),
        _now = now ?? DateTime.now;
  static final _instance = OrderImageCache();

  /// Allows widget tests to use deterministic storage without native plugins.
  static OrderImageCache? debugOverride;
  static OrderImageCache get instance => debugOverride ?? _instance;
  final OrderImageDiskStore _disk;
  final DateTime Function() _now;
  final int maxMemoryBytes;
  final _memory = <String, _ImageEntry>{};
  final Map<String, Future<Uint8List?>> _inflight = {};
  final _missingUntil = <String, DateTime>{};
  // A user opening a full image never queues behind hundreds of thumbnails.
  final _thumbs = _ImageDownloadPool(4);
  final _full = _ImageDownloadPool(2);
  int _generation = 0;

  Future<Uint8List?> load(
      {required String key,
      required bool thumbnail,
      required bool immutable,
      required Future<http.Response> Function(String? etag) fetch,
      bool Function()? isCurrent}) {
    final digest = sha256.convert(utf8.encode(key)).toString();
    if (_missingUntil[digest]?.isAfter(_now()) == true) return Future.value();
    _missingUntil.remove(digest);
    return _inflight.putIfAbsent(digest, () {
      final generation = _generation;
      late Future<Uint8List?> future;
      future = _load(digest, thumbnail, immutable, fetch,
              () => generation == _generation && (isCurrent?.call() ?? true))
          .whenComplete(() {
        if (identical(_inflight[digest], future)) _inflight.remove(digest);
      });
      return future;
    });
  }

  Future<Uint8List?> _load(
      String key,
      bool thumbnail,
      bool immutable,
      Future<http.Response> Function(String?) fetch,
      bool Function() current) async {
    var entry = _memory.remove(key);
    if (entry == null) {
      try {
        entry = _ImageEntry.decode(
            await _disk.read(key).timeout(const Duration(milliseconds: 250)));
      } catch (_) {/* optional cache */}
    }
    if (!current()) return null;
    final ttl =
        immutable ? const Duration(days: 1) : const Duration(seconds: 30);
    if (entry != null &&
        _now().difference(entry.storedAt) >= Duration.zero &&
        _now().difference(entry.storedAt) < ttl) {
      _remember(key, entry);
      return entry.bytes;
    }
    return (thumbnail ? _thumbs : _full).run(() async {
      if (!current()) return null;
      final response = await fetch(entry?.etag);
      if (!current()) return null;
      if (response.statusCode == 404 ||
          response.statusCode == 403 ||
          response.statusCode == 401) {
        _memory.remove(key);
        if (response.statusCode == 404) {
          _missingUntil[key] = _now().add(const Duration(seconds: 15));
          while (_missingUntil.length > 512) {
            _missingUntil.remove(_missingUntil.keys.first);
          }
        }
        try {
          await _disk.remove(key);
        } catch (_) {/* optional cache */}
        return null;
      }
      final Uint8List bytes;
      if (response.statusCode == 304 && entry != null) {
        bytes = entry.bytes;
      } else if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        bytes = response.bodyBytes;
      } else {
        throw http.ClientException('Order image HTTP ${response.statusCode}');
      }
      final updated = _ImageEntry(
          bytes,
          response.headers['etag'] ??
              (response.statusCode == 304 ? entry?.etag : null),
          _now());
      if (response.headers['cache-control']
              ?.toLowerCase()
              .contains('no-store') ==
          true) {
        _memory.remove(key);
        try {
          await _disk.remove(key);
        } catch (_) {/* optional cache */}
        return bytes;
      }
      if (current() && bytes.length <= 8 * 1024 * 1024) {
        _remember(key, updated);
        // Persistence never delays the image's first paint.
        unawaited(_disk.write(key, updated.encode()).catchError((Object _) {}));
      }
      return bytes;
    });
  }

  void _remember(String key, _ImageEntry entry) {
    _memory.remove(key);
    _memory[key] = entry;
    var bytes = _memory.values.fold(0, (a, b) => a + b.bytes.length);
    while (bytes > maxMemoryBytes || _memory.length > 256) {
      bytes -= _memory.remove(_memory.keys.first)!.bytes.length;
    }
  }

  Future<void> clear() async {
    _generation++;
    _inflight.clear();
    _memory.clear();
    _missingUntil.clear();
    try {
      await _disk.clear().timeout(const Duration(seconds: 2));
    } catch (_) {/* cache unavailable */}
  }
}

class _ImageEntry {
  _ImageEntry(this.bytes, this.etag, this.storedAt);
  final Uint8List bytes;
  final String? etag;
  final DateTime storedAt;
  Uint8List encode() {
    final header = utf8.encode(
        jsonEncode({'etag': etag, 'at': storedAt.millisecondsSinceEpoch}));
    final output = Uint8List(4 + header.length + bytes.length);
    ByteData.sublistView(output).setUint32(0, header.length);
    output.setRange(4, 4 + header.length, header);
    output.setRange(4 + header.length, output.length, bytes);
    return output;
  }

  static _ImageEntry? decode(Uint8List? data) {
    if (data == null || data.length < 5 || data.length > 9 * 1024 * 1024) {
      return null;
    }
    final length = ByteData.sublistView(data).getUint32(0);
    if (length > 4096 || 4 + length >= data.length) return null;
    final header = jsonDecode(utf8.decode(data.sublist(4, 4 + length))) as Map;
    return _ImageEntry(
        Uint8List.sublistView(data, 4 + length),
        header['etag'] as String?,
        DateTime.fromMillisecondsSinceEpoch(header['at'] as int));
  }
}

class _ImageDownloadPool {
  _ImageDownloadPool(this.limit);
  final int limit;
  int active = 0;
  final waiting = Queue<Completer<void>>();
  Future<T> run<T>(Future<T> Function() task) async {
    if (active >= limit) {
      final ready = Completer<void>();
      waiting.add(ready);
      await ready.future;
    } else {
      active++;
    }
    try {
      return await task();
    } finally {
      if (waiting.isEmpty) {
        active--;
      } else {
        waiting.removeFirst().complete();
      }
    }
  }
}
