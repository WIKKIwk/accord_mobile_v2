import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/widgets/display/image_fade.dart';

class ChatImageViewerScreen extends StatelessWidget {
  const ChatImageViewerScreen({
    super.key,
    required this.uri,
    required this.headers,
  });

  final Uri uri;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: ImageFade(
            image: NetworkImage(uri.toString(), headers: headers),
            fit: BoxFit.contain,
            placeholder: const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, __) => const _MediaViewerError(
              icon: Icons.broken_image_outlined,
              label: 'Rasm ochilmadi',
            ),
          ),
        ),
      ),
    );
  }
}

class ChatVideoViewerScreen extends StatefulWidget {
  const ChatVideoViewerScreen({
    super.key,
    required this.uri,
    required this.headers,
  });

  final Uri uri;
  final Map<String, String> headers;

  @override
  State<ChatVideoViewerScreen> createState() => _ChatVideoViewerScreenState();
}

class _ChatVideoViewerScreenState extends State<ChatVideoViewerScreen> {
  late final VideoPlayerController controller;
  late final Future<void> initialization;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(
      widget.uri,
      httpHeaders: widget.headers,
    );
    initialization = controller.initialize().then((_) {
      controller.play();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<void>(
        future: initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: _MediaViewerError(
                icon: Icons.video_file_outlined,
                label: 'Video ochilmadi',
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio > 0
                        ? controller.value.aspectRatio
                        : 16 / 9,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, value, _) => IconButton.filled(
                          onPressed: () {
                            value.isPlaying
                                ? controller.pause()
                                : controller.play();
                          },
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                        ),
                      ),
                      Expanded(
                        child: VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          colors: const VideoProgressColors(
                            playedColor: Colors.white,
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, value, _) => Text(
                          _duration(value.position),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MediaViewerError extends StatelessWidget {
  const _MediaViewerError({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 52),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

String _duration(Duration value) {
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
