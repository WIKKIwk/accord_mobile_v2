part of '../mobile_api.dart';

final List<QolipLocationEntry> _testModeQolipLocations = [];
final Map<String, QolipProduct> _testModeQolipSpecs = {};
final List<QolipCheckoutEntry> _testModeQolipCheckouts = [];
final List<QolipBlock> _testModeQolipBlocks = [
  const QolipBlock(name: 'A', warehouse: 'Qolip ombori'),
  const QolipBlock(name: 'B', warehouse: 'Qolip ombori'),
];

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
    'qolip_in_use' => 'Qolip joylashtirilgan yoki ishchiga berilgan',
    'qolip_code_conflict' => 'Bu qolip code allaqachon mavjud',
    'block_in_use' =>
      'Blokda qolip yoki qaytarilmagan berish bor. Uni o‘chirib bo‘lmaydi',
    'block_exists' => 'Bu nomdagi blok allaqachon mavjud',
    'block_not_found' => 'Blok topilmadi',
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
      return QolipBlocksResult(
        warehouses: ['Qolip ombori'],
        blocks: List<QolipBlock>.unmodifiable(_testModeQolipBlocks),
        supportsCrossBlockMove: true,
      );
    }
    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/blocks'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip blocks failed');
    }
    final data = await decodeJsonMapPayload(response.body);
    return QolipBlocksResult.fromJson(data);
  }

  Future<QolipBlock> qolipCreateBlock({
    required String warehouse,
    required String block,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final saved = QolipBlock(name: block.trim(), warehouse: warehouse.trim());
      _testModeQolipBlocks.add(saved);
      return saved;
    }
    final response = await _sendAuthorized(
      () => _post(
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
    final data = await decodeJsonMapPayload(response.body);
    return QolipBlock.fromJson((data['block'] as Map).cast<String, dynamic>());
  }

  Future<QolipBlock> qolipUpdateBlock({
    required QolipBlock block,
    required String newName,
  }) async {
    final updatedName = newName.trim();
    if (updatedName.isEmpty) {
      throw const MobileApiException(
        code: 'block_required',
        message: 'block_required',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      final index = _testModeQolipBlocks.indexWhere(
        (item) =>
            item.name.trim().toLowerCase() == block.name.trim().toLowerCase(),
      );
      if (index < 0) {
        throw const MobileApiException(
          code: 'block_not_found',
          message: 'block_not_found',
        );
      }
      if (_testModeQolipBlocks.any(
        (item) =>
            item.name.trim().toLowerCase() == updatedName.toLowerCase() &&
            item.name.trim().toLowerCase() != block.name.trim().toLowerCase(),
      )) {
        throw const MobileApiException(
          code: 'block_exists',
          message: 'block_exists',
        );
      }
      final saved = QolipBlock(
        name: updatedName,
        warehouse: block.warehouse.trim(),
      );
      _testModeQolipBlocks[index] = saved;
      for (var locationIndex = 0;
          locationIndex < _testModeQolipLocations.length;
          locationIndex++) {
        final location = _testModeQolipLocations[locationIndex];
        if (location.block.trim().toLowerCase() !=
            block.name.trim().toLowerCase()) {
          continue;
        }
        _testModeQolipLocations[locationIndex] = QolipLocationEntry(
          id: location.id,
          block: updatedName,
          warehouse: saved.warehouse,
          itemCode: location.itemCode,
          itemName: location.itemName,
          qolipCode: location.qolipCode,
          size: location.size,
          quantity: location.quantity,
          rowLetter: location.rowLetter,
          columnNumber: location.columnNumber,
          locationLabel: location.locationLabel,
        );
      }
      for (var checkoutIndex = 0;
          checkoutIndex < _testModeQolipCheckouts.length;
          checkoutIndex++) {
        final checkout = _testModeQolipCheckouts[checkoutIndex];
        if (checkout.block.trim().toLowerCase() !=
            block.name.trim().toLowerCase()) {
          continue;
        }
        _testModeQolipCheckouts[checkoutIndex] = QolipCheckoutEntry(
          id: checkout.id,
          locationId: checkout.locationId,
          block: updatedName,
          warehouse: saved.warehouse,
          itemCode: checkout.itemCode,
          itemName: checkout.itemName,
          qolipCode: checkout.qolipCode,
          size: checkout.size,
          quantity: checkout.quantity,
          rowLetter: checkout.rowLetter,
          columnNumber: checkout.columnNumber,
          locationLabel: checkout.locationLabel,
          issuedToName: checkout.issuedToName,
          status: checkout.status,
          issuedAt: checkout.issuedAt,
        );
      }
      return saved;
    }
    final response = await _sendAuthorized(
      () => _put(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/blocks'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'warehouse': block.warehouse.trim(),
          'block': block.name.trim(),
          'new_block': updatedName,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _qolipApiException(
        response,
        fallbackCode: 'qolip_block_update_failed',
        fallbackMessage: 'Blok tahrirlanmadi.',
      );
    }
    final data = await decodeJsonMapPayload(response.body);
    return QolipBlock.fromJson((data['block'] as Map).cast<String, dynamic>());
  }

  Future<void> qolipDeleteBlock(QolipBlock block) async {
    if (await TestModeController.instance.isEnabled()) {
      _testModeQolipBlocks.removeWhere(
        (item) =>
            item.name.trim().toLowerCase() == block.name.trim().toLowerCase(),
      );
      return;
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/blocks'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'warehouse': block.warehouse.trim(),
          'block': block.name.trim(),
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw _qolipApiException(
        response,
        fallbackCode: 'qolip_block_delete_failed',
        fallbackMessage: 'Blok o‘chirilmadi.',
      );
    }
  }

  Future<List<QolipProduct>> qolipProducts({
    String query = '',
    int limit = 50,
    bool withQolipOnly = false,
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalized = query.trim().toLowerCase();
      final products = <QolipProduct>[];
      for (final item in TestModeDemoData.items) {
        final specs = _testModeQolipSpecs.values
            .where(
              (spec) =>
                  spec.code.trim().toLowerCase() ==
                  item.code.trim().toLowerCase(),
            )
            .toList(growable: false);
        if (withQolipOnly && specs.isEmpty) {
          continue;
        }
        if (specs.isEmpty) {
          if (normalized.isEmpty ||
              item.name.toLowerCase().contains(normalized) ||
              item.code.toLowerCase().contains(normalized) ||
              item.customerNames.any(
                (customer) => customer.toLowerCase().contains(normalized),
              )) {
            products.add(
              QolipProduct(
                code: item.code,
                name: item.name,
                itemGroup: item.itemGroup,
                customerNames: item.customerNames,
              ),
            );
          }
          continue;
        }
        for (final spec in specs) {
          if (normalized.isNotEmpty &&
              !item.name.toLowerCase().contains(normalized) &&
              !item.code.toLowerCase().contains(normalized) &&
              !item.customerNames.any(
                (customer) => customer.toLowerCase().contains(normalized),
              ) &&
              !spec.qolipCode.toLowerCase().contains(normalized)) {
            continue;
          }
          final inUse = _testModeQolipCheckouts.any(
            (checkout) =>
                checkout.isOpen &&
                checkout.qolipCode.trim().toLowerCase() ==
                    spec.qolipCode.trim().toLowerCase(),
          );
          products.add(
            QolipProduct(
              code: spec.code,
              name: spec.name,
              itemGroup: spec.itemGroup,
              customerNames: item.customerNames,
              qolipCode: spec.qolipCode,
              qolipSize: spec.qolipSize,
              hasQolipSpec: spec.hasQolipSpec,
              isInUse: inUse,
            ),
          );
          if (products.length >= limit) {
            return products;
          }
        }
      }
      final seenQolipCodes = products
          .map((product) => product.qolipCode.trim().toLowerCase())
          .where((code) => code.isNotEmpty)
          .toSet();
      for (final spec in _testModeQolipSpecs.values) {
        final qolipKey = spec.qolipCode.trim().toLowerCase();
        if (qolipKey.isEmpty || !seenQolipCodes.add(qolipKey)) {
          continue;
        }
        if (normalized.isNotEmpty &&
            !spec.name.toLowerCase().contains(normalized) &&
            !spec.code.toLowerCase().contains(normalized) &&
            !spec.qolipCode.toLowerCase().contains(normalized) &&
            !spec.customerNames.any(
              (customer) => customer.toLowerCase().contains(normalized),
            )) {
          continue;
        }
        products.add(
          QolipProduct(
            code: spec.code,
            name: spec.name,
            itemGroup: spec.itemGroup,
            customerNames: spec.customerNames,
            qolipCode: spec.qolipCode,
            qolipSize: spec.qolipSize,
            hasQolipSpec: spec.hasQolipSpec,
            isInUse: _testModeQolipCheckouts.any(
              (checkout) =>
                  checkout.isOpen &&
                  checkout.qolipCode.trim().toLowerCase() == qolipKey,
            ),
          ),
        );
      }
      for (final location in _testModeQolipLocations) {
        final qolipKey = location.qolipCode.trim().toLowerCase();
        if (qolipKey.isEmpty || !seenQolipCodes.add(qolipKey)) {
          continue;
        }
        QolipProduct? catalogProduct;
        for (final item in TestModeDemoData.items) {
          if (item.code.trim().toLowerCase() ==
              location.itemCode.trim().toLowerCase()) {
            catalogProduct = QolipProduct(
              code: item.code,
              name: item.name,
              itemGroup: item.itemGroup,
              customerNames: item.customerNames,
            );
            break;
          }
        }
        final product = QolipProduct(
          code: location.itemCode,
          name: catalogProduct?.name ?? location.itemName,
          itemGroup: catalogProduct?.itemGroup ?? '',
          customerNames: catalogProduct?.customerNames ?? const [],
          qolipCode: location.qolipCode,
          qolipSize: location.size,
          hasQolipSpec: true,
          isInUse: _testModeQolipCheckouts.any(
            (checkout) =>
                checkout.isOpen &&
                checkout.qolipCode.trim().toLowerCase() == qolipKey,
          ),
        );
        if (normalized.isEmpty ||
            product.name.toLowerCase().contains(normalized) ||
            product.code.toLowerCase().contains(normalized) ||
            product.qolipCode.toLowerCase().contains(normalized) ||
            product.customerNames.any(
              (customer) => customer.toLowerCase().contains(normalized),
            )) {
          products.add(product);
        }
      }
      return products.take(limit).toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => _get(
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
    final data = await decodeJsonMapPayload(response.body);
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
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/locations').replace(
          queryParameters: {'block': block.trim()},
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip locations failed');
    }
    final data = await decodeJsonMapPayload(response.body);
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
      QolipProduct? spec;
      for (final item in _testModeQolipSpecs.values) {
        final matches = effectiveQolipCode.isNotEmpty
            ? item.qolipCode.trim().toLowerCase() ==
                effectiveQolipCode.toLowerCase()
            : product != null &&
                item.code.trim().toLowerCase() ==
                    product.code.trim().toLowerCase();
        if (matches) {
          spec = item;
          break;
        }
      }
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
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/locations'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode(payload),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip location save failed');
    }
    final data = await decodeJsonMapPayload(response.body);
    return QolipLocationEntry.fromJson(
      (data['location'] as Map).cast<String, dynamic>(),
    );
  }

  Future<QolipProduct> qolipSaveProductSpec({
    required QolipProduct product,
    required String qolipCode,
    required int size,
    String? previousQolipCode,
  }) async {
    final saved = QolipProduct(
      code: product.code.trim(),
      name: product.name.trim(),
      itemGroup: product.itemGroup.trim(),
      customerNames: product.customerNames,
      qolipCode: qolipCode.trim(),
      qolipSize: size,
      hasQolipSpec: true,
    );
    if (await TestModeController.instance.isEnabled()) {
      final previous = previousQolipCode?.trim().toLowerCase() ?? '';
      final next = saved.qolipCode.trim().toLowerCase();
      if (previous.isNotEmpty && previous != next) {
        if (_testModeQolipCheckouts.any(
              (checkout) =>
                  checkout.isOpen &&
                  checkout.qolipCode.trim().toLowerCase() == previous,
            ) ||
            _testModeQolipLocations.any(
              (location) => location.qolipCode.trim().toLowerCase() == previous,
            )) {
          throw const MobileApiException(
            code: 'qolip_in_use',
            message: 'qolip_in_use',
          );
        }
        if (_testModeQolipSpecs.containsKey(next)) {
          throw const MobileApiException(
            code: 'qolip_code_conflict',
            message: 'qolip_code_conflict',
          );
        }
        _testModeQolipSpecs.remove(previous);
      }
      _testModeQolipSpecs[saved.qolipCode.trim().toLowerCase()] = saved;
      return saved;
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/product-specs'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'item_code': product.code.trim(),
          'item_name': product.name.trim(),
          'item_group': product.itemGroup.trim(),
          'qolip_code': qolipCode.trim(),
          if (previousQolipCode != null && previousQolipCode.trim().isNotEmpty)
            'previous_qolip_code': previousQolipCode.trim(),
          'size': size,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip product spec save failed');
    }
    final data = await decodeJsonMapPayload(response.body);
    return QolipProduct.fromJson(
      (data['product'] as Map).cast<String, dynamic>(),
    );
  }

  Future<int> qolipDeleteProductSpecs(List<String> qolipCodes) async {
    final normalized = qolipCodes
        .map((code) => code.trim())
        .where((code) => code.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (normalized.isEmpty) {
      return 0;
    }
    if (await TestModeController.instance.isEnabled()) {
      final keys = normalized.map((code) => code.toLowerCase()).toSet();
      if (_testModeQolipCheckouts.any(
        (checkout) =>
            checkout.isOpen &&
            keys.contains(checkout.qolipCode.trim().toLowerCase()),
      )) {
        throw const MobileApiException(
          code: 'qolip_in_use',
          message: 'qolip_in_use',
        );
      }
      final existingCodes = <String>{
        for (final product in _testModeQolipSpecs.values)
          if (keys.contains(product.qolipCode.trim().toLowerCase()))
            product.qolipCode.trim().toLowerCase(),
        for (final location in _testModeQolipLocations)
          if (keys.contains(location.qolipCode.trim().toLowerCase()))
            location.qolipCode.trim().toLowerCase(),
      };
      _testModeQolipSpecs.removeWhere(
        (_, product) => keys.contains(product.qolipCode.trim().toLowerCase()),
      );
      _testModeQolipLocations.removeWhere(
        (location) => keys.contains(location.qolipCode.trim().toLowerCase()),
      );
      return existingCodes.length;
    }
    final response = await _sendAuthorized(
      () => _delete(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/product-specs'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'qolip_codes': normalized}),
      ),
    );
    if (response.statusCode != 200) {
      throw _qolipApiException(
        response,
        fallbackCode: 'qolip_delete_failed',
        fallbackMessage: 'Qoliplar o‘chirilmadi.',
      );
    }
    final data = await decodeJsonMapPayload(response.body);
    return (data['deleted_count'] as num?)?.toInt() ?? 0;
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
      () => _get(
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
    final data = await decodeJsonMapPayload(response.body);
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
      () => _post(
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
    final data = await decodeJsonMapPayload(response.body);
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
      () => _get(
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
    final data = await decodeJsonMapPayload(response.body);
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
      () => _post(
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
    final data = await decodeJsonMapPayload(response.body);
    return QolipCheckoutEntry.fromJson(
      (data['checkout'] as Map).cast<String, dynamic>(),
    );
  }

  Future<QolipLocationEntry> qolipMoveLocation({
    required String locationId,
    required QolipBlock targetBlock,
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
      final targetBlockName = targetBlock.name.trim();
      final targetWarehouse = targetBlock.warehouse.trim();
      final targetId = _testModeQolipLocationId(
        block: targetBlockName,
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
        block: targetBlockName,
        warehouse: targetWarehouse,
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
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/locations/move'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'location_id': locationId.trim(),
          'block': targetBlock.name.trim(),
          'warehouse': targetBlock.warehouse.trim(),
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
    final data = await decodeJsonMapPayload(response.body);
    return QolipLocationEntry.fromJson(
      (data['location'] as Map).cast<String, dynamic>(),
    );
  }

  Future<QolipCellQrPrintResult> qolipPrintCellQr({
    required QolipBlock block,
    required String rowLetter,
    required int columnNumber,
    required String driverUrl,
    String printer = '',
    String printMode = '',
    PrintTransport printTransport = PrintTransport.wifi,
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
      final cellQr = QolipCellQr(
        id: id,
        block: block.name,
        warehouse: block.warehouse,
        rowLetter: cleanRow,
        columnNumber: columnNumber,
        locationLabel: '$cleanRow$columnNumber',
        qrPayload: _testModeQolipCellQrPayload(id),
      );
      return QolipCellQrPrintResult(
        cellQr: cellQr,
        printJob: _qolipCellUsbPrintJob(cellQr),
      );
    }
    final response = await _sendAuthorized(
      () => _post(
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
          if (printTransport.isLocal)
            'print_transport': printTransport.clientApiValue,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip cell QR print failed');
    }
    final data = await decodeJsonMapPayload(response.body);
    final cellQr = QolipCellQr.fromJson(
      (data['cell_qr'] as Map).cast<String, dynamic>(),
    );
    final print = (data['print'] as Map?)?.cast<String, dynamic>();
    final cellLabel = _qolipCellLabel(cellQr);
    return QolipCellQrPrintResult(
      cellQr: cellQr,
      printJob: print == null
          ? _qolipCellUsbPrintJob(cellQr)
          : UsbRpsPrintRequest.fromPrintJson(print).forQolipCell(cellLabel),
    );
  }

  Future<QolipCodeQrPrintResult> qolipPrintCodeQr({
    required String qolipCode,
    required String driverUrl,
    String printer = '',
    String printMode = '',
    PrintTransport printTransport = PrintTransport.wifi,
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
      final qolipQr = QolipCodeQr(
        qolipCode: spec.qolipCode,
        qrPayload: spec.qolipCode,
        itemCode: spec.code,
        itemName: spec.name,
        itemGroup: spec.itemGroup,
        size: spec.qolipSize,
      );
      return QolipCodeQrPrintResult(
        qolipQr: qolipQr,
        printJob: _qolipCodeUsbPrintJob(qolipQr),
      );
    }
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/code-qr/print'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'qolip_code': code,
          'driver_url': driverUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
          if (printer.trim().isNotEmpty) 'printer': printer.trim(),
          if (printMode.trim().isNotEmpty) 'print_mode': printMode.trim(),
          if (printTransport.isLocal)
            'print_transport': printTransport.clientApiValue,
        }),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Qolip code QR print failed');
    }
    final data = await decodeJsonMapPayload(response.body);
    final qolipQr = QolipCodeQr.fromJson(
      (data['qolip_qr'] as Map).cast<String, dynamic>(),
    );
    final print = (data['print'] as Map?)?.cast<String, dynamic>();
    final printJob = print == null
        ? _qolipCodeUsbPrintJob(qolipQr)
        : UsbRpsPrintRequest.fromPrintJson(print);
    return QolipCodeQrPrintResult(
      qolipQr: qolipQr,
      printJob: printJob.forQolipCode(
        name: qolipQr.itemName,
        code: qolipQr.qolipCode,
        payload: qolipQr.qrPayload,
      ),
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
          for (var column = 1; column <= 13; column++) {
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
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/cell-qr').replace(
          queryParameters: {'qr': qr},
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _qolipCellQrException(response);
    }
    final data = await decodeJsonMapPayload(response.body);
    return QolipCellQr.fromJson(
      (data['cell_qr'] as Map).cast<String, dynamic>(),
    );
  }

  Future<QolipScanResult> qolipScanQr(String qrPayload) async {
    final qr = qrPayload.trim();
    if (qr.isEmpty) {
      throw const MobileApiException(
        code: 'qolip_qr_required',
        message: 'QR bo‘sh.',
      );
    }
    if (await TestModeController.instance.isEnabled()) {
      try {
        final cell = await qolipCellQrLookup(qr);
        return QolipScanResult.fromJson({
          'kind': 'cell',
          'cell_qr': {
            'id': cell.id,
            'block': cell.block,
            'warehouse': cell.warehouse,
            'row_letter': cell.rowLetter,
            'column_number': cell.columnNumber,
            'location_label': cell.locationLabel,
            'qr_payload': cell.qrPayload,
          },
        });
      } on MobileApiException catch (error) {
        if (error.code != 'qolip_cell_qr_not_found') {
          rethrow;
        }
      }
      final product = await qolipProductByQr(qr);
      QolipLocationEntry? location;
      for (final block in await qolipBlocks()) {
        for (final item in await qolipLocations(block.name)) {
          if (item.qolipCode.trim().toLowerCase() == qr.toLowerCase()) {
            location = item;
            break;
          }
        }
        if (location != null) {
          break;
        }
      }
      return QolipScanResult.fromJson({
        'kind': 'qolip',
        'product': {
          'code': product.code,
          'name': product.name,
          'item_group': product.itemGroup,
          'qolip_code': product.qolipCode,
          'size': product.qolipSize,
          'has_qolip_spec': product.hasQolipSpec,
        },
        if (location != null)
          'location': {
            'id': location.id,
            'block': location.block,
            'warehouse': location.warehouse,
            'item_code': location.itemCode,
            'item_name': location.itemName,
            'qolip_code': location.qolipCode,
            'size': location.size,
            'quantity': location.quantity,
            'row_letter': location.rowLetter,
            'column_number': location.columnNumber,
            'location_label': location.locationLabel,
          },
      });
    }

    final response = await _sendAuthorized(
      () => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/scan').replace(
          queryParameters: {'qr': qr},
        ),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw _qolipApiException(
        response,
        fallbackCode: 'qolip_scan_failed',
        fallbackMessage: 'QR bo‘yicha qolip yoki yacheyka topilmadi.',
      );
    }
    return QolipScanResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}

class QolipCellQrPrintResult {
  const QolipCellQrPrintResult({required this.cellQr, required this.printJob});

  final QolipCellQr cellQr;
  final UsbRpsPrintRequest printJob;

  String get id => cellQr.id;
  String get block => cellQr.block;
  String get warehouse => cellQr.warehouse;
  String get rowLetter => cellQr.rowLetter;
  int get columnNumber => cellQr.columnNumber;
  String get locationLabel => cellQr.locationLabel;
  String get qrPayload => cellQr.qrPayload;
}

class QolipCodeQrPrintResult {
  const QolipCodeQrPrintResult({required this.qolipQr, required this.printJob});

  final QolipCodeQr qolipQr;
  final UsbRpsPrintRequest printJob;

  String get qolipCode => qolipQr.qolipCode;
  String get qrPayload => qolipQr.qrPayload;
  String get itemCode => qolipQr.itemCode;
  String get itemName => qolipQr.itemName;
  String get itemGroup => qolipQr.itemGroup;
  int get size => qolipQr.size;
}

UsbRpsPrintRequest _qolipCellUsbPrintJob(QolipCellQr cellQr) {
  return UsbRpsPrintRequest(
    epc: cellQr.qrPayload,
    itemCode: cellQr.qrPayload,
    itemName: _qolipCellLabel(cellQr),
    warehouse: cellQr.warehouse,
    printer: 'godex',
    printMode: 'label',
    grossQty: 1,
    unit: 'dona',
    labelKind: 'qolip_cell',
    progressQty: 1,
    progressUnit: 'dona',
  );
}

String _qolipCellLabel(QolipCellQr cellQr) {
  final row = cellQr.rowLetter.trim().toUpperCase();
  if (row.isNotEmpty && cellQr.columnNumber > 0) {
    return '$row${cellQr.columnNumber}';
  }
  return cellQr.locationLabel.trim();
}

UsbRpsPrintRequest _qolipCodeUsbPrintJob(QolipCodeQr qolipQr) {
  return UsbRpsPrintRequest(
    epc: qolipQr.qrPayload,
    itemCode: qolipQr.qolipCode,
    itemName: qolipQr.itemName,
    warehouse: 'ACCORD',
    printer: 'godex',
    printMode: 'label',
    grossQty: 1,
    unit: 'dona',
    labelKind: 'qolip_code',
    progressQty: 1,
    progressUnit: 'dona',
  );
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
