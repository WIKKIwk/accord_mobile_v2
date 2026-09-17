import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedServerEndpoint {
  const SavedServerEndpoint({
    required this.baseUrl,
    required this.lastUsedAt,
  });

  final String baseUrl;
  final DateTime lastUsedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'base_url': baseUrl,
      'last_used_at': lastUsedAt.toUtc().toIso8601String(),
    };
  }

  factory SavedServerEndpoint.fromJson(Map<String, dynamic> json) {
    final baseUrl = ServerEndpointStore.normalize(
      json['base_url']?.toString() ?? '',
    );
    final lastUsedAt = DateTime.tryParse(
      json['last_used_at']?.toString() ?? '',
    );
    if (baseUrl == null || lastUsedAt == null) {
      throw const FormatException('Saved server endpoint is invalid');
    }
    return SavedServerEndpoint(
      baseUrl: baseUrl,
      lastUsedAt: lastUsedAt.toUtc(),
    );
  }
}

class ServerEndpointStore {
  ServerEndpointStore._();

  static final ServerEndpointStore instance = ServerEndpointStore._();
  static const String compiledBaseUrl = String.fromEnvironment(
    'MOBILE_API_BASE_URL',
    defaultValue: 'https://mini-rs-erp-test.wspace.sbs',
  );
  static const String _activeEndpointKey = 'active_server_endpoint';
  static const String _savedEndpointsKey = 'saved_server_endpoints_v1';

  String _activeBaseUrl = compiledBaseUrl;
  bool _runtimeOverride = false;
  final Map<String, SavedServerEndpoint> _savedEndpoints =
      <String, SavedServerEndpoint>{};

  String get baseUrl => _activeBaseUrl;

  bool get isRuntimeOverride => _runtimeOverride;

  List<SavedServerEndpoint> get savedEndpoints {
    final values = _savedEndpoints.values.toList(growable: false);
    values.sort(
      (left, right) => right.lastUsedAt.compareTo(left.lastUsedAt),
    );
    return values;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _savedEndpoints.clear();
    final encodedSavedEndpoints = prefs.getString(_savedEndpointsKey);
    if (encodedSavedEndpoints != null &&
        encodedSavedEndpoints.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(encodedSavedEndpoints);
        if (decoded is List) {
          for (final raw in decoded) {
            if (raw is! Map) {
              continue;
            }
            try {
              final endpoint = SavedServerEndpoint.fromJson(
                Map<String, dynamic>.from(raw),
              );
              _savedEndpoints[endpoint.baseUrl] = endpoint;
            } on Object {
              // Keep valid endpoints even when one stored entry is malformed.
            }
          }
        }
      } on Object {
        // A malformed list must not prevent the app from starting.
      }
    }
    final stored = normalize(prefs.getString(_activeEndpointKey) ?? '');
    if (stored == null) {
      await prefs.remove(_activeEndpointKey);
      _activeBaseUrl = compiledBaseUrl;
      _runtimeOverride = false;
    } else {
      _activeBaseUrl = stored;
      _runtimeOverride = true;
    }
    _upsertInMemory(_activeBaseUrl, touch: false);
    await _persistSavedEndpoints();
  }

  Future<SavedServerEndpoint> saveEndpoint(String raw) async {
    final normalized = normalize(raw);
    if (normalized == null) {
      throw const FormatException(
        'Domen http(s) protokoli bilan va path/query siz kiritilishi kerak',
      );
    }
    final endpoint = _upsertInMemory(normalized, touch: false);
    await _persistSavedEndpoints();
    return endpoint;
  }

  Future<String> setBaseUrl(String raw) async {
    final normalized = normalize(raw);
    if (normalized == null) {
      throw const FormatException(
        'Domen http(s) protokoli bilan va path/query siz kiritilishi kerak',
      );
    }
    _activeBaseUrl = normalized;
    _runtimeOverride = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeEndpointKey, normalized);
    _upsertInMemory(normalized, touch: true);
    await _persistSavedEndpoints();
    return normalized;
  }

  Future<void> clearOverride() async {
    _activeBaseUrl = compiledBaseUrl;
    _runtimeOverride = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeEndpointKey);
    _upsertInMemory(_activeBaseUrl, touch: false);
    await _persistSavedEndpoints();
  }

  SavedServerEndpoint _upsertInMemory(
    String baseUrl, {
    required bool touch,
  }) {
    final existing = _savedEndpoints[baseUrl];
    if (existing != null && !touch) {
      return existing;
    }
    final endpoint = SavedServerEndpoint(
      baseUrl: baseUrl,
      lastUsedAt: touch || existing == null
          ? DateTime.now().toUtc()
          : existing.lastUsedAt,
    );
    _savedEndpoints[baseUrl] = endpoint;
    return endpoint;
  }

  Future<void> _persistSavedEndpoints() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _savedEndpointsKey,
      jsonEncode(savedEndpoints.map((endpoint) => endpoint.toJson()).toList()),
    );
  }

  static String? normalize(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    if (!value.contains('://')) {
      value = 'https://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.trim().isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      return null;
    }

    return Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }
}
