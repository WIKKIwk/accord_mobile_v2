import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show chunkedCoding;
import 'package:shared_preferences/shared_preferences.dart';

import 'network/resilient_iroh_route.dart';
export 'network/resilient_iroh_route.dart' show IrohEndpointConfig;

class NativeIrohTransport {
  const NativeIrohTransport._();

  static const MethodChannel _channel = MethodChannel('accord/iroh_transport');
  static const bool autoConnectEnabled = bool.fromEnvironment(
    'IROH_AUTO_CONNECT',
    defaultValue: false,
  );
  static final _routes = Expando<Map<String, ResilientIrohRoute>>();
  static final _clients = Expando<http.Client>();
  static const String endpointTicketFromEnvironment = String.fromEnvironment(
    'IROH_ENDPOINT_TICKET',
    defaultValue: '',
  );
  static const String endpointTicketDiscoveryUrl = String.fromEnvironment(
    'IROH_TICKET_DISCOVERY_URL',
    defaultValue: '',
  );
  static const String _endpointTicketPreferenceKey = 'iroh_endpoint_ticket';
  static const String _supportsConnectionReusePreferenceKey =
      'iroh_supports_connection_reuse';
  static String? _runtimeEndpointTicket;
  static bool _runtimeSupportsConnectionReuse = false;
  static int? _lastRequestTotalMs;
  static final Map<String, String> _lastLoggedPaths = {};
  static int _nextLiveSubscriptionId = 1;
  static bool _callbackHandlerInstalled = false;
  static final Map<int, StreamController<Map<String, dynamic>>>
      _liveControllers = {};
  static final Map<int, Timer> _liveWatchdogs = {};
  static final Map<int, ResilientIrohRoute> _liveRoutes = {};

  static int? get lastRequestTotalMs => _lastRequestTotalMs;

  static Uri _httpOrigin(Uri uri) => Uri(
        scheme: uri.scheme == 'wss'
            ? 'https'
            : uri.scheme == 'ws'
                ? 'http'
                : uri.scheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
      );

  static ResilientIrohRoute _route(Uri uri, [http.Client? fallbackClient]) {
    final origin = _httpOrigin(uri);
    final routes = _routes[Zone.current] ??= {};
    return routes.putIfAbsent(origin.origin, () {
      final client =
          fallbackClient ?? (_clients[Zone.current] ??= http.Client());
      final cacheKey = 'iroh_endpoint_v2:${origin.origin}';
      return ResilientIrohRoute(
        origin: origin,
        httpClient: client,
        isSupported: () async => canUseFor(uri) && await isSupported(),
        loadCached: () async {
          final prefs = await SharedPreferences.getInstance();
          final value = prefs.getString(cacheKey);
          if (value == null) return null;
          final cached = IrohTicketDiscoveryResponse.fromBody(value);
          return IrohEndpointConfig(
              ticket: cached.ticket,
              supportsConnectionReuse: cached.supportsConnectionReuse);
        },
        discoverTrusted: () async {
          final configured = endpointTicketDiscoveryUrl.trim();
          final discoveryUri = configured.isEmpty
              ? origin.resolve('/v1/mobile/iroh-ticket')
              : Uri.parse(configured);
          // Never learn a new server identity from plaintext LAN discovery,
          // a redirect, or a ticket endpoint belonging to another ERP origin.
          if (discoveryUri.origin != origin.origin ||
              discoveryUri.scheme != 'https') {
            return null;
          }
          final request = http.Request('GET', discoveryUri)
            ..followRedirects = false;
          final response = await client
              .send(request)
              .then(http.Response.fromStream)
              .timeout(const Duration(seconds: 2));
          if (response.statusCode != 200) return null;
          final payload = jsonDecode(response.body);
          if (payload is! Map || payload['auto_connect'] != true) return null;
          final discovered =
              IrohTicketDiscoveryResponse.fromBody(response.body);
          return IrohEndpointConfig(
              ticket: discovered.ticket,
              supportsConnectionReuse: discovered.supportsConnectionReuse);
        },
        discoverLocal: () async {
          final method = defaultTargetPlatform == TargetPlatform.iOS
              ? 'discoverBonjourServices'
              : 'discoverServices';
          final result = await const MethodChannel('accord/erp_discovery')
              .invokeListMethod<dynamic>(method, {
            'timeout_ms': 800,
            'service_types': ['_accord-erp._udp.'],
          });
          return [
            for (final item in result ?? const [])
              if (item is Map) item.cast<String, dynamic>()
          ];
        },
        saveCached: (config) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
              cacheKey,
              jsonEncode({
                'ticket': config.ticket,
                'supports_connection_reuse': config.supportsConnectionReuse,
              }));
        },
        sendNative: (config, method, uri, headers, body) => _sendNative(
          config: config,
          method: method,
          uri: uri,
          headers: headers,
          bodyBytes: body,
        ),
      );
    });
  }

  static Stream<Map<String, dynamic>> liveEvents({
    required Uri uri,
    bool sendPings = false,
  }) {
    final controller = StreamController<Map<String, dynamic>>();
    final subscriptionId = _nextLiveSubscriptionId++;
    var started = false;
    var cancelled = false;
    var attempted = false;

    controller.onListen = () async {
      _ensureCallbackHandler();
      _liveControllers[subscriptionId] = controller;
      try {
        if (!canUseFor(uri)) {
          throw MissingPluginException('Automatic Iroh transport is disabled');
        }
        final supported = await isSupported()
            .timeout(const Duration(milliseconds: 500), onTimeout: () => false);
        if (!supported) {
          throw MissingPluginException('Iroh transport is not supported');
        }
        final route = _route(uri);
        // Give discovery a bounded chance before committing this long-lived
        // subscription to WSS; otherwise it never upgrades after warming.
        await route
            .warmUp()
            .timeout(const Duration(seconds: 3), onTimeout: () {});
        final config = route.ready;
        if (config == null) {
          throw MissingPluginException('Iroh route is not ready');
        }
        if (cancelled) return;
        attempted = true;
        _liveRoutes[subscriptionId] = route;
        // startLive acknowledges native task creation, not its handshake.
        // A stalled native connect must not suppress the existing WSS path.
        _liveWatchdogs[subscriptionId] = Timer(const Duration(seconds: 3), () {
          route.nativeFailed();
          if (!controller.isClosed) {
            controller
                .addError(TimeoutException('Iroh live handshake timed out'));
            unawaited(controller.close());
          }
        });
        await _channel.invokeMethod<void>('startLive', {
          'id': subscriptionId,
          'ticket': config.ticket,
          'reuseConnection': config.supportsConnectionReuse,
          'path': uri.hasQuery && uri.query.isNotEmpty
              ? '${uri.path}?${uri.query}'
              : uri.path,
          'sendPings': sendPings,
        });
        started = true;
        if (cancelled) {
          await _channel.invokeMethod<void>('stopLive', {'id': subscriptionId});
        }
      } catch (error, stackTrace) {
        _liveWatchdogs.remove(subscriptionId)?.cancel();
        _liveRoutes.remove(subscriptionId);
        if (attempted) _route(uri).nativeFailed();
        _liveControllers.remove(subscriptionId);
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
          await controller.close();
        }
      }
    };

    controller.onCancel = () async {
      cancelled = true;
      _liveWatchdogs.remove(subscriptionId)?.cancel();
      _liveRoutes.remove(subscriptionId);
      _liveControllers.remove(subscriptionId);
      if (started) {
        try {
          await _channel.invokeMethod<void>('stopLive', {
            'id': subscriptionId,
          });
        } on MissingPluginException {
          // Native side is already gone; nothing else to stop.
        } on PlatformException {
          // Stop is best-effort for live streams.
        }
      }
    };

    return controller.stream;
  }

  static Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<IrohHealthCheckResult> healthCheck({
    required String ticket,
    int runs = 1,
  }) async {
    final raw = await _channel.invokeMapMethod<String, Object?>('healthCheck', {
      'ticket': ticket,
      'runs': runs,
    });
    return IrohHealthCheckResult.fromMap(raw ?? const {});
  }

  static bool get hasEndpointTicket => autoConnectEnabled && !kIsWeb;

  // HTTPS/WSS is the default, including installations with a cached ticket.
  // Iroh experiments require an explicit build-time opt-in; cache cannot
  // override it for requests, warm-up, or live subscriptions.
  static bool canUseFor(Uri uri) =>
      hasEndpointTicket &&
      (uri.scheme == 'https' || uri.scheme == 'wss') &&
      uri.userInfo.isEmpty;

  static Future<http.Response> send({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? body,
    http.Client? fallbackClient,
  }) async {
    return _route(uri, fallbackClient).send(
      method: method,
      uri: uri,
      headers: headers,
      body: _bodyBytes(body),
    );
  }

  static Future<void> warmUp(Uri uri, {http.Client? fallbackClient}) =>
      _route(uri, fallbackClient).warmUp();

  static Future<String> refreshEndpointTicket({bool force = false}) async {
    return (await refreshEndpointConfig(force: force)).ticket;
  }

  static Future<IrohEndpointConfig> refreshEndpointConfig({
    bool force = false,
  }) async {
    if (!force) {
      final existing = _runtimeEndpointTicket?.trim() ?? '';
      if (existing.isNotEmpty) {
        return IrohEndpointConfig(
          ticket: existing,
          supportsConnectionReuse: _runtimeSupportsConnectionReuse,
        );
      }
    }

    final discoveryUrl = endpointTicketDiscoveryUrl.trim();
    if (discoveryUrl.isEmpty) {
      return _setRuntimeEndpointConfig(
        const IrohEndpointConfig(
          ticket: endpointTicketFromEnvironment,
          supportsConnectionReuse: false,
        ),
      );
    }

    final response = await http
        .get(Uri.parse(discoveryUrl))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      return const IrohEndpointConfig.empty();
    }

    final discovery = IrohTicketDiscoveryResponse.fromBody(response.body);
    return _setRuntimeEndpointConfig(
      IrohEndpointConfig(
        ticket: discovery.ticket,
        supportsConnectionReuse: discovery.supportsConnectionReuse,
      ),
    );
  }

  static Future<void> resetEndpoint() async {
    try {
      await _channel.invokeMethod<void>('reset');
    } on MissingPluginException {
      // Non-native test targets do not register the Iroh channel.
    } on PlatformException {
      // Reset is best-effort; the next request can recreate the endpoint.
    }
  }

  static void _ensureCallbackHandler() {
    if (_callbackHandlerInstalled) {
      return;
    }
    _callbackHandlerInstalled = true;
    _channel.setMethodCallHandler(_handleNativeCallback);
  }

  static Future<void> _handleNativeCallback(MethodCall call) async {
    final rawArguments = call.arguments;
    final arguments = rawArguments is Map ? rawArguments : const {};
    final id = (arguments['id'] as num?)?.toInt();
    if (id == null) {
      return;
    }
    final controller = _liveControllers[id];
    if (controller == null) {
      return;
    }

    switch (call.method) {
      case 'liveMessage':
        final text = arguments['text']?.toString() ?? '';
        if (text.isEmpty || controller.isClosed) {
          return;
        }
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) {
          _liveWatchdogs.remove(id)?.cancel();
          controller.add(decoded);
        }
        break;
      case 'liveError':
        _liveWatchdogs.remove(id)?.cancel();
        _liveRoutes.remove(id)?.nativeFailed();
        _liveControllers.remove(id);
        if (!controller.isClosed) {
          controller.addError(
            Exception(
              arguments['message']?.toString() ?? 'Iroh live stream failed',
            ),
          );
          await controller.close();
        }
        break;
      case 'liveClosed':
        _liveWatchdogs.remove(id)?.cancel();
        _liveRoutes.remove(id);
        _liveControllers.remove(id);
        if (!controller.isClosed) {
          await controller.close();
        }
        break;
    }
  }

  static Future<http.Response> _sendNative({
    required IrohEndpointConfig config,
    required String method,
    required Uri uri,
    required Map<String, String>? headers,
    required List<int> bodyBytes,
  }) async {
    final raw = await _channel.invokeMapMethod<String, Object?>('request', {
      'ticket': config.ticket,
      'reuseConnection': config.supportsConnectionReuse,
      'method': method,
      'path': uri.hasQuery && uri.query.isNotEmpty
          ? '${uri.path}?${uri.query}'
          : uri.path,
      'headers': {
        for (final entry in (headers ?? const <String, String>{}).entries)
          if (entry.key.toLowerCase() != 'accept-encoding')
            entry.key: entry.value,
        'accept-encoding': 'identity',
      },
      'body': Uint8List.fromList(bodyBytes),
    });
    final map = raw ?? const <String, Object?>{};
    final totalMs = (map['totalMs'] as num?)?.round();
    if (totalMs != null && totalMs > 0) {
      _lastRequestTotalMs = totalMs;
    }
    final paths = map['pathInfo']?.toString().split(' | ') ?? const <String>[];
    final selected = paths.where((path) => path.startsWith('* ')).firstOrNull;
    final kind = selected?.contains('direct') == true
        ? 'direct'
        : selected?.contains('relay') == true
            ? 'relay'
            : null;
    if (kind != null && _lastLoggedPaths[uri.origin] != kind) {
      _lastLoggedPaths[uri.origin] = kind;
      debugPrint(
          '[accord-transport] Iroh $kind selected, request=${totalMs ?? 0}ms');
    }
    final responseBody = map['body'];
    List<int> bytes = responseBody is Uint8List
        ? responseBody
        : responseBody is List<int>
            ? Uint8List.fromList(responseBody)
            : Uint8List(0);
    final responseHeaders = <String, String>{};
    final rawHeaders = map['headers'];
    if (rawHeaders is Map) {
      for (final entry in rawHeaders.entries) {
        responseHeaders[entry.key.toString().toLowerCase()] =
            entry.value.toString();
      }
    }
    final status = (map['statusCode'] as num?)?.toInt() ?? 0;
    if (status < 200 || status > 599) {
      throw const FormatException('Invalid native HTTP response status');
    }
    final transfer = responseHeaders['transfer-encoding']?.trim().toLowerCase();
    if (transfer != null && method != 'HEAD') {
      if (transfer != 'chunked') {
        throw const FormatException('Unsupported transfer coding');
      }
      bytes = chunkedCoding.decode(bytes);
      responseHeaders.remove('transfer-encoding');
      responseHeaders['content-length'] = bytes.length.toString();
    }
    final declaredLength =
        int.tryParse(responseHeaders['content-length'] ?? '');
    if (method != 'HEAD' &&
        declaredLength != null &&
        declaredLength != bytes.length) {
      throw const FormatException('Incomplete native HTTP response');
    }
    return http.Response.bytes(
      bytes,
      status,
      headers: responseHeaders,
      request: http.Request(method, uri),
    );
  }

  static Future<IrohEndpointConfig> _setRuntimeEndpointConfig(
    IrohEndpointConfig config,
  ) async {
    final cleaned = config.ticket.trim();
    if (cleaned.isEmpty) {
      return const IrohEndpointConfig.empty();
    }
    _runtimeEndpointTicket = cleaned;
    _runtimeSupportsConnectionReuse = config.supportsConnectionReuse;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_endpointTicketPreferenceKey, cleaned);
    await preferences.setBool(
      _supportsConnectionReusePreferenceKey,
      config.supportsConnectionReuse,
    );
    return IrohEndpointConfig(
      ticket: cleaned,
      supportsConnectionReuse: config.supportsConnectionReuse,
    );
  }

  static List<int> _bodyBytes(Object? body) {
    if (body == null) {
      return const <int>[];
    }
    if (body is String) {
      return utf8.encode(body);
    }
    if (body is List<int>) {
      return body;
    }
    throw ArgumentError(
        'Unsupported Iroh request body type: ${body.runtimeType}');
  }
}

class IrohTicketDiscoveryResponse {
  const IrohTicketDiscoveryResponse({
    required this.ticket,
    required this.supportsConnectionReuse,
  });

  final String ticket;
  final bool supportsConnectionReuse;

  factory IrohTicketDiscoveryResponse.fromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Iroh discovery response is not an object');
    }
    final ticket = decoded['ticket']?.toString().trim() ?? '';
    if (ticket.isEmpty) {
      throw const FormatException('Iroh discovery ticket is empty');
    }
    return IrohTicketDiscoveryResponse(
      ticket: ticket,
      supportsConnectionReuse: decoded['supports_connection_reuse'] == true,
    );
  }
}

class IrohHealthCheckResult {
  const IrohHealthCheckResult({
    required this.ok,
    required this.statusCode,
    required this.runs,
    required this.bytes,
    required this.totalMs,
    required this.pathInfo,
  });

  final bool ok;
  final int statusCode;
  final int runs;
  final int bytes;
  final double totalMs;
  final String pathInfo;

  factory IrohHealthCheckResult.fromMap(Map<String, Object?> map) {
    return IrohHealthCheckResult(
      ok: map['ok'] == true,
      statusCode: (map['statusCode'] as num?)?.toInt() ?? 0,
      runs: (map['runs'] as num?)?.toInt() ?? 0,
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
      totalMs: (map['totalMs'] as num?)?.toDouble() ?? 0,
      pathInfo: map['pathInfo']?.toString() ?? '',
    );
  }
}

String irohTransportErrorText(Object error) {
  if (error is! PlatformException) {
    return 'Iroh transport xatosi';
  }
  return switch (error.code) {
    'iroh_unsupported' => 'Iroh bu platformada yoqilmagan',
    'iroh_invalid_ticket' => 'Iroh ticket xato',
    'iroh_connect_failed' => 'Iroh ulanish xatosi: ${error.message ?? ''}',
    'iroh_request_failed' => 'Iroh so‘rov xatosi: ${error.message ?? ''}',
    _ => error.message?.trim().isNotEmpty == true
        ? error.message!
        : 'Iroh transport xatosi',
  };
}
