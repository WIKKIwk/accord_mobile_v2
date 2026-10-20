part of '../mobile_api.dart';

class QolipMoldDraft {
  const QolipMoldDraft(
      {required this.code,
      this.size = 0,
      this.color = '',
      this.existingOnly = false});
  final String code;
  final int size;
  final String color;
  final bool existingOnly;

  Map<String, dynamic> toJson() => {
        'qolip_code': code.trim(),
        'size': size,
        'color': color.trim(),
        'existing_only': existingOnly
      };
}

class QolipManagedSet {
  const QolipManagedSet({required this.set, required this.source});
  final QolipSharedSet set;
  final QolipProduct source;

  factory QolipManagedSet.fromJson(Map<String, dynamic> json) =>
      QolipManagedSet(
        set: QolipSharedSet.fromJson(json),
        source: QolipProduct(
          warehouse: json['warehouse']?.toString() ?? '',
          code: json['item_code']?.toString() ?? '',
          name: json['item_name']?.toString() ?? '',
          itemGroup: json['item_group']?.toString() ?? '',
        ),
      );
}

final _testModeManagedSets = <String, QolipManagedSet>{};
final _testModeLocalSetIds = <String>{};

extension MobileApiQolipManagement on MobileApi {
  Future<List<QolipManagedSet>> qolipManagedSets() async {
    if (await TestModeController.instance.isEnabled()) {
      for (final mold in _sharedPhysicalMolds()) {
        if (_testModeLocalSetIds.contains(mold.setId)) continue;
        final snapshot = await qolipResolveSet(mold.setId);
        if (snapshot == null) continue;
        final targets = _testModeQolipSetLinks[mold.setId]?.values ?? [mold];
        _testModeManagedSets[mold.setId] = QolipManagedSet(
          set: QolipSharedSet(
            id: snapshot.id,
            code: snapshot.code,
            fingerprint: snapshot.fingerprint,
            members: snapshot.members,
            productLabels: targets.map((p) => '${p.name} (${p.code})').toList(),
          ),
          source: mold,
        );
      }
      final result = _testModeManagedSets.values.toList()
        ..sort((a, b) => a.set.code.compareTo(b.set.code));
      return result;
    }
    final response = await _sendAuthorized(() => _get(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/sets'),
          headers: _headers(requireToken()),
        ));
    if (response.statusCode != 200) {
      throw _qolipApiException(response,
          fallbackCode: 'qolip_set_load_failed',
          fallbackMessage: 'Komplektlar yuklanmadi');
    }
    final data = await decodeJsonMapPayload(response.body);
    return (data['sets'] as List)
        .map((raw) =>
            QolipManagedSet.fromJson((raw as Map).cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<QolipManagedSet> qolipEditSet({
    required QolipManagedSet current,
    List<QolipMoldDraft> add = const [],
    List<String> remove = const [],
  }) async {
    if (await TestModeController.instance.isEnabled()) {
      final snapshot = await qolipResolveSet(current.set.id);
      if (snapshot == null || snapshot.fingerprint != current.set.fingerprint) {
        throw const MobileApiException(
            code: 'qolip_set_changed', message: 'qolip_set_changed');
      }
      final removed = remove.map((s) => s.trim().toLowerCase()).toSet();
      final physical = _sharedPhysicalMolds();
      if (snapshot.members.any((m) => m.isInUse) ||
          _testModeQolipCheckouts.any((c) =>
              c.isOpen &&
              snapshot.members.any((m) =>
                  m.qolipCode.toLowerCase() == c.qolipCode.toLowerCase()))) {
        throw const MobileApiException(
            code: 'qolip_in_use', message: 'qolip_in_use');
      }
      if (removed.any((c) =>
          !snapshot.members.any((m) => m.qolipCode.toLowerCase() == c))) {
        throw const MobileApiException(
            code: 'qolip_set_changed', message: 'qolip_set_changed');
      }
      final additions = <QolipProduct>[];
      for (final draft in add) {
        if (draft.code.trim().isEmpty ||
            draft.size <= 0 ||
            physical.any((m) =>
                m.qolipCode.toLowerCase() == draft.code.trim().toLowerCase())) {
          throw const MobileApiException(
              code: 'qolip_code_conflict', message: 'qolip_code_conflict');
        }
        additions.add(QolipProduct(
          qolipSetId: current.set.id,
          warehouse: current.source.warehouse,
          code: current.source.code,
          name: current.source.name,
          itemGroup: current.source.itemGroup,
          qolipCode: draft.code.trim(),
          qolipSize: draft.size,
          qolipColor: draft.color,
          hasQolipSpec: true,
        ));
      }
      _testModeQolipSetLinks.putIfAbsent(current.set.id,
          () => {current.source.code.toLowerCase(): current.source});
      _testModeQolipSpecs.removeWhere(
          (_, mold) => removed.contains(mold.qolipCode.toLowerCase()));
      _testModeQolipLocations.removeWhere(
          (mold) => removed.contains(mold.qolipCode.toLowerCase()));
      for (final overrides in _testModeQolipProductOverrides.values) {
        overrides.removeWhere((code, _) => removed.contains(code));
      }
      for (final mold in additions) {
        _testModeQolipSpecs[mold.qolipCode.toLowerCase()] = mold;
      }
      final members = [
        ...snapshot.members
            .where((m) => !removed.contains(m.qolipCode.toLowerCase())),
        ...additions,
      ];
      final updated = QolipManagedSet(
        source: current.source,
        set: QolipSharedSet(
          id: current.set.id,
          code: current.set.code,
          fingerprint: jsonEncode(members
              .map((m) => [
                    m.setId,
                    m.qolipCode,
                    m.qolipSize,
                    m.qolipColor,
                    m.warehouse
                  ])
              .toList()),
          members: members,
          productLabels: current.set.productLabels,
        ),
      );
      _testModeManagedSets[current.set.id] = updated;
      _qolipProductsSnapshot = null;
      return updated;
    }
    final response = await _sendAuthorized(() => _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/sets'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({
            'set_id': current.set.id,
            'fingerprint': current.set.fingerprint,
            'add': add.map((draft) => draft.toJson()).toList(),
            'remove': remove,
          }),
        ));
    if (response.statusCode != 200) {
      throw _qolipApiException(response,
          fallbackCode: 'qolip_set_save_failed',
          fallbackMessage: 'Komplekt saqlanmadi');
    }
    _qolipProductsSnapshot = null;
    final data = await decodeJsonMapPayload(response.body);
    return QolipManagedSet.fromJson(
        (data['set'] as Map).cast<String, dynamic>());
  }

  Future<void> qolipAddProductMold(
          QolipProduct product, QolipMoldDraft draft) =>
      _editProductMolds([
        {
          'item_code': product.code,
          'warehouse': product.warehouse,
          'add': [draft.toJson()],
        }
      ]);

  Future<int> qolipRemoveProductMolds(List<QolipProduct> molds) async {
    final byProduct = <String, Set<String>>{};
    for (final mold in molds) {
      byProduct.putIfAbsent(mold.code, () => {}).add(mold.qolipCode);
    }
    await _editProductMolds([
      for (final entry in byProduct.entries)
        {'item_code': entry.key, 'remove': entry.value.toList()}
    ]);
    return byProduct.values.fold<int>(0, (sum, codes) => sum + codes.length);
  }

  Future<void> _editProductMolds(List<Map<String, dynamic>> changes) async {
    if (await TestModeController.instance.isEnabled()) {
      final physical = _sharedPhysicalMolds();
      final additions = <QolipProduct>[];
      final updates = <(String, String, bool)>[];
      for (final change in changes) {
        final itemCode = change['item_code'] as String;
        final item = TestModeDemoData.items
            .firstWhere((p) => p.code.toLowerCase() == itemCode.toLowerCase());
        for (final raw in (change['add'] as List? ?? const [])) {
          final code = raw['qolip_code'].toString().trim();
          var mold = physical
              .where((m) => m.qolipCode.toLowerCase() == code.toLowerCase())
              .firstOrNull;
          final existingOnly = raw['existing_only'] == true;
          if (mold != null && !existingOnly) {
            throw const MobileApiException(
                code: 'qolip_code_conflict', message: 'qolip_code_conflict');
          }
          if (mold == null && existingOnly) {
            throw const MobileApiException(
                code: 'qolip_code_not_found', message: 'qolip_code_not_found');
          }
          if (mold == null) {
            if ((raw['size'] as int) <= 0 ||
                (change['warehouse'] as String).isEmpty) {
              throw const MobileApiException(
                  code: 'size_invalid', message: 'size_invalid');
            }
            mold = QolipProduct(
              qolipSetId:
                  'qolip-local:${DateTime.now().microsecondsSinceEpoch}:$code',
              warehouse: change['warehouse'] as String,
              code: item.code,
              name: item.name,
              itemGroup: item.itemGroup,
              qolipCode: code,
              qolipSize: raw['size'] as int,
              qolipColor: raw['color'] as String,
              hasQolipSpec: true,
            );
            additions.add(mold);
          }
          if (mold.isInUse ||
              _testModeQolipCheckouts.any((c) =>
                  c.isOpen &&
                  c.qolipCode.toLowerCase() == code.toLowerCase())) {
            throw const MobileApiException(
                code: 'qolip_in_use', message: 'qolip_in_use');
          }
          updates.add((itemCode.toLowerCase(), code.toLowerCase(), true));
        }
        for (final code in (change['remove'] as List? ?? const [])) {
          final mold = physical.firstWhere((m) =>
              m.qolipCode.toLowerCase() == code.toString().toLowerCase());
          if (mold.isInUse ||
              _testModeQolipCheckouts.any((c) =>
                  c.isOpen &&
                  c.qolipCode.toLowerCase() == mold.qolipCode.toLowerCase())) {
            throw const MobileApiException(
                code: 'qolip_in_use', message: 'qolip_in_use');
          }
          updates.add(
              (itemCode.toLowerCase(), code.toString().toLowerCase(), false));
        }
      }
      for (final mold in additions) {
        _testModeLocalSetIds.add(mold.setId);
        _testModeQolipSetLinks[mold.setId] = {};
        _testModeQolipSpecs[mold.qolipCode.toLowerCase()] = mold;
      }
      for (final update in updates) {
        _testModeQolipProductOverrides.putIfAbsent(
            update.$1, () => {})[update.$2] = update.$3;
      }
      _qolipProductsSnapshot = null;
      return;
    }
    final response = await _sendAuthorized(() => _post(
          Uri.parse('${MobileApi.baseUrl}/v1/mobile/qolip/product-molds'),
          headers: _headers(requireToken())
            ..['Content-Type'] = 'application/json',
          body: jsonEncode({'changes': changes}),
        ));
    if (response.statusCode != 200) {
      throw _qolipApiException(response,
          fallbackCode: 'qolip_set_save_failed',
          fallbackMessage: 'Mahsulot qoliplari saqlanmadi');
    }
    _qolipProductsSnapshot = null;
  }
}
