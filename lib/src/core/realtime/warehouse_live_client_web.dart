// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

Stream<Map<String, dynamic>> connectWarehouseLivePlatform(Uri uri) {
  final controller = StreamController<Map<String, dynamic>>();
  final socket = html.WebSocket(uri.toString());

  socket.onMessage.listen((event) {
    final Object? data = event.data;
    if (data is! String) {
      return;
    }
    final Object? decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) {
      controller.add(decoded);
    }
  });
  socket.onError.listen((event) {
    if (!controller.isClosed) {
      controller.addError(event);
    }
  });
  socket.onClose.listen((event) {
    if (!controller.isClosed) {
      controller.close();
    }
  });
  controller.onCancel = () {
    socket.close();
  };
  return controller.stream;
}

Stream<Map<String, dynamic>> connectSystemMonitorLivePlatform(Uri uri) {
  final controller = StreamController<Map<String, dynamic>>();
  final socket = html.WebSocket(uri.toString());
  Timer? timer;
  var pingId = 0;

  void sendPing() {
    if (socket.readyState != html.WebSocket.OPEN) {
      return;
    }
    socket.sendString(jsonEncode({
      'type': 'ping',
      'id': ++pingId,
      'sent_at_ms': DateTime.now().millisecondsSinceEpoch,
    }));
  }

  socket.onOpen.listen((event) {
    sendPing();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => sendPing());
  });
  socket.onMessage.listen((event) {
    final Object? data = event.data;
    if (data is! String) {
      return;
    }
    final Object? decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) {
      controller.add(decoded);
    }
  });
  socket.onError.listen((event) {
    if (!controller.isClosed) {
      controller.addError(event);
    }
  });
  socket.onClose.listen((event) {
    timer?.cancel();
    if (!controller.isClosed) {
      controller.close();
    }
  });
  controller.onCancel = () {
    timer?.cancel();
    socket.close();
  };
  return controller.stream;
}
