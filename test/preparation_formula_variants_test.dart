import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_create_hub_sheet.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_formula_variants_screen.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_order_formula_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'preparation_material_management_test.dart' as fixtures;

Widget app({int revision = 0}) => fixtures.app(
    home: PreparationFormulaVariantsScreen(
        key: ValueKey(revision),
        orderId: 'order-1',
        orderCode: '0097',
        productCode: 'P',
        productTitle: 'Mosh',
        materialId: 'pe-pr',
        materialName: 'PE PR'));

class VariantApi {
  final variants = <Map<String, dynamic>>[
    {
      'id': 'legacy',
      'name': 'Asosiy',
      'formula_count': 3,
      'shares_complete': true
    }
  ];
  final creates = <Map<String, dynamic>>[];
  final formulaReads = <String>[];
  bool loseFirstResponse = false;

  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/formula-variants')) {
      if (request.method == 'GET') {
        expect(request.url.queryParameters,
            {'product_code': 'P', 'material_id': 'pe-pr', 'order_id': 'order-1'});
        return fixtures.response({
          'product_code': 'P',
          'material_id': 'pe-pr',
          'variants': variants
        });
      }
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      expect(body['product_code'], 'P');
      expect(body['material_id'], 'pe-pr');
      creates.add(body);
      if (!variants.any((v) => v['id'] == 'new')) {
        variants.add({
          'id': 'new',
          'name': body['name'],
          'formula_count': 0,
          'shares_complete': false
        });
      }
      if (loseFirstResponse && creates.length == 1) {
        throw http.ClientException('lost response');
      }
      return fixtures.response({
        'id': 'new',
        'name': body['name'],
        'product_code': 'P',
        'material_id': 'pe-pr'
      });
    }
    if (path.endsWith('/snapshot')) {
      return fixtures.response(
          {'warehouses': [], 'materials': [], 'history': [], 'orders': []});
    }
    if (path.endsWith('/order-materials')) {
      return fixtures.response({
        'materials': [
          {
            'material_id': 'pe-pr',
            'material_name': 'PE PR',
            'estimated_kg': '1000.000000'
          }
        ]
      });
    }
    expect(path, '/v1/mobile/preparation/formulas');
    expect(request.method, 'GET');
    final id = request.url.queryParameters['variant_id']!;
    formulaReads.add(id);
    return fixtures.response({
      'product_code': 'P',
      'material_id': 'pe-pr',
      'formulas': [
        if (id == 'legacy')
          {
            'name': 'A',
            'share_percent': '100.000000',
            'lines': [
              {'item_code': 'C1', 'name': '0209', 'percent': '100.000000'}
            ]
          },
      ]
    });
  }
}

Future<void> openCreate(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Amallar'));
  await tester.pumpAndSettle();
  expect(find.text('Variant qo‘shish'), findsWidgets);
  expect(find.text('Shnek formula qo‘shish'), findsNothing);
  await tester.tap(find.text('Variant qo‘shish').last);
  await tester.pumpAndSettle();
  expect(find.text('Shnek variantiga nom bering'), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = fixtures.profile(UserRole.tayyorlovMasteri);
    adminCreateHubMenuOpen.value = false;
  });
  tearDown(() {
    adminCreateHubMenuOpen.value = false;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('entry lists variants and opens only the selected variant',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final api = VariantApi();
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.text('Shnek formulalar'), findsOneWidget);
      expect(find.text('Asosiy'), findsOneWidget);
      expect(find.byType(PreparationOrderFormulaScreen), findsNothing);
      expect(api.formulaReads, isEmpty);
      await tester.tap(
          find.byKey(const ValueKey('preparation-formula-variant-legacy')));
      await tester.pumpAndSettle();
      expect(api.formulaReads, ['legacy']);
      final screen = tester.widget<PreparationOrderFormulaScreen>(
          find.byType(PreparationOrderFormulaScreen));
      expect(screen.variantId, 'legacy');
      expect(screen.variantName, 'Asosiy');
      expect(screen.openEditorOnLoad, isFalse);
      expect(find.text('≈ 1000.00 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient(api.respond)).whenComplete(semantics.dispose);
  });

  testWidgets(
      'named empty variant is saved before composition and survives returning and reopening',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final api = VariantApi();
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await openCreate(tester);
      final save = find.byKey(const ValueKey('preparation-variant-create'));
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(api.creates, isEmpty);
      expect(api.formulaReads, isEmpty);
      await tester.enterText(
          find.byKey(const ValueKey('preparation-variant-name')),
          '  Yangi   qatlam  ');
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.creates.single['name'], 'Yangi qatlam');
      expect(api.formulaReads, ['new']);
      expect(find.text('Yangi qatlam'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      Navigator.of(tester.element(find.byType(PreparationOrderFormulaScreen)))
          .pop();
      await tester.pumpAndSettle();
      expect(find.text('Yangi qatlam'), findsOneWidget);
      expect(find.text('Tarkib hali kiritilmagan'), findsOneWidget);
      await tester.pumpWidget(app(revision: 1));
      await tester.pumpAndSettle();
      expect(find.text('Yangi qatlam'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient(api.respond)).whenComplete(semantics.dispose);
  });

  testWidgets(
      'cancel creates nothing and uncertain creation retries the same request',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final api = VariantApi()..loseFirstResponse = true;
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await openCreate(tester);
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      expect(api.creates, isEmpty);
      expect(api.formulaReads, isEmpty);
      await openCreate(tester);
      await tester.enterText(
          find.byKey(const ValueKey('preparation-variant-name')), 'Sinov');
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('preparation-variant-create'));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Shnek variantiga nom bering'), findsOneWidget);
      expect(find.byType(PreparationOrderFormulaScreen), findsNothing);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.creates.length, 2);
      expect(api.creates[0]['request_id'], api.creates[1]['request_id']);
      expect(api.variants.where((v) => v['name'] == 'Sinov').length, 1);
      expect(
          tester
              .widget<PreparationOrderFormulaScreen>(
                  find.byType(PreparationOrderFormulaScreen))
              .variantId,
          'new');
      expect(tester.takeException(), isNull);
    }, () => MockClient(api.respond)).whenComplete(semantics.dispose);
  });

  test(
      'all formula and share operations carry the selected variant in both scopes',
      () async {
    final calls = <http.Request>[];
    await http.runWithClient(() async {
      for (final saved in [false, true]) {
        await MobileApi.instance.preparationFormulas('P',
            materialId: 'pe-pr', savedOnly: saved, variantId: 'v2');
        await MobileApi.instance.preparationUpsertFormula(
            'P',
            [
              {'item_code': 'C1', 'percent': '100.000000'}
            ],
            name: 'A',
            materialId: 'pe-pr',
            savedOnly: saved,
            variantId: 'v2');
        await MobileApi.instance.preparationUpdateFormulaShares(
            productCode: 'P',
            materialId: 'pe-pr',
            shares: [
              {'name': 'A', 'percent': '100.000000'}
            ],
            savedOnly: saved,
            variantId: 'v2');
        await MobileApi.instance.preparationDeleteFormula('P', 'A',
            materialId: 'pe-pr', savedOnly: saved, variantId: 'v2');
      }
      expect(calls.length, 8);
    },
        () => MockClient((request) async {
              calls.add(request);
              expect(request.url.queryParameters['variant_id'], 'v2');
              final formula = {
                'name': 'A',
                'share_percent': '100.000000',
                'lines': [
                  {'item_code': 'C1', 'name': '0209', 'percent': '100.000000'}
                ]
              };
              return fixtures.response({
                'product_code': 'P',
                'material_id': 'pe-pr',
                ...formula,
                'formulas': [formula],
                'deleted': true
              });
            }));
  });
}
