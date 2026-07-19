import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ChatVoiceRecording {
  const ChatVoiceRecording({required this.source, required this.durationMs});

  final XFile source;
  final int durationMs;
}

class ChatVoiceRecorder {
  ChatVoiceRecorder({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final Stopwatch _stopwatch = Stopwatch();
  bool _recording = false;

  bool get recording => _recording;
  Duration get elapsed => _stopwatch.elapsed;

  Future<void> start() async {
    if (_recording) return;
    if (!await _recorder.hasPermission()) {
      throw const ChatVoiceRecorderException('microphone_access_denied');
    }
    if (!await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
      throw const ChatVoiceRecorderException('voice_encoder_unavailable');
    }
    final filename =
        'voice_${DateTime.now().microsecondsSinceEpoch.toString()}.m4a';
    final path =
        kIsWeb ? '' : '${(await getTemporaryDirectory()).path}/$filename';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 48000,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
      path: path,
    );
    _stopwatch
      ..reset()
      ..start();
    _recording = true;
  }

  Future<ChatVoiceRecording?> stop() async {
    if (!_recording) return null;
    _stopwatch.stop();
    final durationMs = _stopwatch.elapsedMilliseconds;
    _recording = false;
    String? path;
    path = await _recorder.stop();
    if (path == null || path.trim().isEmpty) return null;
    return ChatVoiceRecording(
      source: XFile(
        path,
        name: 'voice_${DateTime.now().microsecondsSinceEpoch}.m4a',
        mimeType: 'audio/mp4',
      ),
      durationMs: durationMs,
    );
  }

  Future<void> cancel() async {
    try {
      if (_recording) await _recorder.cancel();
    } finally {
      _stopwatch
        ..stop()
        ..reset();
      _recording = false;
    }
  }

  Future<void> dispose() async {
    try {
      await cancel();
    } finally {
      await _recorder.dispose();
    }
  }
}

class ChatVoiceRecorderException implements Exception {
  const ChatVoiceRecorderException(this.code);

  final String code;

  @override
  String toString() => code;
}
