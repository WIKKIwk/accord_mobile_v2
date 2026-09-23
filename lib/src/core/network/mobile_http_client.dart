import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Must match web_dev_config.yaml. Never send another server's credentials to
// this proxy, and retain the real endpoint in sessions/saved accounts.
const devApiProxyTarget = 'https://mini-rs-erp-test.wspace.sbs';

http.Client createMobileHttpClient() {
  final client = http.Client();
  if (!kIsWeb ||
      !kDebugMode ||
      !const bool.fromEnvironment('ACCORD_DEV_API_PROXY') ||
      !const {'127.0.0.1', 'localhost', '::1'}.contains(Uri.base.host)) {
    return client;
  }
  return DevApiProxyClient(client, previewOrigin: Uri.base);
}

/// Routes only the configured test backend through Flutter's local dev server.
class DevApiProxyClient extends http.BaseClient {
  DevApiProxyClient(this._inner, {required this.previewOrigin});

  final http.Client _inner;
  final Uri previewOrigin;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.origin != devApiProxyTarget) {
      return _inner.send(request);
    }
    final proxiedUrl = Uri.parse(previewOrigin.origin).replace(
      path: '/__accord_api${request.url.path}',
      query: request.url.hasQuery ? request.url.query : null,
    );
    // Finalize first so multipart headers and content length are populated.
    final body = request.finalize();
    return _inner.send(_ProxiedRequest(request, proxiedUrl, body));
  }

  @override
  void close() => _inner.close();
}

class _ProxiedRequest extends http.BaseRequest {
  _ProxiedRequest(http.BaseRequest original, Uri uri, this._body)
      : super(original.method, uri) {
    headers.addAll(original.headers);
    contentLength = original.contentLength;
    followRedirects = original.followRedirects;
    maxRedirects = original.maxRedirects;
    persistentConnection = original.persistentConnection;
  }

  final http.ByteStream _body;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return _body;
  }
}
