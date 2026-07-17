import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'backup_file_saver_types.dart';

Future<SavedBackupFile> saveBackupStream({
  required Stream<List<int>> stream,
  required String filename,
  required int contentLength,
  BackupProgressCallback? onProgress,
}) async {
  final documents = await getApplicationDocumentsDirectory();
  final directory = Directory('${documents.path}/Backups');
  await directory.create(recursive: true);
  final safeName = _safeFilename(filename);
  final temporary = File('${directory.path}/$safeName.part');
  final target = File('${directory.path}/$safeName');
  if (await temporary.exists()) {
    await temporary.delete();
  }
  final sink = temporary.openWrite(mode: FileMode.writeOnly);
  var received = 0;
  try {
    await for (final chunk in stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(received, contentLength);
    }
    await sink.flush();
  } catch (_) {
    await sink.close();
    if (await temporary.exists()) {
      await temporary.delete();
    }
    rethrow;
  }
  await sink.close();
  if (contentLength > 0 && received != contentLength) {
    await temporary.delete();
    throw StateError('Backup download size mismatch');
  }
  if (await target.exists()) {
    await target.delete();
  }
  await temporary.rename(target.path);
  return SavedBackupFile(filename: safeName, path: target.path);
}

String _safeFilename(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return cleaned.isEmpty ? 'mini_rs_erp.dump' : cleaned;
}
