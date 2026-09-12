import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../native_iroh_transport.dart';

Stream<Map<String, dynamic>> connectWarehouseLivePlatform(
  Uri uri, {
  Duration connectTimeout = const Duration(seconds: 10),
  Duration pingInterval = const Duration(seconds: 25),
}) =>
    _connectLive(uri,
        connectTimeout: connectTimeout, pingInterval: pingInterval);

Stream<Map<String, dynamic>> connectSystemMonitorLivePlatform(Uri uri) =>
    _connectLive(uri, sendPings: true);

Stream<Map<String, dynamic>> _connectLive(
  Uri uri, {
  bool sendPings = false,
  Duration connectTimeout = const Duration(seconds: 10),
  Duration pingInterval = const Duration(seconds: 25),
}) {
  final controller = StreamController<Map<String, dynamic>>();
  StreamSubscription<Map<String, dynamic>>? nativeSubscription;
  StreamSubscription<dynamic>? socketSubscription;
  HttpClient? client;
  WebSocket? socket;
  Timer? timer;
  var cancelled = false;
  var connectingHttp = false;
  var pingId = 0;

  void finish() {
    if (!cancelled && !controller.isClosed) unawaited(controller.close());
  }

  void fail(Object error, StackTrace stackTrace) {
    if (!cancelled && !controller.isClosed) {
      controller.addError(error, stackTrace);
      finish();
    }
  }

  void sendPing() {
    final active = socket;
    if (cancelled || active == null || active.readyState != WebSocket.open) {
      return;
    }
    active.add(jsonEncode({
      'type': 'ping',
      'id': ++pingId,
      'sent_at_ms': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  Future<void> connectHttp() async {
    if (cancelled || connectingHttp) return;
    connectingHttp = true;
    var expired = false;
    final connectingClient = HttpClient()..connectionTimeout = connectTimeout;
    client = connectingClient;
    try {
      final connected = await WebSocket.connect(uri.toString(),
              customClient: connectingClient)
          .then((connected) {
        // Future.timeout does not cancel the underlying handshake. Dispose a
        // late connection instead of retaining a stale worker subscription.
        if (cancelled || expired) unawaited(connected.close());
        return connected;
      }).timeout(connectTimeout);
      if (cancelled) return;
      socket = connected;
      // Ping/pong detects half-open transport without treating a quiet queue
      // (no JSON changes) as disconnected or polling full snapshots.
      connected.pingInterval = pingInterval;
      socketSubscription = connected.listen((Object? message) {
        if (cancelled || controller.isClosed || message is! String) return;
        try {
          final decoded = jsonDecode(message);
          if (decoded is Map<String, dynamic>) controller.add(decoded);
        } catch (error, stackTrace) {
          fail(error, stackTrace);
        }
      }, onError: fail, onDone: finish);
      if (controller.isPaused) socketSubscription?.pause();
      if (sendPings) {
        sendPing();
        timer = Timer.periodic(const Duration(seconds: 2), (_) => sendPing());
      }
    } catch (error, stackTrace) {
      expired = true;
      connectingClient.close(force: true);
      fail(error, stackTrace);
    }
  }

  controller.onListen = () {
    if (NativeIrohTransport.canUseFor(uri)) {
      nativeSubscription =
          NativeIrohTransport.liveEvents(uri: uri, sendPings: sendPings).listen(
              (event) {
        if (!cancelled && !controller.isClosed && !connectingHttp) {
          controller.add(event);
        }
      }, onError: (Object error, StackTrace stackTrace) {
        unawaited(nativeSubscription?.cancel());
        unawaited(connectHttp());
      }, onDone: () {
        if (!connectingHttp) finish();
      });
    } else {
      unawaited(connectHttp());
    }
  };
  controller.onPause = () {
    nativeSubscription?.pause();
    socketSubscription?.pause();
  };
  controller.onResume = () {
    nativeSubscription?.resume();
    socketSubscription?.resume();
  };
  controller.onCancel = () {
    cancelled = true;
    timer?.cancel();
    // Cancellation must not wait for a peer that may already be unreachable.
    unawaited(nativeSubscription?.cancel());
    unawaited(socketSubscription?.cancel());
    unawaited(socket?.close());
    client?.close(force: true);
  };
  return controller.stream;
}
