part of '../mobile_api.dart';

final _testModeQolipSetLinks = <String, Map<String, QolipProduct>>{};
final _testModeQolipProductOverrides = <String, Map<String, bool>>{};
final _testModeImportedSetIds = <String, String>{};
var _testModeNextSetNumber = 1;

String _nextTestModeQolipSetId() {
  while (_testModeNextSetNumber <= 99999999) {
    final id = '9501${(_testModeNextSetNumber++).toString().padLeft(8, '0')}';
    if (!_testModeManagedSets.containsKey(id) &&
        !_testModeImportedSetIds.containsValue(id) &&
        !_testModeLocalSetIds.contains(id) &&
        !_testModeQolipSpecs.values
            .any((mold) => mold.setId == id || mold.qolipCode == id) &&
        !_testModeQolipLocations.any((mold) => mold.qolipCode == id)) {
      return id;
    }
  }
  throw const MobileApiException(
      code: 'qolip_set_save_failed', message: 'qolip_set_save_failed');
}

bool? _testModeEffectiveMold(QolipProduct mold, String itemCode) {
  final item = itemCode.trim().toLowerCase();
  final override = _testModeQolipProductOverrides[item]
      ?[mold.qolipCode.trim().toLowerCase()];
  if (override == false) return null;
  final base = _testModeQolipSetLinks[mold.setId]?.containsKey(item) ??
      (mold.code.trim().toLowerCase() == item);
  if (base) return false;
  return override == true ? true : null;
}

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
  // Promote legacy demo entries once. Store the new identity on each mold so
  // product groups, set selection and edits all use the same actual ID.
  for (final entry in molds.entries.toList()) {
    final mold = entry.value;
    if (RegExp(r'^9501[0-9]{8}$').hasMatch(mold.qolipSetId)) continue;
    final id = _testModeImportedSetIds.putIfAbsent(mold.setId, () {
      final next = _nextTestModeQolipSetId();
      final links = _testModeQolipSetLinks.remove(mold.setId);
      if (links != null) _testModeQolipSetLinks[next] = links;
      if (_testModeLocalSetIds.remove(mold.setId)) {
        _testModeLocalSetIds.add(next);
      }
      return next;
    });
    final promoted = QolipProduct(
      qolipSetId: id,
      isExtension: mold.isExtension,
      warehouse: mold.warehouse,
      code: mold.code,
      name: mold.name,
      itemGroup: mold.itemGroup,
      customerNames: mold.customerNames,
      qolipCode: mold.qolipCode,
      firstQolipCode: mold.firstQolipCode,
      qolipSize: mold.qolipSize,
      qolipColor: mold.qolipColor,
      hasQolipSpec: mold.hasQolipSpec,
      isInUse: mold.isInUse,
      orderImageOrderId: mold.orderImageOrderId,
    );
    molds[entry.key] = promoted;
    _testModeQolipSpecs[entry.key] = promoted;
  }
  return molds.values.toList(growable: false);
}

class QolipSharedSet {
  const QolipSharedSet(
      {required this.id,
      required this.fingerprint,
      required this.members,
      required this.productLabels});
  final String id;
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
        members
            .any((member) => member.qolipCode.isEmpty || member.setId != id)) {
      throw const MobileApiException(
          code: 'qolip_set_changed', message: 'qolip_set_changed');
    }
    return QolipSharedSet(
        id: id,
        fingerprint: json['fingerprint']?.toString() ?? '',
        members: members,
        productLabels: (json['products'] as List).map((raw) {
          final product = raw as Map;
          return '${product['name']} (${product['code']})';
        }).toList(growable: false));
  }
}

QolipProduct _sharedMoldForProduct(QolipProduct mold, QolipProduct product,
        {bool isExtension = false}) =>
    QolipProduct(
      isExtension: isExtension,
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
    final targets = <String, QolipProduct>{
      for (final target in _testModeQolipSetLinks[mold.setId]?.values ?? [mold])
        target.code.trim().toLowerCase(): target,
    };
    for (final product in catalog) {
      if (_testModeQolipProductOverrides[product.code.trim().toLowerCase()]
              ?[mold.qolipCode.trim().toLowerCase()] ==
          true) {
        targets[product.code.trim().toLowerCase()] = product;
      }
    }
    for (final target in targets.values) {
      final isExtension = _testModeEffectiveMold(mold, target.code);
      if (isExtension == null) continue;
      result.add(_sharedMoldForProduct(mold, target, isExtension: isExtension));
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
      final all = _sharedPhysicalMolds()
          .where((mold) => !_testModeLocalSetIds.contains(mold.setId)).toList();
      final registered = _testModeManagedSets.values.where((entry) =>
          entry.set.id == identifier.trim()).firstOrNull;
      var matched = all
          .where((mold) =>
              mold.setId == identifier.trim() ||
              mold.qolipCode.toLowerCase() == identifier.trim().toLowerCase())
          .toList();
      if (matched.isEmpty && registered == null) {
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
      if (registered != null) ids.add(registered.set.id);
      if (ids.length > 1)
        throw const MobileApiException(
            code: 'qolip_set_ambiguous', message: 'qolip_set_ambiguous');
      if (ids.isEmpty) return null;
      final id = ids.single;
      final members = all.where((mold) => mold.setId == id).toList()
        ..sort((a, b) =>
            a.qolipCode.toLowerCase().compareTo(b.qolipCode.toLowerCase()));
      if (members.isEmpty) return _testModeManagedSets[id]?.set;
      final targets = <String, QolipProduct>{
        for (final product
            in _testModeQolipSetLinks[id]?.values ?? [members.first])
          product.code.trim().toLowerCase(): product,
      };
      for (final item in TestModeDemoData.items) {
        if (members.any((mold) =>
            _testModeQolipProductOverrides[item.code.trim().toLowerCase()]
                ?[mold.qolipCode.trim().toLowerCase()] ==
            true)) {
          targets[item.code.trim().toLowerCase()] = QolipProduct(
              code: item.code, name: item.name, itemGroup: item.itemGroup);
        }
      }
      return QolipSharedSet(
          id: id,
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
          productLabels: targets.values
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
    final catalogScope = currentSessionReadScope();
    if (set.members.isEmpty) {
      throw const MobileApiException(
          code: 'qolip_set_changed', message: 'qolip_set_changed');
    }
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
      for (final member in current.members) {
        _testModeQolipProductOverrides[product.code.trim().toLowerCase()]
            ?.remove(member.qolipCode.trim().toLowerCase());
      }
      await QolipCatalogStore.instance.applyTestMode();
      return current.members
          .map((mold) => _sharedMoldForProduct(mold, product)).toList();
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
    QolipCatalogStore.instance.applyResponse(data, catalogScope);
    return saved.members
        .map((mold) => _sharedMoldForProduct(mold, product)).toList();
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
