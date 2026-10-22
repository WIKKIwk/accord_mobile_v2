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

const formula = {
  'name': 'A',
  'share_percent': '100.000000',
  'lines': [
    {'item_code': 'C1', 'name': '0209', 'percent': '10.000000'},
    {'item_code': 'C2', 'name': '11503', 'percent': '20.000000'},
    {'item_code': 'C3', 'name': '2426H', 'percent': '70.000000'},
  ],
};

Widget screen(String orderId) => fixtures.app(
      home: PreparationOrderFormulaScreen(
        orderId: orderId,
        orderCode: orderId,
        productCode: 'P',
        productTitle: 'Product',
        materialId: 'pe-pr',
        materialName: 'PE PR',
      ),
    );

MockClient client(String? kg, {bool failed = false}) =>
    MockClient((request) async {
      expect(request.method, 'GET');
      if (request.url.path.endsWith('/snapshot')) {
        return fixtures.response({
          'warehouses': [], 'materials': [], 'history': [],
          // The whole order's weight must not be used as the material weight.
          'orders': [
            {'id': '0278', 'code': '0278', 'order_kg': '1000.000000'}
          ],
        });
      }
      if (request.url.path.endsWith('/order-materials')) {
        if (failed) return http.Response('{}', 503);
        return fixtures.response({
          'order_id': request.url.queryParameters['order_id'],
          'materials': [
            {
              'material_id': 'opp',
              'material_name': 'OPP',
              'estimated_kg': '208.674900'
            },
            {
              'material_id': 'pe-pr',
              'material_name': 'PE PR',
              if (kg != null) 'estimated_kg': kg
            },
          ],
        });
      }
      expect(request.url.path, '/v1/mobile/preparation/formulas');
      return fixtures.response({
        'product_code': 'P',
        'formulas': [formula]
      });
    });

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

  test('estimated kg display rounds hundredths without a false zero', () {
    expect(preparationEstimatedKgDisplay('824.964000'), '824.96');
    expect(preparationEstimatedKgDisplay('82.496400'), '82.50');
    expect(preparationEstimatedKgDisplay('0.005000'), '0.01');
    expect(preparationEstimatedKgDisplay('0.000001'), '< 0.01');
  });

  for (final sample in [
    ('0278', '824.964000', ['82.50', '164.99', '577.47']),
    ('0277', '860.384000', ['86.04', '172.08', '602.27']),
  ]) {
    testWidgets(
        'order ${sample.$1} shows its own kg beside shared recipe percentages',
        (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(screen(sample.$1));
        await tester.pumpAndSettle();
        expect(
            find.text(
                'PE PR: ≈ ${preparationEstimatedKgDisplay(sample.$2)} kg (taxminiy)'),
            findsOneWidget);
        for (final kg in sample.$3) {
          expect(find.text('≈ $kg kg'), findsOneWidget);
        }
        expect(find.text('10%'), findsOneWidget);
        expect(find.text('20%'), findsOneWidget);
        expect(find.text('70%'), findsOneWidget);
        await tester
            .tap(find.byKey(const ValueKey('preparation-formula-card-A')));
        await tester.pumpAndSettle();
        final details =
            find.byKey(const ValueKey('preparation-formula-info-sheet'));
        expect(details, findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        for (final kg in sample.$3) {
          expect(find.descendant(of: details, matching: find.text('≈ $kg kg')),
              findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }, () => client(sample.$2));
    });
  }

  for (final failed in [false, true]) {
    testWidgets(
        'unavailable estimate keeps percentages and does not use overall order kg ($failed)',
        (tester) async {
      await http.runWithClient(() async {
        await tester.pumpWidget(screen('0278'));
        await tester.pumpAndSettle();
        expect(
            find.text('Taxminiy kg hisobi hozir mavjud emas'), findsOneWidget);
        expect(find.text('10%'), findsOneWidget);
        expect(find.text('20%'), findsOneWidget);
        expect(find.text('70%'), findsOneWidget);
        expect(find.textContaining('≈'), findsNothing);
        expect(tester.takeException(), isNull);
      }, () => client(null, failed: failed));
    });
  }
}
