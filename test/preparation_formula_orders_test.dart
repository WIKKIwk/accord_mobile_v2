import 'dart:convert';

import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
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
          'share_percent': '100.000000',
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

MockClient legacyClient(Future<http.Response> Function(http.Request) handler) =>
    MockClient((request) => request.url.path.endsWith('/formula-catalog')
        ? Future.value(fixtures.response({'formulas': []}))
        : handler(request));

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

  testWidgets('product lists recipes once and opens their own internal formulas',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var deleted = false;

    Map<String, dynamic> recipe(String id, String product, String material,
            {bool canCreate = true}) =>
        {
          'id': id,
          'formula_code': '95040000000${id.substring(1)}',
          'name': 'LG',
          'product_code': product,
          'product_title': 'Test product',
          'set_name': 'Test product',
          'material_id': material,
          'material_name': material == 'mat-a' ? 'PE PR' : 'PE',
          'order_codes': ['O-1'],
          'can_create': canCreate,
        };

    Map<String, dynamic> part(String name) => {
          'name': name,
          'share_percent': '30.000000',
          'lines': lines,
        };

    await http.runWithClient(() async {
      await tester.pumpWidget(
          fixtures.app(home: const PreparationFormulaOrdersScreen()));
      await tester.pumpAndSettle();
      final product = find.byKey(
          const ValueKey('preparation-formula-set-950200000001'));
      expect(tester.widget<AdminCatalogListRow>(product).value, '2 ta formula');
      await tester.tap(product);
      await tester.pumpAndSettle();

      final lg = find.byKey(const ValueKey('preparation-product-recipe-v1'));
      final shell = tester.widget<AppShell>(
          find.ancestor(of: lg, matching: find.byType(AppShell)).first);
      expect(shell.title, 'Test product');
      expect(shell.subtitle, '950200000001');
      final otherMaterial =
          find.byKey(const ValueKey('preparation-product-recipe-v2'));
      expect(lg, findsOneWidget);
      expect(otherMaterial, findsOneWidget);
      expect(find.byKey(const ValueKey('preparation-product-recipe-v3')),
          findsNothing);
      expect(tester.widget<AdminCatalogListRow>(lg).title, 'LG');
      expect(tester.widget<AdminCatalogListRow>(lg).subtitle,
          '950400000001 • PE PR');
      expect(find.text('LG • PE PR • A'), findsNothing);
      expect(find.text('LG • PE PR • B'), findsNothing);
      expect(find.text('LG • PE PR • C'), findsNothing);

      await tester.tap(lg);
      await tester.pumpAndSettle();
      var screen = tester.widget<PreparationOrderFormulaScreen>(
          find.byType(PreparationOrderFormulaScreen));
      expect(screen.variantId, 'v1');
      expect(screen.variantName, 'LG');
      expect(screen.variantCode, '950400000001');
      expect(screen.materialId, 'mat-a');
      expect(screen.allowAddingFormula, isTrue);
      for (final name in ['A', 'B', 'C']) {
        final card = find.byKey(ValueKey('preparation-formula-card-$name'));
        await tester.ensureVisible(card);
        expect(card, findsOneWidget);
      }
      final cardB = find.byKey(const ValueKey('preparation-formula-card-B'));
      await tester.ensureVisible(cardB);
      await tester.tap(find.descendant(
          of: cardB, matching: find.byTooltip('O‘chirish')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('O‘chirish').last);
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
      expect(cardB, findsNothing);
      Navigator.of(tester.element(find.byType(PreparationOrderFormulaScreen)))
          .pop();
      await tester.pumpAndSettle();
      expect(lg, findsOneWidget);
      expect(otherMaterial, findsOneWidget);

      await tester.tap(otherMaterial);
      await tester.pumpAndSettle();
      screen = tester.widget<PreparationOrderFormulaScreen>(
          find.byType(PreparationOrderFormulaScreen));
      expect(screen.variantId, 'v2');
      expect(screen.materialId, 'mat-b');
      expect(screen.allowAddingFormula, isFalse);
      expect(find.text('Bu formulada ichki tarkib yo‘q.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
          if (request.url.path.endsWith('/formula-sets')) {
            return fixtures.response({
              'sets': [
                {
                  ...orderData(),
                  'formulas': [
                    for (final name in ['A', 'B', 'C'])
                      if (!deleted || name != 'B')
                        {
                          'material_id': 'mat-a',
                          'material_name': 'PE PR',
                          'variant_id': 'v1',
                          'variant_name': 'LG',
                          ...part(name),
                        },
                  ],
                }
              ],
            });
          }
          if (request.url.path.endsWith('/formula-catalog')) {
            return fixtures.response({
              'formulas': [
                recipe('v1', 'P', 'mat-a'),
                recipe('v2', 'P', 'mat-b', canCreate: false),
                recipe('v3', 'OTHER', 'mat-a'),
              ],
            });
          }
          if (request.url.path.endsWith('/snapshot')) {
            return fixtures.response(snapshot());
          }
          expect(request.url.path, '/v1/mobile/preparation/formulas/saved');
          if (request.method == 'DELETE') {
            expect(request.url.queryParameters, {
              'product_code': 'P',
              'material_id': 'mat-a',
              'variant_id': 'v1',
              'name': 'B',
            });
            deleted = true;
            return fixtures.response({'deleted': true});
          }
          expect(request.url.queryParameters['product_code'], 'P');
          final variant = request.url.queryParameters['variant_id'];
          expect(request.url.queryParameters['material_id'],
              variant == 'v1' ? 'mat-a' : 'mat-b');
          return fixtures.response({
            'product_code': 'P',
            'formulas': variant == 'v1'
                ? [part('A'), if (!deleted) part('B'), part('C')]
                : [],
          });
        }));
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
      await tester.tap(find.text('Mahsulot formulasi'));
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
      expect(formulaRow.subtitle, 'Shnek ulushi: 100%\nKley • 60%\nUn • 40%');
      expect(formulaRow.subtitleMaxLines, 3);
      expect(find.textContaining('boshqa buyurtmalarda'), findsOneWidget);
      await tester.tap(formulaCard());
      await tester.pumpAndSettle();
      expect(find.text('Formula ma’lumotlari'), findsOneWidget);
      expect(find.text('Kley'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('Un'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byType(PreparationOrderFormulaScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('preparation-formula-card-A')));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byTooltip('Tahrirlash'));
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
      expect(find.text('Shnek ulushi: 100%\nKley • 70%\nUn • 30%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => legacyClient((request) async {
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

  testWidgets('saved formula opens details and only its pencil opens the editor',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(fixtures.app(
        home: const PreparationOrderFormulaScreen(
          orderId: 'order-1',
          orderCode: 'O-1',
          productCode: 'P',
          productTitle: 'Test product',
          materialId: 'mat-a',
          materialName: 'Mat A',
        ),
      ));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('preparation-formula-card-A'));
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(card);
      await tester.pumpAndSettle();
      final details =
          find.byKey(const ValueKey('preparation-formula-info-sheet'));
      expect(details, findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.descendant(of: details, matching: find.text('Kley')),
          findsOneWidget);
      expect(find.descendant(of: details, matching: find.text('60%')),
          findsOneWidget);
      await tester.tap(find.descendant(
          of: details, matching: find.byTooltip('Tahrirlash')));
      await tester.pumpAndSettle();
      expect(details, findsNothing);
      expect(
          find.byKey(const ValueKey('preparation-formula-percent-0')),
          findsOneWidget);
      await tester.tap(find.byTooltip('Bekor qilish'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNothing);
      expect(card, findsOneWidget);
      expect(tester.takeException(), isNull);
    }, () => legacyClient((request) async {
      expect(request.method, 'GET');
      if (request.url.path.endsWith('/snapshot')) {
        return fixtures.response(snapshot());
      }
      return fixtures.response({
        'product_code': 'P',
        'formulas': [
          {'name': 'A', 'lines': lines}
        ],
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
        await tester.tap(find.byTooltip('O‘chirish'));
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
        () => legacyClient((request) async {
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
      await tester.tap(find.byTooltip('O‘chirish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('O‘chirish'));
      await tester.pumpAndSettle();
      expect(other, findsNothing);
      expect(formulaCard(), findsOneWidget);
    },
        () => legacyClient((request) async {
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
      await tester.tap(find.byTooltip('Tahrirlash'));
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
        await tester.tap(find.byTooltip('O‘chirish'));
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
        () => legacyClient((request) async {
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
        () => legacyClient((_) async => ++count == 1
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
    }, () => legacyClient((request) async {
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
    }, () => legacyClient((request) async => request.method == 'PATCH'
        ? fixtures.response({'error': 'Nomni o‘zgartirishga ruxsat yo‘q'}, 403)
        : fixtures.response({'sets': [orderData()]})));
  });
}
