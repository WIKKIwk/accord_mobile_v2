import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/cache/production_snapshot_store.dart';

class MemoryProductionSnapshotBackend implements ProductionSnapshotBackend {
  final values = <String, Uint8List>{};
  final savedAt = <String, int>{};
  int writeCount = 0;
  Future<void> Function()? beforeRead;

  @override
  Future<Uint8List?> read(String id, {required int maxBytes}) async {
    await beforeRead?.call();
    final value = values[id];
    return value == null || value.length > maxBytes
        ? null
        : Uint8List.fromList(value);
  }

  @override
  Future<void> write(String id, Uint8List bytes,
      {required int savedAtMs}) async {
    writeCount++;
    values[id] = Uint8List.fromList(bytes);
    savedAt[id] = savedAtMs;
  }

  @override
  Future<List<ProductionSnapshotStoredEntry>> entries() async => [
        for (final entry in values.entries)
          ProductionSnapshotStoredEntry(
              id: entry.key,
              bytes: entry.value.length,
              savedAtMs: savedAt[entry.key]!),
      ];

  @override
  Future<void> remove(String id) async {
    values.remove(id);
    savedAt.remove(id);
  }

  @override
  Future<void> clear() async {
    values.clear();
    savedAt.clear();
  }
}
