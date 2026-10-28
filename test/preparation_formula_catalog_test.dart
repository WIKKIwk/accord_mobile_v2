import 'dart:async';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preparation_material_management_test.dart' as fixtures;

Map<String, dynamic> formulaSet(int index, {bool noOrders = false}) => {
      'set_id': '95020000000$index',
      'name': 'Mahsulot $index',
      'product_title': 'Mahsulot $index',
      'product_code': 'P$index',
      'order_codes': noOrders ? <String>[] : ['O-$index'],
      'formulas': [
        {
          'formula_code': '95030000000$index',
          'name': 'A',
          'material_id': 'mat-a',
          'material_name': 'PE',
          'variant_id': 'v$index',
          'variant_name': 'Variant $index',
          'share_percent': '100.000000',
          'lines': [
            {'item_code': 'C1', 'name': 'Seriya', 'percent': '100.000000'}
          ],
        }
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

  testWidgets('drawer opens every saved formula with its own code',
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
      for (var i = 1; i <= 3; i++) {
        final row =
            find.byKey(ValueKey('preparation-catalog-formula-95030000000$i'));
        await tester.ensureVisible(row);
        expect(find.descendant(of: row, matching: find.text('Variant $i • A')),
            findsOneWidget);
        expect(
            find.descendant(
                of: row, matching: find.textContaining('95030000000$i')),
            findsOneWidget);
      }
      await tester.enterText(find.byType(EditableText), 'O-2');
      await tester.pumpAndSettle();
      expect(find.text('Variant 2 • A'), findsOneWidget);
      expect(find.text('Variant 1 • A'), findsNothing);
      await tester.enterText(find.byType(EditableText), '950300000003');
      await tester.pumpAndSettle();
      expect(find.text('Variant 3 • A'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/snapshot')) {
                return fixtures.response({
                  'warehouses': [],
                  'materials': [],
                  'orders': [],
                  'history': [],
                });
              }
              expect(request.url.path, '/v1/mobile/preparation/formula-sets');
              return fixtures.response({
                'sets': [
                  formulaSet(1),
                  formulaSet(2),
                  formulaSet(3, noOrders: true)
                ]
              });
            }));
  });

  testWidgets(
      'catalog manages the exact formula in another product and variant',
      (tester) async {
    var deleted = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(
          fixtures.app(home: const PreparationFormulaCatalogScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), '950300000002');
      await tester.pumpAndSettle();
      await tester.tap(find
          .byKey(const ValueKey('preparation-catalog-formula-950300000002')));
      await tester.pumpAndSettle();
      final sheet =
          find.byKey(const ValueKey('preparation-formula-info-sheet'));
      expect(find.descendant(of: sheet, matching: find.text('950300000002')),
          findsOneWidget);
      await tester.tap(find.byTooltip('O‘chirish'));
      await tester.pumpAndSettle();
      expect(find.textContaining('boshqa buyurtmalarda'), findsOneWidget);
      await tester.tap(find.text('O‘chirish').last);
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
      expect(find.text('Formula topilmadi.'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '');
      await tester.pumpAndSettle();
      expect(find.text('Variant 1 • A'), findsOneWidget);
      expect(find.text('Variant 2 • A'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/formula-sets')) {
                return fixtures.response({
                  'sets': [formulaSet(1), if (!deleted) formulaSet(2)]
                });
              }
              expect(request.method, 'DELETE');
              expect(request.url.path, '/v1/mobile/preparation/formulas/saved');
              expect(request.url.queryParameters, {
                'product_code': 'P2',
                'material_id': 'mat-a',
                'variant_id': 'v2',
                'name': 'A',
              });
              deleted = true;
              return fixtures.response({'deleted': true});
            }));
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
        'sets': [formulaSet(1)]
      }));
      await tester.pumpAndSettle();
      expect(find.text('Akkaunt o‘zgargan. Sahifani qayta oching'),
          findsOneWidget);
      expect(find.textContaining('950300000001'), findsNothing);
      expect(AppRouter.canOpenRoute(AppRoutes.preparationFormulas), isFalse);
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) => reply.future));
  });
}
