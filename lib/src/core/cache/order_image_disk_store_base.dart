import 'dart:typed_data';

abstract class OrderImageDiskStore {
  Future<Uint8List?> read(String key);
  Future<void> write(String key, Uint8List bytes);
  Future<void> remove(String key);
  Future<void> clear();
}
