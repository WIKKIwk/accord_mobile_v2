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
