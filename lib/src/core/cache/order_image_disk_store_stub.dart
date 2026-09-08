import 'dart:typed_data';
import 'order_image_disk_store_base.dart';

OrderImageDiskStore createOrderImageDiskStore() => _NoDisk();

class _NoDisk implements OrderImageDiskStore {
  @override
  Future<Uint8List?> read(String key) async => null;
  @override
  Future<void> write(String key, Uint8List bytes) async {}
  @override
  Future<void> remove(String key) async {}
  @override
  Future<void> clear() async {}
}
