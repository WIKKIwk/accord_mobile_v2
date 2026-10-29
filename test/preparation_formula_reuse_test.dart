import 'dart:convert';

import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_create_hub_sheet.dart';
import 'package:accord_mobile_v2/src/features/preparation/models/preparation_models.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_formula_variants_screen.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_order_formula_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/widgets/m3_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preparation_formula_variants_test.dart' as variants;
import 'preparation_material_management_test.dart' as fixtures;

class _ReuseApi extends variants.VariantApi {
  final reuses = <Map<String, dynamic>>[];
  var catalogReads = 0;
  var failNext = false;

  @override
  Future<http.Response> respond(http.Request request) async {
    if (request.url.path.endsWith('/formula-catalog')) {
      catalogReads++;
      return fixtures.response({
        'formulas': [
          for (final (id, name, code, product, material, order) in [
            (
              'source-lg',
              'LG',
              '950400000001',
              'Silver choy 100 gr',
              'mat-b',
              '0317'
            ),
            ('source-xl', 'XL', '950400000002', 'Mosh 900 gr', 'mat-a', '0318'),
            ('empty', 'Sinov', '950400000003', 'Papay', 'mat-b', '0319'),
          ])
            {
              'id': id,
              'name': name,
              'formula_code': code,
              'product_code': 'OTHER-$id',
              'product_title': product,
              'material_id': material,
              'material_name': 'PE PR',
              'order_codes': [order],
              'can_create': true,
            },
        ]
      });
    }
    if (request.url.path.endsWith('/formula-variants/reuse')) {
      expect(request.url.queryParameters['order_id'], 'order-1');
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      reuses.add(body);
      expect(body, {
        'product_code': 'P',
        'material_id': 'pe-pr',
        'source_variant_id': 'source-lg'
      });
      if (failNext) {
        failNext = false;
        return fixtures.response({'error': 'Qayta urinib ko‘ring'}, 409);
      }
      final copied = {
        'id': 'copied-lg',
        'name': 'LG',
        'formula_code': '950400000010',
        'product_code': 'P',
        'material_id': 'pe-pr',
        'formula_count': 3,
        'shares_complete': true,
      };
      if (!this.variants.any((entry) => entry['id'] == 'copied-lg')) {
        this.variants.add(copied);
      }
      return fixtures.response(copied);
    }
    if (request.url.path.endsWith('/formulas') &&
        request.url.queryParameters['variant_id'] == 'copied-lg') {
      formulaReads.add('copied-lg');
      expect(request.url.queryParameters['product_code'], 'P');
      expect(request.url.queryParameters['material_id'], 'pe-pr');
      return fixtures.response({
        'product_code': 'P',
        'material_id': 'pe-pr',
        'formulas': [
          for (final (name, share) in [
            ('A', '30.000000'),
            ('B', '40.000000'),
            ('C', '30.000000')
          ])
            {
              'name': name,
              'share_percent': share,
              'lines': [
                {'item_code': 'C1', 'name': '0209', 'percent': '100.000000'}
              ]
            },
        ],
      });
    }
    return super.respond(request);
  }
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Amallar'));
  await tester.pumpAndSettle();
  expect(find.text('Variant qo‘shish'), findsWidgets);
  await tester.tap(find.text('Qidirib variant qo‘shish').last);
  await tester.pumpAndSettle();
}

Future<void> _withApi(
    WidgetTester tester, _ReuseApi api, Future<void> Function() body) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final semantics = tester.ensureSemantics();
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(variants.app());
      await tester.pumpAndSettle();
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => MockClient(api.respond)).whenComplete(semantics.dispose);
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
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    adminCreateHubMenuOpen.value = false;
  });

  testWidgets(
      'shared product picker searches complete recipes and reuses one in the target scope',
      (tester) async {
    final api = _ReuseApi();
    await _withApi(tester, api, () async {
      await _openPicker(tester);
      final sheet =
          find.byType(M3AsyncPickerSheet<PreparationFormulaCatalogEntry>);
      expect(sheet, findsOneWidget);
      expect(find.text('LG'), findsOneWidget);
      expect(find.text('XL'), findsOneWidget);
      expect(find.text('Sinov'), findsOneWidget);
      final route =
          ModalRoute.of(tester.element(sheet)) as ModalBottomSheetRoute;
      expect(route.backgroundColor, Colors.transparent);
      final search =
          find.descendant(of: sheet, matching: find.byType(TextField));
      final lgTitle = find.descendant(
        of: sheet,
        matching: find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == 'LG'),
      );
      for (final query in ['950400000001', '0317', 'LG']) {
        await tester.enterText(search, query);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(lgTitle, findsOneWidget);
        expect(find.text('XL'), findsNothing);
      }
      expect(api.catalogReads, 1);
      await tester.tap(lgTitle);
      await tester.pumpAndSettle();
      final editor = tester.widget<PreparationOrderFormulaScreen>(
          find.byType(PreparationOrderFormulaScreen));
      expect(editor.variantId, 'copied-lg');
      expect(editor.variantName, 'LG');
      expect(editor.variantCode, '950400000010');
      expect(editor.productCode, 'P');
      expect(editor.materialId, 'pe-pr');
      expect(api.reuses, hasLength(1));
      expect(api.creates, isEmpty);
      expect(api.formulaReads, ['copied-lg']);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('closing the search does not add a variant', (tester) async {
    final api = _ReuseApi();
    await _withApi(tester, api, () async {
      await _openPicker(tester);
      Navigator.of(tester.element(
              find.byType(M3AsyncPickerSheet<PreparationFormulaCatalogEntry>)))
          .pop();
      await tester.pumpAndSettle();
      expect(api.reuses, isEmpty);
      expect(api.creates, isEmpty);
      expect(find.byType(PreparationFormulaVariantsScreen), findsOneWidget);
    });
  });

  testWidgets('a failed reuse can be retried without adding an empty variant',
      (tester) async {
    final api = _ReuseApi()..failNext = true;
    await _withApi(tester, api, () async {
      await _openPicker(tester);
      await tester.tap(find.text('LG'));
      await tester.pumpAndSettle();
      expect(find.byType(PreparationOrderFormulaScreen), findsNothing);
      expect(api.creates, isEmpty);
      expect(api.variants, hasLength(1));
      await _openPicker(tester);
      await tester.tap(find.text('LG'));
      await tester.pumpAndSettle();
      expect(api.reuses, hasLength(2));
      expect(api.variants.where((entry) => entry['id'] == 'copied-lg'),
          hasLength(1));
      expect(find.byType(PreparationOrderFormulaScreen), findsOneWidget);
    });
  });

  testWidgets(
      'selection from an old account cannot be reused in the new account',
      (tester) async {
    final api = _ReuseApi();
    await _withApi(tester, api, () async {
      await _openPicker(tester);
      AppSession.instance.profile =
          AppSession.instance.profile!.copyWith(ref: 'other-master');
      await tester.tap(find.text('LG'));
      await tester.pumpAndSettle();
      expect(api.reuses, isEmpty);
      expect(find.byType(PreparationOrderFormulaScreen), findsNothing);
    });
  });
}
