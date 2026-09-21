part of '../mobile_api.dart';

extension MobileApiPreparationMaterials on MobileApi {
  Future<List<PreparationOwnedMaterial>> preparationOwnedMaterials() async {
    final data = await _preparationMaterialRequest('GET', const {});
    return (data['materials'] as List)
        .map((entry) => PreparationOwnedMaterial.fromJson(
            Map<String, dynamic>.from(entry as Map)))
        .toList();
  }

  Future<String> preparationRenameMaterial(
      {required String itemCode, required String name}) async {
    final data = await _preparationMaterialRequest(
        'PATCH', {'item_code': itemCode, 'name': name.trim()});
    if (data['item_code'] != itemCode ||
        data['name'] is! String ||
        (data['name'] as String).trim().isEmpty) {
      throw const MobileApiException(
          code: 'invalid_response',
          message: 'Server javobi tushunarsiz. Ro‘yxatni yangilang');
    }
    return data['name'] as String;
  }

  Future<void> preparationDeleteMaterial(String itemCode) async {
    final data =
        await _preparationMaterialRequest('DELETE', {'item_code': itemCode});
    if (data['item_code'] != itemCode || data['deleted'] != true) {
      throw const MobileApiException(
          code: 'invalid_response',
          message: 'O‘chirish tasdiqlanmadi. Ro‘yxatni yangilang');
    }
  }

  Future<PreparationOwnedMaterial> preparationSetMaterialWarehouses(
      {required String itemCode, required List<String> warehouses}) async {
    final data = await _preparationMaterialRequest(
        'PATCH', {'item_code': itemCode, 'warehouses': warehouses},
        suffix: '/warehouses');
    if (data['item_code'] != itemCode ||
        data['name'] is! String ||
        data['warehouses'] is! List ||
        (data['warehouses'] as List).any((value) => value is! String)) {
      throw const MobileApiException(
          code: 'invalid_response',
          message: 'Ombor biriktirilgani tasdiqlanmadi. Ro‘yxatni yangilang');
    }
    return PreparationOwnedMaterial.fromJson(data);
  }

  Future<Map<String, dynamic>> _preparationMaterialRequest(
      String method, Map<String, dynamic> payload,
      {String suffix = ''}) async {
    final key = _preparationStorageKey();
    if (method != 'GET' && await TestModeController.instance.isEnabled()) {
      throw const MobileApiException(
          code: 'test_mode',
          message: 'Homashyoni boshqarish uchun haqiqiy akkaunt kerak');
    }
    void checkAccount() {
      if (_preparationStorageKey() != key) {
        throw const MobileApiException(
            code: 'account_changed',
            message: 'Akkaunt o‘zgargan. Sahifani qayta oching');
      }
    }

    final response = await _sendAuthorized(() {
      checkAccount();
      final uri = Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/preparation/materials$suffix');
      final headers = _headers(requireToken())
        ..['Content-Type'] = 'application/json';
      if (method == 'GET') return _get(uri, headers: headers);
      if (method == 'DELETE') {
        return _delete(uri.replace(queryParameters: payload), headers: headers);
      }
      return _patch(uri, headers: headers, body: jsonEncode(payload));
    });
    checkAccount();
    Map<String, dynamic>? data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {}
    if (response.statusCode == 200 && data != null) return data;
    final rawCode = data?['code'];
    final code = rawCode is String ? rawCode : 'preparation_material_failed';
    final message = switch (code) {
      'preparation_material_not_owned' =>
        'Faqat o‘zingiz yaratgan homashyoni boshqarishingiz mumkin',
      'preparation_material_name_taken' =>
        'Sizda bunday nomli homashyo mavjud. Boshqa nom kiriting',
      'preparation_material_in_use' =>
        'Homashyo ishlatilgan: qoldiq, kirim, formula yoki boshqa bog‘langan yozuvlar bor. Uni o‘chirib bo‘lmaydi',
      'preparation_material_warehouse_in_use' =>
        'Bu omborda homashyo qoldig‘i, kutilayotgan kirim yoki faol ko‘chirish bor. Avval ularni yakunlang',
      'preparation_warehouse_not_exclusive' =>
        'Faqat o‘zingizga exclusive biriktirilgan omborlarni o‘zgartirishingiz mumkin',
      'preparation_invalid' when suffix == '/warehouses' =>
        'Omborlar ro‘yxati noto‘g‘ri. Ro‘yxatni yangilab, qayta tanlang',
      'preparation_invalid' =>
        'Homashyo nomi 1–160 ta belgidan iborat bo‘lishi kerak',
      'preparation_conflict' =>
        'Homashyo hozir band. Birozdan keyin qayta urinib ko‘ring',
      _ when response.statusCode == 401 => 'Sessiya tugagan. Qayta kiring',
      _ when response.statusCode == 403 =>
        'Bu amal uchun Tayyorlov masteri huquqi kerak',
      _ =>
        'Homashyo bilan amal bajarilmadi. Birozdan keyin qayta urinib ko‘ring',
    };
    throw MobileApiException(
        code: code, message: message, statusCode: response.statusCode);
  }
}
