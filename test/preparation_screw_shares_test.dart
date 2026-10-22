import 'dart:convert';

import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/preparation/models/preparation_models.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_order_formula_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'preparation_material_management_test.dart' as fixtures;

List<Map<String, dynamic>> formulas({bool complete = true}) => [
      {
        'name': 'A',
        'share_percent': complete ? '30.000000' : '100.000000',
        'lines': [
          {'item_code': 'C1', 'name': '0209', 'percent': '20.000000'},
          {'item_code': 'C2', 'name': '11503', 'percent': '80.000000'}
        ]
      },
      {
        'name': 'B',
        'share_percent': complete ? '40.000000' : null,
        'lines': [
          {'item_code': 'C1', 'name': '0209', 'percent': '50.000000'},
          {'item_code': 'C2', 'name': '11503', 'percent': '50.000000'}
        ]
      },
      {
        'name': 'C',
        'share_percent': complete ? '30.000000' : null,
        'lines': [
          {'item_code': 'C3', 'name': '2426H', 'percent': '100.000000'}
        ]
      },
    ];

Widget app({int revision = 0, bool savedOnly = false}) => fixtures.app(
      home: PreparationOrderFormulaScreen(
          key: ValueKey(revision),
          orderId: 'order-1',
          orderCode: '0278',
          productCode: 'P',
          productTitle: 'Product',
          materialId: 'pe-pr',
          materialName: 'PE PR',
          manageSavedFormula: savedOnly),
    );

Finder cardLine(String formula, String item) =>
    find.byKey(ValueKey('preparation-formula-line-$formula-$item'));
void expectLine(String formula, String item, String kg) => expect(
    find.descendant(
        of: cardLine(formula, item), matching: find.text('≈ $kg kg')),
    findsOneWidget);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = fixtures.profile(UserRole.tayyorlovMasteri);
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('nested shares round once and require both levels to be valid', () {
    expect(preparationScrewLineKg('1000', '30', '20'), '60.000000');
    expect(preparationScrewLineKg('824.964', '30', '10'), '24.748920');
    expect(preparationScrewLineKg('0.000005', '50', '50'), '0.000001');
    expect(preparationScrewLineKg('999999999999.999999', '100', '100'),
        '999999999999.999999');
    for (final invalid in ['0', '-1', '101', 'NaN', '1.0000001']) {
      expect(() => preparationScrewLineKg('1000', invalid, '20'),
          throwsFormatException);
      expect(() => preparationScrewLineKg('1000', '30', invalid),
          throwsFormatException);
    }
  });

  for (final savedOnly in [false, true]) {
    testWidgets(
        'three screw shares save as one recipe and survive reload (saved=$savedOnly)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var stored = formulas();
      var saves = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(app(savedOnly: savedOnly));
        await tester.pumpAndSettle();
        expect(find.text('Jami: 100% • bitta umumiy tarkib'), findsOneWidget);
        if (!savedOnly) {
          expectLine('A', 'C1', '60.00');
          expectLine('A', 'C2', '240.00');
          expectLine('B', 'C1', '200.00');
          expectLine('C', 'C3', '300.00');
        }
        final card = find.byKey(const ValueKey('preparation-formula-card-A'));
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        expect(find.byType(TextFormField), findsNothing);
        await tester.tap(
            find.byKey(const ValueKey('preparation-formula-share-action')));
        await tester.pumpAndSettle();
        final save =
            find.byKey(const ValueKey('preparation-screw-shares-save'));
        Future<void> percent(String name, String value) async {
          final field = find.byKey(ValueKey('preparation-screw-share-$name'));
          await tester.ensureVisible(field);
          await tester.enterText(field, value);
          await tester.pumpAndSettle();
        }

        await percent('A', '20');
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        await percent('A', '101');
        expect(tester.widget<FilledButton>(save).onPressed, isNull);
        await percent('A', '25');
        await percent('B', '50');
        await percent('C', '25');
        expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        expect(saves, 1);
        expect(find.byKey(const ValueKey('preparation-screw-shares-sheet')),
            findsNothing);
        if (!savedOnly) {
          expectLine('A', 'C1', '50.00');
          expectLine('A', 'C2', '200.00');
          expectLine('B', 'C1', '250.00');
          expectLine('C', 'C3', '250.00');
        } else {
          expect(find.textContaining('≈'), findsNothing);
        }
        await tester.pumpWidget(app(revision: 1, savedOnly: savedOnly));
        await tester.pumpAndSettle();
        expect(find.textContaining('Shnek ulushi: 25%'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/snapshot')) {
                  return fixtures.response({
                    'warehouses': [],
                    'materials': [],
                    'history': [],
                    'orders': [],
                  });
                }
                if (request.url.path.endsWith('/order-materials')) {
                  expect(savedOnly, isFalse);
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
                final path =
                    '/v1/mobile/preparation/formulas${savedOnly ? '/saved' : ''}';
                if (request.method == 'PATCH') {
                  expect(request.url.path, '$path/shares');
                  final body = jsonDecode(request.body) as Map;
                  expect(body['product_code'], 'P');
                  expect(body['material_id'], 'pe-pr');
                  expect(body['shares'], [
                    {'name': 'A', 'percent': '25.000000'},
                    {'name': 'B', 'percent': '50.000000'},
                    {'name': 'C', 'percent': '25.000000'}
                  ]);
                  stored = [
                    for (final f in stored)
                      {
                        ...f,
                        'share_percent': (body['shares'] as List).firstWhere(
                            (s) => s['name'] == f['name'])['percent']
                      }
                  ];
                  saves++;
                } else {
                  expect(request.url.path, path);
                }
                return fixtures.response({
                  'product_code': 'P',
                  'material_id': 'pe-pr',
                  'formulas': stored
                });
              }));
    });
  }

  testWidgets(
      'incomplete allocation hides every screw kg and failed save keeps the editor',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      for (final f in formulas(complete: false)) {
        for (final line in f['lines'] as List) {
          expect(
              find.descendant(
                  of: cardLine(
                      f['name'] as String, line['item_code'] as String),
                  matching: find.textContaining('kg')),
              findsNothing);
        }
      }
      final action =
          find.byKey(const ValueKey('preparation-screw-shares-action'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      for (final entry in [('A', '30'), ('B', '40'), ('C', '30')]) {
        final field =
            find.byKey(ValueKey('preparation-screw-share-${entry.$1}'));
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.$2);
      }
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('preparation-screw-shares-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preparation-screw-shares-sheet')),
          findsOneWidget);
      expect(find.text('Shnek ulushlari saqlanmadi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'PATCH') {
                return fixtures
                    .response({'error': 'Shnek ulushlari saqlanmadi'}, 409);
              }
              if (request.url.path.endsWith('/snapshot')) {
                return fixtures.response({
                  'warehouses': [],
                  'materials': [],
                  'orders': [],
                  'history': []
                });
              }
              if (request.url.path.endsWith('/order-materials')) {
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
              return fixtures.response({
                'product_code': 'P',
                'material_id': 'pe-pr',
                'formulas': formulas(complete: false)
              });
            }));
  });
}
