import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

Future<String> persistChatMediaFile(XFile source, String localId) async {
  final root = await getApplicationSupportDirectory();
  final directory = Directory('${root.path}/chat_media_pending');
  await directory.create(recursive: true);
  final extension = _safeExtension(source.name);
  final target = '${directory.path}/$localId$extension';
  final targetFile = File(target);
  final expectedSize = await source.length();
  final sink = targetFile.openWrite();
  try {
    await sink.addStream(source.openRead());
    await sink.flush();
    await sink.close();
    if (await targetFile.length() != expectedSize) {
      throw const FileSystemException('Incomplete chat media copy');
    }
  } catch (_) {
    await sink.close();
    if (await targetFile.exists()) await targetFile.delete();
    rethrow;
  }
  return target;
}

Future<bool> chatMediaFileExists(String path) => File(path).exists();

Future<void> deleteChatMediaFile(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}

Future<String> promoteChatMediaFile(String path, String mediaId) async {
  final source = File(path);
  if (!await source.exists()) return '';
  final safeId = _safeMediaId(mediaId);
  if (safeId.isEmpty) return '';
  final root = await getApplicationSupportDirectory();
  final directory = Directory('${root.path}/chat_media_cache');
  await directory.create(recursive: true);
  final extension = _safeExtension(source.path);
  final target = File('${directory.path}/$safeId$extension');
  if (await target.exists()) await target.delete();
  try {
    await source.rename(target.path);
  } on FileSystemException {
    await source.copy(target.path);
    await source.delete();
  }
  await _trimPlaybackCache(directory, keepPath: target.path);
  return target.path;
}

Future<String?> cachedChatMediaFile(String mediaId) async {
  final safeId = _safeMediaId(mediaId);
  if (safeId.isEmpty) return null;
  final root = await getApplicationSupportDirectory();
  final directory = Directory('${root.path}/chat_media_cache');
  if (!await directory.exists()) return null;
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (name == safeId || name.startsWith('$safeId.')) return entity.path;
  }
  return null;
}

Future<void> _trimPlaybackCache(
  Directory directory, {
  required String keepPath,
}) async {
  const maxFiles = 40;
  const maxBytes = 2 * 1024 * 1024 * 1024;
  final files = <({File file, int size, DateTime modified})>[];
  await for (final entity in directory.list(followLinks: false)) {
    if (entity is! File) continue;
    try {
      final stat = await entity.stat();
      files.add((file: entity, size: stat.size, modified: stat.modified));
    } catch (_) {}
  }
  files.sort((left, right) => right.modified.compareTo(left.modified));
  var bytes = 0;
  var count = 0;
  for (final item in files) {
    final keep = item.file.path == keepPath ||
        (count < maxFiles && bytes + item.size <= maxBytes);
    if (keep) {
      count++;
      bytes += item.size;
      continue;
    }
    try {
      await item.file.delete();
    } catch (_) {}
  }
}

String _safeExtension(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return '';
  final value = filename.substring(dot).toLowerCase();
  return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(value) ? value : '';
}

String _safeMediaId(String value) {
  final trimmed = value.trim();
  return RegExp(r'^[a-zA-Z0-9_-]{1,160}$').hasMatch(trimmed) ? trimmed : '';
}
