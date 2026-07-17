import 'package:image_picker/image_picker.dart';

Future<String> persistChatMediaFile(XFile source, String localId) async {
  return source.path;
}

Future<bool> chatMediaFileExists(String path) async => path.trim().isNotEmpty;

Future<void> deleteChatMediaFile(String path) async {}
