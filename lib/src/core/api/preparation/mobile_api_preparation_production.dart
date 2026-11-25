part of '../mobile_api.dart';

extension MobileApiPreparationProduction on MobileApi {
  Future<PreparationRollNotes?> preparationRollNotesForScan(
      String barcode) async {
    final code = barcode.trim();
    final scope = currentSessionReadScope();
    if (code.isEmpty ||
        !AppSession.instance.isLoggedIn ||
        !const {
          UserRole.rezkaMaster,
          UserRole.homashyoRezkachi,
          UserRole.aparatchi,
        }.contains(AppSession.instance.profile?.role) ||
        await TestModeController.instance.isEnabled() ||
        scope != currentSessionReadScope()) {
      return null;
    }
    final response = await _sendAuthorized(() {
      if (scope != currentSessionReadScope()) {
        throw StateError('Akkaunt o‘zgargan');
      }
      return _get(
        Uri.parse(
                '${MobileApi.baseUrl}/v1/mobile/preparation/production/notes/scan')
            .replace(queryParameters: {'barcode': code}),
        headers: _headers(requireToken()),
      );
    });
    if (scope != currentSessionReadScope() ||
        response.statusCode == 403 ||
        response.statusCode == 404) {
      return null;
    }
    final data = _preparationResponse(response);
    final returnedCode = data['barcode'];
    if (returnedCode is! String ||
        returnedCode.trim().toUpperCase() != code.toUpperCase()) {
      throw const FormatException('Eslatma boshqa rulonga tegishli');
    }
    final notes = PreparationRollNotes.fromJson(data);
    return notes.isEmpty ? null : notes;
  }

  Future<Map<String, dynamic>> _productionRead(
      String path, Map<String, String> query) async {
    final key = _preparationStorageKey();
    final scope = currentSessionReadScope();
    final response = await _sendAuthorized(() {
      if (_preparationStorageKey() != key ||
          currentSessionReadScope() != scope) {
        throw StateError('Akkaunt o‘zgargan');
      }
      return _get(
          Uri.parse(
                  '${MobileApi.baseUrl}/v1/mobile/preparation/production/$path')
              .replace(queryParameters: query),
          headers: _headers(requireToken()));
    });
    if (_preparationStorageKey() != key || currentSessionReadScope() != scope) {
      throw StateError('Akkaunt o‘zgargan');
    }
    return _preparationResponse(response);
  }

  Future<PreparationProductionOrdersPage> preparationProductionOrders({
    String query = '',
    String status = 'all',
    int offset = 0,
  }) async {
    return PreparationProductionOrdersPage.fromJson(
        await _productionList('orders', query, status, offset));
  }

  Future<PreparationProductionBatchesPage> preparationProductionBatches({
    String query = '',
    String status = 'all',
    int offset = 0,
  }) async {
    return PreparationProductionBatchesPage.fromJson(
        await _productionList('batches', query, status, offset));
  }

  Future<PreparationProductionRollsPage> preparationProductionRolls({
    String query = '',
    String status = 'all',
    int offset = 0,
  }) async {
    return PreparationProductionRollsPage.fromJson(
        await _productionList('rolls', query, status, offset));
  }

  Future<Map<String, dynamic>> _productionList(
      String mode, String query, String status, int offset) async {
    if (!const {'all', 'active', 'completed'}.contains(status) || offset < 0) {
      throw ArgumentError('Ishlab chiqarish filtri noto‘g‘ri');
    }
    try {
      return await _productionRead(mode, {
        'q': String.fromCharCodes(query.trim().runes.take(200)),
        'status': status,
        'offset': '$offset',
        'limit': '50',
      });
    } on MobileApiException catch (error) {
      if (mode != 'orders' && error.statusCode == 404) {
        throw const MobileApiException(
          code: 'preparation_output_api_unavailable',
          statusCode: 404,
          message:
              'Batch va rulon ro‘yxati uchun Mini RS ERP’ni yangilash kerak.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> syncPreparationJournal({
    required String view,
    required String query,
    required String status,
    required int length,
    required PreparationJournalCheckpoint? baseline,
    required bool watch,
    required Future<void> abort,
  }) async {
    _preparationStorageKey();
    final scope = currentSessionReadScope();
    final uri = Uri.parse(
        '${MobileApi.baseUrl}/v1/mobile/preparation/production/sync');
    final body = jsonEncode({
      'view': view,
      'q': query,
      'status': status,
      'length': length,
      'baseline': baseline?.toJson(),
      'watch': watch,
    });
    void guardAccount() {
      if (currentSessionReadScope() != scope) {
        throw StateError('Akkaunt o‘zgargan');
      }
    }

    final response = await _sendAuthorized(() async {
      guardAccount();
      final headers = _headers(requireToken())
        ..['Content-Type'] = 'application/json';
      if (NativeIrohTransport.canUseFor(uri)) {
        return NativeIrohTransport.send(
          method: 'POST',
          uri: uri,
          headers: headers,
          body: body,
          fallbackClient: _httpClient,
        ).timeout(MobileApi._requestTimeout);
      }
      final request = http.AbortableRequest('POST', uri, abortTrigger: abort)
        ..headers.addAll(headers)
        ..body = body;
      return _httpClient.send(request).then(http.Response.fromStream)
          .timeout(MobileApi._requestTimeout);
    });
    guardAccount();
    return _preparationResponse(response);
  }

  Future<Map<String, PreparationOutputNote>> savePreparationBatchNotes(
    Map<String, int> revisions,
    String? text, {
    PreparationNoteAudience? audience,
  }) {
    if (revisions.keys.any((id) => !id.startsWith('batch:') || id.length <= 6)) {
      throw ArgumentError('Batch tanlanmagan');
    }
    final input = switch (revisions.entries.toList(growable: false)) {
      [final batch] => {
          'scope': 'batch',
          'batch_id': batch.key,
          'expected_revision': batch.value,
        },
      final batches => {
          'scope': 'batches',
          'batches': [
            for (final batch in batches)
              {'batch_id': batch.key, 'expected_revision': batch.value},
          ],
        },
    };
    return _savePreparationOutputNotes(input, revisions, text, audience);
  }

  Future<Map<String, PreparationOutputNote>> savePreparationRollNotes(
    Map<String, int> revisions,
    String? text, {
    PreparationNoteAudience? audience,
  }) {
    return _savePreparationOutputNotes({
      'scope': 'rolls',
      'rolls': [
        for (final entry in revisions.entries)
          {'receipt_name': entry.key, 'expected_revision': entry.value},
      ],
    }, revisions, text, audience);
  }

  Future<Map<String, PreparationOutputNote>> _savePreparationOutputNotes(
    Map<String, Object> input,
    Map<String, int> revisions,
    String? draft,
    PreparationNoteAudience? audience,
  ) async {
    final expected = Map<String, int>.of(revisions);
    final text = draft?.trim();
    if ((text == null && audience == null) ||
        expected.isEmpty ||
        expected.length > preparationNoteSelectionLimit ||
        expected.entries.any((entry) =>
            entry.key.isEmpty ||
            entry.key != entry.key.trim() ||
            entry.key.length > 1024 ||
            entry.key.contains('\u0000') ||
            entry.value < 0 ||
            entry.value >= 9007199254740991) ||
        (text != null &&
            (text.runes.length > preparationNoteLimit || text.contains('\u0000')))) {
      throw ArgumentError('Eslatma yoki tanlangan rulonlar noto‘g‘ri');
    }
    final key = _preparationStorageKey();
    final scope = currentSessionReadScope();
    void requireCurrentAccount() {
      if (_preparationStorageKey() != key ||
          currentSessionReadScope() != scope) {
        throw StateError('Akkaunt o‘zgargan. Sahifani qayta oching');
      }
    }

    final response = await _sendAuthorized(() {
      requireCurrentAccount();
      return _patch(
        Uri.parse(
            '${MobileApi.baseUrl}/v1/mobile/preparation/production/notes'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          ...input,
          if (text != null) 'text': text,
          if (audience != null) 'audience': audience.toJson(),
        }),
      );
    });
    requireCurrentAccount();
    if (response.statusCode == 404 && response.body.trim().isEmpty) {
      throw const MobileApiException(
        code: 'preparation_output_api_unavailable',
        statusCode: 404,
        message: 'Eslatma saqlash uchun Mini RS ERP’ni yangilash kerak.',
      );
    }
    final raw = _preparationResponse(response)['notes'];
    if (raw is! Map || raw.length != expected.length) {
      throw const FormatException('Eslatmalar saqlangani tasdiqlanmadi');
    }
    final saved = <String, PreparationOutputNote>{};
    for (final entry in expected.entries) {
      final note = PreparationOutputNote.fromJson(raw[entry.key]);
      if (note == null ||
          (text != null && note.text != text) ||
          (audience != null && note.audience != audience) ||
          note.revision != entry.value + 1) {
        throw const FormatException('Eslatmalar saqlangani tasdiqlanmadi');
      }
      saved[entry.key] = note;
    }
    return saved;
  }

  Future<PreparationProductionOrderPage> preparationProductionOrder(
      String orderId,
      {int offset = 0}) async {
    if (orderId.trim().isEmpty || offset < 0) {
      throw ArgumentError('Buyurtma tanlanmagan');
    }
    final page =
        PreparationProductionOrderPage.fromJson(await _productionRead('order', {
      'order_id': orderId.trim(),
      'offset': '$offset',
      'limit': '30',
    }));
    if (page.order.id != orderId.trim()) {
      throw const FormatException('Buyurtma mos kelmadi');
    }
    return page;
  }

  Future<PreparationProductionBatchPage> preparationProductionBatch(
      String batchId,
      {int offset = 0}) async {
    if (batchId.trim().isEmpty || offset < 0) {
      throw ArgumentError('Ishlab chiqarish tanlanmagan');
    }
    final page =
        PreparationProductionBatchPage.fromJson(await _productionRead('batch', {
      'batch_id': batchId.trim(),
      'offset': '$offset',
      'limit': '50',
    }));
    if (page.batch.id != batchId.trim()) {
      throw const FormatException('Ishlab chiqarish mos kelmadi');
    }
    return page;
  }
}
