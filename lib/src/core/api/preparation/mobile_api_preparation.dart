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
    if (!const ['materials', 'receipts', 'consumptions'].contains(kind)) {
      throw ArgumentError.value(kind);
    }
    return _submitPreparationCommand(
      kind: kind,
      path: 'preparation/$kind',
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> preparationReverseReceipt({
    required String receiptId,
    required String reason,
  }) {
    return _submitPreparationCommand(
      kind: 'receipt_reversals',
      path: 'preparation/receipt-reversals',
      payload: {
        'receipt_id': receiptId,
        'reason': reason,
      },
    );
  }

  /// Tarozi kirimida Tayyorlov masterining o'z (exclusive) omboriga QR'siz
  /// kirim. Bu alohida GScale endpointi bo'lib, oddiy preparation kirimi
  /// picker/qoidalarini o'zgartirmaydi.
  Future<Map<String, dynamic>> gscaleSimpleMaterialReceipt(
      Map<String, dynamic> payload) {
    return _submitPreparationCommand(
      kind: 'gscale_simple_receipt',
      path: 'gscale/material-receipt/simple',
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> _submitPreparationCommand({
    required String kind,
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    if (_preparationSending) throw StateError('Saqlash davom etmoqda');
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
            Uri.parse('${MobileApi.baseUrl}/v1/mobile/$path'),
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
            'preparation_receipt_requires_qr',
            'preparation_warehouse_not_exclusive',
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

  /// Tayyorlov formula cardlari: bitta tayyor mahsulot kodi + bitta
  /// homashyo (calculate-material oilasi) uchun bir nechta nomli formula.
  /// Cardlar nom bo'yicha alifboda. Homashyo majburiy scope.
  Future<List<PreparationFormula>> preparationFormulas(
    String productCode, {
    required String materialId,
  }) async {
    final code = productCode.trim();
    final material = materialId.trim();
    if (code.isEmpty) {
      throw const MobileApiException(
          code: 'preparation_invalid', message: 'Mahsulot kodi topilmadi');
    }
    if (material.isEmpty) {
      throw const MobileApiException(
          code: 'preparation_invalid', message: 'Homashyo tanlanmadi');
    }
    final key = _preparationStorageKey();
    final uri = Uri.parse('${MobileApi.baseUrl}/v1/mobile/preparation/formulas')
        .replace(queryParameters: {
      'product_code': code,
      'material_id': material,
    });
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != key) {
        throw StateError('Akkaunt o‘zgargan');
      }
      return _get(uri, headers: _headers(requireToken()));
    });
    if (_preparationStorageKey() != key) throw StateError('Akkaunt o‘zgargan');
    return PreparationFormula.listFromJson(_preparationResponse(response));
  }

  Future<PreparationFormula> preparationUpsertFormula(
    String productCode,
    List<Map<String, String>> lines, {
    String? name,
    required String materialId,
  }) async {
    final key = _preparationStorageKey();
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != key) {
        throw StateError('Akkaunt o‘zgargan');
      }
      return _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/preparation/formulas'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({
            'product_code': productCode.trim(),
            'material_id': materialId.trim(),
            if (name != null) 'name': name.trim(),
            'lines': lines,
          }));
    });
    if (_preparationStorageKey() != key) throw StateError('Akkaunt o‘zgargan');
    return PreparationFormula.fromJson(_preparationResponse(response));
  }

  Future<void> preparationDeleteFormula(
    String productCode,
    String name, {
    required String materialId,
  }) async {
    final key = _preparationStorageKey();
    final uri = Uri.parse('${MobileApi.baseUrl}/v1/mobile/preparation/formulas')
        .replace(queryParameters: {
      'product_code': productCode.trim(),
      'name': name.trim(),
      'material_id': materialId.trim(),
    });
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != key) {
        throw StateError('Akkaunt o‘zgargan');
      }
      return _delete(uri, headers: _headers(requireToken()));
    });
    if (_preparationStorageKey() != key) throw StateError('Akkaunt o‘zgargan');
    _preparationResponse(response);
  }

  /// Order qatlamlaridagi homashyolar — faqat o'ziga biriktirilganlari qaytadi.
  /// Formula tugmasi uchun: bu orderning qaysi homashyosi so'raladi.
  Future<List<PreparationResponsibility>> preparationOrderMaterials(
    String orderId,
  ) async {
    final id = orderId.trim();
    if (id.isEmpty) {
      throw const MobileApiException(
          code: 'preparation_invalid', message: 'Order topilmadi');
    }
    final key = _preparationStorageKey();
    final uri = Uri.parse(
            '${MobileApi.baseUrl}/v1/mobile/preparation/order-materials')
        .replace(queryParameters: {'order_id': id});
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != key) {
        throw StateError('Akkaunt o‘zgargan');
      }
      return _get(uri, headers: _headers(requireToken()));
    });
    if (_preparationStorageKey() != key) throw StateError('Akkaunt o‘zgargan');
    final data = _preparationResponse(response);
    final raw = data['materials'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map)
          PreparationResponsibility.fromJson(
              Map<String, dynamic>.from(e)),
    ];
  }

  /// Bola ombor ochish: ota ombor ostiga yangi ichki ombor.
  /// Qaytgach snapshot yangilanadi — yangi ombor filtrda chiqadi.
  Future<String> preparationCreateWarehouse({
    required String name,
    required String parent,
  }) async {
    final key = _preparationStorageKey();
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != key) {
        throw StateError('Akkaunt o‘zgargan');
      }
      return _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/preparation/warehouses'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode(
              {'name': name.trim(), 'parent_warehouse': parent.trim()}));
    });
    if (_preparationStorageKey() != key) throw StateError('Akkaunt o‘zgargan');
    final data = _preparationResponse(response);
    return (data['warehouse'] as String? ?? '').trim();
  }

  /// Admin: tayyorlov masterining javobgar homashyolari ro'yxati.
  /// Faqat admin roliga — tayyorlov masteri o'z snapshot'idan ko'radi.
  Future<List<PreparationResponsibility>> preparationResponsibilities(
    String principalRef,
  ) async {
    final ref = principalRef.trim();
    if (ref.isEmpty) {
      throw const MobileApiException(
          code: 'preparation_invalid', message: 'Foydalanuvchi topilmadi');
    }
    final response = await _sendAuthorized(() => _get(
        Uri.parse(
                '${MobileApi.baseUrl}/v1/mobile/admin/preparation/responsibilities')
            .replace(queryParameters: {'principal_ref': ref}),
        headers: _headers(requireToken())));
    final data = _preparationResponse(response);
    final raw = data['materials'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map)
          PreparationResponsibility.fromJson(
              Map<String, dynamic>.from(e)),
    ];
  }

  /// Admin: tayyorlov masteriga homashyo (calculate-material id) biriktirish.
  Future<PreparationResponsibility> preparationAssignResponsibility({
    required String principalRef,
    required String materialId,
  }) async {
    final response = await _sendAuthorized(() => _post(
        Uri.parse(
            '${MobileApi.baseUrl}/v1/mobile/admin/preparation/responsibilities'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'principal_ref': principalRef.trim(),
          'material_id': materialId.trim(),
        })));
    final data = _preparationResponse(response);
    return PreparationResponsibility(
      materialId: (data['material_id'] as String? ?? '').trim(),
      materialName: (data['material_name'] as String? ?? '').trim(),
    );
  }

  /// Admin: tayyorlov masteridan homashyo biriktirishni olib tashlash.
  Future<void> preparationUnassignResponsibility({
    required String principalRef,
    required String materialId,
  }) async {
    final response = await _sendAuthorized(() => _delete(
        Uri.parse(
                '${MobileApi.baseUrl}/v1/mobile/admin/preparation/responsibilities')
            .replace(queryParameters: {
          'principal_ref': principalRef.trim(),
          'material_id': materialId.trim(),
        }),
        headers: _headers(requireToken())));
    _preparationResponse(response);
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
