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

String _safeExtension(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot < 0 || dot == filename.length - 1) return '';
  final value = filename.substring(dot).toLowerCase();
  return RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(value) ? value : '';
}
