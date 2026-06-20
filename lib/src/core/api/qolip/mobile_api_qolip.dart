part of '../mobile_api.dart';

final List<QolipLocationEntry> _testModeQolipLocations = [];

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
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final normalized = query.trim().toLowerCase();
      return TestModeDemoData.items
          .where((item) =>
              normalized.isEmpty ||
              item.name.toLowerCase().contains(normalized) ||
              item.code.toLowerCase().contains(normalized))
          .take(limit)
          .map((item) => QolipProduct(
                code: item.code,
                name: item.name,
                itemGroup: item.itemGroup,
              ))
          .toList(growable: false);
    }
    final response = await _sendAuthorized(
      () => http.get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/products').replace(
          queryParameters: {
            if (query.trim().isNotEmpty) 'q': query.trim(),
            if (limit > 0) 'limit': '$limit',
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
    required String qolipCode,
    required int size,
    required int quantity,
    String rowLetter = '',
    int? columnNumber,
  }) async {
    final payload = {
      'block': block.name.trim(),
      'warehouse': block.warehouse.trim(),
      if (product != null) 'item_code': product.code.trim(),
      if (product != null) 'item_name': product.name.trim(),
      'qolip_code': qolipCode.trim(),
      'size': size,
      'quantity': quantity,
      if (rowLetter.trim().isNotEmpty) 'row_letter': rowLetter.trim(),
      if (columnNumber != null) 'column_number': columnNumber,
    };
    if (await TestModeController.instance.isEnabled()) {
      final locationLabel = rowLetter.trim().isEmpty || columnNumber == null
          ? ''
          : '${rowLetter.trim().toUpperCase()}$columnNumber';
      final entry = QolipLocationEntry(
        id: [
          block.name,
          product?.code ?? qolipCode,
          qolipCode,
          size,
          rowLetter,
          columnNumber ?? 0,
        ].join(':'),
        block: block.name,
        warehouse: block.warehouse,
        itemCode: product?.code ?? qolipCode.trim(),
        itemName: product?.name ?? qolipCode.trim(),
        qolipCode: qolipCode.trim(),
        size: size,
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
}
