import 'package:video_player/video_player.dart';

VideoPlayerController createLocalChatVideoController(String path) {
  return VideoPlayerController.networkUrl(Uri.parse(path));
}
