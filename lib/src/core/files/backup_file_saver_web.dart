// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

import 'backup_file_saver_types.dart';

Future<SavedBackupFile> saveBackupStream({
  required Stream<List<int>> stream,
  required String filename,
  required int contentLength,
  BackupProgressCallback? onProgress,
}) async {
  final chunks = <int>[];
  var received = 0;
  await for (final chunk in stream) {
    chunks.addAll(chunk);
    received += chunk.length;
    onProgress?.call(received, contentLength);
  }
  if (contentLength > 0 && received != contentLength) {
    throw StateError('Backup download size mismatch');
  }
  final safeName = _safeFilename(filename);
  final blob = html.Blob(
    [Uint8List.fromList(chunks)],
    'application/octet-stream',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = safeName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return SavedBackupFile(filename: safeName, path: safeName);
}

String _safeFilename(String value) {
  final cleaned = value
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  return cleaned.isEmpty ? 'mini_rs_erp.dump' : cleaned;
}
