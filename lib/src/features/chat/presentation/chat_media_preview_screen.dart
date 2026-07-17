import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/chat_media_models.dart';
import 'chat_local_video_controller.dart';

class ChatMediaDraft {
  const ChatMediaDraft({
    required this.source,
    required this.kind,
    required this.caption,
  });

  final XFile source;
  final ChatMediaKind kind;
  final String caption;
}

class ChatMediaPreviewScreen extends StatefulWidget {
  const ChatMediaPreviewScreen({
    super.key,
    required this.source,
    required this.kind,
  });

  final XFile source;
  final ChatMediaKind kind;

  @override
  State<ChatMediaPreviewScreen> createState() => _ChatMediaPreviewScreenState();
}

class _ChatMediaPreviewScreenState extends State<ChatMediaPreviewScreen> {
  final captionController = TextEditingController();
  Future<Uint8List>? imageBytes;
  VideoPlayerController? videoController;
  Future<void>? videoInitialization;
  bool imageReady = false;
  String validationError = '';

  @override
  void initState() {
    super.initState();
    if (widget.kind == ChatMediaKind.image) {
      imageBytes = _loadImage();
    } else {
      final controller = createLocalChatVideoController(widget.source.path);
      videoController = controller;
      videoInitialization = controller.initialize().then((_) {
        if (controller.value.duration > chatMediaVideoMaxDuration) {
          validationError = 'Video 120 soniyadan oshmasligi kerak.';
        }
        if (mounted) setState(() {});
      }).catchError((Object _) {
        validationError = 'Video ko‘rib chiqish uchun ochilmadi.';
        if (mounted) setState(() {});
      });
    }
  }

  Future<Uint8List> _loadImage() async {
    try {
      final bytes = await widget.source.readAsBytes();
      if (bytes.isEmpty) throw const FormatException('empty image');
      imageReady = true;
      if (mounted) setState(() {});
      return bytes;
    } catch (_) {
      validationError = 'Rasm ko‘rib chiqish uchun ochilmadi.';
      if (mounted) setState(() {});
      rethrow;
    }
  }

  @override
  void dispose() {
    captionController.dispose();
    videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind == ChatMediaKind.image ? 'Rasm' : 'Video'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: Colors.black,
                child: Center(child: _preview()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: captionController,
                minLines: 1,
                maxLines: 4,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Izoh yozing (ixtiyoriy)',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            if (validationError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  validationError,
                  style: TextStyle(color: scheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _canSend ? _confirm : null,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Yuborish'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    if (widget.kind == ChatMediaKind.image) {
      return FutureBuilder<Uint8List>(
        future: imageBytes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _PreviewError(label: 'Rasm ochilmadi');
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return const CircularProgressIndicator();
          }
          return InteractiveViewer(
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              cacheWidth: 1440,
              errorBuilder: (_, __, ___) =>
                  const _PreviewError(label: 'Rasm ochilmadi'),
            ),
          );
        },
      );
    }
    final controller = videoController;
    return FutureBuilder<void>(
      future: videoInitialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            controller == null ||
            !controller.value.isInitialized) {
          if (snapshot.hasError) {
            return const _PreviewError(label: 'Video ochilmadi');
          }
          return const CircularProgressIndicator();
        }
        return GestureDetector(
          onTap: () async {
            if (controller.value.isPlaying) {
              await controller.pause();
            } else {
              await controller.play();
            }
            if (mounted) setState(() {});
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : 16 / 9,
                child: VideoPlayer(controller),
              ),
              if (!controller.value.isPlaying)
                const CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.play_arrow_rounded, size: 38),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirm() {
    Navigator.of(context).pop(
      ChatMediaDraft(
        source: widget.source,
        kind: widget.kind,
        caption: captionController.text.trim(),
      ),
    );
  }

  bool get _canSend {
    if (validationError.isNotEmpty) return false;
    if (widget.kind == ChatMediaKind.image) return imageReady;
    return videoController?.value.isInitialized == true;
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
        const SizedBox(height: 10),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
