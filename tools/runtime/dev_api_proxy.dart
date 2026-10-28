// Project-owned HTTP bridge: API transport errors must never become index.html.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

const devApiProxyPort = 39120;
const devApiProxyService = 'accord-dev-api-proxy-v1';
const _hopHeaders = {
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  'host',
};

Future<void> main() async {
  await startDevApiProxy();
  stdout.writeln(
      'Development API bridge listening on 127.0.0.1:$devApiProxyPort');
}

Future<HttpServer> startDevApiProxy({
  int port = devApiProxyPort,
  int upstreamPort = 18081,
  Duration readTimeout = const Duration(seconds: 15),
}) async {
  final client = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 5);
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  server.listen(
    (request) =>
        unawaited(_forward(request, client, upstreamPort, readTimeout)),
    onDone: () => client.close(force: true),
  );
  return server;
}

Set<String> _excludedHeaders(HttpHeaders headers) => {
      ..._hopHeaders,
      ...?headers[HttpHeaders.connectionHeader]
          ?.expand((value) => value.split(','))
          .map((value) => value.trim().toLowerCase()),
    };

bool _localOrigin(HttpRequest request) {
  final raw = request.headers.value('origin');
  if (raw == null) return true;
  final origin = Uri.tryParse(raw);
  return origin != null &&
      {'http', 'https'}.contains(origin.scheme) &&
      {'127.0.0.1', 'localhost', '::1'}.contains(origin.host) &&
      origin.userInfo.isEmpty &&
      origin.path.isEmpty &&
      !origin.hasQuery &&
      !origin.hasFragment;
}

void _cors(HttpRequest request) {
  final origin = request.headers.value('origin');
  if (origin == null || !_localOrigin(request)) return;
  final vary = request.response.headers[HttpHeaders.varyHeader] ?? const [];
  if (!vary
      .expand((value) => value.split(','))
      .any((value) => value.trim().toLowerCase() == 'origin')) {
    request.response.headers.add(HttpHeaders.varyHeader, 'origin');
  }
  request.response.headers
    ..set('access-control-allow-origin', origin)
    ..set('access-control-allow-methods',
        'GET,HEAD,POST,PUT,PATCH,DELETE,OPTIONS')
    ..set('access-control-allow-headers',
        'authorization,content-length,content-range,content-type,idempotency-key,x-file-name,x-backup-filename,range,if-none-match,prefer')
    ..set('access-control-expose-headers',
        'accept-ranges,content-length,content-range,content-type,content-disposition,location,etag,preference-applied,x-request-id,x-production-epoch,x-production-revision,x-preparation-scope,x-preparation-version');
}

Future<void> _json(HttpRequest request, int status, Object payload) async {
  final bytes = utf8.encode(jsonEncode(payload));
  request.response.headers.clear();
  _cors(request);
  request.response
    ..statusCode = status
    ..headers.contentType = ContentType.json
    ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
    ..contentLength = bytes.length
    ..add(bytes);
  await request.response.close();
}

Future<void> _forward(HttpRequest request, HttpClient client, int upstreamPort,
    Duration readTimeout) async {
  HttpClientRequest? outgoing;
  var streaming = false;
  unawaited(request.response.done.catchError((Object _) {
    outgoing?.abort();
  }));
  try {
    if (!_localOrigin(request)) {
      await _json(
          request, HttpStatus.forbidden, {'error': 'origin_not_allowed'});
      return;
    }
    if (request.method == 'GET' &&
        request.uri.path == '/__accord_proxy_healthz') {
      await _json(request, HttpStatus.ok, {'service': devApiProxyService});
      return;
    }
    if (request.uri.path != '/healthz' &&
        !request.uri.path.startsWith('/v1/mobile/')) {
      await _json(request, HttpStatus.notFound, {'error': 'not_found'});
      return;
    }
    if (request.method == 'OPTIONS') {
      _cors(request);
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }
    // Only the path/query are supplied by callers; the upstream is loopback.
    final target = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: upstreamPort,
      path: request.uri.path,
      query: request.uri.hasQuery ? request.uri.query : null,
    );
    outgoing = await client.openUrl(request.method, target);
    outgoing.followRedirects = false;
    final excludedRequestHeaders = _excludedHeaders(request.headers);
    request.headers.forEach((name, values) {
      if (!excludedRequestHeaders.contains(name.toLowerCase())) {
        outgoing!.headers.set(name, values);
      }
    });
    await outgoing.addStream(request);
    final isRead = request.method == 'GET' || request.method == 'HEAD';
    final response = isRead
        ? await outgoing.close().timeout(readTimeout)
        : await outgoing.close();
    request.response.statusCode = response.statusCode;
    final excludedResponseHeaders = _excludedHeaders(response.headers);
    response.headers.forEach((name, values) {
      if (!excludedResponseHeaders.contains(name.toLowerCase())) {
        request.response.headers.set(name, values);
      }
    });
    _cors(request);
    streaming = true;
    await request.response
        .addStream(isRead ? response.timeout(readTimeout) : response);
    await request.response.close();
  } catch (error) {
    outgoing?.abort();
    // URLs/exception messages can contain socket tickets and credentials.
    stderr.writeln('Development API bridge failed: ${request.method} '
        '${request.uri.path} (${error.runtimeType})');
    try {
      if (streaming) {
        // Do not terminate a partial chunked response as a successful body.
        request.response.deadline = Duration.zero;
      } else {
        await _json(
          request,
          error is TimeoutException
              ? HttpStatus.gatewayTimeout
              : HttpStatus.badGateway,
          {
            'error': error is TimeoutException
                ? 'upstream_timeout'
                : 'upstream_unavailable'
          },
        );
      }
    } catch (failure) {
      stderr.writeln(
          'Development API bridge response failed (${failure.runtimeType})');
      // The browser may already have disconnected.
    }
  }
}
