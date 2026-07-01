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
  static String? _runtimeEndpointTicket;
  static int? _lastRequestTotalMs;

  static int? get lastRequestTotalMs => _lastRequestTotalMs;

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

    final ticket = await _resolveEndpointTicket();
    if (ticket.isEmpty) {
      return _directHttpRequest(
        method: method,
        uri: uri,
        headers: headers,
        bodyBytes: bodyBytes,
      );
    }

    try {
      return await _sendNative(
        ticket: ticket,
        method: method,
        uri: uri,
        headers: headers,
        bodyBytes: bodyBytes,
      );
    } catch (error) {
      String refreshedTicket = '';
      try {
        refreshedTicket = await refreshEndpointTicket(force: true);
      } catch (_) {
        refreshedTicket = '';
      }
      if (refreshedTicket.isNotEmpty && refreshedTicket != ticket) {
        await resetEndpoint();
        return _sendNative(
          ticket: refreshedTicket,
          method: method,
          uri: uri,
          headers: headers,
          bodyBytes: bodyBytes,
        );
      }
      rethrow;
    }
  }

  static Future<String> refreshEndpointTicket({bool force = false}) async {
    if (!force) {
      final existing = _runtimeEndpointTicket?.trim() ?? '';
      if (existing.isNotEmpty) {
        return existing;
      }
    }

    final discoveryUrl = endpointTicketDiscoveryUrl.trim();
    if (discoveryUrl.isEmpty) {
      return _setRuntimeEndpointTicket(endpointTicketFromEnvironment);
    }

    final response = await http
        .get(Uri.parse(discoveryUrl))
        .timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      return '';
    }

    final ticket = IrohTicketDiscoveryResponse.fromBody(response.body).ticket;
    return _setRuntimeEndpointTicket(ticket);
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

  static Future<String> _resolveEndpointTicket() async {
    final runtimeTicket = _runtimeEndpointTicket?.trim() ?? '';
    if (runtimeTicket.isNotEmpty) {
      return runtimeTicket;
    }

    final preferences = await SharedPreferences.getInstance();
    final storedTicket =
        preferences.getString(_endpointTicketPreferenceKey)?.trim() ?? '';
    if (storedTicket.isNotEmpty) {
      _runtimeEndpointTicket = storedTicket;
      return storedTicket;
    }

    final discoveredTicket = await refreshEndpointTicket();
    if (discoveredTicket.isNotEmpty) {
      return discoveredTicket;
    }
    return _setRuntimeEndpointTicket(endpointTicketFromEnvironment);
  }

  static Future<http.Response> _sendNative({
    required String ticket,
    required String method,
    required Uri uri,
    required Map<String, String>? headers,
    required List<int> bodyBytes,
  }) async {
    final raw = await _channel.invokeMapMethod<String, Object?>('request', {
      'ticket': ticket,
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

  static Future<String> _setRuntimeEndpointTicket(String ticket) async {
    final cleaned = ticket.trim();
    if (cleaned.isEmpty) {
      return '';
    }
    _runtimeEndpointTicket = cleaned;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_endpointTicketPreferenceKey, cleaned);
    return cleaned;
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
  const IrohTicketDiscoveryResponse({required this.ticket});

  final String ticket;

  factory IrohTicketDiscoveryResponse.fromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Iroh discovery response is not an object');
    }
    final ticket = decoded['ticket']?.toString().trim() ?? '';
    if (ticket.isEmpty) {
      throw const FormatException('Iroh discovery ticket is empty');
    }
    return IrohTicketDiscoveryResponse(ticket: ticket);
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
