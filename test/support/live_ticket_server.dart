import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Stream<HttpRequest> liveUpgrades(
    HttpServer server, String path, String bearer) async* {
  var issued = 0;
  await for (final request in server) {
    if (request.uri.path == '/v1/mobile/auth/live-ticket') {
      expect(request.method, 'POST');
      expect(request.headers.value('authorization'), 'Bearer $bearer');
      expect(
          jsonDecode(await utf8.decoder.bind(request).join()), {'path': path});
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'ticket': 'ticket-${++issued}'}));
      await request.response.close();
    } else {
      expect(request.method, 'GET');
      expect(request.uri.path, path);
      expect(request.uri.queryParameters.containsKey('token'), isFalse);
      expect(request.uri.queryParameters['ticket'], 'ticket-$issued');
      expect(request.headers.value('authorization'), isNull);
      yield request;
    }
  }
}
