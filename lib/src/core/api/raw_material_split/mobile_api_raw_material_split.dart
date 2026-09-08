part of '../mobile_api.dart';

bool _rawSplitSending = false;

extension MobileApiRawMaterialSplit on MobileApi {
  String rawSplitScope() {
    final profile = AppSession.instance.profile;
    if (profile?.role != UserRole.homashyoRezkachi ||
        profile!.ref.isEmpty ||
        !profile.hasCapability('raw_material.split')) {
      throw StateError('Homashyo rezkachisi huquqi kerak');
    }
    return 'raw-material-split.pending.v1:${MobileApi.baseUrl}:${profile.ref}';
  }

  Future<Map<String, dynamic>?> rawSplitPending() async {
    final key = rawSplitScope();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (rawSplitScope() != key) throw StateError('Akkaunt o‘zgargan');
    return raw == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<Map<String, dynamic>> _rawSplitRead(String path,
      [Map<String, String>? query]) async {
    final key = rawSplitScope();
    final response = await _sendAuthorized(() {
      if (rawSplitScope() != key) throw StateError('Akkaunt o‘zgargan');
      return _get(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/raw-material-split/$path')
              .replace(queryParameters: query),
          headers: _headers(requireToken()));
    });
    if (rawSplitScope() != key) throw StateError('Akkaunt o‘zgargan');
    return _rawSplitResponse(response);
  }

  Future<RawSplitSnapshot> rawSplitSnapshot() async =>
      RawSplitSnapshot.fromJson(await _rawSplitRead('snapshot'));
  Future<RawSplitRoll> rawSplitSource(String barcode) async {
    final roll = RawSplitRoll.fromJson(
        await _rawSplitRead('source', {'barcode': barcode.trim()}));
    if (roll.revision == null || roll.revision!.isEmpty) {
      throw const FormatException('Rulon versiyasi olinmadi');
    }
    return roll;
  }

  /// The persisted payload, including its request ID, is the only retry source.
  /// An uncertain response cannot be replaced by a new command.
  Future<RawSplitResult> rawSplitSave(Map<String, dynamic> payload) async {
    if (_rawSplitSending) throw StateError('Saqlash davom etmoqda');
    _rawSplitSending = true;
    try {
      if (await TestModeController.instance.isEnabled()) {
        throw StateError('Haqiqiy akkaunt kerak');
      }
      final key = rawSplitScope();
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      final pending = raw == null
          ? Map<String, dynamic>.from(payload)
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
      if (jsonEncode(pending) != jsonEncode(payload)) {
        throw StateError('Avval oldingi operatsiya natijasini tekshiring');
      }
      if (!await prefs.setString(key, jsonEncode(pending))) {
        throw StateError('So‘rov kaliti saqlanmadi');
      }
      final response = await _sendAuthorized(() {
        if (rawSplitScope() != key) throw StateError('Akkaunt o‘zgargan');
        return _post(
            Uri.parse(
                '${MobileApi.baseUrl}/v1/mobile/raw-material-split/split'),
            headers: _headers(requireToken())
              ..['Content-Type'] = 'application/json',
            body: jsonEncode(pending));
      });
      String? code;
      try {
        code = (jsonDecode(response.body) as Map)['code'] as String?;
      } catch (_) {}
      if (response.statusCode >= 400 &&
          response.statusCode < 500 &&
          ['raw_split_invalid', 'raw_split_conflict', 'raw_split_scope']
              .contains(code)) {
        await prefs.remove(key);
      }
      // Validate the complete stock result before discarding the durable key.
      final result = RawSplitResult.fromJson(_rawSplitResponse(response));
      if (!await prefs.remove(key)) {
        throw StateError('Operatsiya natijasini qayta tekshiring');
      }
      if (rawSplitScope() != key) throw StateError('Akkaunt o‘zgargan');
      return result;
    } finally {
      _rawSplitSending = false;
    }
  }

  Future<void> rawSplitPrint(
      {required String splitId,
      required String barcode,
      required String driverUrl,
      required String printer,
      required String printMode}) async {
    final key = rawSplitScope();
    final response = await _sendAuthorized(() {
      if (rawSplitScope() != key) throw StateError('Akkaunt o‘zgargan');
      return _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/raw-material-split/print'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({
            'split_id': splitId,
            'barcode': barcode,
            'driver_url': driverUrl,
            'printer': printer,
            'print_mode': printMode
          }));
    });
    final result = _rawSplitResponse(response);
    if (result['ok'] != true ||
        result['status'] != 'done' ||
        result['barcode'] != barcode) {
      throw StateError('Chop etish tasdiqlanmadi');
    }
  }
}

Map<String, dynamic> _rawSplitResponse(http.Response response) {
  Map<String, dynamic>? data;
  try {
    data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  } catch (_) {}
  if (response.statusCode != 200 || data == null) {
    throw MobileApiException(
        code: 'raw_split_request_failed',
        statusCode: response.statusCode,
        message:
            data?['error'] as String? ?? 'Natija olinmadi. Qayta tekshiring.');
  }
  return data;
}
