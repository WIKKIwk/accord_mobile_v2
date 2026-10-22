import 'dart:typed_data';

/// Optional local storage. Keys are SHA-256 digests, never account credentials.
abstract interface class ProductionSnapshotBackend {
  Future<Uint8List?> read(String id, {required int maxBytes});
  Future<void> write(String id, Uint8List bytes, {required int savedAtMs});
  Future<List<ProductionSnapshotStoredEntry>> entries();
  Future<void> remove(String id);
  Future<void> clear();
}

class ProductionSnapshotStoredEntry {
  const ProductionSnapshotStoredEntry({
    required this.id,
    required this.bytes,
    required this.savedAtMs,
  });

  final String id;
  final int bytes;
  final int savedAtMs;
}
