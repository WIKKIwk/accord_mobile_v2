import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class NativeIrohTransport {
  const NativeIrohTransport._();

  static const MethodChannel _channel = MethodChannel('accord/iroh_transport');
  static const String endpointTicketFromEnvironment = String.fromEnvironment(
    'IROH_ENDPOINT_TICKET',
    defaultValue: '',
  );
  static const String endpointTicketDiscoveryUrl = String.fromEnvironment(
    'IROH_TICKET_DISCOVERY_URL',
    defaultValue: 'https://mini-rs-erp-dev.wspace.sbs/v1/mobile/iroh-ticket',
  );
  static const String _endpointTicketPreferenceKey = 'iroh_endpoint_ticket';
  static const String _supportsConnectionReusePreferenceKey =
      'iroh_supports_connection_reuse';
  static String? _runtimeEndpointTicket;
  static bool _runtimeSupportsConnectionReuse = false;
  static int? _lastRequestTotalMs;
  static int _nextLiveSubscriptionId = 1;
  static bool _callbackHandlerInstalled = false;
  static final Map<int, StreamController<Map<String, dynamic>>>
      _liveControllers = {};

  static int? get lastRequestTotalMs => _lastRequestTotalMs;

  static Stream<Map<String, dynamic>> liveEvents({
    required Uri uri,
    bool sendPings = false,
  }) {
    final controller = StreamController<Map<String, dynamic>>();
    final subscriptionId = _nextLiveSubscriptionId++;
    var started = false;

    controller.onListen = () async {
      _ensureCallbackHandler();
      _liveControllers[subscriptionId] = controller;
      try {
        final supported = await isSupported();
        if (!supported) {
          throw MissingPluginException('Iroh transport is not supported');
        }
        final config = await _resolveEndpointConfig();
        if (config.ticket.isEmpty) {
          throw MissingPluginException('Iroh endpoint ticket is empty');
        }
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
      } catch (error, stackTrace) {
        _liveControllers.remove(subscriptionId);
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
          await controller.close();
        }
      }
    };

    controller.onCancel = () async {
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

  static bool get hasEndpointTicket =>
      endpointTicketFromEnvironment.trim().isNotEmpty ||
      endpointTicketDiscoveryUrl.trim().isNotEmpty;

  static Future<http.Response> send({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final bodyBytes = _bodyBytes(body);
    final supported = await isSupported();
    if (!supported) {
      return _directHttpRequest(
        method: method,
        uri: uri,
        headers: headers,
        bodyBytes: bodyBytes,
      );
    }

    final config = await _resolveEndpointConfig();
    if (config.ticket.isEmpty) {
      return _directHttpRequest(
        method: method,
        uri: uri,
        headers: headers,
        bodyBytes: bodyBytes,
      );
    }

    try {
      return await _sendNative(
        config: config,
        method: method,
        uri: uri,
        headers: headers,
        bodyBytes: bodyBytes,
      );
    } catch (_) {
      await resetEndpoint();
      var retryConfig = config;
      try {
        final refreshedConfig = await refreshEndpointConfig(force: true);
        if (refreshedConfig.ticket.isNotEmpty) {
          retryConfig = refreshedConfig;
        }
      } catch (_) {}
      return _sendNative(
        config: retryConfig,
        method: method,
        uri: uri,
        headers: headers,
        bodyBytes: bodyBytes,
      );
    }
  }

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

  static Future<IrohEndpointConfig> _resolveEndpointConfig() async {
    final runtimeTicket = _runtimeEndpointTicket?.trim() ?? '';
    if (runtimeTicket.isNotEmpty) {
      return IrohEndpointConfig(
        ticket: runtimeTicket,
        supportsConnectionReuse: _runtimeSupportsConnectionReuse,
      );
    }

    final discoveredConfig = await refreshEndpointConfig();
    if (discoveredConfig.ticket.isNotEmpty) {
      return discoveredConfig;
    }

    final preferences = await SharedPreferences.getInstance();
    final storedTicket =
        preferences.getString(_endpointTicketPreferenceKey)?.trim() ?? '';
    if (storedTicket.isNotEmpty) {
      _runtimeEndpointTicket = storedTicket;
      _runtimeSupportsConnectionReuse =
          preferences.getBool(_supportsConnectionReusePreferenceKey) ?? false;
      return IrohEndpointConfig(
        ticket: storedTicket,
        supportsConnectionReuse: _runtimeSupportsConnectionReuse,
      );
    }
    return _setRuntimeEndpointConfig(
      const IrohEndpointConfig(
        ticket: endpointTicketFromEnvironment,
        supportsConnectionReuse: false,
      ),
    );
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
          controller.add(decoded);
        }
        break;
      case 'liveError':
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
      'headers': headers ?? const <String, String>{},
      'body': Uint8List.fromList(bodyBytes),
    });
    final map = raw ?? const <String, Object?>{};
    final totalMs = (map['totalMs'] as num?)?.round();
    if (totalMs != null && totalMs > 0) {
      _lastRequestTotalMs = totalMs;
    }
    final responseBody = map['body'];
    final bytes = responseBody is Uint8List
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
    return http.Response.bytes(
      bytes,
      (map['statusCode'] as num?)?.toInt() ?? 0,
      headers: responseHeaders,
      request: http.Request(method, uri),
    );
  }

  static Future<http.Response> _directHttpRequest({
    required String method,
    required Uri uri,
    required Map<String, String>? headers,
    required List<int> bodyBytes,
  }) {
    switch (method.toUpperCase()) {
      case 'GET':
        return http.get(uri, headers: headers);
      case 'POST':
        return http.post(uri, headers: headers, body: bodyBytes);
      case 'PUT':
        return http.put(uri, headers: headers, body: bodyBytes);
      case 'DELETE':
        return http.delete(uri, headers: headers, body: bodyBytes);
      default:
        final request = http.Request(method, uri)
          ..bodyBytes = bodyBytes
          ..headers.addAll(headers ?? const <String, String>{});
        return request.send().then(http.Response.fromStream);
    }
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

class IrohEndpointConfig {
  const IrohEndpointConfig({
    required this.ticket,
    required this.supportsConnectionReuse,
  });

  const IrohEndpointConfig.empty()
      : ticket = '',
        supportsConnectionReuse = false;

  final String ticket;
  final bool supportsConnectionReuse;
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
