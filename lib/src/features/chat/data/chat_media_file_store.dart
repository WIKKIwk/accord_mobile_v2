import 'package:image_picker/image_picker.dart';

import 'chat_media_file_store_web.dart'
    if (dart.library.io) 'chat_media_file_store_io.dart' as implementation;

Future<String> persistChatMediaFile(XFile source, String localId) {
  return implementation.persistChatMediaFile(source, localId);
}

Future<bool> chatMediaFileExists(String path) {
  return implementation.chatMediaFileExists(path);
}

Future<void> deleteChatMediaFile(String path) {
  return implementation.deleteChatMediaFile(path);
}
