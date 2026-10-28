import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_transport_policy.dart';

// Only this canonical API origin may use the project loopback HTTP bridge.
// Retain it in sessions/saved accounts, and never send
// another server's credentials to the local core.
const devApiProxyTarget = 'https://mini-rs-erp-test.wspace.sbs';
const devApiBridgeOrigin = 'http://127.0.0.1:39120';

http.Client createMobileHttpClient({bool useDevProxy = true}) {
  final client = http.Client();
  if (!useDevProxy ||
      !kIsWeb ||
      !kDebugMode ||
      !const bool.fromEnvironment('ACCORD_DEV_API_PROXY') ||
      !const {'127.0.0.1', 'localhost', '::1'}.contains(Uri.base.host)) {
    return SecureMobileApiClient(client);
  }
  return SecureMobileApiClient(
    DevApiProxyClient(client, previewOrigin: Uri.base),
  );
}

class SecureMobileApiClient extends http.BaseClient {
  SecureMobileApiClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final isApi = request.url.path.startsWith('/v1/mobile/') ||
        request.headers.keys.any((key) => key.toLowerCase() == 'authorization');
    if (!isApi) return _inner.send(request);
    if (!allowsApiTransport(request.url)) {
      throw http.ClientException('API connections require HTTPS', request.url);
    }
    final follow = request.followRedirects &&
        const {'GET', 'HEAD'}.contains(request.method);
    var remaining = request.maxRedirects;
    var current = request;
    while (true) {
      current.followRedirects = false;
      final response = await _inner.send(current);
      final location = response.headers['location'];
      if (!follow ||
          !const {301, 302, 303, 307, 308}.contains(response.statusCode) ||
          location == null) {
        return response;
      }
      final destination = current.url.resolve(location);
      await response.stream.drain<void>();
      if (!allowsApiTransport(destination) ||
          (current.url.scheme == 'https' && destination.scheme != 'https')) {
        throw http.ClientException('API redirect requires HTTPS', destination);
      }
      if (remaining-- <= 0) {
        throw http.ClientException('Too many API redirects', destination);
      }
      final headers = Map<String, String>.from(current.headers);
      if (destination.origin != current.url.origin) {
        headers.removeWhere((key, _) => const {
              'authorization',
              'cookie',
              'proxy-authorization',
            }.contains(key.toLowerCase()));
      }
      current = http.AbortableRequest(
        current.method,
        destination,
        abortTrigger: current is http.Abortable ? current.abortTrigger : null,
      )
        ..headers.addAll(headers)
        ..persistentConnection = request.persistentConnection;
    }
  }

  @override
  void close() => _inner.close();
}

/// Routes the test backend directly through the project's local HTTP bridge.
/// Flutter's asset server must never turn a failed API request into index.html.
class DevApiProxyClient extends http.BaseClient {
  DevApiProxyClient(this._inner, {required this.previewOrigin});

  final http.Client _inner;
  final Uri previewOrigin;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.origin != devApiProxyTarget ||
        !const {'127.0.0.1', 'localhost', '::1'}.contains(previewOrigin.host)) {
      return _inner.send(request);
    }
    final proxiedUrl = Uri.parse(devApiBridgeOrigin).replace(
      path: request.url.path,
      query: request.url.hasQuery ? request.url.query : null,
    );
    // Finalize first so multipart headers and content length are populated.
    final body = request.finalize();
    return _inner.send(_ProxiedRequest(request, proxiedUrl, body));
  }

  @override
  void close() => _inner.close();
}

class _ProxiedRequest extends http.BaseRequest with http.Abortable {
  _ProxiedRequest(http.BaseRequest original, Uri uri, this._body)
      : abortTrigger = original is http.Abortable ? original.abortTrigger : null,
        super(original.method, uri) {
    headers.addAll(original.headers);
    contentLength = original.contentLength;
    followRedirects = original.followRedirects;
    maxRedirects = original.maxRedirects;
    persistentConnection = original.persistentConnection;
  }

  final http.ByteStream _body;
  @override
  final Future<void>? abortTrigger;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return _body;
  }
}
