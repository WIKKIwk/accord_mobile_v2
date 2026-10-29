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

import 'preparation_formula_variants_test.dart' as variants;
import 'preparation_material_management_test.dart' as fixtures;

class _ActionsApi extends variants.VariantApi {
  _ActionsApi() {
    this.variants.add({'id': 'empty', 'name': '0209', 'formula_count': 0});
  }
  final removed = <String>{};
  final deletes = <Map<String, String>>[];
  bool failNext = false;

  @override
  Future<http.Response> respond(http.Request request) async {
    final query = request.url.queryParameters;
    if (request.url.path.endsWith('/formula-variants') &&
        request.method == 'GET') {
      expect(query['product_code'], 'P');
      expect(query['material_id'], 'pe-pr');
      expect(query['order_id'], isNotEmpty);
      return fixtures.response({
        'product_code': 'P',
        'material_id': 'pe-pr',
        'variants': this
            .variants
            .where((v) => !removed.contains('${query['order_id']}:${v['id']}'))
            .toList(),
      });
    }
    if (request.url.path.endsWith('/formula-variants/order')) {
      expect(request.method, 'DELETE');
      expect(query, {
        'order_id': 'order-1',
        'product_code': 'P',
        'material_id': 'pe-pr',
        'variant_id': 'legacy'
      });
      deletes.add(query);
      if (failNext) {
        failNext = false;
        return fixtures.response({'error': 'Olib tashlash bajarilmadi'}, 409);
      }
      removed.add('${query['order_id']}:${query['variant_id']}');
      return fixtures.response({
        'removed': true,
        'order_id': query['order_id'],
        'variant_id': query['variant_id']
      });
    }
    return super.respond(request);
  }
}

Widget _page({String order = 'order-1', int revision = 0}) => fixtures.app(
      home: PreparationFormulaVariantsScreen(
        key: ValueKey('$order:$revision'),
        orderId: order,
        orderCode: '0097',
        productCode: 'P',
        productTitle: 'Mosh',
        materialId: 'pe-pr',
        materialName: 'PE PR',
      ),
    );

Future<void> _withApi(
    WidgetTester tester, _ActionsApi api, Future<void> Function() body) async {
  await http.runWithClient(() async {
    try {
      await tester.pumpWidget(_page());
      await tester.pumpAndSettle();
      await body();
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  }, () => MockClient(api.respond));
}

Future<void> _actions(WidgetTester tester, {String id = 'legacy'}) async {
  await tester
      .longPress(find.byKey(ValueKey('preparation-formula-variant-$id')));
  await tester.pumpAndSettle();
  expect(find.text('Tahrirlash'), findsOneWidget);
  expect(find.text('O‘chirish'), findsOneWidget);
}

Future<void> _delete(WidgetTester tester) async {
  await _actions(tester);
  await tester.tap(find.text('O‘chirish'));
  await tester.pumpAndSettle();
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

  for (final empty in [false, true]) {
    testWidgets(
        'long press opens details with composition editing, empty=$empty',
        (tester) async {
      final api = _ActionsApi();
      await _withApi(tester, api, () async {
        await _actions(tester, id: empty ? 'empty' : 'legacy');
        await tester.tap(find.text('Tahrirlash'));
        await tester.pumpAndSettle();
        final editor = tester.widget<PreparationOrderFormulaScreen>(
            find.byType(PreparationOrderFormulaScreen));
        expect(editor.variantId, empty ? 'empty' : 'legacy');
        expect(editor.openEditorOnLoad, isTrue);
        expect(find.text(empty ? 'Yangi formula' : '«A»'), findsOneWidget);
        expect(api.deletes, isEmpty);
        expect(api.creates, isEmpty);
      });
    });
  }

  testWidgets('deletion persists only for the selected order', (tester) async {
    final api = _ActionsApi();
    await _withApi(tester, api, () async {
      await _delete(tester);
      expect(api.deletes, isEmpty);
      await tester.tap(
          find.byKey(const ValueKey('preparation-variant-remove-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preparation-formula-variant-legacy')),
          findsNothing);
      expect(find.text('0209'), findsOneWidget);
      await tester.pumpWidget(_page(revision: 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preparation-formula-variant-legacy')),
          findsNothing);
      await tester.pumpWidget(_page(order: 'order-2'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preparation-formula-variant-legacy')),
          findsOneWidget);
      expect(api.deletes, hasLength(1));
      expect(api.variants, hasLength(2));
    });
  });

  testWidgets('cancel keeps the order formula', (tester) async {
    final api = _ActionsApi();
    await _withApi(tester, api, () async {
      await _delete(tester);
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();
      expect(api.deletes, isEmpty);
      expect(find.byKey(const ValueKey('preparation-formula-variant-legacy')),
          findsOneWidget);
    });
  });

  testWidgets('failed deletion retains the row and can be retried',
      (tester) async {
    final api = _ActionsApi()..failNext = true;
    await _withApi(tester, api, () async {
      await _delete(tester);
      await tester.tap(
          find.byKey(const ValueKey('preparation-variant-remove-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Olib tashlash bajarilmadi'), findsOneWidget);
      expect(find.byKey(const ValueKey('preparation-formula-variant-legacy')),
          findsOneWidget);
      await _delete(tester);
      await tester.tap(
          find.byKey(const ValueKey('preparation-variant-remove-confirm')));
      await tester.pumpAndSettle();
      expect(api.deletes, hasLength(2));
      expect(find.byKey(const ValueKey('preparation-formula-variant-legacy')),
          findsNothing);
    });
  });

  testWidgets('account switch cannot remove a formula from the previous order',
      (tester) async {
    final api = _ActionsApi();
    await _withApi(tester, api, () async {
      await _delete(tester);
      AppSession.instance.profile =
          AppSession.instance.profile!.copyWith(ref: 'other-master');
      await tester.tap(
          find.byKey(const ValueKey('preparation-variant-remove-confirm')));
      await tester.pumpAndSettle();
      expect(api.deletes, isEmpty);
      expect(find.byKey(const ValueKey('preparation-formula-variant-legacy')),
          findsOneWidget);
    });
  });
}
