part of '../mobile_api.dart';

class ProductionComboCatalogEntry {
  const ProductionComboCatalogEntry(
      {required this.combo, required this.template});
  final ProductionComboReference combo;
  final CalculateOrderTemplate template;
}

/// Local freshness key only. The backend owns the canonical fingerprint/revision.
String productionComboLayoutSignature(CalculateOrderTemplate template) =>
    jsonEncode({
      'customer_ref': template.customerRef.trim(),
      'products': [
        for (final row in template.products)
          {
            'item_code': row.itemCode.trim(),
            'frame_product_size_mm': row.frameProductSizeMm,
            'frame_count': row.frameCount,
          }
      ],
      'layers': [for (final layer in template.effectiveLayers) layer.toJson()],
      'edge_allowance_mm': template.edgeAllowanceMm,
      'print_val_size_mm': template.printValSizeMm,
      'production_options': template.productionOptions?.toJson(),
      'roll_count': template.rollCount,
      'status': template.status.trim().toLowerCase(),
      'image_id': template.imageId,
      'color': template.color,
    });

void _checkProductionComboScope(String scope) {
  if (scope != currentSessionReadScope()) {
    throw StateError('Combo account changed');
  }
}

final _testModeComboRevisions = <String, ProductionComboCatalogEntry>{};
final _testModeComboScopes = <String, String>{};
int _testModeComboSequence = 0;

extension MobileApiProductionCombos on MobileApi {
  void invalidateProductionComboCatalog() {
    _qolipProductsSnapshot = null;
    QolipCatalogStore.instance.reset();
    QolipCatalogStore.instance.invalidateDetails();
  }

  Future<ProductionComboReference> adminSaveProductionCombo({
    required String name,
    required CalculateOrderTemplate template,
    String? comboId,
  }) async {
    final scope = currentSessionReadScope();
    final testMode = await TestModeController.instance.isEnabled();
    _checkProductionComboScope(scope);
    if (testMode) {
      final fingerprint = productionComboLayoutSignature(template);
      final id = comboId ?? 'test-combo-${++_testModeComboSequence}';
      final previous = _testModeComboRevisions.values
          .where((entry) =>
              entry.combo.id == id &&
              _testModeComboScopes[entry.combo.itemCode] == scope)
          .toList();
      if (comboId != null && previous.isEmpty) {
        throw const MobileApiException(
            code: 'combo_not_found', message: 'Kombo topilmadi');
      }
      for (final entry in previous) {
        if (entry.combo.layoutFingerprint == fingerprint) return entry.combo;
      }
      final revision = previous.length + 1;
      final combo = ProductionComboReference(
        id: id,
        itemCode: 'COMBO-${++_testModeComboSequence}-$revision',
        name: name.trim(),
        revision: revision,
        layoutFingerprint: fingerprint,
      );
      _testModeComboRevisions[combo.itemCode] = ProductionComboCatalogEntry(
        combo: combo,
        template: template.copyWith(
            combo: combo,
            itemCode: combo.itemCode,
            name: combo.name,
            product: combo.name,
            kg: 0,
            id: '',
            code: '',
            orderNumber: '',
            sourceMapId: '',
            variantId: '',
            savedAt: DateTime.fromMillisecondsSinceEpoch(0)),
      );
      _testModeComboScopes[combo.itemCode] = scope;
      return combo;
    }
    final response = await _sendAuthorized(() {
      _checkProductionComboScope(scope);
      return _post(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/combos'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({
          'name': name.trim(),
          'template': template.toJson(),
          if (comboId != null && comboId.isNotEmpty) 'combo_id': comboId
        }),
      );
    });
    _checkProductionComboScope(scope);
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'combo_save_failed');
    }
    final payload = await decodeJsonMapPayload(response.body);
    final combo = ProductionComboReference.fromJson(payload['combo']);
    if (combo == null ||
        combo.id.isEmpty ||
        combo.itemCode.isEmpty ||
        combo.revision < 1) {
      throw const FormatException('Incomplete combo revision response');
    }
    return combo;
  }

  Future<ProductionComboCatalogEntry> adminProductionCombo(
      String itemCode) async {
    final scope = currentSessionReadScope();
    final testMode = await TestModeController.instance.isEnabled();
    _checkProductionComboScope(scope);
    if (testMode) {
      final entry = _testModeComboRevisions[itemCode];
      if (entry != null && _testModeComboScopes[itemCode] == scope) {
        return entry;
      }
      throw const MobileApiException(
          code: 'combo_not_found', message: 'Kombo topilmadi');
    }
    final response = await _sendAuthorized(() {
      _checkProductionComboScope(scope);
      return _get(
        Uri.parse('${MobileApi.baseUrl}/v1/mobile/admin/combos')
            .replace(queryParameters: {'item_code': itemCode}),
        headers: _headers(requireToken()),
      );
    });
    _checkProductionComboScope(scope);
    if (response.statusCode != 200) {
      throw _adminProductionMapException(response, 'combo_load_failed');
    }
    final payload = await decodeJsonMapPayload(response.body);
    final combo = ProductionComboReference.fromJson(payload['combo']);
    final rawTemplate = payload['template'];
    if (combo == null || combo.itemCode != itemCode || rawTemplate is! Map) {
      throw const FormatException('Incomplete combo catalog response');
    }
    return ProductionComboCatalogEntry(
        combo: combo,
        template:
            CalculateOrderTemplate.fromJson(rawTemplate.cast<String, dynamic>())
                .copyWith(combo: combo));
  }
}
