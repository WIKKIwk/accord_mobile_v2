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

  String _paddonAttachmentKey() => '${_paddonStorageKey(write: true)}:attach';

  Future<PreparationPendingCommand?> pendingPreparationPaddonAttachment() =>
      _readPaddonCommand(_paddonAttachmentKey);

  Future<PreparationMaterialPaddonsPage> preparationPaddonOptions(
    List<String> receiptNames, {
    int offset = 0,
  }) async {
    final data = await _preparationPaddonOptions({
      'receipt_names': receiptNames,
      'offset': offset,
    });
    return PreparationMaterialPaddonsPage.fromJson(data);
  }

  Future<(PreparationMaterialPaddonsPage, PreparationBatchPaddonSelection)>
      preparationBatchPaddonOptions(String batchId, {int offset = 0}) async {
    final data = await _preparationPaddonOptions({
      'batch_id': batchId,
      'offset': offset,
    });
    final selection = PreparationBatchPaddonSelection.fromJson(
      (data['batch_selection'] as Map).cast<String, dynamic>(),
    );
    if (selection.batchId != batchId) {
      throw const FormatException('Rulonlar boshqa batchga tegishli');
    }
    return (PreparationMaterialPaddonsPage.fromJson(data), selection);
  }

  Future<Map<String, dynamic>> _preparationPaddonOptions(
    Map<String, Object> payload,
  ) async {
    final key = _paddonAttachmentKey();
    final scope = currentSessionReadScope();
    void checkAccess() {
      if (scope != currentSessionReadScope() || _paddonAttachmentKey() != key) {
        throw StateError('Akkaunt o‘zgargan');
      }
    }

    final response = await _sendAuthorized(() {
      checkAccess();
      return _post(
        Uri.parse(
          '${MobileApi.baseUrl}/v1/mobile/preparation/production/paddon-options',
        ),
        headers: _headers(requireToken())..['Content-Type'] = 'application/json',
        body: jsonEncode(payload),
      );
    });
    checkAccess();
    return _preparationResponse(response);
  }

  Future<void> attachPreparationRollsToPaddon(
    String code,
    List<String> receiptNames, {
    String? batchId,
  }) async {
    final receipts = receiptNames.toList()..sort();
    await _submitPreparationCommand(
      kind: 'preparation_paddon_attach',
      path: 'preparation/production/paddon-attach',
      payload: {
        'code': code,
        'receipt_names': receipts,
        if (batchId != null) 'batch_id': batchId,
      },
      storageKey: _paddonAttachmentKey,
      validateResult: (result) {
        final saved = result['receipt_names'];
        if (result['paddon_code'] != code ||
            saved is! List ||
            saved.length != receipts.length ||
            !setEquals(receipts.toSet(), saved.toSet())) {
          throw const FormatException('Rulonlar biriktirilgani tasdiqlanmadi');
        }
      },
    );
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

  String _labelKey(String issueId) =>
      '${_paddonStorageKey(write: false)}:labels:$issueId';

  Future<Map<String, PreparationPaddonPrintState>> localPaddonPrintStates(
      String issueId) async {
    final key = _labelKey(issueId);
    final prefs = await SharedPreferences.getInstance();
    if (key != _labelKey(issueId)) throw StateError('Akkaunt o‘zgargan');
    final saved = jsonDecode(prefs.getString(key) ?? '{}') as Map;
    return {
      for (final entry in saved.entries)
        entry.key as String: PreparationPaddonPrintState.fromJson(
            Map<String, dynamic>.from(entry.value as Map)),
    };
  }

  Future<PreparationPaddonPrintState> trackPaddonLabel(
    PreparationPaddonIssue issue,
    String barcode, {
    required String attempt,
    String? previous,
    required bool confirm,
  }) async {
    final scope = currentSessionReadScope();
    final account = _paddonStorageKey(write: true);
    void check() {
      if (scope != currentSessionReadScope() ||
          account != _paddonStorageKey(write: true)) {
        throw StateError('Akkaunt o‘zgargan');
      }
    }

    if (!issue.tracksPrint) {
      // Older servers cannot share acknowledgements. Keep their existing printer flow resumable on this device.
      final key = _labelKey(issue.id);
      final prefs = await SharedPreferences.getInstance();
      check();
      final all =
          jsonDecode(prefs.getString(key) ?? '{}') as Map<String, dynamic>;
      final saved = all[barcode] as Map?;
      if (saved?['attempt'] != (confirm ? attempt : previous)) {
        throw StateError('Yorliq holati o‘zgargan');
      }
      final state = {'attempt': attempt, 'printed': confirm};
      all[barcode] = state;
      if (!await prefs.setString(key, jsonEncode(all))) {
        throw StateError('Chop holati saqlanmadi');
      }
      return PreparationPaddonPrintState.fromJson(state);
    }
    final response = await _sendAuthorized(() {
      check();
      return _post(
          Uri.parse(
              '${MobileApi.baseUrl}/v1/mobile/raw-material-paddons/issues/print'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({
            'issue_id': issue.id,
            'barcode': barcode,
            'action': confirm ? 'confirm' : 'start',
            'attempt': attempt,
            if (previous != null) 'previous_attempt': previous
          }));
    });
    check();
    return PreparationPaddonPrintState.fromJson(_preparationResponse(response));
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
