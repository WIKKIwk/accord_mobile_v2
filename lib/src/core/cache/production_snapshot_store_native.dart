import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'production_snapshot_store_backend.dart';

ProductionSnapshotBackend createProductionSnapshotBackend() =>
    FileProductionSnapshotBackend();

/// Atomic files inside the application's private support directory.
class FileProductionSnapshotBackend implements ProductionSnapshotBackend {
  FileProductionSnapshotBackend({this.directory});

  final Directory? directory;
  Directory? _root;
  final _namePattern = RegExp(r'^[a-f0-9]{64}\.snapshot$');
  final _temporaryPattern = RegExp(r'^\.pending-[A-Za-z0-9]+$');

  bool _alreadyAbsent(FileSystemException error) =>
      error.osError?.errorCode == 2 ||
      (Platform.isWindows && error.osError?.errorCode == 3);

  Future<Directory> _directory() async {
    if (_root case final root?) {
      await root.create(recursive: true);
      return root;
    }
    final root = directory ??
        Directory('${(await getApplicationSupportDirectory()).path}'
            '/production-snapshots-v1');
    await root.create(recursive: true);
    // The shared store serializes all operations. On a fresh process these
    // directories can only be remnants of an interrupted atomic write.
    await for (final entity in root.list(followLinks: false)) {
      if (entity is Directory &&
          _temporaryPattern.hasMatch(entity.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last)) {
        try {
          await entity.delete(recursive: true);
        } on FileSystemException catch (error) {
          if (!_alreadyAbsent(error)) rethrow;
        }
      }
    }
    _root = root;
    return root;
  }

  String _name(String id) {
    final name = '$id.snapshot';
    if (!_namePattern.hasMatch(name)) {
      throw ArgumentError('Invalid production snapshot key');
    }
    return name;
  }

  @override
  Future<Uint8List?> read(String id, {required int maxBytes}) async {
    final file = File('${(await _directory()).path}/${_name(id)}');
    try {
      if (await file.length() > maxBytes) return null;
      final bytes = await file.readAsBytes();
      return bytes.length <= maxBytes ? bytes : null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> write(String id, Uint8List bytes,
      {required int savedAtMs}) async {
    final root = await _directory();
    final name = _name(id);
    final temporary = await root.createTemp('.pending-');
    try {
      final file = File('${temporary.path}/value');
      await file.writeAsBytes(bytes, flush: true);
      await file.setLastModified(
          DateTime.fromMillisecondsSinceEpoch(savedAtMs, isUtc: true));
      await file.rename('${root.path}/$name');
    } finally {
      try {
        await temporary.delete(recursive: true);
      } on FileSystemException {
        // The snapshot itself has already been committed or the OS evicted it.
      }
    }
  }

  @override
  Future<List<ProductionSnapshotStoredEntry>> entries() async {
    final root = await _directory();
    final entries = <ProductionSnapshotStoredEntry>[];
    await for (final file in root.list(followLinks: false)) {
      final name = file.uri.pathSegments.last;
      if (file is! File || !_namePattern.hasMatch(name)) continue;
      try {
        final stat = await file.stat();
        entries.add(ProductionSnapshotStoredEntry(
          id: name.substring(0, 64),
          bytes: stat.size,
          savedAtMs: stat.modified.millisecondsSinceEpoch,
        ));
      } on FileSystemException {
        // Another OS cache cleanup can race a directory listing.
      }
    }
    return entries;
  }

  @override
  Future<void> remove(String id) async {
    try {
      await File('${(await _directory()).path}/${_name(id)}').delete();
    } on FileSystemException catch (error) {
      if (!_alreadyAbsent(error)) rethrow;
    }
  }

  @override
  Future<void> clear() async {
    final root = await _directory();
    await for (final file in root.list(followLinks: false)) {
      final name = file.uri.pathSegments.last;
      if (file is File && _namePattern.hasMatch(name)) {
        try {
          await file.delete();
        } on FileSystemException catch (error) {
          if (!_alreadyAbsent(error)) rethrow;
        }
      } else if (file is Directory &&
          _temporaryPattern.hasMatch(file.uri.pathSegments
              .where((segment) => segment.isNotEmpty)
              .last)) {
        try {
          await file.delete(recursive: true);
        } on FileSystemException catch (error) {
          if (!_alreadyAbsent(error)) rethrow;
        }
      }
    }
  }
}
