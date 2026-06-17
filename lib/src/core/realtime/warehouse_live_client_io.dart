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
