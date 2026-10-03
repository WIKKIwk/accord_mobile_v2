part of '../mobile_api.dart';

final _testModeQolipTransfers = <String, (String, List<QolipProduct>)>{};

extension MobileApiQolipProductTransfer on MobileApi {
  Future<List<QolipProduct>> qolipTransferProducts({
    required String requestId,
    required String fromItemCode,
    required String toItemCode,
    required List<String> qolipCodes,
  }) async {
    if (AppSession.instance.profile?.role != UserRole.qolipchi) {
      throw const MobileApiException(code: 'forbidden', message: 'forbidden');
    }
    final codes = qolipCodes
        .map((code) => code.trim().toLowerCase())
        .toSet()
        .toList()
      ..sort();
    final body = {
      'request_id': requestId,
      'from_item_code': fromItemCode.trim(),
      'to_item_code': toItemCode.trim(),
      'qolip_codes': codes,
    };
    if (await TestModeController.instance.isEnabled()) {
      final key = '${AppSession.instance.profile?.ref}:$requestId';
      final signature = jsonEncode(body);
      final previous = _testModeQolipTransfers[key];
      if (previous != null) {
        if (previous.$1 != signature) {
          throw const MobileApiException(
              code: 'qolip_product_transfer_conflict', message: 'conflict');
        }
        return previous.$2;
      }
      if (codes.isEmpty ||
          codes.length > 100 ||
          fromItemCode.trim().toLowerCase() ==
              toItemCode.trim().toLowerCase()) {
        throw const MobileApiException(
            code: 'qolip_product_transfer_conflict', message: 'conflict');
      }
      final molds = await qolipProducts(limit: 20000, withQolipOnly: true);
      final products = await qolipProducts(query: toItemCode, limit: 20000);
      final target = products.where((p) =>
          p.code.trim().toLowerCase() == toItemCode.trim().toLowerCase());
      if (target.isEmpty)
        throw const MobileApiException(
            code: 'item_required', message: 'item_required');
      final saved = <QolipProduct>[];
      for (final code in codes) {
        final matches =
            molds.where((m) => m.qolipCode.trim().toLowerCase() == code);
        if (matches.isEmpty ||
            matches.first.code.trim().toLowerCase() !=
                fromItemCode.trim().toLowerCase()) {
          throw const MobileApiException(
              code: 'qolip_product_transfer_conflict', message: 'conflict');
        }
        final mold = matches.first;
        if (mold.isInUse ||
            _testModeQolipCheckouts.any(
                (c) => c.isOpen && c.qolipCode.trim().toLowerCase() == code)) {
          throw const MobileApiException(
              code: 'qolip_in_use', message: 'qolip_in_use');
        }
        saved.add(QolipProduct(
          warehouse: mold.warehouse,
          code: target.first.code,
          name: target.first.name,
          itemGroup: target.first.itemGroup,
          customerNames: target.first.customerNames,
          qolipCode: mold.qolipCode,
          firstQolipCode: target.first.firstQolipCode,
          qolipSize: mold.qolipSize,
          qolipColor: mold.qolipColor,
          hasQolipSpec: true,
        ));
      }
      for (final mold in saved) {
        _testModeQolipSpecs[mold.qolipCode.trim().toLowerCase()] = mold;
        for (var i = 0; i < _testModeQolipLocations.length; i++) {
          final location = _testModeQolipLocations[i];
          if (location.qolipCode.trim().toLowerCase() !=
              mold.qolipCode.trim().toLowerCase()) continue;
          _testModeQolipLocations[i] = QolipLocationEntry(
            id: [
              location.block,
              mold.code,
              mold.qolipCode,
              mold.qolipSize,
              location.rowLetter,
              location.columnNumber ?? 0
            ].join(':'),
            block: location.block,
            warehouse: location.warehouse,
            itemCode: mold.code,
            itemName: mold.name,
            qolipCode: mold.qolipCode,
            size: location.size,
            quantity: location.quantity,
            rowLetter: location.rowLetter,
            columnNumber: location.columnNumber,
            locationLabel: location.locationLabel,
          );
        }
      }
      _testModeQolipTransfers[key] = (signature, List.unmodifiable(saved));
      return saved;
    }
    final response = await _sendAuthorized(() => _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/product-transfer'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode(body),
        ));
    if (response.statusCode != 200) {
      throw _qolipApiException(response,
          fallbackCode: 'qolip_product_transfer_failed',
          fallbackMessage: 'Qoliplarni mahsulotga ko‘chirib bo‘lmadi');
    }
    final data = await decodeJsonMapPayload(response.body);
    final saved = (data['specs'] as List).map((raw) {
      final spec = (raw as Map).cast<String, dynamic>();
      return QolipProduct.fromJson({
        ...spec,
        'code': spec['item_code'],
        'name': spec['item_name'],
        'has_qolip_spec': true,
      });
    }).toList();
    final returnedCodes =
        saved.map((m) => m.qolipCode.trim().toLowerCase()).toSet();
    if (returnedCodes.length != codes.length ||
        !returnedCodes.containsAll(codes) ||
        saved.any((m) =>
            m.code.trim().toLowerCase() != toItemCode.trim().toLowerCase())) {
      throw const MobileApiException(
          code: 'qolip_product_transfer_failed',
          message: 'Incomplete transfer response');
    }
    return saved;
  }
}
