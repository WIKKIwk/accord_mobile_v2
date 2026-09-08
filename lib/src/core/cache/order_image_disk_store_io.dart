import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'order_image_disk_store_base.dart';

OrderImageDiskStore createOrderImageDiskStore() => FileOrderImageDiskStore();

/// Only manages hashed .cache files inside its own application-cache folder.
class FileOrderImageDiskStore implements OrderImageDiskStore {
  FileOrderImageDiskStore({this.directory, this.maxBytes = 96 * 1024 * 1024});
  final Directory? directory;
  final int maxBytes;
  final Map<String, int> _sizes = {};
  Directory? _root;
  Future<void> _tail = Future.value();
  final _fileName = RegExp(r'^[a-f0-9]{64}\.cache$');

  Future<T> _serial<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<Directory> _directory() async {
    if (_root != null) return _root!;
    final root = directory ??
        Directory(
            '${(await getApplicationCacheDirectory()).path}/order-images-v1');
    await root.create(recursive: true);
    final files = <(String, FileStat)>[];
    await for (final file in root.list(followLinks: false)) {
      final name = file.uri.pathSegments.last;
      if (file is File && _fileName.hasMatch(name)) {
        files.add((name, await file.stat()));
      }
    }
    files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    for (final file in files) {
      _sizes[file.$1] = file.$2.size;
    }
    _root = root;
    await _trim(root);
    return root;
  }

  Future<void> _trim(Directory root) async {
    var size = _sizes.values.fold(0, (a, b) => a + b);
    while (size > maxBytes || _sizes.length > 512) {
      final name = _sizes.keys.first;
      final bytes = _sizes.remove(name)!;
      try {
        await File('${root.path}/$name').delete();
      } on FileSystemException {/* OS eviction */}
      size -= bytes;
    }
  }

  String _name(String key) {
    final name = '$key.cache';
    if (!_fileName.hasMatch(name)) {
      throw ArgumentError('Invalid image cache key');
    }
    return name;
  }

  @override
  Future<Uint8List?> read(String key) => _serial(() async {
        final name = _name(key);
        final root = await _directory();
        if (!_sizes.containsKey(name)) return null;
        try {
          final bytes = await File('${root.path}/$name').readAsBytes();
          _sizes.remove(name);
          _sizes[name] = bytes.length;
          return bytes;
        } on FileSystemException {
          _sizes.remove(name);
          return null;
        }
      });

  @override
  Future<void> write(String key, Uint8List bytes) => _serial(() async {
        if (bytes.length > maxBytes) return;
        final name = _name(key);
        final root = await _directory();
        final temporary = File('${root.path}/$name.tmp');
        try {
          await temporary.writeAsBytes(bytes);
          await temporary.rename('${root.path}/$name');
          _sizes.remove(name);
          _sizes[name] = bytes.length;
          await _trim(root);
        } finally {
          if (await temporary.exists()) await temporary.delete();
        }
      });

  @override
  Future<void> remove(String key) => _serial(() async {
        final name = _name(key);
        final root = await _directory();
        _sizes.remove(name);
        try {
          await File('${root.path}/$name').delete();
        } on FileSystemException {/* already gone */}
      });

  @override
  Future<void> clear() => _serial(() async {
        final root = await _directory();
        for (final name in _sizes.keys.toList()) {
          try {
            await File('${root.path}/$name').delete();
          } on FileSystemException {/* already gone */}
        }
        _sizes.clear();
      });
}
