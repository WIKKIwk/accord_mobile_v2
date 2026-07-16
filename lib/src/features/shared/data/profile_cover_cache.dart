import '../models/app_models.dart';

import 'package:flutter/foundation.dart';

class ProfileCoverCache {
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static final Map<String, Uint8List> _memory = {};

  static String _profileKey(SessionProfile profile) =>
      '${profile.role.name}_${_safePart(profile.ref)}';

  static Future<Uint8List?> getCached(SessionProfile profile) async {
    return _memory[_profileKey(profile)];
  }

  static Future<Uint8List?> cacheFromBytes(
    SessionProfile profile,
    List<int> bytes,
  ) async {
    if (profile.ref.trim().isEmpty || bytes.isEmpty) {
      return null;
    }
    _memory[_profileKey(profile)] = Uint8List.fromList(bytes);
    _bumpRevision();
    return Uint8List.fromList(bytes);
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
