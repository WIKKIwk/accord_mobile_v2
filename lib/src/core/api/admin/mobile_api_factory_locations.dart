part of '../mobile_api.dart';

final List<AdminFactoryLocation> _testModeFactoryLocations = [];

void resetMobileApiFactoryLocationTestData() {
  _testModeFactoryLocations.clear();
}

extension MobileApiFactoryLocations on MobileApi {
  Future<List<AdminFactoryLocation>> adminFactoryLocations() async {
    if (await TestModeController.instance.isEnabled()) {
      return List<AdminFactoryLocation>.unmodifiable(
        [..._testModeFactoryLocations]..sort(
            (left, right) =>
                left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          ),
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/factory-locations',
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: 'factory_locations_load_failed',
        fallbackMessage: 'State’lar yuklanmadi',
      );
    }
    final payload = await decodeJsonListPayload(response.body);
    return payload
        .whereType<Map>()
        .map(
          (item) => AdminFactoryLocation.fromJson(item.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Future<AdminFactoryLocation> adminCreateFactoryLocation({
    required String name,
    List<String> apparatusIds = const [],
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw const MobileApiException(
        code: 'state_name_required',
        message: 'State nomini kiriting',
      );
    }
    final normalizedIds = _normalizedFactoryLocationApparatusIds(apparatusIds);
    if (await TestModeController.instance.isEnabled()) {
      if (_testModeFactoryLocations.any(
        (item) =>
            item.name.trim().toLowerCase() == normalizedName.toLowerCase(),
      )) {
        throw const MobileApiException(
          code: 'state_name_already_exists',
          message: 'Bu nomdagi state mavjud',
          statusCode: 409,
        );
      }
      final apparatus = await _resolveTestModeFactoryLocationApparatus(
        normalizedIds,
      );
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final location = AdminFactoryLocation(
        id: 'state_${now}_${_testModeFactoryLocations.length + 1}',
        name: normalizedName,
        active: true,
        apparatus: apparatus,
        createdAtUnix: now,
        updatedAtUnix: now,
      );
      _testModeFactoryLocations.add(location);
      return location;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/factory-locations',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'name': normalizedName,
          'apparatus_ids': normalizedIds,
        }),
      ),
    );
    return _decodeFactoryLocationMutation(
      response,
      fallbackCode: 'factory_location_create_failed',
      fallbackMessage: 'State yaratilmadi',
    );
  }

  Future<AdminFactoryLocation> adminUpdateFactoryLocation({
    required String id,
    String? name,
    bool? active,
  }) async {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty || (name == null && active == null)) {
      throw const MobileApiException(
        code: 'factory_location_update_invalid',
        message: 'State o‘zgarishi topilmadi',
      );
    }
    final normalizedName = name?.trim();
    if (name != null && normalizedName!.isEmpty) {
      throw const MobileApiException(
        code: 'state_name_required',
        message: 'State nomini kiriting',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeFactoryLocations.indexWhere(
        (item) => item.id == normalizedId,
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'state_not_found',
          message: 'State topilmadi',
          statusCode: 404,
        );
      }
      if (normalizedName != null &&
          _testModeFactoryLocations.any(
            (item) =>
                item.id != normalizedId &&
                item.name.toLowerCase() == normalizedName.toLowerCase(),
          )) {
        throw const MobileApiException(
          code: 'state_name_already_exists',
          message: 'Bu nomdagi state mavjud',
          statusCode: 409,
        );
      }
      final current = _testModeFactoryLocations[index];
      final updated = AdminFactoryLocation(
        id: current.id,
        name: normalizedName ?? current.name,
        active: active ?? current.active,
        apparatus: current.apparatus,
        createdAtUnix: current.createdAtUnix,
        updatedAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      _testModeFactoryLocations[index] = updated;
      return updated;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/factory-locations/'
          '${Uri.encodeComponent(normalizedId)}',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          if (normalizedName != null) 'name': normalizedName,
          if (active != null) 'active': active,
        }),
      ),
    );
    return _decodeFactoryLocationMutation(
      response,
      fallbackCode: 'factory_location_update_failed',
      fallbackMessage: 'State yangilanmadi',
    );
  }

  Future<AdminFactoryLocation> adminReplaceFactoryLocationApparatus({
    required String id,
    required List<String> apparatusIds,
  }) async {
    final normalizedId = id.trim();
    final normalizedIds = _normalizedFactoryLocationApparatusIds(apparatusIds);
    if (normalizedId.isEmpty) {
      throw const MobileApiException(
        code: 'state_not_found',
        message: 'State topilmadi',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeFactoryLocations.indexWhere(
        (item) => item.id == normalizedId,
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'state_not_found',
          message: 'State topilmadi',
          statusCode: 404,
        );
      }
      final current = _testModeFactoryLocations[index];
      final updated = AdminFactoryLocation(
        id: current.id,
        name: current.name,
        active: current.active,
        apparatus: await _resolveTestModeFactoryLocationApparatus(
          normalizedIds,
        ),
        createdAtUnix: current.createdAtUnix,
        updatedAtUnix: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      _testModeFactoryLocations[index] = updated;
      return updated;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/admin/factory-locations/'
          '${Uri.encodeComponent(normalizedId)}/apparatus',
        ),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'apparatus_ids': normalizedIds}),
      ),
    );
    return _decodeFactoryLocationMutation(
      response,
      fallbackCode: 'factory_location_apparatus_update_failed',
      fallbackMessage: 'State apparatlari yangilanmadi',
    );
  }

  AdminFactoryLocation _decodeFactoryLocationMutation(
    http.Response response, {
    required String fallbackCode,
    required String fallbackMessage,
  }) {
    if (response.statusCode != 200) {
      throw _adminApiException(
        response,
        fallbackCode: fallbackCode,
        fallbackMessage: fallbackMessage,
      );
    }
    return AdminFactoryLocation.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

List<String> _normalizedFactoryLocationApparatusIds(Iterable<String> ids) {
  final seen = <String>{};
  return ids
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty && seen.add(id))
      .toList(growable: false);
}

Future<List<AdminApparatus>> _resolveTestModeFactoryLocationApparatus(
  List<String> ids,
) async {
  final catalog = await MobileApi.instance.adminApparatus(limit: 10000);
  final byId = {for (final item in catalog) item.id: item};
  final resolved = <AdminApparatus>[];
  for (final id in ids) {
    final item = byId[id];
    if (item == null) {
      throw const MobileApiException(
        code: 'apparatus_id_invalid',
        message: 'Noto‘g‘ri apparat tanlandi',
        statusCode: 400,
      );
    }
    resolved.add(item);
  }
  return resolved;
}
