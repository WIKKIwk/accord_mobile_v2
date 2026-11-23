part of '../mobile_api.dart';

extension MobileApiMaterialPaddons on MobileApi {
  String _paddonStorageKey({required bool write}) {
    final profile = AppSession.instance.profile;
    final role = profile?.role;
    final allowed = switch (role) {
      UserRole.tayyorlovMasteri => profile!.hasCapability('preparation.access'),
      UserRole.materialTaminotchi =>
        profile!.hasCapability(write ? 'gscale.print' : 'gscale.catalog.read'),
      _ => false,
    };
    if (!allowed || profile!.ref.isEmpty) {
      throw const MobileApiException(
          code: 'forbidden', message: 'Xomashyo paddonlariga ruxsat yo‘q');
    }
    return 'raw-material-paddon.pending.v1:${MobileApi.baseUrl}:${role!.name}:${profile.ref}';
  }

  Future<PreparationMaterialPaddonsPage> materialPaddons({
    String query = '',
    String status = 'all',
    int offset = 0,
    String? code,
  }) async {
    if (!const {'all', 'available', 'empty'}.contains(status) || offset < 0) {
      throw ArgumentError('Paddon qoldig‘i filtri noto‘g‘ri');
    }
    final key = _paddonStorageKey(write: false);
    final scope = currentSessionReadScope();
    void checkAccess() {
      if (_paddonStorageKey(write: false) != key ||
          currentSessionReadScope() != scope) {
        throw StateError('Akkaunt o‘zgargan');
      }
    }

    final response = await _sendAuthorized(() {
      checkAccess();
      return _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/raw-material-paddons')
            .replace(queryParameters: {
          'q': String.fromCharCodes(query.trim().runes.take(200)),
          if (code != null) 'code': code,
          'status': status,
          'offset': '$offset',
          'limit': '50',
        }),
        headers: _headers(requireToken()),
      );
    });
    checkAccess();
    if (response.statusCode == 404 && response.body.trim().isEmpty) {
      throw const MobileApiException(
        code: 'material_paddons_api_unavailable',
        statusCode: 404,
        message: 'Xomashyo paddonlari bu serverda hali mavjud emas.',
      );
    }
    return PreparationMaterialPaddonsPage.fromJson(
        _preparationResponse(response));
  }

  Future<PreparationPendingCommand?> pendingMaterialPaddon() async {
    return _readPaddonCommand(() => _paddonStorageKey(write: true));
  }

  Future<PreparationPendingCommand?> _readPaddonCommand(
      String Function() storageKey) async {
    final key = storageKey();
    final preferences = await SharedPreferences.getInstance();
    if (storageKey() != key) {
      throw StateError('Akkaunt o‘zgargan');
    }
    final raw = preferences.getString(key);
    return raw == null
        ? null
        : PreparationPendingCommand.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  Future<String> receiveMaterialPaddon(Map<String, dynamic> payload) async {
    final result = await _submitPreparationCommand(
      kind: 'raw_material_paddon',
      path: 'raw-material-paddons',
      payload: payload,
      storageKey: () => _paddonStorageKey(write: true),
      validateResult: (result) {
        if (result['paddon_code'] is! String ||
            (result['paddon_code'] as String).trim().isEmpty) {
          throw const FormatException('Paddon kirimi tasdiqlanmadi');
        }
      },
    );
    return result['paddon_code'] as String;
  }

  Future<PreparationMaterialPaddon?> materialPaddonByCode(String code) async {
    final page = await materialPaddons(code: code);
    return page.paddons
        .where((paddon) => paddon.code.toUpperCase() == code.toUpperCase())
        .firstOrNull;
  }

  String _paddonIssueKey() => '${_paddonStorageKey(write: true)}:issue';

  Future<PreparationPendingCommand?> pendingMaterialPaddonIssue() =>
      _readPaddonCommand(_paddonIssueKey);

  Future<PreparationPaddonIssue> issueMaterialPaddon(
    Map<String, dynamic> payload,
  ) async {
    final result = await _submitPreparationCommand(
      kind: 'raw_material_paddon_issue',
      path: 'raw-material-paddons/issues',
      payload: payload,
      storageKey: _paddonIssueKey,
      validateResult: (result) {
        final issue = PreparationPaddonIssue.fromJson(result);
        if (issue.paddonCode != payload['code'] ||
            issue.labels.length != (payload['weights'] as List).length) {
          throw const FormatException('Paddon chiqimi tasdiqlanmadi');
        }
      },
    );
    return PreparationPaddonIssue.fromJson(result);
  }

  Future<List<PreparationPaddonIssue>> materialPaddonIssues(String code) async {
    _paddonStorageKey(write: false);
    final scope = currentSessionReadScope();
    void checkScope() {
      if (scope != currentSessionReadScope()) {
        throw StateError('Akkaunt o‘zgargan');
      }
    }

    final response = await _sendAuthorized(() {
      checkScope();
      return _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/raw-material-paddons/issues')
            .replace(queryParameters: {'code': code}),
        headers: _headers(requireToken()),
      );
    });
    checkScope();
    final result = _preparationResponse(response);
    final issues = result['issues'] as List;
    return [
      for (final issue in issues)
        PreparationPaddonIssue.fromJson(
            Map<String, dynamic>.from(issue as Map)),
    ];
  }
}
