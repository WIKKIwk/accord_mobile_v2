import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'production_snapshot_store_backend.dart';
import 'production_snapshot_store_native.dart'
    if (dart.library.js_interop) 'production_snapshot_store_web.dart'
    as platform;

export 'production_snapshot_store_backend.dart';

const _backgroundCodecThreshold = 64 * 1024;

String _snapshotHash(String value) =>
    sha256.convert(utf8.encode(value)).toString();

Uint8List _encodeSnapshotEnvelope(Map<String, Object> message) {
  final valueJson = message['value'] as String;
  if (jsonDecode(valueJson) is! Map) {
    throw const FormatException('Snapshot must be a JSON object');
  }
  final header = jsonEncode({
    'schema': ProductionSnapshotStore._schema,
    'scope': message['scope'],
    'key': message['key'],
    'saved_at_ms': message['saved_at_ms'],
    'sha256': _snapshotHash(valueJson),
  });
  // A fixed newline boundary preserves the exact immutable JSON for hashing.
  // It remains an ordinary JSON object, without decoding/re-encoding the
  // payload or escaping an entire second copy of it into a JSON string.
  final bytes = Uint8List.fromList(
      utf8.encode('{"value":$valueJson,\n${header.substring(1)}'));
  if (bytes.length > (message['max_bytes'] as int)) {
    throw const FormatException('Snapshot exceeds the local byte budget');
  }
  return bytes;
}

Map<String, dynamic> _decodeSnapshotEnvelope(Map<String, Object> message) {
  final bytes = message['bytes'] as Uint8List;
  if (bytes.length > (message['max_bytes'] as int)) {
    throw const FormatException('Oversized snapshot');
  }
  final encoded = utf8.decode(bytes);
  const prefix = '{"value":';
  final boundary = encoded.lastIndexOf('\n');
  if (!encoded.startsWith(prefix) ||
      boundary <= prefix.length ||
      encoded[boundary - 1] != ',') {
    throw const FormatException('Invalid snapshot envelope');
  }
  final header = jsonDecode('{${encoded.substring(boundary + 1)}');
  if (header is! Map ||
      header['schema'] != ProductionSnapshotStore._schema ||
      header['scope'] != message['scope'] ||
      header['key'] != message['key'] ||
      header['saved_at_ms'] is! int ||
      header['sha256'] is! String) {
    throw const FormatException('Invalid snapshot metadata');
  }
  final age = (message['now_ms'] as int) - (header['saved_at_ms'] as int);
  if (age < 0 || age >= (message['max_age_ms'] as int)) {
    throw const FormatException('Expired snapshot');
  }
  final valueJson = encoded.substring(prefix.length, boundary - 1);
  if (_snapshotHash(valueJson) != header['sha256']) {
    throw const FormatException('Corrupt snapshot');
  }
  final value = jsonDecode(valueJson);
  if (value is! Map) {
    throw const FormatException('Snapshot must be a JSON object');
  }
  return Map<String, dynamic>.from(value);
}

/// Durable, bounded, optional baselines for server reconciliation.
///
/// A cached value is display data, never evidence that a write is authorized.
/// Callers bind [scope] to server/account/permissions and [key] to the exact
/// query. The server must confirm the saved revision before actions resume.
class ProductionSnapshotStore {
  ProductionSnapshotStore({
    ProductionSnapshotBackend? backend,
    DateTime Function()? now,
    this.maxAge = const Duration(days: 7),
    this.maxEntries = 24,
    this.maxEntryBytes = 16 * 1024 * 1024,
    this.maxTotalBytes = 64 * 1024 * 1024,
  })  : _backend = backend ?? platform.createProductionSnapshotBackend(),
        _now = now ?? DateTime.now {
    if (maxAge <= Duration.zero ||
        maxEntries <= 0 ||
        maxEntryBytes <= 0 ||
        maxTotalBytes < maxEntryBytes) {
      throw ArgumentError('Invalid production snapshot cache limits');
    }
  }

  static final _instance = ProductionSnapshotStore();
  static ProductionSnapshotStore? debugOverride;
  static ProductionSnapshotStore get instance => debugOverride ?? _instance;

  static const _schema = 1;
  final ProductionSnapshotBackend _backend;
  final DateTime Function() _now;
  final Duration maxAge;
  final int maxEntries;
  final int maxEntryBytes;
  final int maxTotalBytes;
  Future<void> _tail = Future.value();
  int _generation = 0;
  final _keyGenerations = <String, int>{};
  bool _needsClear = false;

  /// Capture when a screen opens; [clear] invalidates its delayed saves
  /// synchronously, before logout finishes replacing the session profile.
  int get generation => _generation;

  String _hash(String value) => _snapshotHash(value);
  String _id(String scope, String key) => _hash(jsonEncode([scope, key]));

  Future<T> _serial<T>(T fallback, Future<T> Function() operation) {
    final result = _tail.then((_) async {
      try {
        return await operation();
      } catch (_) {
        // Disk/plugin/JSON failures must not stop normal network loading.
        return fallback;
      }
    });
    _tail = result.then<void>((_) {});
    return result;
  }

  Future<Map<String, dynamic>?> read({
    required String scope,
    required String key,
  }) {
    if (scope.isEmpty || key.isEmpty) return Future.value();
    final id = _id(scope, key);
    final generation = _generation;
    final keyGeneration = _keyGenerations[id] ?? 0;
    bool current() =>
        generation == _generation &&
        keyGeneration == (_keyGenerations[id] ?? 0);
    return _serial(null, () async {
      if (!current() || _needsClear) return null;
      await _trim();
      final bytes = await _backend.read(id, maxBytes: maxEntryBytes);
      if (!current() || bytes == null) return null;
      Map<String, dynamic>? value;
      try {
        final message = <String, Object>{
          'bytes': bytes,
          'scope': _hash(scope),
          'key': _hash(key),
          'now_ms': _now().millisecondsSinceEpoch,
          'max_age_ms': maxAge.inMilliseconds,
          'max_bytes': maxEntryBytes,
        };
        value = bytes.length >= _backgroundCodecThreshold
            ? await compute(_decodeSnapshotEnvelope, message)
            : _decodeSnapshotEnvelope(message);
      } catch (_) {
        await _backend.remove(id);
        return null;
      }
      return current() ? value : null;
    });
  }

  Future<void> write({
    required String scope,
    required String key,
    required Map<String, dynamic> value,
  }) {
    // Capture immediately: callers may replace mutable UI maps while this
    // write waits behind another operation. Only this immutable encoding wins.
    try {
      return writeEncoded(scope: scope, key: key, valueJson: jsonEncode(value));
    } catch (_) {
      return Future.value();
    }
  }

  /// Large callers can build [valueJson] off the UI isolate. Capture
  /// [generation] before that work and pass it as [expectedGeneration] so a
  /// logout that finishes during computation rejects the delayed result.
  Future<void> writeEncoded({
    required String scope,
    required String key,
    required String valueJson,
    int? expectedGeneration,
  }) {
    if (scope.isEmpty ||
        key.isEmpty ||
        valueJson.length > maxEntryBytes ||
        (expectedGeneration != null && expectedGeneration != _generation)) {
      return Future.value();
    }
    final id = _id(scope, key);
    final generation = _generation;
    final keyGeneration = _keyGenerations[id] ?? 0;
    final savedAtMs = _now().millisecondsSinceEpoch;
    bool current() =>
        generation == _generation &&
        keyGeneration == (_keyGenerations[id] ?? 0);
    // Enqueue before awaiting compute, preserving write/clear ordering.
    return _serial<void>(null, () async {
      if (!current()) return;
      final message = <String, Object>{
        'value': valueJson,
        'scope': _hash(scope),
        'key': _hash(key),
        'saved_at_ms': savedAtMs,
        'max_bytes': maxEntryBytes,
      };
      final bytes = valueJson.length >= _backgroundCodecThreshold
          ? await compute(_encodeSnapshotEnvelope, message)
          : _encodeSnapshotEnvelope(message);
      if (!current()) return;
      // A failed logout deletion must not expose the old files when storage
      // becomes readable again. A later successful save first retries clear.
      if (_needsClear) {
        await _backend.clear();
        if (!current()) return;
        _needsClear = false;
      }
      // Reserve room before writing, so a crash after the atomic replace
      // cannot leave the persistent cache above its declared byte budget.
      await _trim(incomingId: id, incomingBytes: bytes.length);
      if (!current()) return;
      await _backend.write(id, bytes, savedAtMs: savedAtMs);
      // clear/remove may arrive during the asynchronous atomic write. Its
      // queued deletion follows this operation before any new read can run.
    });
  }

  Future<void> _trim({String? incomingId, int incomingBytes = 0}) async {
    final now = _now().millisecondsSinceEpoch;
    final entries = await _backend.entries();
    final retained = <ProductionSnapshotStoredEntry>[];
    for (final entry in entries) {
      final age = now - entry.savedAtMs;
      if (entry.bytes > maxEntryBytes ||
          age < 0 ||
          age >= maxAge.inMilliseconds) {
        await _backend.remove(entry.id);
      } else if (entry.id != incomingId) {
        retained.add(entry);
      }
    }
    retained.sort((a, b) => a.savedAtMs.compareTo(b.savedAtMs));
    var count = retained.length + (incomingId == null ? 0 : 1);
    var bytes = retained.fold<int>(incomingBytes, (sum, e) => sum + e.bytes);
    for (final entry in retained) {
      if (count <= maxEntries && bytes <= maxTotalBytes) break;
      await _backend.remove(entry.id);
      count--;
      bytes -= entry.bytes;
    }
  }

  Future<void> remove({required String scope, required String key}) {
    final id = _id(scope, key);
    if (!_keyGenerations.containsKey(id) &&
        _keyGenerations.length >= maxEntries * 4) {
      // Keep cancellation bookkeeping bounded even for many invalid queries.
      // Invalidating optional pending saves only causes a later cache miss.
      _generation++;
      _keyGenerations.clear();
    }
    _keyGenerations[id] = (_keyGenerations[id] ?? 0) + 1;
    return _serial<void>(null, () => _backend.remove(id));
  }

  /// Synchronously invalidates reads and saves already waiting for storage.
  /// Logout callers should await this before the next session is activated.
  Future<void> clear() {
    _generation++;
    _keyGenerations.clear();
    _needsClear = true;
    return _serial<void>(null, () async {
      await _backend.clear();
      _needsClear = false;
    });
  }

  Future<void> flush() => _tail;
}
