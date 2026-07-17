import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/widgets/display/image_fade.dart';
import '../models/chat_media_models.dart';

Route<void> chatMediaViewerRoute({
  required ChatMediaKind kind,
  required Uri contentUri,
  required Uri previewUri,
  required Map<String, String> headers,
  required String heroTag,
}) {
  return PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    barrierLabel: 'Media viewer',
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return kind == ChatMediaKind.image
          ? ChatImageViewerScreen(
              uri: contentUri,
              previewUri: previewUri,
              headers: headers,
              heroTag: heroTag,
            )
          : ChatVideoViewerScreen(
              uri: contentUri,
              previewUri: previewUri,
              headers: headers,
              heroTag: heroTag,
            );
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curved, child: child);
    },
  );
}

class ChatImageViewerScreen extends StatefulWidget {
  const ChatImageViewerScreen({
    super.key,
    required this.uri,
    required this.headers,
    this.previewUri,
    this.heroTag = 'chat-media-viewer',
  });

  final Uri uri;
  final Map<String, String> headers;
  final Uri? previewUri;
  final String heroTag;

  @override
  State<ChatImageViewerScreen> createState() => _ChatImageViewerScreenState();
}

class _ChatImageViewerScreenState extends State<ChatImageViewerScreen> {
  late final TransformationController transformationController;
  int quarterTurns = 0;

  @override
  void initState() {
    super.initState();
    transformationController = TransformationController();
  }

  @override
  void dispose() {
    transformationController.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    final scale = transformationController.value.getMaxScaleOnAxis();
    transformationController.value = scale > 1.1
        ? Matrix4.identity()
        : (Matrix4.identity()..scaleByDouble(2.4, 2.4, 2.4, 1));
  }

  void _rotate() {
    setState(() {
      quarterTurns = (quarterTurns + 1) % 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ChatMediaViewerShell(
      actions: [
        IconButton(
          tooltip: 'Rasmni aylantirish',
          onPressed: _rotate,
          icon: const Icon(Icons.rotate_right_rounded),
        ),
      ],
      child: GestureDetector(
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: transformationController,
          minScale: 0.8,
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(80),
          child: Hero(
            tag: widget.heroTag,
            child: RotatedBox(
              quarterTurns: quarterTurns,
              child: ImageFade(
                image: NetworkImage(
                  widget.uri.toString(),
                  headers: widget.headers,
                ),
                fit: BoxFit.contain,
                placeholder: Center(
                  child: _MediaPreviewImage(
                    uri: widget.previewUri,
                    headers: widget.headers,
                  ),
                ),
                errorBuilder: (_, __) => const _MediaViewerError(
                  icon: Icons.broken_image_outlined,
                  label: 'Rasm ochilmadi',
                ),
              ),
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
    this.previewUri,
    this.heroTag = 'chat-media-viewer',
  });

  final Uri uri;
  final Map<String, String> headers;
  final Uri? previewUri;
  final String heroTag;

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
    return _ChatMediaViewerShell(
      child: FutureBuilder<void>(
        future: initialization,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Hero(
                tag: widget.heroTag,
                child: const _MediaViewerError(
                  icon: Icons.video_file_outlined,
                  label: 'Video ochilmadi',
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Hero(
                tag: widget.heroTag,
                child: _MediaPreviewImage(
                  uri: widget.previewUri,
                  headers: widget.headers,
                ),
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: Hero(
                    tag: widget.heroTag,
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio > 0
                          ? controller.value.aspectRatio
                          : 16 / 9,
                      child: VideoPlayer(controller),
                    ),
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

class _ChatMediaViewerShell extends StatelessWidget {
  const _ChatMediaViewerShell({required this.child, this.actions = const []});

  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(child: SafeArea(child: child)),
          Positioned(
            left: 4,
            top: 0,
            child: SafeArea(
              child: IconButton(
                tooltip: 'Orqaga',
                onPressed: () => Navigator.of(context).pop(),
                color: Colors.white,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
          ),
          if (actions.isNotEmpty)
            Positioned(
              right: 4,
              top: 0,
              child: SafeArea(
                child: Row(children: actions),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaPreviewImage extends StatelessWidget {
  const _MediaPreviewImage({required this.uri, required this.headers});

  final Uri? uri;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    if (uri == null) {
      return const CircularProgressIndicator();
    }
    return ImageFade(
      image: NetworkImage(uri!.toString(), headers: headers),
      fit: BoxFit.contain,
      placeholder: const CircularProgressIndicator(),
      errorBuilder: (_, __) => const CircularProgressIndicator(),
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
