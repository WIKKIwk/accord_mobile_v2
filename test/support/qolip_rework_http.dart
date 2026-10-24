import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Existing catalog fixtures have no molds away for rework.
MockClient qolipCatalogClient(
        Future<http.Response> Function(http.Request) handler) =>
    MockClient((request) async {
      if (request.url.path == '/v1/mobile/qolip/reworks') {
        return http.Response('{"ok":true,"reworks":[]}', 200);
      }
      return handler(request);
    });
