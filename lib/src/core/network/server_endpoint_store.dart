import 'package:shared_preferences/shared_preferences.dart';

class ServerEndpointStore {
  ServerEndpointStore._();

  static final ServerEndpointStore instance = ServerEndpointStore._();
  static const String compiledBaseUrl = String.fromEnvironment(
    'MOBILE_API_BASE_URL',
    defaultValue: 'https://mini-rs-erp-test.wspace.sbs',
  );
  static const String _activeEndpointKey = 'active_server_endpoint';

  String _activeBaseUrl = compiledBaseUrl;
  bool _runtimeOverride = false;

  String get baseUrl => _activeBaseUrl;

  bool get isRuntimeOverride => _runtimeOverride;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = normalize(prefs.getString(_activeEndpointKey) ?? '');
    if (stored == null) {
      await prefs.remove(_activeEndpointKey);
      return;
    }
    _activeBaseUrl = stored;
    _runtimeOverride = true;
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
    return normalized;
  }

  Future<void> clearOverride() async {
    _activeBaseUrl = compiledBaseUrl;
    _runtimeOverride = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeEndpointKey);
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
