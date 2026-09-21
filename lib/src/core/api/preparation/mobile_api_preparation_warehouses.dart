part of '../mobile_api.dart';

extension MobileApiPreparationWarehouses on MobileApi {
  Future<String> preparationRenameWarehouse({
    required String warehouse,
    required String name,
  }) =>
      _preparationWarehouseMutation('PATCH', {
        'warehouse': warehouse.trim(),
        'name': name.trim(),
      });

  Future<void> preparationDeleteWarehouse(String warehouse) async {
    await _preparationWarehouseMutation(
        'DELETE', {'warehouse': warehouse.trim()});
  }

  Future<String> _preparationWarehouseMutation(
      String method, Map<String, String> payload) async {
    final key = _preparationStorageKey();
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != key) {
        throw const MobileApiException(
            code: 'account_changed',
            message: 'Akkaunt o‘zgargan. Sahifani qayta oching');
      }
      final uri =
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/preparation/warehouses');
      final headers = _headers(requireToken())
        ..['Content-Type'] = 'application/json';
      if (method == 'DELETE') {
        return _delete(uri.replace(queryParameters: payload), headers: headers);
      }
      final send = method == 'PATCH' ? _patch : _post;
      return send(uri, headers: headers, body: jsonEncode(payload));
    });
    if (_preparationStorageKey() != key) {
      throw const MobileApiException(
          code: 'account_changed',
          message: 'Akkaunt o‘zgargan. Sahifani qayta oching');
    }
    Map<String, dynamic>? data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {}
    if (response.statusCode == 200 &&
        data?['warehouse'] is String &&
        (data!['warehouse'] as String).trim().isNotEmpty) {
      return (data['warehouse'] as String).trim();
    }
    final code = data?['code'] as String? ?? 'preparation_warehouse_failed';
    final message = switch (code) {
      'preparation_warehouse_name_taken' =>
        'Bunday nomli ombor mavjud. Boshqa nom kiriting',
      'preparation_warehouse_not_empty' =>
        'Omborda homashyo yoki mahsulot bor. Avval ularni boshqa omborga ko‘chiring',
      'preparation_warehouse_has_materials' =>
        'Omborga homashyo biriktirilgan. Avval homashyo bog‘lanishlarini olib tashlang',
      'preparation_warehouse_has_children' =>
        'Bu omborda bola omborlar bor. Avval ularni boshqaring',
      'preparation_warehouse_in_use' =>
        'Omborda bog‘langan yozuvlar yoki faol operatsiyalar bor. Uni o‘chirib bo‘lmaydi',
      'preparation_warehouse_not_exclusive' =>
        'Bola omborni faqat o‘zingizga eksklyuziv biriktirilgan omborda ochishingiz mumkin',
      'preparation_warehouse_not_owned' ||
      'preparation_scope' =>
        'Faqat o‘zingiz yaratgan va faqat sizga biriktirilgan bola omborni boshqarishingiz mumkin',
      'preparation_invalid' =>
        'Ombor nomi 1–160 ta belgidan iborat va ota ombor nomidan farqli bo‘lishi kerak',
      'preparation_conflict' =>
        'Ombor hozir band yoki unga boshqa yozuvlar bog‘langan. Ma’lumotlarni yangilab, qayta urinib ko‘ring',
      _ when response.statusCode == 401 => 'Sessiya tugagan. Qayta kiring',
      _ when response.statusCode == 403 =>
        'Bu omborni boshqarish huquqingiz yo‘q',
      _ => 'Ombor bilan amal bajarilmadi. Birozdan keyin qayta urinib ko‘ring',
    };
    throw MobileApiException(
        code: code, message: message, statusCode: response.statusCode);
  }
}
