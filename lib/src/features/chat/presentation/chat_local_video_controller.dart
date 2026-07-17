import 'package:video_player/video_player.dart';

import 'chat_local_video_controller_web.dart'
    if (dart.library.io) 'chat_local_video_controller_io.dart' as platform;

VideoPlayerController createLocalChatVideoController(String path) {
  return platform.createLocalChatVideoController(path);
}
