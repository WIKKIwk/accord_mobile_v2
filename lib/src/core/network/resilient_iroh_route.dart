import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

typedef IrohSend = Future<http.Response> Function(
  IrohEndpointConfig config,
  String method,
  Uri uri,
  Map<String, String>? headers,
  List<int> body,
);

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

  String? get endpointId {
    try {
      if (ticket.length > 16384) return null;
      final value = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(ticket))));
      final id = value is Map ? value['id'] : null;
      return id is String && RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(id)
          ? id.toLowerCase()
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Bonjour is only an address hint. Its name/TXT record NEVER establishes
  /// trust: QUIC still authenticates the ID learned over trusted HTTPS.
  IrohEndpointConfig withLocalServices(List<Map<String, dynamic>> services) {
    final id = endpointId;
    if (id == null) return this;
    final ips = <String>{};
    for (final service in services) {
      if (service['server_ref']?.toString().toLowerCase() != id) continue;
      final port = int.tryParse(service['http_port'].toString()) ?? 0;
      if (port < 1 || port > 65535) continue;
      final hosts = [
        service['host'],
        if (service['hosts'] is List) ...(service['hosts'] as List).take(16),
      ];
      for (final hint in hosts) {
        final host = hint?.toString() ?? '';
        if (_isLocalIPv4(host)) ips.add('$host:$port');
      }
    }
    if (ips.isEmpty) return this;
    final value =
        (jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(ticket))))
                as Map)
            .cast<String, dynamic>();
    final addresses = List<dynamic>.from(value['addrs'] as List? ?? const []);
    for (final ip in ips.take(8)) {
      if (!addresses
          .any((entry) => entry is Map && (entry['Ip'] ?? entry['ip']) == ip)) {
        addresses.insert(0, {'Ip': ip});
      }
    }
    value['addrs'] = addresses;
    return IrohEndpointConfig(
      ticket:
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', ''),
      supportsConnectionReuse: supportsConnectionReuse,
    );
  }

  static bool _isLocalIPv4(String host) {
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((p) => p == null || p < 0 || p > 255)) {
      return false;
    }
    return parts[0] == 10 ||
        (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31) ||
        (parts[0] == 192 && parts[1] == 168) ||
        (parts[0] == 169 && parts[1] == 254);
  }
}

/// One trusted origin, one health-gated preferred route, one shared HTTP client.
/// Discovery/probes contain no user credentials and never delay a cold HTTP
/// request. A POST that may have been written is NEVER replayed on another path.
class ResilientIrohRoute {
  ResilientIrohRoute({
    required this.origin,
    required this.httpClient,
    required this.isSupported,
    required this.loadCached,
    required this.discoverTrusted,
    required this.discoverLocal,
    required this.saveCached,
    required this.sendNative,
    DateTime Function()? now,
    this.probeTimeout = const Duration(seconds: 2),
    this.requestTimeout = const Duration(seconds: 10),
    this.recoveryGrace = const Duration(milliseconds: 250),
    this.cooldown = const Duration(seconds: 15),
  }) : now = now ?? DateTime.now;

  final Uri origin;
  final http.Client httpClient;
  final Future<bool> Function() isSupported;
  final Future<IrohEndpointConfig?> Function() loadCached;
  final Future<IrohEndpointConfig?> Function() discoverTrusted;
  final Future<List<Map<String, dynamic>>> Function() discoverLocal;
  final Future<void> Function(IrohEndpointConfig) saveCached;
  final IrohSend sendNative;
  final DateTime Function() now;
  final Duration probeTimeout, requestTimeout, recoveryGrace, cooldown;
  Future<void>? _initializing;
  Future<void>? _warming;
  bool _supported = false;
  IrohEndpointConfig? _known;
  IrohEndpointConfig? _ready;
  DateTime? _retryAfter;
  DateTime? _lastProbe;
  int _generation = 0;

  IrohEndpointConfig? get ready => _ready;

  Future<void> _initialize() => _initializing ??= () async {
        try {
          _supported = await isSupported().timeout(probeTimeout);
          if (_supported) {
            final cached = await loadCached().timeout(probeTimeout);
            if (cached?.endpointId != null && cached!.supportsConnectionReuse) {
              _known = cached;
            }
          }
        } catch (_) {
          // Optional acceleration must not prevent the existing HTTPS path.
        }
      }();

  void nativeFailed() {
    _generation++;
    _ready = null;
    _retryAfter = now().add(cooldown);
  }

  Future<void> warmUp() async {
    await _initialize();
    if (!_supported) return;
    if (_warming != null) return _warming;
    if (_retryAfter != null && now().isBefore(_retryAfter!)) return;
    if (_ready != null &&
        _lastProbe != null &&
        now().difference(_lastProbe!) < const Duration(minutes: 1)) {
      return;
    }
    final generation = _generation;
    final future = _probe(generation);
    _warming = future;
    try {
      await future;
    } finally {
      if (identical(_warming, future)) _warming = null;
    }
  }

  Future<void> _probe(int generation) async {
    try {
      // Restore/pin before internet discovery: a previously paired LAN must
      // still connect when the WAN and HTTPS ticket endpoint are unavailable.
      var config = _known;
      if (config == null) {
        config = await discoverTrusted().timeout(probeTimeout);
        if (config?.endpointId == null || !config!.supportsConnectionReuse) {
          _retryAfter = now().add(cooldown);
          return;
        }
        if (generation != _generation) return;
        _known = config;
      }
      // Use known addresses immediately; Bonjour can repair DHCP changes in
      // parallel without serializing ordinary requests behind discovery.
      final local = discoverLocal()
          .timeout(probeTimeout, onTimeout: () => <Map<String, dynamic>>[])
          .catchError((_) => <Map<String, dynamic>>[]);
      var candidate = config;
      try {
        await _health(candidate);
      } catch (_) {
        candidate = config.withLocalServices(await local);
        try {
          if (candidate.ticket == config.ticket) rethrow;
          await _health(candidate);
        } catch (_) {
          // A restored installation/key rotation can invalidate a cached
          // ticket. Only this same HTTPS origin may replace its identity.
          final fresh = await discoverTrusted().timeout(probeTimeout);
          if (fresh?.endpointId == null || !fresh!.supportsConnectionReuse) {
            rethrow;
          }
          candidate = fresh.withLocalServices(await local);
          await _health(candidate);
          config = fresh;
        }
      }
      if (generation != _generation) return;
      _ready = candidate;
      _known = candidate;
      _lastProbe = now();
      _retryAfter = null;
      await _persist(candidate);
      final updated = config.withLocalServices(await local);
      if (updated.ticket != candidate.ticket) {
        // Promote a new LAN hint only after the pinned peer answers. A fake
        // advertisement cannot replace a working authenticated connection.
        try {
          await _health(updated);
          if (generation != _generation) return;
          _ready = updated;
          _known = updated;
          await _persist(updated);
        } catch (_) {}
      }
    } catch (_) {
      if (generation == _generation) {
        _ready = null;
        _retryAfter = now().add(cooldown);
      }
    }
  }

  Future<void> _persist(IrohEndpointConfig config) async {
    try {
      await saveCached(config).timeout(probeTimeout);
    } catch (_) {}
  }

  Future<void> _health(IrohEndpointConfig config) async {
    final result = await sendNative(
            config, 'GET', origin.resolve('/healthz'), null, const [])
        .timeout(probeTimeout);
    final payload = result.statusCode == 200 ? jsonDecode(result.body) : null;
    if (payload is! Map || payload['ok'] != true) {
      throw const FormatException('Iroh peer health check failed');
    }
  }

  Future<http.Response> send({
    required String method,
    required Uri uri,
    Map<String, String>? headers,
    List<int> body = const [],
  }) async {
    if (uri.origin != origin.origin) {
      throw ArgumentError('Transport origin mismatch');
    }
    final verb = method.toUpperCase();
    // Never put native support/preference initialization in front of a cold
    // worker command. Until a route is warmed, dispatch HTTP immediately.
    final warming = warmUp();
    // Only cached/pinned endpoints get this short head start on app reopen.
    if (_ready == null && _known != null) {
      await warming.timeout(recoveryGrace, onTimeout: () {});
    } else {
      unawaited(warming);
    }
    final config = _ready;
    // Large uploads retain the established streaming/HTTP behavior and do
    // not hit the native bridge's bounded request buffer.
    if (config != null && body.length <= 1024 * 1024) {
      try {
        return await sendNative(config, verb, uri, headers, body)
            .timeout(requestTimeout);
      } catch (error) {
        nativeFailed();
        final notSent =
            error is PlatformException && error.code == 'iroh_not_sent';
        if (verb != 'GET' && verb != 'HEAD' && !notSent) rethrow;
        return _sendHttp(verb, uri, headers, body);
      }
    }
    try {
      return await _sendHttp(verb, uri, headers, body);
    } catch (_) {
      // HTTPS can also commit before losing a reply: only reads may switch.
      if (verb != 'GET' && verb != 'HEAD') rethrow;
      await warming.timeout(probeTimeout, onTimeout: () {});
      final recovered = _ready;
      if (recovered == null) rethrow;
      return sendNative(recovered, verb, uri, headers, body)
          .timeout(requestTimeout);
    }
  }

  Future<http.Response> _sendHttp(String method, Uri uri,
      Map<String, String>? headers, List<int> body) async {
    final request = http.Request(method, uri)..bodyBytes = body;
    if (headers != null) request.headers.addAll(headers);
    return httpClient
        .send(request)
        .then(http.Response.fromStream)
        .timeout(requestTimeout);
  }
}
