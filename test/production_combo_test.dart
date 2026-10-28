import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _comboJson = {
  'id': 'combo-1',
  'item_code': 'COMBO-1-R2',
  'name': 'Vitaminlar',
  'revision': 2,
  'layout_fingerprint': 'signature'
};
CalculateOrderTemplate _template() => CalculateOrderTemplate.fromJson({
      'name': 'Vitaminlar',
      'product': 'Vitaminlar',
      'customer_ref': 'C1',
      'products': [
        {
          'id': 'p1',
          'item_code': 'SKU-A',
          'product': 'A',
          'frame_product_size_mm': 100,
          'frame_count': 2
        },
        {
          'id': 'p2',
          'item_code': 'SKU-B',
          'product': 'B',
          'frame_product_size_mm': 150,
          'frame_count': 1
        }
      ],
      'layers': [
        {'material_id': 'pet', 'material': 'PET', 'micron': '12'}
      ],
      'combo': _comboJson,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
  });
  tearDown(() {
    AppSession.instance.token = null;
  });

  test(
      'combo revision and ordered output SKUs survive template/map JSON and copies',
      () {
    final template =
        CalculateOrderTemplate.fromJson(_template().toJson()).copyWith(kg: 500);
    expect(template.combo!.toJson(), _comboJson);
    expect(template.products.map((p) => p.itemCode), ['SKU-A', 'SKU-B']);
    final map = ProductionMapDefinition.fromJson({
      'id': 'zakaz-1',
      'product_code': 'COMBO-1-R2',
      'title': 'Vitaminlar',
      'products': template.products.map((p) => p.toJson()).toList(),
      'combo': _comboJson
    });
    final restored =
        ProductionMapDefinition.fromJson(map.copyWith(orderKg: 500).toJson());
    expect(restored.combo!.toJson(), _comboJson);
    expect(restored.layoutWidths, [100, 100, 150]);
    expect(template.copyWith(clearCombo: true).toJson().containsKey('combo'),
        isFalse);
    expect(
        map.copyWith(clearCombo: true).toJson().containsKey('combo'), isFalse);
  });

  test(
      'local combo freshness ignores quantity and row ids, preserves physical layout',
      () {
    final template = _template();
    final signature = productionComboLayoutSignature(template);
    expect(
        productionComboLayoutSignature(
            template.copyWith(kg: 100, wastePercent: 10, note: 'Changed')),
        signature);
    final reordered =
        template.copyWith(products: template.products.reversed.toList());
    expect(productionComboLayoutSignature(reordered), isNot(signature));
    expect(
        productionComboLayoutSignature(
            template.copyWith(imageId: 'new-artwork')),
        isNot(signature));
    expect(productionComboLayoutSignature(template.copyWith(rollCount: 8)),
        isNot(signature));
  });

  test(
      'combo API uses explicit name, stable master id and exact revision catalog lookup',
      () async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      final ref = await MobileApi.instance.adminSaveProductionCombo(
          name: 'Vitaminlar', template: _template(), comboId: 'combo-1');
      expect(ref.itemCode, 'COMBO-1-R2');
      final entry = await MobileApi.instance.adminProductionCombo(ref.itemCode);
      expect(
          entry.template.products.map((p) => p.itemCode), ['SKU-A', 'SKU-B']);
      expect(entry.template.combo!.revision, 2);
    },
        () => MockClient((request) async {
              requests.add(request);
              expect(request.url.path, '/v1/mobile/admin/combos');
              if (request.method == 'POST') {
                final body = jsonDecode(request.body) as Map;
                expect(body['name'], 'Vitaminlar');
                expect(body['combo_id'], 'combo-1');
                expect((body['template'] as Map)['combo'], _comboJson);
                return http.Response(
                    jsonEncode({'ok': true, 'combo': _comboJson}), 200);
              }
              expect(request.url.queryParameters['item_code'], 'COMBO-1-R2');
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'combo': _comboJson,
                    'template': _template().toJson()
                  }),
                  200);
            }));
    expect(requests.map((r) => r.method), ['POST', 'GET']);
  });
}
