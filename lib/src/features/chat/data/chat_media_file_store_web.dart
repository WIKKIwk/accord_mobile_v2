import 'package:image_picker/image_picker.dart';

final Map<String, String> _playbackCache = {};

Future<String> persistChatMediaFile(XFile source, String localId) async {
  return source.path;
}

Future<bool> chatMediaFileExists(String path) async => path.trim().isNotEmpty;

Future<void> deleteChatMediaFile(String path) async {}

Future<String> promoteChatMediaFile(String path, String mediaId) async {
  if (path.trim().isEmpty || mediaId.trim().isEmpty) return '';
  _playbackCache[mediaId.trim()] = path;
  return path;
}

Future<String?> cachedChatMediaFile(String mediaId) async {
  return _playbackCache[mediaId.trim()];
}
