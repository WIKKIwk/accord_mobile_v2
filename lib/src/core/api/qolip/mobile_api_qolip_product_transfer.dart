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
      final physical = _sharedPhysicalMolds();
      for (final code in codes) {
        final matches = molds.where((mold) =>
            mold.qolipCode.trim().toLowerCase() == code &&
            mold.code.trim().toLowerCase() ==
                fromItemCode.trim().toLowerCase());
        if (matches.isEmpty)
          throw const MobileApiException(
              code: 'qolip_product_transfer_conflict', message: 'conflict');
        final mold = matches.first;
        if (mold.isInUse ||
            _testModeQolipCheckouts.any((checkout) =>
                checkout.isOpen && checkout.qolipCode.toLowerCase() == code)) {
          throw const MobileApiException(
              code: 'qolip_in_use', message: 'qolip_in_use');
        }
        final sourceMold = physical
            .firstWhere((m) => m.qolipCode.trim().toLowerCase() == code);
        if (_testModeEffectiveMold(sourceMold, toItemCode) != null) {
          throw const MobileApiException(
              code: 'qolip_product_transfer_conflict', message: 'conflict');
        }
        final isBase = _testModeQolipSetLinks[sourceMold.setId]
                ?.containsKey(toItemCode.trim().toLowerCase()) ??
            (sourceMold.code.trim().toLowerCase() ==
                toItemCode.trim().toLowerCase());
        saved.add(
            _sharedMoldForProduct(mold, target.first, isExtension: !isBase));
      }
      for (final mold in saved) {
        final code = mold.qolipCode.trim().toLowerCase();
        _testModeQolipProductOverrides.putIfAbsent(
            fromItemCode.trim().toLowerCase(), () => {})[code] = false;
        final overrides = _testModeQolipProductOverrides.putIfAbsent(
            toItemCode.trim().toLowerCase(), () => {});
        if (mold.isExtension) {
          overrides[code] = true;
        } else {
          overrides.remove(code);
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
    _qolipProductsSnapshot = null;
    return saved;
  }
}
