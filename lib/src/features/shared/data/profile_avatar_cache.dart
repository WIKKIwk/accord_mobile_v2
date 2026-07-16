import '../../shared/models/app_models.dart';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ProfileAvatarCache {
  static const Duration _downloadTimeout = Duration(seconds: 8);
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static http.Client? debugHttpClient;
  static final Map<String, _CachedAvatar> _memory = {};

  static String _profileKey(SessionProfile profile) =>
      '${profile.role.name}_${_safePart(profile.ref)}';
  static Future<Uint8List?> getCached(SessionProfile profile) async {
    final cached = _memory[_profileKey(profile)];
    return cached?.url == profile.avatarUrl ? cached?.bytes : null;
  }

  static Future<Uint8List?> cacheFromBytes(
    SessionProfile profile,
    List<int> bytes,
    String filename,
  ) async {
    if (profile.ref.trim().isEmpty || bytes.isEmpty) {
      return null;
    }
    _memory[_profileKey(profile)] = _CachedAvatar(
      url: profile.avatarUrl,
      bytes: Uint8List.fromList(bytes),
    );
    _bumpRevision();
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List?> ensureCached(SessionProfile profile) async {
    if (profile.avatarUrl.trim().isEmpty) {
      return null;
    }
    final cached = await getCached(profile);
    if (cached != null) {
      return cached;
    }

    return refreshFromUrl(profile);
  }

  static Future<Uint8List?> refreshFromUrl(SessionProfile profile) async {
    if (profile.avatarUrl.trim().isEmpty) {
      return null;
    }
    final http.Response response;
    try {
      final uri = Uri.parse(profile.avatarUrl);
      response = await (debugHttpClient?.get(uri) ?? http.get(uri))
          .timeout(_downloadTimeout);
    } catch (_) {
      return null;
    }
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }
    return cacheFromBytes(profile, response.bodyBytes, profile.avatarUrl);
  }

  static Future<void> clearForProfile(SessionProfile profile) async {
    if (profile.ref.trim().isEmpty) {
      return;
    }
    _memory.remove(_profileKey(profile));
    _bumpRevision();
  }

  static Future<void> clearAll() async {
    if (_memory.isEmpty) {
      return;
    }
    _memory.clear();
    _bumpRevision();
  }

  static void _bumpRevision() {
    revision.value = revision.value + 1;
  }

  static String _safePart(String value) {
    final buffer = StringBuffer();
    for (final codeUnit in value.trim().codeUnits) {
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      final isUpper = codeUnit >= 65 && codeUnit <= 90;
      final isLower = codeUnit >= 97 && codeUnit <= 122;
      if (isDigit || isUpper || isLower || codeUnit == 45 || codeUnit == 95) {
        buffer.writeCharCode(isUpper ? codeUnit + 32 : codeUnit);
      } else if (buffer.isNotEmpty && !buffer.toString().endsWith('_')) {
        buffer.write('_');
      }
    }
    final safe = buffer.toString().replaceAll(RegExp(r'^_+|_+$'), '');
    return safe.isEmpty ? 'profile' : safe;
  }
}

class _CachedAvatar {
  const _CachedAvatar({required this.url, required this.bytes});

  final String url;
  final Uint8List bytes;
}
