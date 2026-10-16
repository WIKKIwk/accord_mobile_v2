part of '../mobile_api.dart';

final _testModeQolipSetLinks = <String, Map<String, QolipProduct>>{};

List<QolipProduct> _sharedPhysicalMolds() {
  final molds = Map<String, QolipProduct>.from(_testModeQolipSpecs);
  for (final location in _testModeQolipLocations) {
    final key = location.qolipCode.trim().toLowerCase();
    if (molds.containsKey(key)) continue;
    final items = TestModeDemoData.items.where(
        (item) => item.code.toLowerCase() == location.itemCode.toLowerCase());
    molds[key] = QolipProduct(
        warehouse: location.warehouse,
        code: location.itemCode,
        name: location.itemName,
        itemGroup: items.isEmpty ? '' : items.first.itemGroup,
        customerNames: items.isEmpty ? const [] : items.first.customerNames,
        qolipCode: location.qolipCode,
        qolipSize: location.size,
        hasQolipSpec: true);
  }
  return molds.values.toList(growable: false);
}

class QolipSharedSet {
  const QolipSharedSet(
      {required this.id,
      required this.code,
      required this.fingerprint,
      required this.members,
      required this.productLabels});
  final String id;
  final String code;
  final String fingerprint;
  final List<QolipProduct> members;
  final List<String> productLabels;

  factory QolipSharedSet.fromJson(Map<String, dynamic> json) {
    final id = json['set_id']?.toString() ?? '';
    final members = (json['members'] as List).map((raw) {
      final spec = (raw as Map).cast<String, dynamic>();
      return QolipProduct.fromJson({
        ...spec,
        'qolip_set_id': id,
        'code': spec['item_code'],
        'name': spec['item_name'],
        'has_qolip_spec': true
      });
    }).toList(growable: false);
    if (id.isEmpty ||
        members.isEmpty ||
        members
            .any((member) => member.qolipCode.isEmpty || member.setId != id)) {
      throw const MobileApiException(
          code: 'qolip_set_changed', message: 'qolip_set_changed');
    }
    return QolipSharedSet(
        id: id,
        code: json['display_code']?.toString() ?? '',
        fingerprint: json['fingerprint']?.toString() ?? '',
        members: members,
        productLabels: (json['products'] as List).map((raw) {
          final product = raw as Map;
          return '${product['name']} (${product['code']})';
        }).toList(growable: false));
  }
}

QolipProduct _sharedMoldForProduct(QolipProduct mold, QolipProduct product) =>
    QolipProduct(
      qolipSetId: mold.setId,
      warehouse: mold.warehouse,
      code: product.code,
      name: product.name,
      itemGroup: product.itemGroup,
      customerNames: product.customerNames,
      qolipCode: mold.qolipCode,
      firstQolipCode: product.firstQolipCode.isEmpty
          ? mold.qolipCode
          : product.firstQolipCode,
      qolipSize: mold.qolipSize,
      qolipColor: mold.qolipColor,
      hasQolipSpec: true,
      isInUse: mold.isInUse ||
          _testModeQolipCheckouts.any((checkout) =>
              checkout.isOpen &&
              checkout.qolipCode.toLowerCase() == mold.qolipCode.toLowerCase()),
    );

List<QolipProduct> _sharedTestModeCatalog(
    String query, int limit, bool withQolipOnly) {
  final result = <QolipProduct>[];
  final catalog = [
    for (final item in TestModeDemoData.items)
      QolipProduct(
          code: item.code,
          name: item.name,
          itemGroup: item.itemGroup,
          customerNames: item.customerNames)
  ];
  final withMolds = <String>{};
  for (final mold in _sharedPhysicalMolds()) {
    final targets = _testModeQolipSetLinks[mold.setId]?.values ?? [mold];
    for (final target in targets) {
      result.add(_sharedMoldForProduct(mold, target));
      withMolds.add(target.code.toLowerCase());
    }
  }
  if (!withQolipOnly)
    result.addAll(catalog
        .where((product) => !withMolds.contains(product.code.toLowerCase())));
  final normalized = query.trim().toLowerCase();
  return result
      .where((product) =>
          normalized.isEmpty ||
          [
            product.code,
            product.name,
            product.qolipCode,
            ...product.customerNames
          ].any((value) => value.toLowerCase().contains(normalized)))
      .take(limit)
      .toList(growable: false);
}

extension MobileApiQolipSharedSets on MobileApi {
  Future<QolipSharedSet?> qolipResolveSet(String identifier) async {
    if (await TestModeController.instance.isEnabled()) {
      final all = _sharedPhysicalMolds();
      var matched = all
          .where((mold) =>
              mold.setId == identifier.trim() ||
              mold.qolipCode.toLowerCase() == identifier.trim().toLowerCase())
          .toList();
      if (matched.isEmpty) {
        final match = RegExp(r'^(.*)-([0-9]+)$').firstMatch(identifier.trim());
        final count = int.tryParse(match?.group(2) ?? '') ?? 0;
        if (count > 0 && count <= 100) {
          final candidates = {
            for (var index = 1; index <= count; index++)
              '${match!.group(1)}-${index.toString().padLeft(match.group(2)!.length, '0')}'
                  .toLowerCase()
          };
          matched = all
              .where(
                  (mold) => candidates.contains(mold.qolipCode.toLowerCase()))
              .toList();
        }
      }
      final ids = matched.map((mold) => mold.setId).toSet();
      if (ids.length > 1)
        throw const MobileApiException(
            code: 'qolip_set_ambiguous', message: 'qolip_set_ambiguous');
      if (ids.isEmpty) return null;
      final id = ids.single;
      final members = all.where((mold) => mold.setId == id).toList()
        ..sort((a, b) =>
            a.qolipCode.toLowerCase().compareTo(b.qolipCode.toLowerCase()));
      final display = [...members]..sort((a, b) =>
          a.qolipCode.length == b.qolipCode.length
              ? a.qolipCode.compareTo(b.qolipCode)
              : a.qolipCode.length.compareTo(b.qolipCode.length));
      final targets = _testModeQolipSetLinks[id]?.values ?? [members.first];
      return QolipSharedSet(
          id: id,
          code: display.last.qolipCode,
          fingerprint: jsonEncode(members
              .map((mold) => [
                    mold.setId,
                    mold.qolipCode,
                    mold.qolipSize,
                    mold.qolipColor,
                    mold.warehouse
                  ])
              .toList()),
          members: members,
          productLabels: targets
              .map((product) => '${product.name} (${product.code})')
              .toList());
    }
    final response = await _sendAuthorized(() => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/shared-sets')
            .replace(queryParameters: {'identifier': identifier.trim()}),
        headers: _headers(requireToken())));
    if (response.statusCode != 200)
      throw _qolipApiException(response,
          fallbackCode: 'qolip_set_load_failed',
          fallbackMessage: 'Qolip komplekti yuklanmadi');
    final data = await decodeJsonMapPayload(response.body);
    return data['set'] == null
        ? null
        : QolipSharedSet.fromJson((data['set'] as Map).cast<String, dynamic>());
  }

  Future<List<QolipProduct>> qolipReuseSet(
      {required QolipSharedSet set, required QolipProduct product}) async {
    if (await TestModeController.instance.isEnabled()) {
      final current = await qolipResolveSet(set.id);
      if (current == null || current.fingerprint != set.fingerprint)
        throw const MobileApiException(
            code: 'qolip_set_changed', message: 'qolip_set_changed');
      final targets = _testModeQolipSetLinks.putIfAbsent(
          set.id,
          () => {
                current.members.first.code.toLowerCase(): current.members.first
              });
      targets[product.code.toLowerCase()] = product;
      return current.members;
    }
    final response = await _sendAuthorized(() => _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/shared-sets'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'set_id': set.id,
          'item_code': product.code,
          'fingerprint': set.fingerprint
        })));
    if (response.statusCode != 200)
      throw _qolipApiException(response,
          fallbackCode: 'qolip_set_save_failed',
          fallbackMessage: 'Qolip komplekti ulanmagan');
    final data = await decodeJsonMapPayload(response.body);
    final saved =
        QolipSharedSet.fromJson((data['set'] as Map).cast<String, dynamic>());
    if (saved.id != set.id || saved.fingerprint != set.fingerprint)
      throw const MobileApiException(
          code: 'qolip_set_changed', message: 'qolip_set_changed');
    _qolipProductsSnapshot = null;
    return saved.members;
  }

  Future<List<QolipProduct>> qolipProductMolds(String itemCode) async {
    if (await TestModeController.instance.isEnabled())
      return (await qolipProducts(
              query: itemCode, limit: 20000, withQolipOnly: true))
          .where((product) =>
              product.code.trim().toLowerCase() ==
              itemCode.trim().toLowerCase())
          .toList(growable: false);
    final response = await _sendAuthorized(() => _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/shared-sets')
            .replace(queryParameters: {'item_code': itemCode.trim()}),
        headers: _headers(requireToken())));
    if (response.statusCode != 200)
      throw _qolipApiException(response,
          fallbackCode: 'qolip_set_load_failed',
          fallbackMessage: 'Qoliplar yuklanmadi');
    final data = await decodeJsonMapPayload(response.body);
    return (data['products'] as List)
        .map((raw) =>
            QolipProduct.fromJson((raw as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }
}
