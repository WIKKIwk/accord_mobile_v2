import '../models/app_models.dart';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileCoverCache {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String _profileKey(SessionProfile profile) =>
      '${profile.role.name}_${_safePart(profile.ref)}';

  static String _bytesKey(SessionProfile profile) =>
      'profile_cover_bytes_${_profileKey(profile)}';

  static Future<Uint8List?> getCached(SessionProfile profile) async {
    if (profile.ref.trim().isEmpty) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_bytesKey(profile));
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      return base64Decode(encoded);
    } catch (_) {
      await prefs.remove(_bytesKey(profile));
      _bumpRevision();
      return null;
    }
  }

  static Future<Uint8List?> cacheFromBytes(
    SessionProfile profile,
    List<int> bytes,
  ) async {
    if (profile.ref.trim().isEmpty || bytes.isEmpty) {
      return null;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bytesKey(profile), base64Encode(bytes));
    _bumpRevision();
    return Uint8List.fromList(bytes);
  }

  static Future<void> clearForProfile(SessionProfile profile) async {
    if (profile.ref.trim().isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bytesKey(profile));
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
