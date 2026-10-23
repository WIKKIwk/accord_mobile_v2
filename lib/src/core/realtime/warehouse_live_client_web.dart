// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import '../network/mobile_http_client.dart' show devApiProxyTarget;

// The Flutter HTTP preview proxy cannot upgrade WebSockets. An explicit local
// bridge keeps preview sockets on the same verified upstream as proxied HTTP.
Uri _developmentLiveUri(Uri uri) {
  const proxyUrl = String.fromEnvironment('ACCORD_DEV_WS_PROXY_URL');
  const loopback = {'127.0.0.1', 'localhost', '::1'};
  if (!kDebugMode || proxyUrl.isEmpty ||
      !const bool.fromEnvironment('ACCORD_DEV_API_PROXY') ||
      !loopback.contains(Uri.base.host) || uri.scheme != 'wss' ||
      uri.replace(scheme: 'https').origin != devApiProxyTarget) {
    return uri;
  }
  final proxy = Uri.parse(proxyUrl);
  if (proxy.scheme != 'ws' || !loopback.contains(proxy.host) ||
      proxy.userInfo.isNotEmpty || proxy.hasQuery || proxy.hasFragment ||
      (proxy.path.isNotEmpty && proxy.path != '/')) {
    throw ArgumentError('The development WebSocket bridge must be a loopback origin.');
  }
  return proxy.replace(path: uri.path, query: uri.hasQuery ? uri.query : null);
}

Stream<Map<String, dynamic>> connectWarehouseLivePlatform(Uri uri) {
  final controller = StreamController<Map<String, dynamic>>();
  final socket = html.WebSocket(_developmentLiveUri(uri).toString());

  socket.onOpen.listen((_) {
    if (kDebugMode) debugPrint('LIVE opened path=${uri.path} protocol=${uri.queryParameters['protocol']}');
  });
  socket.onMessage.listen((event) {
    final Object? data = event.data;
    if (data is! String) {
      return;
    }
    final Object? decoded = jsonDecode(data);
    if (decoded is Map<String, dynamic>) {
      if (kDebugMode) debugPrint('LIVE frame type=${decoded['type']} ok=${decoded['ok']} error=${decoded['error']} rev=${decoded['rev']}');
      controller.add(decoded);
    }
  });
  socket.onError.listen((event) {
    if (kDebugMode) debugPrint('LIVE socket error path=${uri.path}');
    if (!controller.isClosed) {
      controller.addError(event);
    }
  });
  socket.onClose.listen((event) {
    if (kDebugMode) debugPrint('LIVE closed path=${uri.path} code=${event.code} reason=${event.reason}');
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
  final socket = html.WebSocket(_developmentLiveUri(uri).toString());
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
