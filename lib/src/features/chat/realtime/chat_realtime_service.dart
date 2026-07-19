import 'dart:async';

import '../../../core/realtime/warehouse_live_client.dart';

class ChatRealtimeService {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _reconnectTimer;
  Future<Uri> Function()? _liveUri;
  void Function(Map<String, dynamic>)? _onEvent;
  void Function(bool)? _onConnectionChanged;
  bool _running = false;
  int _retry = 0;

  bool get isRunning => _running;

  void start({
    required Future<Uri> Function() liveUri,
    required void Function(Map<String, dynamic>) onEvent,
    required void Function(bool) onConnectionChanged,
  }) {
    stop();
    _running = true;
    _liveUri = liveUri;
    _onEvent = onEvent;
    _onConnectionChanged = onConnectionChanged;
    unawaited(_connect());
  }

  void stop() {
    _running = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _retry = 0;
    _onConnectionChanged?.call(false);
  }

  Future<void> _connect() async {
    if (!_running || _liveUri == null) return;
    try {
      final uri = await _liveUri!();
      if (!_running) return;
      await _subscription?.cancel();
      _subscription = connectWarehouseLive(uri).listen(
        (event) {
          _retry = 0;
          _onConnectionChanged?.call(true);
          _onEvent?.call(event);
        },
        onError: (_, __) {
          _onConnectionChanged?.call(false);
          _scheduleReconnect();
        },
        onDone: () {
          _onConnectionChanged?.call(false);
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _onConnectionChanged?.call(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_running || _reconnectTimer?.isActive == true) return;
    final exponent = _retry > 4 ? 4 : _retry;
    final seconds = (1 << exponent).clamp(1, 15).toInt();
    _retry++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }
}
