import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_order_formula_screen.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preparation_material_management_test.dart' as fixtures;

Map<String, dynamic> recipe(int index,
        {String? name, bool noOrders = false, bool canCreate = true}) =>
    {
      'id': 'v$index',
      'formula_code': '95040000000$index',
      'name': name ?? 'Variant $index',
      'product_title': 'Mahsulot $index',
      'set_name': 'Mahsulot $index',
      'product_code': 'P$index',
      'material_id': 'mat-a',
      'material_name': 'PE',
      'can_create': canCreate,
      'order_codes': noOrders ? <String>[] : ['O-$index'],
      'formula_count': index == 1 ? 3 : 0,
      'shares_complete': index == 1,
    };

Map<String, dynamic> part(String name) => {
      'formula_code': '95030000000${name.codeUnitAt(0) - 64}',
      'name': name,
      'share_percent': name == 'A' ? '20.000000' : '40.000000',
      'lines': [
        {'item_code': 'C1', 'name': 'Seriya', 'percent': '100.000000'}
      ],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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

  testWidgets(
      'drawer lists one row per named recipe, including an empty recipe',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const PreparationScreen(),
        onGenerateRoute: AppRouter.onGenerateRoute,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(NavigationDrawer),
          matching: find.text('Formulalar')));
      await tester.pumpAndSettle();
      expect(find.byType(PreparationFormulaCatalogScreen), findsOneWidget);
      expect(find.textContaining('Barcha buyurtmalarning formulalari: 3 ta'),
          findsOneWidget);
      expect(find.text('LG'), findsOneWidget);
      expect(find.text('LG • A'), findsNothing);
      for (var i = 1; i <= 3; i++) {
        final row = find.byKey(ValueKey('preparation-catalog-formula-v$i'));
        await tester.ensureVisible(row);
        expect(
            find.descendant(
                of: row, matching: find.textContaining('95040000000$i')),
            findsOneWidget);
      }
      await tester.enterText(find.byType(EditableText), 'O-2');
      await tester.pumpAndSettle();
      expect(find.text('Variant 2'), findsOneWidget);
      expect(find.text('LG'), findsNothing);
      await tester.enterText(find.byType(EditableText), '950400000003');
      await tester.pumpAndSettle();
      expect(find.text('Variant 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/snapshot')) {
                return fixtures.response({
                  'warehouses': [],
                  'materials': [],
                  'orders': [],
                  'history': []
                });
              }
              expect(
                  request.url.path, '/v1/mobile/preparation/formula-catalog');
              return fixtures.response({
                'formulas': [
                  recipe(1, name: 'LG'),
                  recipe(2),
                  recipe(3, noOrders: true)
                ]
              });
            }));
  });

  testWidgets('opening LG shows and manages A, B and C inside the same recipe',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var deleted = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(
          fixtures.app(home: const PreparationFormulaCatalogScreen()));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('preparation-catalog-formula-v1')));
      await tester.pumpAndSettle();
      final screen = tester.widget<PreparationOrderFormulaScreen>(
          find.byType(PreparationOrderFormulaScreen));
      expect(screen.variantId, 'v1');
      expect(screen.variantName, 'LG');
      expect(screen.variantCode, '950400000001');
      expect(find.text('Formula kodi: 950400000001'), findsOneWidget);
      expect(find.text('Ichki formulalar (3)'), findsOneWidget);
      for (final name in ['A', 'B', 'C']) {
        final card = find.byKey(ValueKey('preparation-formula-card-$name'));
        await tester.ensureVisible(card);
        expect(card, findsOneWidget);
      }
      expect(find.textContaining('950300000001'), findsNothing);
      final editB = find.byKey(const ValueKey('preparation-formula-edit-B'));
      await tester.ensureVisible(editB);
      final headerB =
          find.ancestor(of: editB, matching: find.byType(Card)).first;
      await tester.tap(
          find.descendant(of: headerB, matching: find.byTooltip('O‘chirish')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('O‘chirish').last);
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
      expect(find.byKey(const ValueKey('preparation-formula-card-B')),
          findsNothing);
      Navigator.of(tester.element(find.byType(PreparationOrderFormulaScreen)))
          .pop();
      await tester.pumpAndSettle();
      expect(find.text('LG'), findsOneWidget);
      expect(find.textContaining('950400000001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/formula-catalog')) {
                return fixtures.response({
                  'formulas': [recipe(1, name: 'LG')]
                });
              }
              if (request.url.path.endsWith('/snapshot')) {
                return fixtures.response({
                  'warehouses': [],
                  'materials': [],
                  'orders': [],
                  'history': []
                });
              }
              expect(request.url.path, '/v1/mobile/preparation/formulas/saved');
              if (request.method == 'GET') {
                expect(request.url.queryParameters['variant_id'], 'v1');
                return fixtures.response({
                  'product_code': 'P1',
                  'formulas': [part('A'), if (!deleted) part('B'), part('C')]
                });
              }
              expect(request.method, 'DELETE');
              expect(request.url.queryParameters, {
                'product_code': 'P1',
                'material_id': 'mat-a',
                'variant_id': 'v1',
                'name': 'B'
              });
              deleted = true;
              return fixtures.response({'deleted': true});
            }));
  });

  testWidgets('catalog can add an internal formula to the selected recipe',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var created = false;
    final semantics = tester.ensureSemantics();
    await http.runWithClient(() async {
      await tester.pumpWidget(
          fixtures.app(home: const PreparationFormulaCatalogScreen()));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('preparation-catalog-formula-v1')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Amallar'));
      await tester.pumpAndSettle();
      expect(find.text('Ishlab chiqarishni boshlash'), findsNothing);
      await tester.tap(find.text('Ichki formula qo‘shish').last);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('preparation-formula-pick-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seriya').last);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('preparation-formula-percent-0')), '100');
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('preparation-formula-save'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(created, isTrue);
      expect(find.byKey(const ValueKey('preparation-formula-card-D')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/formula-catalog')) {
                return fixtures.response({
                  'formulas': [recipe(1, name: 'LG')]
                });
              }
              if (request.url.path.endsWith('/snapshot')) {
                return fixtures.response({
                  'warehouses': [],
                  'materials': [
                    {'item_code': 'C1', 'name': 'Seriya', 'balances': []}
                  ],
                  'orders': [],
                  'history': []
                });
              }
              if (request.method == 'GET') {
                expect(
                    request.url.path, '/v1/mobile/preparation/formulas/saved');
                return fixtures.response({
                  'product_code': 'P1',
                  'formulas': [
                    part('A'),
                    part('B'),
                    part('C'),
                    if (created) part('D')
                  ]
                });
              }
              expect(request.method, 'POST');
              expect(request.url.path, '/v1/mobile/preparation/formulas');
              expect(request.url.queryParameters['variant_id'], 'v1');
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['name'], 'D');
              expect(body['product_code'], 'P1');
              created = true;
              return fixtures.response({
                'product_code': 'P1',
                'name': 'D',
                'lines': [part('D')['lines'][0]]
              });
            })).whenComplete(semantics.dispose);
  });

  testWidgets(
      'an account change clears formulas and discards an in-flight read',
      (tester) async {
    final reply = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(
          fixtures.app(home: const PreparationFormulaCatalogScreen()));
      await tester.pump();
      AppSession.instance.profile = null;
      AppSession.instance.revision.value++;
      await tester.pump();
      reply.complete(fixtures.response({
        'formulas': [recipe(1)]
      }));
      await tester.pumpAndSettle();
      expect(find.text('Akkaunt o‘zgargan. Sahifani qayta oching'),
          findsOneWidget);
      expect(find.textContaining('950400000001'), findsNothing);
      expect(AppRouter.canOpenRoute(AppRoutes.preparationFormulas), isFalse);
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) => reply.future));
  });
}
