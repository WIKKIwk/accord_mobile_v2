import 'dart:async';
import 'dart:convert';
import 'dart:io';

Stream<Map<String, dynamic>> connectWarehouseLivePlatform(Uri uri) async* {
  final WebSocket socket = await WebSocket.connect(uri.toString());
  try {
    await for (final Object? message in socket) {
      if (message is! String) {
        continue;
      }
      final Object? decoded = jsonDecode(message);
      if (decoded is Map<String, dynamic>) {
        yield decoded;
      }
    }
  } finally {
    await socket.close();
  }
}

Stream<Map<String, dynamic>> connectSystemMonitorLivePlatform(Uri uri) {
  final controller = StreamController<Map<String, dynamic>>();
  WebSocket? socket;
  Timer? timer;
  var pingId = 0;

  void sendPing() {
    final activeSocket = socket;
    if (activeSocket == null || activeSocket.readyState != WebSocket.open) {
      return;
    }
    activeSocket.add(jsonEncode({
      'type': 'ping',
      'id': ++pingId,
      'sent_at_ms': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  controller.onListen = () async {
    try {
      socket = await WebSocket.connect(uri.toString());
      sendPing();
      timer = Timer.periodic(const Duration(seconds: 2), (_) => sendPing());
      await for (final Object? message in socket!) {
        if (message is! String) {
          continue;
        }
        final Object? decoded = jsonDecode(message);
        if (decoded is Map<String, dynamic> && !controller.isClosed) {
          controller.add(decoded);
        }
      }
      if (!controller.isClosed) {
        await controller.close();
      }
    } catch (error, stackTrace) {
      if (!controller.isClosed) {
        controller.addError(error, stackTrace);
      }
    }
  };

  controller.onCancel = () async {
    timer?.cancel();
    await socket?.close();
  };
  return controller.stream;
}
