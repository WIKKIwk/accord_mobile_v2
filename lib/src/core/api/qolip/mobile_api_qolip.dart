part of '../mobile_api.dart';

final List<QolipLocationEntry> _testModeQolipLocations = [];
final Map<String, QolipProduct> _testModeQolipSpecs = {};
final List<QolipCheckoutEntry> _testModeQolipCheckouts = [];

String qolipErrorMessage(
  Object error, {
  String fallback = 'Amal bajarilmadi',
}) {
  final code = switch (error) {
    MobileApiException(code: final value) => value,
    _ => error.toString(),
  };
  return switch (code) {
    'insufficient_stock' => 'Joyda yetarli qolip qolmadi',
    'location_not_found' => 'Qolip joyi topilmadi',
    'location_invalid' => 'Joy noto‘g‘ri tanlangan',
    'checkout_not_found' => 'Berilgan qolip topilmadi',
    'checkout_not_returnable' => 'Bu qolipni qaytarib bo‘lmaydi',
    'worker_required' => 'Ishchini tanlang',
    'worker_not_found' => 'Ishchi topilmadi',
    'quantity_required' => 'Qolip soni noto‘g‘ri',
    'location_identity_mismatch' =>
      'Bu joyda boshqa qolip bor. Avval mavjud qolipni ko‘chiring',
    'forbidden' => 'Bu amal uchun ruxsat yo‘q',
    'unauthorized' => 'Sessiya tugagan. Qayta kiring',
    _ when code.contains('insufficient_stock') => 'Joyda yetarli qolip qolmadi',
    _ when code.contains('location_not_found') => 'Qolip joyi topilmadi',
    _ => fallback,
  };
}

String _testModeQolipLocationId({
  required String block,
  required String itemCode,
  required String qolipCode,
  required int size,
  required String rowLetter,
  int? columnNumber,
}) {
  return [
    block.trim(),
    itemCode.trim(),
    qolipCode.trim(),
    size,
    rowLetter.trim(),
    columnNumber ?? 0,
  ].join(':');
}

extension MobileApiQolip on MobileApi {
  Future<List<QolipBlock>> qolipBlocks() async {
    final result = await qolipBlocksData();
    return result.blocks;
  }

  Future<QolipBlocksResult> qolipBlocksData() async {
    if (await TestModeController.instance.isEnabled()) {
      return const QolipBlocksResult(
        warehouses: ['Qolip ombori'],
        blocks: [
          QolipBlock(name: 'A', warehouse: 'Qolip ombori'),
          QolipBlock(name: 'B', warehouse: 'Qolip ombori'),
        ],
      );
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/blocks'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip blocks failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return QolipBlocksResult.fromJson(data);
  }

  Future<QolipBlock> qolipCreateBlock({
    required String warehouse,
    required String block,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      return QolipBlock(name: block.trim(), warehouse: warehouse.trim());
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/blocks'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'warehouse': warehouse.trim(),
          'block': block.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip block create failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return QolipBlock.fromJson((data['block'] as Map).cast<String, dynamic>());
  }

  Future<List<QolipProduct>> qolipProducts({
    String query = '',
    int limit = 50,
    bool withQolipOnly = false,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalized = query.trim().toLowerCase();
      return TestModeDemoData.items
          .where((item) =>
              !withQolipOnly ||
              _testModeQolipSpecs.containsKey(item.code.trim().toLowerCase()))
          .where((item) {
            final spec = _testModeQolipSpecs[item.code.trim().toLowerCase()];
            return normalized.isEmpty ||
                item.name.toLowerCase().contains(normalized) ||
                item.code.toLowerCase().contains(normalized) ||
                (spec?.qolipCode.toLowerCase().contains(normalized) ?? false);
          })
          .take(limit)
          .map((item) {
            return _testModeQolipSpecs[item.code.trim().toLowerCase()] ??
                QolipProduct(
                  code: item.code,
                  name: item.name,
                  itemGroup: item.itemGroup,
                );
          })
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/products').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (limit > 0) 'limit': '$limit',
            if (withQolipOnly) 'with_qolip': 'true',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip products failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = data['products'];
    return [
      if (raw is List)
        for (final item in raw)
          QolipProduct.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<QolipProduct> qolipProductByQr(String qrPayload) async {
    final code = qrPayload.trim();
    if (code.isEmpty) {
      throw const MobileApiException(
        code: 'qolip_code_required',
        message: 'Qolip QR bo‘sh.',
      );
    }
    final products = await qolipProducts(
      query: code,
      limit: 20,
      withQolipOnly: true,
    );
    for (final product in products) {
      if (product.qolipCode.trim().toLowerCase() == code.toLowerCase()) {
        return product;
      }
    }
    throw const MobileApiException(
      code: 'qolip_code_not_found',
      message: 'Qolip QR topilmadi.',
    );
  }

  Future<List<QolipLocationEntry>> qolipLocations(String block) async {
    final normalized = block.trim().toLowerCase();
    if (await TestModeController.instance.isEnabled()) {
      return _testModeQolipLocations
          .where((item) => item.block.trim().toLowerCase() == normalized)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/locations').replace(
          queryParameters: {'block': block.trim()},
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip locations failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = data['locations'];
    return [
      if (raw is List)
        for (final item in raw)
          QolipLocationEntry.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<QolipLocationEntry> qolipSaveLocation({
    required QolipBlock block,
    QolipProduct? product,
    String qolipCode = '',
    int size = 0,
    required int quantity,
    String rowLetter = '',
    int? columnNumber,
  }) async {
    final effectiveQolipCode = qolipCode.trim().isNotEmpty
        ? qolipCode.trim()
        : product?.qolipCode.trim() ?? '';
    final effectiveSize = size > 0 ? size : product?.qolipSize ?? 0;
    final payload = {
      'block': block.name.trim(),
      'warehouse': block.warehouse.trim(),
      if (product != null) 'item_code': product.code.trim(),
      if (product != null) 'item_name': product.name.trim(),
      if (effectiveQolipCode.isNotEmpty) 'qolip_code': effectiveQolipCode,
      if (effectiveSize > 0) 'size': effectiveSize,
      'quantity': quantity,
      if (rowLetter.trim().isNotEmpty) 'row_letter': rowLetter.trim(),
      if (columnNumber != null) 'column_number': columnNumber,
    };
    if (await TestModeController.instance.isEnabled()) {
      final spec = product == null
          ? null
          : _testModeQolipSpecs[product.code.trim().toLowerCase()];
      final savedQolipCode = qolipCode.trim().isNotEmpty
          ? qolipCode.trim()
          : spec?.qolipCode.trim() ?? '';
      final savedSize = size > 0 ? size : spec?.qolipSize ?? 0;
      if (savedQolipCode.isEmpty || savedSize <= 0) {
        throw Exception('Qolip product spec required');
      }
      final locationLabel = rowLetter.trim().isEmpty || columnNumber == null
          ? ''
          : '${rowLetter.trim().toUpperCase()}$columnNumber';
      final entry = QolipLocationEntry(
        id: [
          block.name,
          product?.code ?? savedQolipCode,
          savedQolipCode,
          savedSize,
          rowLetter,
          columnNumber ?? 0,
        ].join(':'),
        block: block.name,
        warehouse: block.warehouse,
        itemCode: product?.code ?? savedQolipCode,
        itemName: product?.name ?? savedQolipCode,
        qolipCode: savedQolipCode,
        size: savedSize,
        quantity: quantity,
        rowLetter: rowLetter.trim().toUpperCase(),
        columnNumber: columnNumber,
        locationLabel: locationLabel,
      );
      final index =
          _testModeQolipLocations.indexWhere((item) => item.id == entry.id);
      if (index >= 0) {
        _testModeQolipLocations[index] = entry;
      } else {
        _testModeQolipLocations.add(entry);
      }
      return entry;
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/locations'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(payload),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip location save failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return QolipLocationEntry.fromJson(
      (data['location'] as Map).cast<String, dynamic>(),
    );
  }

  Future<QolipProduct> qolipSaveProductSpec({
    required QolipProduct product,
    required String qolipCode,
    required int size,
  }) async {
    final saved = QolipProduct(
      code: product.code.trim(),
      name: product.name.trim(),
      itemGroup: product.itemGroup.trim(),
      qolipCode: qolipCode.trim(),
      qolipSize: size,
      hasQolipSpec: true,
    );
    if (await TestModeController.instance.isEnabled()) {
      _testModeQolipSpecs[product.code.trim().toLowerCase()] = saved;
      return saved;
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/product-specs'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'item_code': product.code.trim(),
          'item_name': product.name.trim(),
          'item_group': product.itemGroup.trim(),
          'qolip_code': qolipCode.trim(),
          'size': size,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip product spec save failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return QolipProduct.fromJson(
      (data['product'] as Map).cast<String, dynamic>(),
    );
  }

  Future<List<QolipWorkerOption>> qolipWorkers({String query = ''}) async {
    if (await TestModeController.instance.isEnabled()) {
      return const [
        QolipWorkerOption(
          id: 'worker_test_1',
          name: 'Test ishchi',
          level: 'Master',
        ),
      ];
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/workers').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            'limit': '100',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _qolipApiException(
        response,
        fallbackCode: 'qolip_workers_failed',
        fallbackMessage: 'Qolipchilar yuklanmadi.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return [
      for (final item in (data['workers'] as List<dynamic>? ?? const []))
        QolipWorkerOption.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<QolipCheckoutEntry> qolipIssueCheckout({
    required String locationId,
    required int quantity,
    required String workerId,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final sourceIndex = _testModeQolipLocations.indexWhere(
        (item) => item.id == locationId.trim(),
      );
      if (sourceIndex < 0) {
        throw const MobileApiException(
          code: 'location_not_found',
          message: 'location_not_found',
        );
      }
      final source = _testModeQolipLocations[sourceIndex];
      if (quantity <= 0 || quantity > source.quantity) {
        throw const MobileApiException(
          code: 'insufficient_stock',
          message: 'insufficient_stock',
        );
      }
      final remaining = source.quantity - quantity;
      if (remaining > 0) {
        _testModeQolipLocations[sourceIndex] = QolipLocationEntry(
          id: source.id,
          block: source.block,
          warehouse: source.warehouse,
          itemCode: source.itemCode,
          itemName: source.itemName,
          qolipCode: source.qolipCode,
          size: source.size,
          quantity: remaining,
          rowLetter: source.rowLetter,
          columnNumber: source.columnNumber,
          locationLabel: source.locationLabel,
        );
      } else {
        _testModeQolipLocations.removeAt(sourceIndex);
      }
      final entry = QolipCheckoutEntry(
        id: 'checkout-test-${_testModeQolipCheckouts.length + 1}',
        locationId: locationId.trim(),
        block: source.block,
        warehouse: source.warehouse,
        itemCode: source.itemCode,
        itemName: source.itemName,
        qolipCode: source.qolipCode,
        size: source.size,
        quantity: quantity,
        rowLetter: source.rowLetter,
        columnNumber: source.columnNumber,
        locationLabel: source.locationLabel,
        issuedToName: 'Test ishchi',
        status: 'open',
      );
      _testModeQolipCheckouts.insert(0, entry);
      return entry;
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/checkouts'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'location_id': locationId.trim(),
          'quantity': quantity,
          'worker_id': workerId.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _qolipApiException(
        response,
        fallbackCode: 'qolip_checkout_failed',
        fallbackMessage: 'Qolip olish amalga oshmadi.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return QolipCheckoutEntry.fromJson(
      (data['checkout'] as Map).cast<String, dynamic>(),
    );
  }

  Future<List<QolipCheckoutEntry>> qolipCheckouts({
    String block = '',
    String status = 'open',
    int limit = 100,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalizedBlock = block.trim().toLowerCase();
      final normalizedStatus = status.trim().toLowerCase();
      return _testModeQolipCheckouts
          .where(
            (item) =>
                normalizedStatus.isEmpty ||
                item.status.trim().toLowerCase() == normalizedStatus,
          )
          .where(
            (item) =>
                normalizedBlock.isEmpty ||
                item.block.trim().toLowerCase() == normalizedBlock,
          )
          .take(limit)
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/checkouts').replace(
          queryParameters: {
            if (block.trim().isNotEmpty) 'block': block.trim(),
            if (status.trim().isNotEmpty) 'status': status.trim(),
            'limit': '$limit',
          },
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _qolipApiException(
        response,
        fallbackCode: 'qolip_checkouts_failed',
        fallbackMessage: 'Qarz daftari yuklanmadi.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return [
      for (final item in (data['checkouts'] as List<dynamic>? ?? const []))
        QolipCheckoutEntry.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<QolipCheckoutEntry> qolipReturnCheckout(
    String checkoutId, {
    String rowLetter = '',
    int? columnNumber,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeQolipCheckouts.indexWhere(
        (item) => item.id == checkoutId.trim(),
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'checkout_not_found',
          message: 'checkout_not_found',
        );
      }
      final current = _testModeQolipCheckouts[index];
      if (!current.isOpen) {
        throw const MobileApiException(
          code: 'checkout_not_returnable',
          message: 'checkout_not_returnable',
        );
      }
      final cleanRow = rowLetter.trim().isEmpty
          ? current.rowLetter.trim().toUpperCase()
          : rowLetter.trim().toUpperCase();
      final cleanColumn = columnNumber ?? current.columnNumber;
      if (cleanRow.isEmpty || cleanColumn == null) {
        throw const MobileApiException(
          code: 'location_invalid',
          message: 'location_invalid',
        );
      }
      final itemCode =
          current.itemCode.isEmpty ? current.qolipCode : current.itemCode;
      final targetId = _testModeQolipLocationId(
        block: current.block,
        itemCode: itemCode,
        qolipCode: current.qolipCode,
        size: current.size,
        rowLetter: cleanRow,
        columnNumber: cleanColumn,
      );
      final locIndex =
          _testModeQolipLocations.indexWhere((item) => item.id == targetId);
      if (locIndex >= 0) {
        final loc = _testModeQolipLocations[locIndex];
        _testModeQolipLocations[locIndex] = QolipLocationEntry(
          id: loc.id,
          block: loc.block,
          warehouse: loc.warehouse,
          itemCode: loc.itemCode,
          itemName: loc.itemName,
          qolipCode: loc.qolipCode,
          size: loc.size,
          quantity: loc.quantity + current.quantity,
          rowLetter: loc.rowLetter,
          columnNumber: loc.columnNumber,
          locationLabel: loc.locationLabel,
        );
      } else {
        _testModeQolipLocations.add(
          QolipLocationEntry(
            id: targetId,
            block: current.block,
            warehouse: current.warehouse,
            itemCode: itemCode,
            itemName: current.itemName,
            qolipCode: current.qolipCode,
            size: current.size,
            quantity: current.quantity,
            rowLetter: cleanRow,
            columnNumber: cleanColumn,
            locationLabel: '$cleanRow$cleanColumn',
          ),
        );
      }
      final returned = QolipCheckoutEntry(
        id: current.id,
        locationId: current.locationId,
        block: current.block,
        warehouse: current.warehouse,
        itemCode: current.itemCode,
        itemName: current.itemName,
        qolipCode: current.qolipCode,
        size: current.size,
        quantity: current.quantity,
        rowLetter: current.rowLetter,
        columnNumber: current.columnNumber,
        locationLabel: current.locationLabel,
        issuedToName: current.issuedToName,
        status: 'returned',
        issuedAt: current.issuedAt,
      );
      _testModeQolipCheckouts[index] = returned;
      return returned;
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/checkouts/return'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'checkout_id': checkoutId.trim(),
          if (rowLetter.trim().isNotEmpty)
            'row_letter': rowLetter.trim().toUpperCase(),
          if (columnNumber != null) 'column_number': columnNumber,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _qolipApiException(
        response,
        fallbackCode: 'qolip_checkout_return_failed',
        fallbackMessage: 'Qolip qaytarilmadi.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return QolipCheckoutEntry.fromJson(
      (data['checkout'] as Map).cast<String, dynamic>(),
    );
  }

  Future<QolipLocationEntry> qolipMoveLocation({
    required String locationId,
    required int quantity,
    required String rowLetter,
    required int columnNumber,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeQolipLocations.indexWhere(
        (item) => item.id == locationId.trim(),
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'location_not_found',
          message: 'location_not_found',
        );
      }
      final source = _testModeQolipLocations[index];
      if (quantity <= 0 || quantity > source.quantity) {
        throw const MobileApiException(
          code: 'insufficient_stock',
          message: 'insufficient_stock',
        );
      }
      final cleanRow = rowLetter.trim().toUpperCase();
      final targetId = _testModeQolipLocationId(
        block: source.block,
        itemCode: source.itemCode,
        qolipCode: source.qolipCode,
        size: source.size,
        rowLetter: cleanRow,
        columnNumber: columnNumber,
      );
      if (targetId == source.id) {
        throw const MobileApiException(
          code: 'location_invalid',
          message: 'location_invalid',
        );
      }
      final remaining = source.quantity - quantity;
      if (remaining > 0) {
        _testModeQolipLocations[index] = QolipLocationEntry(
          id: source.id,
          block: source.block,
          warehouse: source.warehouse,
          itemCode: source.itemCode,
          itemName: source.itemName,
          qolipCode: source.qolipCode,
          size: source.size,
          quantity: remaining,
          rowLetter: source.rowLetter,
          columnNumber: source.columnNumber,
          locationLabel: source.locationLabel,
        );
      } else {
        _testModeQolipLocations.removeAt(index);
      }
      final targetIndex =
          _testModeQolipLocations.indexWhere((item) => item.id == targetId);
      if (targetIndex >= 0) {
        final target = _testModeQolipLocations[targetIndex];
        final merged = QolipLocationEntry(
          id: target.id,
          block: target.block,
          warehouse: target.warehouse,
          itemCode: target.itemCode,
          itemName: target.itemName,
          qolipCode: target.qolipCode,
          size: target.size,
          quantity: target.quantity + quantity,
          rowLetter: target.rowLetter,
          columnNumber: target.columnNumber,
          locationLabel: target.locationLabel,
        );
        _testModeQolipLocations[targetIndex] = merged;
        return merged;
      }
      final created = QolipLocationEntry(
        id: targetId,
        block: source.block,
        warehouse: source.warehouse,
        itemCode: source.itemCode,
        itemName: source.itemName,
        qolipCode: source.qolipCode,
        size: source.size,
        quantity: quantity,
        rowLetter: cleanRow,
        columnNumber: columnNumber,
        locationLabel: '$cleanRow$columnNumber',
      );
      _testModeQolipLocations.add(created);
      return created;
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/locations/move'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'location_id': locationId.trim(),
          'quantity': quantity,
          'row_letter': rowLetter.trim().toUpperCase(),
          'column_number': columnNumber,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _qolipApiException(
        response,
        fallbackCode: 'qolip_location_move_failed',
        fallbackMessage: 'Ko‘chirish amalga oshmadi.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return QolipLocationEntry.fromJson(
      (data['location'] as Map).cast<String, dynamic>(),
    );
  }

  Future<QolipCellQr> qolipPrintCellQr({
    required QolipBlock block,
    required String rowLetter,
    required int columnNumber,
    required String driverUrl,
    String printer = '',
    String printMode = '',
  }) async {
    final cleanRow = rowLetter.trim().toUpperCase();
    if (await TestModeController.instance.isEnabled()) {
      final id = [
        'qolip-cell',
        block.warehouse,
        block.name,
        cleanRow,
        columnNumber,
      ].join(':');
      return QolipCellQr(
        id: id,
        block: block.name,
        warehouse: block.warehouse,
        rowLetter: cleanRow,
        columnNumber: columnNumber,
        locationLabel: '$cleanRow$columnNumber',
        qrPayload: _testModeQolipCellQrPayload(id),
      );
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/cell-qr/print'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'block': block.name.trim(),
          'warehouse': block.warehouse.trim(),
          'row_letter': cleanRow,
          'column_number': columnNumber,
          'driver_url': driverUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
          if (printer.trim().isNotEmpty) 'printer': printer.trim(),
          if (printMode.trim().isNotEmpty) 'print_mode': printMode.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip cell QR print failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return QolipCellQr.fromJson(
      (data['cell_qr'] as Map).cast<String, dynamic>(),
    );
  }

  Future<QolipCodeQr> qolipPrintCodeQr({
    required String qolipCode,
    required String driverUrl,
    String printer = '',
    String printMode = '',
  }) async {
    final code = qolipCode.trim();
    if (await TestModeController.instance.isEnabled()) {
      final spec = _testModeQolipSpecs.values
          .where((item) =>
              item.qolipCode.trim().toLowerCase() == code.toLowerCase())
          .cast<QolipProduct?>()
          .firstWhere((item) => item != null, orElse: () => null);
      if (spec == null) {
        throw Exception('Qolip code not found');
      }
      return QolipCodeQr(
        qolipCode: spec.qolipCode,
        qrPayload: spec.qolipCode,
        itemCode: spec.code,
        itemName: spec.name,
        itemGroup: spec.itemGroup,
        size: spec.qolipSize,
      );
    }
    final response = await _sendAuthorized(
      () => http.post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/code-qr/print'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'qolip_code': code,
          'driver_url': driverUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
          if (printer.trim().isNotEmpty) 'printer': printer.trim(),
          if (printMode.trim().isNotEmpty) 'print_mode': printMode.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip code QR print failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return QolipCodeQr.fromJson(
      (data['qolip_qr'] as Map).cast<String, dynamic>(),
    );
  }

  Future<QolipCellQr> qolipCellQrLookup(String qrPayload) async {
    final qr = qrPayload.trim();
    if (qr.isEmpty) {
      throw const MobileApiException(
        code: 'qolip_cell_qr_required',
        message: 'Yachayka QR bo‘sh.',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final blocks = await qolipBlocks();
      for (final block in blocks) {
        for (var rowUnit = 'A'.codeUnitAt(0);
            rowUnit <= 'Z'.codeUnitAt(0);
            rowUnit++) {
          for (var column = 1; column <= 9; column++) {
            final row = String.fromCharCode(rowUnit);
            final id = [
              'qolip-cell',
              block.warehouse,
              block.name,
              row,
              column,
            ].join(':');
            final payload = _testModeQolipCellQrPayload(id);
            if (payload.toLowerCase() == qr.toLowerCase()) {
              return QolipCellQr(
                id: id,
                block: block.name,
                warehouse: block.warehouse,
                rowLetter: row,
                columnNumber: column,
                locationLabel: '$row$column',
                qrPayload: payload,
              );
            }
          }
        }
      }
      throw const MobileApiException(
        code: 'qolip_cell_qr_not_found',
        message: 'Yachayka QR topilmadi.',
      );
    }

    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/cell-qr').replace(
          queryParameters: {'qr': qr},
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _qolipCellQrException(response);
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return QolipCellQr.fromJson(
      (data['cell_qr'] as Map).cast<String, dynamic>(),
    );
  }
}

MobileApiException _qolipCellQrException(http.Response response) {
  String code = 'qolip_cell_qr_lookup_failed';
  String message = 'Yachayka QR tekshirishda xatolik.';
  try {
    final data = jsonDecode(response.body);
    if (data is Map) {
      code = data['error']?.toString() ?? data['code']?.toString() ?? code;
      final serverMessage = data['message']?.toString() ?? '';
      if (serverMessage.trim().isNotEmpty) {
        message = serverMessage.trim();
      } else if (code == 'cell_qr_not_found') {
        message = 'Bu QR yachayka uchun topilmadi.';
      } else if (code == 'qr_required') {
        message = 'Yachayka QR bo‘sh.';
      }
    }
  } catch (_) {
    // Keep the user-facing fallback above.
  }
  return MobileApiException(
    code: code,
    message: message,
    statusCode: response.statusCode,
  );
}

MobileApiException _qolipApiException(
  http.Response response, {
  required String fallbackCode,
  required String fallbackMessage,
}) {
  var code = fallbackCode;
  var message = fallbackMessage;
  try {
    final data = jsonDecode(response.body);
    if (data is Map) {
      code = data['error']?.toString() ?? data['code']?.toString() ?? code;
      final serverMessage = data['message']?.toString() ?? '';
      if (serverMessage.trim().isNotEmpty) {
        message = serverMessage.trim();
      }
    }
  } catch (_) {
    // Keep fallback values.
  }
  return MobileApiException(
    code: code,
    message: message,
    statusCode: response.statusCode,
  );
}

String _testModeQolipCellQrPayload(String value) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = BigInt.parse('ffffffffffffffff', radix: 16);
  for (final unit in value.trim().codeUnits) {
    hash = hash ^ BigInt.from(unit);
    hash = (hash * prime) & mask;
  }
  final checksum = hash & BigInt.from(0xffff);
  return '4002${hash.toRadixString(16).padLeft(16, '0').toUpperCase()}'
      '${checksum.toRadixString(16).padLeft(4, '0').toUpperCase()}';
}
