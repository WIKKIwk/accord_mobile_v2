import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An immutable draft captured before a send starts.
class ChatDraftSnapshot {
  const ChatDraftSnapshot._(this.text, this._version, this._owner);

  final String text;
  final String _version;
  final ChatDraftController _owner;
}

/// Persists one conversation's draft without sharing it across accounts/servers.
/// Dispose this controller before disposing [textController].
class ChatDraftController with WidgetsBindingObserver {
  ChatDraftController({
    required this.textController,
    required String endpoint,
    required String accountId,
    required String conversationId,
    this.debounce = const Duration(milliseconds: 350),
    Future<SharedPreferences> Function()? loadPreferences,
  })  : _storageKey = 'chat_draft_v1_${sha256.convert(utf8.encode(jsonEncode([
              endpoint.trim().replaceFirst(RegExp(r'/+$'), ''),
              accountId.trim(),
              conversationId.trim(),
            ])))}',
        _loadPreferences = loadPreferences ?? SharedPreferences.getInstance {
    _lastText = textController.text;
    _dirty = _lastText.isNotEmpty;
    (_activeControllers[_storageKey] ??= {}).add(this);
    textController.addListener(_onChanged);
    WidgetsBinding.instance.addObserver(this);
    ready = _restore();
  }

  final TextEditingController textController;
  final Duration debounce;
  final String _storageKey;
  final Future<SharedPreferences> Function() _loadPreferences;
  late final Future<void> ready;
  late String _lastText;
  Timer? _timer;
  int _revision = 0;
  String _version = _nextVersion();
  bool _disposed = false;
  bool _restoring = false;
  bool _dirty = false;

  // Opening a conversation immediately after leaving it must wait for its
  // final write, including writes still waiting for the preferences plugin.
  static final Map<String, Future<void>> _writes = {};
  static final Map<String, Set<ChatDraftController>> _activeControllers = {};
  static int _versionCounter = 0;

  static String _nextVersion() =>
      '${DateTime.now().microsecondsSinceEpoch}:${_versionCounter++}';

  static ({String text, String version}) _decodeDraft(String saved) {
    try {
      final record = jsonDecode(saved);
      if (record is Map &&
          record['format'] == 'chat_draft_v1' &&
          record['text'] is String &&
          record['version'] is String) {
        return (
          text: record['text'] as String,
          version: record['version'] as String
        );
      }
    } catch (_) {
      // Preserve plain-text drafts written before versioned records.
    }
    return (
      text: saved,
      version: 'legacy:${sha256.convert(utf8.encode(saved))}'
    );
  }

  Future<void> _restore() async {
    try {
      final preferences = await _loadPreferences();
      await _writes[_storageKey];
      if (_disposed || _revision != 0 || textController.text.isNotEmpty) return;
      final saved = preferences.getString(_storageKey);
      if (saved == null || saved.isEmpty) return;
      final record = _decodeDraft(saved);
      _version = record.version;
      _restoring = true;
      textController.value = TextEditingValue(
        text: record.text,
        selection: TextSelection.collapsed(offset: record.text.length),
      );
      _restoring = false;
    } catch (_) {
      // A local storage failure must not prevent composing or sending messages.
      _restoring = false;
    }
  }

  void _onChanged() {
    final text = textController.text;
    // Cursor/composition-only changes are not edits.
    if (text == _lastText) return;
    _lastText = text;
    if (_restoring) return;
    _revision++;
    _version = _nextVersion();
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  ChatDraftSnapshot capture() {
    final snapshot = ChatDraftSnapshot._(textController.text, _version, this);
    // Queue the captured version before a fast response or screen disposal.
    unawaited(flush());
    return snapshot;
  }

  /// Acknowledges a send even after disposal, preserving every newer draft.
  void markSent(ChatDraftSnapshot sent) {
    if (!identical(sent._owner, this)) return;
    _clearAcknowledgedControllers(sent);
    unawaited(_enqueue(() async {
      try {
        final preferences = await _loadPreferences();
        final saved = preferences.getString(_storageKey);
        if (saved != null && _decodeDraft(saved).version == sent._version) {
          await preferences.remove(_storageKey);
        }
        // A reopened controller may have finished restoring during the write.
        _clearAcknowledgedControllers(sent);
      } catch (_) {
        // Storage availability must not change the successful send result.
      }
    }));
    unawaited(flush());
  }

  void _clearAcknowledgedControllers(ChatDraftSnapshot sent) {
    for (final controller in List<ChatDraftController>.of(
      _activeControllers[_storageKey] ?? const <ChatDraftController>{},
    )) {
      if (controller._disposed ||
          controller._version != sent._version ||
          controller._lastText != sent.text) {
        continue;
      }
      controller._timer?.cancel();
      controller._timer = null;
      controller._dirty = false;
      controller._revision++;
      controller._version = _nextVersion();
      controller._lastText = '';
      controller.textController.clear();
    }
  }

  Future<void> flush() {
    _timer?.cancel();
    _timer = null;
    if (!_dirty) return _writes[_storageKey] ?? Future<void>.value();
    final text = _lastText;
    final version = _version;
    _dirty = false;
    return _enqueue(() async {
      try {
        final preferences = await _loadPreferences();
        if (text.isEmpty) {
          await preferences.remove(_storageKey);
        } else {
          await preferences.setString(
              _storageKey,
              jsonEncode({
                'format': 'chat_draft_v1',
                'text': text,
                'version': version,
              }));
        }
      } catch (_) {
        // Retry on the next lifecycle flush if there has been no newer edit.
        if (!_disposed && _version == version) _dirty = true;
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final previous = _writes[_storageKey] ?? Future<void>.value();
    final write = previous.then((_) => operation());
    _writes[_storageKey] = write;
    unawaited(write.then((_) {
      if (identical(_writes[_storageKey], write)) _writes.remove(_storageKey);
    }));
    return write;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(flush());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final active = _activeControllers[_storageKey];
    active?.remove(this);
    if (active?.isEmpty ?? false) _activeControllers.remove(_storageKey);
    WidgetsBinding.instance.removeObserver(this);
    textController.removeListener(_onChanged);
    unawaited(flush());
  }
}
