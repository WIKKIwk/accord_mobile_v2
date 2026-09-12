part of '../mobile_api.dart';

bool _preparationSending = false;

extension MobileApiPreparation on MobileApi {
  String _preparationStorageKey() {
    final profile = AppSession.instance.profile;
    if (profile?.role != UserRole.tayyorlovMasteri ||
        profile!.ref.isEmpty ||
        !profile.hasCapability('preparation.access')) {
      throw const MobileApiException(
          code: 'forbidden', message: 'Tayyorlov masteri huquqi kerak');
    }
    return 'preparation.pending.v1:${MobileApi.baseUrl}:${profile.ref}';
  }

  Future<PreparationPendingCommand?> preparationPendingCommand() async {
    final key = _preparationStorageKey();
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    return raw == null
        ? null
        : PreparationPendingCommand.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  Future<PreparationSnapshot> preparationSnapshot() async {
    final key = _preparationStorageKey();
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != key) {
        throw StateError('Akkaunt o‘zgargan');
      }
      return _get(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/preparation/snapshot'),
          headers: _headers(requireToken()));
    });
    if (_preparationStorageKey() != key) throw StateError('Akkaunt o‘zgargan');
    return PreparationSnapshot.fromJson(_preparationResponse(response));
  }

  /// Persist one immutable command per account/server. A lost response or app
  /// restart must never turn the same save into a second stock movement.
  Future<Map<String, dynamic>> preparationSubmit(
      String kind, Map<String, dynamic> payload) async {
    if (_preparationSending) throw StateError('Saqlash davom etmoqda');
    if (!const ['materials', 'receipts', 'consumptions'].contains(kind)) {
      throw ArgumentError.value(kind);
    }
    if (payload.containsKey('request_id')) {
      throw ArgumentError('request_id is managed by the client');
    }
    _preparationSending = true;
    try {
      if (await TestModeController.instance.isEnabled()) {
        throw const MobileApiException(
            code: 'test_mode',
            message: 'Tayyorlov ombori uchun haqiqiy akkaunt kerak');
      }
      final key = _preparationStorageKey();
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(key);
      final pending = raw == null
          ? PreparationPendingCommand(
              kind: kind,
              payload: payload,
              requestId: newPreparationRequestId())
          : PreparationPendingCommand.fromJson(
              Map<String, dynamic>.from(jsonDecode(raw) as Map));
      if (pending.kind != kind ||
          jsonEncode(pending.payload) != jsonEncode(payload)) {
        throw const MobileApiException(
            code: 'pending_preparation',
            message: 'Avval oldingi operatsiya natijasini tekshiring');
      }
      if (!await preferences.setString(key, jsonEncode(pending.toJson()))) {
        throw StateError('Saqlash kaliti qurilmada saqlanmadi');
      }
      final response = await _sendAuthorized(() {
        if (_preparationStorageKey() != key) {
          throw StateError('Akkaunt o‘zgargan');
        }
        return _post(
            Uri.parse('${MobileApi.baseUrl}/v1/mobile/preparation/$kind'),
            headers: _headers(requireToken())
              ..['Content-Type'] = 'application/json',
            body: jsonEncode(
                {...pending.payload, 'request_id': pending.requestId}));
      });
      // Only a definitive domain rejection proves no commit occurred. A proxy
      // error or expired/revoked login must not discard an uncertain retry key.
      String? rejectedCode;
      try {
        rejectedCode = (jsonDecode(response.body) as Map)['code'] as String?;
      } catch (_) {}
      if (response.statusCode >= 400 &&
          response.statusCode < 500 &&
          const [
            'preparation_invalid',
            'preparation_conflict',
            'preparation_scope',
            'preparation_insufficient_stock'
          ].contains(rejectedCode)) {
        await preferences.remove(key);
      }
      final result = _preparationResponse(response);
      if (!await preferences.remove(key)) {
        throw StateError('Operatsiya natijasini qayta tekshiring');
      }
      if (_preparationStorageKey() != key) {
        throw StateError('Akkaunt o‘zgargan');
      }
      return result;
    } finally {
      _preparationSending = false;
    }
  }

  /// Tayyorlov formulasi: bitta tayyor mahsulot kodi uchun
  /// seriya (homashyo) + foiz ro'yxati. Alifbo tartibi serverda saqlanadi.
  Future<PreparationFormula> preparationFormula(String productCode) async {
    final code = productCode.trim();
    if (code.isEmpty) {
      throw const MobileApiException(
          code: 'preparation_invalid', message: 'Mahsulot kodi topilmadi');
    }
    final key = _preparationStorageKey();
    final uri = Uri.parse('${MobileApi.baseUrl}/v1/mobile/preparation/formulas')
        .replace(queryParameters: {'product_code': code});
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != key) {
        throw StateError('Akkaunt o‘zgargan');
      }
      return _get(uri, headers: _headers(requireToken()));
    });
    if (_preparationStorageKey() != key) throw StateError('Akkaunt o‘zgargan');
    return PreparationFormula.fromJson(_preparationResponse(response));
  }

  Future<PreparationFormula> preparationUpsertFormula(
    String productCode,
    List<Map<String, String>> lines,
  ) async {
    final key = _preparationStorageKey();
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != key) {
        throw StateError('Akkaunt o‘zgargan');
      }
      return _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/preparation/formulas'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body:
              jsonEncode({'product_code': productCode.trim(), 'lines': lines}));
    });
    if (_preparationStorageKey() != key) throw StateError('Akkaunt o‘zgargan');
    return PreparationFormula.fromJson(_preparationResponse(response));
  }
}

Map<String, dynamic> _preparationResponse(http.Response response) {
  Map<String, dynamic>? data;
  try {
    data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  } catch (_) {/* Keep retry key on a corrupt success response. */}
  if (response.statusCode != 200 || data == null) {
    throw MobileApiException(
        code: 'preparation_request_failed',
        statusCode: response.statusCode,
        message: data?['error'] as String? ??
            'Tayyorlov ma’lumotlari olinmadi. Qayta urinib ko‘ring');
  }
  return data;
}
