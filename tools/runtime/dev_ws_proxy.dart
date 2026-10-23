// Development bridge for browsers that cannot reach the public WSS endpoint.
// Run with `dart tools/runtime/dev_ws_proxy.dart`; no HTTP polling is involved.
import 'dart:async';
import 'dart:io';

const _port = 39119;
const _upstreamHost = 'mini-rs-erp-test.wspace.sbs';
const _connectTimeout = Duration(seconds: 10);
const _pingInterval = Duration(seconds: 25);
const _maxPayload = 64 * 1024 * 1024;

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port);
  stdout.writeln('Development WebSocket bridge listening on 127.0.0.1:$_port');
  await for (final request in server) {
    unawaited(_handle(request));
  }
}

Future<void> _reject(HttpRequest request, int status) async {
  request.response.statusCode = status;
  await request.response.close();
}

Future<void> _handle(HttpRequest request) async {
  if (request.method == 'GET' && request.uri.path == '/healthz') {
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    request.response.write('{"service":"accord-dev-ws-proxy-v1"}');
    await request.response.close();
    return;
  }
  final origin = Uri.tryParse(request.headers.value('origin') ?? '');
  if (origin == null ||
      !{'http', 'https'}.contains(origin.scheme) ||
      !{'localhost', '127.0.0.1'}.contains(origin.host) ||
      origin.userInfo.isNotEmpty ||
      origin.path.isNotEmpty ||
      origin.hasQuery ||
      origin.hasFragment) {
    await _reject(request, HttpStatus.forbidden);
    return;
  }
  if (!request.uri.path.startsWith('/v1/mobile/')) {
    await _reject(request, HttpStatus.notFound);
    return;
  }
  if (!WebSocketTransformer.isUpgradeRequest(request)) {
    await _reject(request, HttpStatus.badRequest);
    return;
  }

  final client = HttpClient()..connectionTimeout = _connectTimeout;
  WebSocket? upstream;
  WebSocket? browser;
  try {
    // The target is fixed. Only the application's path and query are forwarded.
    final target = Uri(
      scheme: 'wss',
      host: _upstreamHost,
      path: request.uri.path,
      query: request.uri.hasQuery ? request.uri.query : null,
    );
    final protocols = request.headers['sec-websocket-protocol']
        ?.expand((value) => value.split(','))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    upstream = await WebSocket.connect(
      target.toString(),
      customClient: client,
      protocols: protocols,
      headers: {'origin': origin.toString()},
      maxPayloadLength: _maxPayload,
    ).timeout(_connectTimeout);
    upstream.pingInterval = _pingInterval;
    final selectedProtocol = upstream.protocol;
    browser = await WebSocketTransformer.upgrade(
      request,
      protocolSelector: (_) => selectedProtocol,
      maxPayloadLength: _maxPayload,
    );
    browser.pingInterval = _pingInterval;
    await _relay(browser, upstream);
  } catch (error) {
    // Exceptions may contain the authenticated URL. Never print their contents.
    stderr
        .writeln('Development WebSocket bridge failed (${error.runtimeType})');
    if (browser == null) {
      await _reject(
        request,
        error is TimeoutException
            ? HttpStatus.gatewayTimeout
            : HttpStatus.badGateway,
      );
    }
  } finally {
    client.close(force: true);
    await Future.wait([
      if (browser != null) _close(browser),
      if (upstream != null) _close(upstream),
    ]);
  }
}

Future<void> _relay(WebSocket browser, WebSocket upstream) async {
  final fromBrowser = StreamIterator<dynamic>(browser);
  final fromUpstream = StreamIterator<dynamic>(upstream);
  Future<void>? stopping;
  Future<void> stop() => stopping ??= Future.wait([
        fromBrowser.cancel(),
        fromUpstream.cancel(),
      ]).then((_) {});

  Future<void> pump(
      StreamIterator<dynamic> source, WebSocket destination) async {
    try {
      while (await source.moveNext()) {
        // StreamIterator pauses input between messages; addStream propagates
        // the destination socket's backpressure while preserving text/binary.
        await destination.addStream(Stream<dynamic>.value(source.current));
      }
    } finally {
      await stop();
    }
  }

  await Future.wait([
    pump(fromBrowser, upstream),
    pump(fromUpstream, browser),
  ]);
}

Future<void> _close(WebSocket socket) async {
  try {
    await socket.close(WebSocketStatus.normalClosure);
  } catch (_) {
    // The other half may already have closed after a transport failure.
  }
}
