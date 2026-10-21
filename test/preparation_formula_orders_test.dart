import 'dart:convert';

import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_summary_card.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_list_row.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_screen.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_order_formula_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'preparation_material_management_test.dart' as fixtures;

List<Map<String, dynamic>> lines = [];
Map<String, dynamic> orderData() => {
      'set_id': '950200000001',
      'name': 'Test product',
      'product_code': 'P',
      'product_title': 'Test product',
      'order_codes': ['O-1'],
      'formulas': [
        {
          'material_id': 'mat-a',
          'material_name': 'Mat A',
          'name': 'A',
          'lines': lines
        },
      ]
    };
Map<String, dynamic> snapshot() => {
      'warehouses': ['Own'],
      'assigned_warehouses': ['Own'],
      'material_warehouses': ['Own'],
      'orders': [],
      'history': [],
      'materials': [
        {'item_code': 'C1', 'name': 'Kley', 'balances': []},
        {'item_code': 'C2', 'name': 'Un', 'balances': []},
      ]
    };
Finder formulaCard() =>
    find.byKey(const ValueKey('preparation-order-formula-mat-a-A'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = fixtures.profile(UserRole.tayyorlovMasteri);
    lines = [
      {'item_code': 'C1', 'name': 'Kley', 'percent': '60.000000'},
      {'item_code': 'C2', 'name': 'Un', 'percent': '40.000000'}
    ];
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets(
      'compact home cards, formula set list, view and edit scoped formula',
      (tester) async {
    var saves = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(fixtures.app(home: const PreparationScreen()));
      await tester.pumpAndSettle();
      expect(find.text('O‘zim yaratgan homashyolar'), findsNothing);
      final materialCard = find.ancestor(
          of: find.text('Homashyolar'),
          matching: find.byType(AdminSummaryCard));
      final orderCard = find.ancestor(
          of: find.text('Buyurtmalar'),
          matching: find.byType(AdminSummaryCard));
      expect(tester.getSize(materialCard).height,
          lessThanOrEqualTo(tester.getSize(orderCard).height));
      await tester.tap(find.text('Formulalar'));
      await tester.pumpAndSettle();
      expect(find.text('950200000001'), findsOneWidget);
      expect(find.text('Test product'), findsOneWidget);
      final row = tester.widget<AdminCatalogListRow>(find.byKey(
          const ValueKey('preparation-formula-set-950200000001')));
      expect(row.title, 'Test product');
      expect(row.subtitle, '950200000001');
      expect(row.value, '1 ta formula');
      expect(tester.getTopLeft(find.text('Test product')).dy,
          lessThan(tester.getTopLeft(find.text('950200000001')).dy));
      await tester
          .tap(find.byKey(const ValueKey('preparation-formula-set-950200000001')));
      await tester.pumpAndSettle();
      final formulaRow = tester.widget<AdminCatalogListRow>(formulaCard());
      expect(formulaRow.title, 'Mat A • A');
      expect(formulaRow.subtitle, 'Kley • 60%\nUn • 40%');
      expect(formulaRow.subtitleMaxLines, 2);
      expect(find.textContaining('boshqa buyurtmalarda'), findsOneWidget);
      await tester.tap(formulaCard());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tahrirlash'));
      await tester.pumpAndSettle();
      expect(find.byType(PreparationOrderFormulaScreen), findsOneWidget);
      for (final entry in [(0, '70'), (1, '30')]) {
        final field =
            find.byKey(ValueKey('preparation-formula-percent-${entry.$1}'));
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.$2);
        await tester.pumpAndSettle();
      }
      final save = find.byKey(const ValueKey('preparation-formula-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saves, 1);
      Navigator.of(tester.element(find.byType(PreparationOrderFormulaScreen)))
          .pop();
      await tester.pumpAndSettle();
      expect(find.text('Kley • 70%\nUn • 30%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/snapshot')) {
                return fixtures.response(snapshot());
              }
              if (request.url.path.endsWith('/formula-sets')) {
                return fixtures.response({
                  'sets': [orderData()]
                });
              }
              expect(request.url.path, '/v1/mobile/preparation/formulas/saved');
              if (request.method == 'PATCH') {
                saves++;
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                expect(body['product_code'], 'P');
                expect(body['material_id'], 'mat-a');
                expect(body['name'], 'A');
                expect(body['lines'], [
                  {'item_code': 'C1', 'percent': '70.000000'},
                  {'item_code': 'C2', 'percent': '30.000000'}
                ]);
                lines = [
                  for (final line in body['lines'] as List)
                    {
                      ...Map<String, dynamic>.from(line as Map),
                      'name': line['item_code'] == 'C1' ? 'Kley' : 'Un'
                    }
                ];
                return fixtures.response(
                    {'product_code': 'P', 'name': 'A', 'lines': lines});
              }
              expect(request.url.queryParameters,
                  {'product_code': 'P', 'material_id': 'mat-a'});
              return fixtures.response({
                'product_code': 'P',
                'formulas': [
                  {'name': 'A', 'lines': lines}
                ]
              });
            }));
  });

  testWidgets(
      'delete confirmation, rejected delete retained, last formula removes order from list',
      (tester) async {
    var attempts = 0;
    var deleted = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(
          fixtures.app(home: const PreparationFormulaOrdersScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('950200000001'));
      await tester.pumpAndSettle();
      Future<void> confirm() async {
        await tester.tap(formulaCard());
        await tester.pumpAndSettle();
        await tester.tap(find.text('O‘chirish'));
        await tester.pumpAndSettle();
      }

      await confirm();
      expect(attempts, 0);
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      expect(attempts, 0);
      await confirm();
      await tester.tap(find.text('O‘chirish'));
      await tester.pumpAndSettle();
      expect(formulaCard(), findsOneWidget);
      expect(attempts, 1);
      ScaffoldMessenger.of(tester.element(formulaCard())).clearSnackBars();
      await tester.pumpAndSettle();
      await confirm();
      await tester.tap(find.text('O‘chirish'));
      await tester.pumpAndSettle();
      expect(formulaCard(), findsOneWidget);
      expect(attempts, 2);
      expect(
          find.text('Formula o‘chirilgani tasdiqlanmadi. Ro‘yxatni yangilang'),
          findsOneWidget);
      await confirm();
      await tester.tap(find.text('O‘chirish'));
      await tester.pumpAndSettle();
      expect(formulaCard(), findsNothing);
      expect(find.text('Bu komplektda formula qolmadi.'), findsOneWidget);
      Navigator.of(tester.element(find.text('Bu komplektda formula qolmadi.')))
          .pop();
      await tester.pumpAndSettle();
      expect(find.text('Saqlangan formulalar yo‘q.'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                return fixtures.response({
                  'sets': deleted ? [] : [orderData()]
                });
              }
              expect(request.method, 'DELETE');
              expect(request.url.path, '/v1/mobile/preparation/formulas/saved');
              expect(request.url.queryParameters,
                  {'product_code': 'P', 'material_id': 'mat-a', 'name': 'A'});
              if (++attempts == 1) {
                return fixtures
                    .response({'error': 'Bu formula uchun ruxsat yo‘q'}, 403);
              }
              if (attempts == 2) return fixtures.response({'deleted': false});
              deleted = true;
              return fixtures.response({'deleted': true});
            }));
  });

  testWidgets(
      'same formula name in two material scopes deletes only selected scope',
      (tester) async {
    final order = orderData();
    (order['formulas'] as List).add({
      'material_id': 'mat-b',
      'material_name': 'Mat B',
      'name': 'A',
      'lines': [
        {'item_code': 'C2', 'name': 'Un', 'percent': '100'}
      ]
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
          fixtures.app(home: const PreparationFormulaOrdersScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('950200000001'));
      await tester.pumpAndSettle();
      final other =
          find.byKey(const ValueKey('preparation-order-formula-mat-b-A'));
      expect(formulaCard(), findsOneWidget);
      expect(other, findsOneWidget);
      await tester.ensureVisible(other);
      await tester.tap(other);
      await tester.pumpAndSettle();
      await tester.tap(find.text('O‘chirish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('O‘chirish'));
      await tester.pumpAndSettle();
      expect(other, findsNothing);
      expect(formulaCard(), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                return fixtures.response({
                  'sets': [order]
                });
              }
              expect(request.url.queryParameters,
                  {'product_code': 'P', 'material_id': 'mat-b', 'name': 'A'});
              return fixtures.response({'deleted': true});
            }));
  });

  testWidgets(
      'orphan legacy formulas can be viewed, edited and deleted by exact identity',
      (tester) async {
    var saves = 0;
    final names = ['A', 'Asosiy'];
    final orphan = {
      'set_id': '950200000002',
      'name': 'Nilo maffin 180 gr',
      'product_code': 'OLD',
      'product_title': 'Nilo maffin 180 gr',
      'order_codes': <String>[],
    };
    await http.runWithClient(() async {
      await tester.pumpWidget(
          fixtures.app(home: const PreparationFormulaOrdersScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mos buyurtma yo‘q'), findsOneWidget);
      expect(find.text('2 ta formula'), findsOneWidget);
      await tester.tap(find.byKey(
          const ValueKey('preparation-formula-set-950200000002')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Eski formula — homashyo turi belgilanmagan'),
          findsNWidgets(2));
      expect(find.text(' • A'), findsNothing);
      final card = find.byKey(const ValueKey('preparation-order-formula--A'));
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tahrirlash'));
      await tester.pumpAndSettle();
      expect(find.byType(PreparationOrderFormulaScreen), findsOneWidget);
      expect(find.text('Formula qo‘shish'), findsNothing);
      final save = find.byKey(const ValueKey('preparation-formula-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saves, 1);
      Navigator.of(tester.element(find.byType(PreparationOrderFormulaScreen)))
          .pop();
      await tester.pumpAndSettle();
      for (final name in ['A', 'Asosiy']) {
        final target = find.byKey(ValueKey('preparation-order-formula--$name'));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        await tester.tap(find.text('O‘chirish'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('O‘chirish'));
        await tester.pumpAndSettle();
        expect(target, findsNothing);
        if (name == 'A') {
          expect(
              find.byKey(const ValueKey('preparation-order-formula--Asosiy')),
              findsOneWidget);
        }
      }
      expect(find.text('Bu komplektda formula qolmadi.'), findsOneWidget);
      Navigator.of(tester.element(find.text('Bu komplektda formula qolmadi.')))
          .pop();
      await tester.pumpAndSettle();
      expect(find.text('Saqlangan formulalar yo‘q.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/snapshot')) {
                return fixtures.response(snapshot());
              }
              if (request.url.path.endsWith('/formula-sets')) {
                return fixtures.response({
                  'sets': names.isEmpty
                      ? []
                      : [
                          {
                            ...orphan,
                            'formulas': [
                              for (final name in names)
                                {
                                  'material_id': '',
                                  'material_name': '',
                                  'name': name,
                                  'lines': lines
                                }
                            ]
                          }
                        ]
                });
              }
              expect(request.url.path, '/v1/mobile/preparation/formulas/saved');
              if (request.method == 'PATCH') {
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                expect(body['material_id'], '');
                expect(body['product_code'], 'OLD');
                expect(body['name'], 'A');
                saves++;
                return fixtures.response(
                    {'product_code': 'OLD', 'name': 'A', 'lines': lines});
              }
              expect(request.url.queryParameters['product_code'], 'OLD');
              expect(request.url.queryParameters['material_id'], '');
              if (request.method == 'DELETE') {
                names.remove(request.url.queryParameters['name']);
                return fixtures.response({'deleted': true});
              }
              return fixtures.response({
                'product_code': 'OLD',
                'formulas': [
                  for (final name in names) {'name': name, 'lines': lines}
                ]
              });
            }));
  });

  testWidgets('list failure has retry, does not pretend list is empty',
      (tester) async {
    var count = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(
          fixtures.app(home: const PreparationFormulaOrdersScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Saqlangan formulalar yo‘q.'), findsNothing);
      await tester.tap(find.text('Qayta urinish'));
      await tester.pumpAndSettle();
      expect(find.text('950200000001'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'absent');
      await tester.pumpAndSettle();
      expect(find.text('Formula komplekti topilmadi.'), findsOneWidget);
    },
        () => MockClient((_) async => ++count == 1
            ? http.Response('Bad gateway', 502)
            : fixtures.response({
                'sets': [orderData()]
              })));
  });

  testWidgets('long press renames a set and searches by ID, name, product and order',
      (tester) async {
    var name = 'Test product';
    var renames = 0;
    const id = '950200000001';
    final card = find.byKey(const ValueKey('preparation-formula-set-$id'));
    await http.runWithClient(() async {
      await tester.pumpWidget(fixtures.app(home: const PreparationFormulaOrdersScreen()));
      await tester.pumpAndSettle();
      expect(find.text(id), findsOneWidget);
      expect(find.text(name), findsOneWidget);
      await tester.longPress(card);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nomini o‘zgartirish'));
      await tester.pumpAndSettle();
      final field = find.byType(TextFormField);
      expect(tester.widget<TextFormField>(field).controller!.text, 'Test product');
      await tester.enterText(field, '   ');
      await tester.tap(find.text('Saqlash'));
      await tester.pumpAndSettle();
      expect(find.text('Nom kiriting'), findsOneWidget);
      expect(renames, 0);
      await tester.enterText(field, 'Qurt maxsus');
      await tester.tap(find.text('Saqlash'));
      await tester.pumpAndSettle();
      expect(renames, 1);
      expect(find.text('Qurt maxsus'), findsOneWidget);
      expect(find.text(id), findsOneWidget);
      expect(find.text('1 ta formula'), findsOneWidget);
      for (final query in [id, 'Qurt maxsus', 'Test product', 'O-1']) {
        await tester.enterText(find.byType(EditableText), query);
        await tester.pumpAndSettle();
        expect(card, findsOneWidget, reason: query);
      }
      await tester.enterText(find.byType(EditableText), '');
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('Qurt maxsus'), findsOneWidget);
      expect(formulaCard(), findsOneWidget);
      Navigator.of(tester.element(formulaCard())).pop();
      await tester.pumpAndSettle();
      expect(find.text('Qurt maxsus'), findsOneWidget);
      expect(find.text(id), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
      expect(request.url.path, '/v1/mobile/preparation/formula-sets');
      if (request.method == 'PATCH') {
        expect(jsonDecode(request.body), {'set_id': id, 'name': 'Qurt maxsus'});
        name = 'Qurt maxsus';
        renames++;
        return fixtures.response({'set_id': id, 'name': name});
      }
      return fixtures.response({'sets': [{...orderData(), 'name': name}]});
    }));
  });

  testWidgets('failed rename retains the set name, ID and formulas', (tester) async {
    const id = '950200000001';
    final card = find.byKey(const ValueKey('preparation-formula-set-$id'));
    await http.runWithClient(() async {
      await tester.pumpWidget(fixtures.app(home: const PreparationFormulaOrdersScreen()));
      await tester.pumpAndSettle();
      await tester.longPress(card);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nomini o‘zgartirish'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Rejected');
      await tester.tap(find.text('Saqlash'));
      await tester.pumpAndSettle();
      expect(find.text('Rejected'), findsNothing);
      expect(find.text('Test product'), findsOneWidget);
      expect(find.text(id), findsOneWidget);
      expect(find.text('1 ta formula'), findsOneWidget);
      expect(find.text('Bu formulani boshqarish huquqingiz yo‘q'), findsOneWidget);
    }, () => MockClient((request) async => request.method == 'PATCH'
        ? fixtures.response({'error': 'Nomni o‘zgartirishga ruxsat yo‘q'}, 403)
        : fixtures.response({'sets': [orderData()]})));
  });
}
