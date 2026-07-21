import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/api/mobile_api.dart';
import '../data/chat_media_file_store.dart';
import '../models/chat_media_models.dart';
import '../models/chat_models.dart';

/// Owns the single voice-message player for a chat detail screen.
///
/// Keeping one player here makes it possible to show the active message away
/// from its bubble and to continue with the next voice message automatically.
class ChatAudioPlaybackController extends ChangeNotifier {
  ChatAudioPlaybackController() {
    _playerStateSubscription = _player.playerStateStream.listen(
      _handlePlayerState,
    );
    _positionSubscription = _player.positionStream.listen((position) {
      if (_disposed || _currentMessage == null) return;
      if ((position - _position).abs() < const Duration(milliseconds: 150) &&
          position != Duration.zero) {
        return;
      }
      _position = position;
      notifyListeners();
    });
    _durationSubscription = _player.durationStream.listen((duration) {
      if (_disposed || _currentMessage == null) return;
      _duration = duration;
      notifyListeners();
    });
    _errorSubscription = _player.errorStream.listen((exception) {
      if (_disposed || _currentMessage == null) return;
      _loading = false;
      _error = 'Ovozli xabarni ochib bo‘lmadi';
      notifyListeners();
    });
  }

  final AudioPlayer _player = AudioPlayer();
  late final StreamSubscription<PlayerState> _playerStateSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration?> _durationSubscription;
  late final StreamSubscription<PlayerException> _errorSubscription;

  List<ChatMessage> _knownMessages = const <ChatMessage>[];
  List<ChatMessage> _queue = const <ChatMessage>[];
  ChatMessage? _currentMessage;
  int _queueIndex = -1;
  int _operation = 0;
  bool _loading = false;
  bool _advancing = false;
  bool _disposed = false;
  String _error = '';
  Duration _position = Duration.zero;
  Duration? _duration;

  ChatMessage? get currentMessage => _currentMessage;
  bool get hasCurrentMessage => _currentMessage != null;
  bool get isPlaying => _currentMessage != null && _player.playing;
  bool get isLoading => _loading;
  String get error => _error;
  Duration get position => _position;
  Duration get currentDuration {
    final loaded = _duration;
    if (loaded != null && loaded > Duration.zero) return loaded;
    return Duration(
      milliseconds: _currentMessage?.attachment?.durationMs ?? 0,
    );
  }

  int get queueIndex => _queueIndex;
  int get queueLength => _queue.length;

  bool isCurrent(ChatMessage message) {
    return _currentMessage != null &&
        _messageKey(_currentMessage) == _messageKey(message);
  }

  /// Supplies the currently loaded timeline so newly received voice messages
  /// can be picked up when the current item finishes.
  void setKnownMessages(Iterable<ChatMessage> messages) {
    _knownMessages = List<ChatMessage>.unmodifiable(_audioMessages(messages));
  }

  Future<void> toggle(ChatMessage message) async {
    final attachment = message.attachment;
    if (_disposed ||
        attachment?.kind != ChatMediaKind.audio ||
        attachment?.mediaId.trim().isEmpty != false) {
      return;
    }
    if (!isCurrent(message)) {
      await _startQueue(message);
      return;
    }
    if (_loading) return;
    _error = '';
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      _position = Duration.zero;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      unawaited(_player.play());
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> seek(double milliseconds) async {
    if (_disposed || _currentMessage == null || _loading) return;
    final duration = currentDuration;
    final value = milliseconds
        .clamp(0, duration.inMilliseconds > 0 ? duration.inMilliseconds : 1)
        .round();
    await _player.seek(Duration(milliseconds: value));
    if (!_disposed) {
      _position = Duration(milliseconds: value);
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_disposed) return;
    _operation++;
    _loading = false;
    await _player.stop();
    if (_disposed) return;
    _currentMessage = null;
    _queue = const <ChatMessage>[];
    _queueIndex = -1;
    _position = Duration.zero;
    _duration = null;
    _error = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _operation++;
    unawaited(_playerStateSubscription.cancel());
    unawaited(_positionSubscription.cancel());
    unawaited(_durationSubscription.cancel());
    unawaited(_errorSubscription.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _startQueue(ChatMessage message) async {
    final operation = ++_operation;
    _queue = voiceQueueFor(message, _knownMessages);
    _queueIndex = 0;
    _currentMessage = message;
    _position = Duration.zero;
    _duration = null;
    _loading = true;
    _error = '';
    notifyListeners();

    try {
      await _player.stop();
      if (!_isActive(operation)) return;
      await _setSource(message, operation);
      if (!_isActive(operation)) return;
      unawaited(_player.play());
    } catch (_) {
      if (_isActive(operation)) {
        _loading = false;
        _error = 'Ovozli xabarni ochib bo‘lmadi';
        notifyListeners();
      }
      return;
    }
    if (_isActive(operation)) {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _setSource(ChatMessage message, int operation) async {
    final attachment = message.attachment;
    if (attachment == null ||
        attachment.kind != ChatMediaKind.audio ||
        attachment.mediaId.trim().isEmpty) {
      throw StateError('audio_attachment_missing');
    }
    String? cachedPath;
    try {
      cachedPath = await cachedChatMediaFile(attachment.mediaId);
    } catch (_) {}
    if (!_isActive(operation)) return;

    if (cachedPath != null && cachedPath.isNotEmpty) {
      try {
        await _player.setFilePath(cachedPath);
        return;
      } catch (_) {}
    }
    final playbackUri = await MobileApi.instance.chatMediaPlaybackUri(
      attachment.mediaId,
    );
    if (!_isActive(operation)) return;
    await _player.setUrl(playbackUri.toString());
  }

  void _handlePlayerState(PlayerState state) {
    if (_disposed || _currentMessage == null) return;
    if (state.processingState == ProcessingState.completed) {
      final duration = currentDuration;
      if (duration > Duration.zero) _position = duration;
      notifyListeners();
      if (!_loading && !_advancing) unawaited(_advanceQueue());
      return;
    }
    notifyListeners();
  }

  Future<void> _advanceQueue() async {
    if (_disposed || _advancing || _currentMessage == null) return;
    _refreshQueue();
    if (_queueIndex + 1 >= _queue.length) return;

    _advancing = true;
    final operation = _operation;
    final next = _queue[++_queueIndex];
    _currentMessage = next;
    _position = Duration.zero;
    _duration = null;
    _loading = true;
    _error = '';
    notifyListeners();
    try {
      await _setSource(next, operation);
      if (_isActive(operation)) unawaited(_player.play());
    } catch (_) {
      if (_isActive(operation)) {
        _loading = false;
        _error = 'Ovozli xabarni ochib bo‘lmadi';
        notifyListeners();
      }
    } finally {
      _advancing = false;
      if (_isActive(operation)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  void _refreshQueue() {
    final current = _currentMessage;
    if (current == null) return;
    final existingKeys = _queue.map(_messageKey).toSet();
    final following = voiceQueueFor(current, _knownMessages).skip(1).where(
          (message) => !existingKeys.contains(_messageKey(message)),
        );
    if (following.isNotEmpty) {
      _queue = List<ChatMessage>.unmodifiable([..._queue, ...following]);
    }
  }

  bool _isActive(int operation) {
    return !_disposed && operation == _operation;
  }

  static List<ChatMessage> voiceQueueFor(
    ChatMessage selected,
    Iterable<ChatMessage> messages,
  ) {
    final attachment = selected.attachment;
    if (attachment == null ||
        attachment.kind != ChatMediaKind.audio ||
        attachment.mediaId.trim().isEmpty) {
      return const <ChatMessage>[];
    }
    final sorted = _audioMessages(messages)
        .where((message) => message.conversationId == selected.conversationId)
        .toList();
    sorted.removeWhere(
        (message) => _messageKey(message) == _messageKey(selected));
    sorted.removeWhere((message) => !_isAfter(message, selected));
    return List<ChatMessage>.unmodifiable([selected, ...sorted]);
  }

  static List<ChatMessage> _audioMessages(Iterable<ChatMessage> messages) {
    final byKey = <String, ChatMessage>{};
    for (final message in messages) {
      if (message.attachment?.kind != ChatMediaKind.audio ||
          message.attachment?.mediaId.trim().isEmpty != false) {
        continue;
      }
      byKey[_messageKey(message)] = message;
    }
    final result = byKey.values.toList()
      ..sort((left, right) {
        final sequence = left.sequence.compareTo(right.sequence);
        if (sequence != 0) return sequence;
        return left.createdAtUnix.compareTo(right.createdAtUnix);
      });
    return result;
  }

  static bool _isAfter(ChatMessage message, ChatMessage selected) {
    if (message.sequence != selected.sequence) {
      return message.sequence > selected.sequence;
    }
    return message.createdAtUnix > selected.createdAtUnix;
  }

  static String _messageKey(ChatMessage? message) {
    if (message == null) return '';
    final messageId = message.messageId.trim();
    if (messageId.isNotEmpty) return 'message:$messageId';
    return 'media:${message.attachment?.mediaId.trim() ?? ''}';
  }
}
