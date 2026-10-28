import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_create_hub_sheet.dart';
import 'package:accord_mobile_v2/src/features/gscale/presentation/gscale_mode_screen.dart';
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

const _variantList = PreparationFormulaVariantsScreen(
  orderId: 'order-1',
  orderCode: '0097',
  productCode: 'P',
  productTitle: 'Mosh',
  materialId: 'pe-pr',
  materialName: 'PE PR',
);

Widget _app({required Widget home, RouteFactory? onGenerateRoute}) {
  final base = fixtures.app(home: home) as MaterialApp;
  return MaterialApp(
    theme: base.theme,
    locale: base.locale,
    localizationsDelegates: base.localizationsDelegates,
    supportedLocales: base.supportedLocales,
    home: home,
    onGenerateRoute: onGenerateRoute,
  );
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.tayyorlovMasteri,
      displayName: 'Master',
      legalName: '',
      ref: 'prep-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['preparation.access', 'gscale.print'],
    );
    adminCreateHubMenuOpen.value = false;
  });

  tearDown(() {
    adminCreateHubMenuOpen.value = false;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets(
      'variant detail FAB opens receipt with original order and target material',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final api = variants.VariantApi();
    GScaleModeScreen? destination;
    final writes = <http.Request>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(
        home: _variantList,
        onGenerateRoute: (settings) {
          expect(settings.name, AppRoutes.gscaleMode);
          final route =
              AppRouter.onGenerateRoute(settings) as MaterialPageRoute;
          destination = route.builder(
                  tester.element(find.byType(PreparationOrderFormulaScreen)))
              as GScaleModeScreen;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Homashyo kirimi')),
          );
        },
      ));
      await tester.pumpAndSettle();
      await tester.tap(
          find.byKey(const ValueKey('preparation-formula-variant-legacy')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Amallar'));
      await tester.pumpAndSettle();
      expect(find.text('Shnek formula qo‘shish'), findsWidgets);
      await tester.tap(find.text('Ishlab chiqarishni boshlash').last);
      await tester.pumpAndSettle();

      expect(find.text('Homashyo kirimi'), findsOneWidget);
      expect(destination!.initialOrder!.id, 'order-1');
      expect(destination!.initialOrder!.code, '0097');
      expect(destination!.initialOrder!.title, 'Mosh');
      expect(destination!.initialMaterialId, 'pe-pr');
      expect(destination!.initialMaterialName, 'PE PR');
      expect(destination!.initialFormulaVariantId, 'legacy');
      expect(destination!.initialWarehouse, isNull);
      expect(destination!.freshForm, isTrue);
      expect(AppSession.instance.profile!.role, UserRole.tayyorlovMasteri);
      expect(writes, isEmpty);
      Navigator.of(tester.element(find.text('Homashyo kirimi'))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(PreparationOrderFormulaScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) {
              if (request.method != 'GET') writes.add(request);
              return api.respond(request);
            })).whenComplete(semantics.dispose);
  });

  testWidgets('formula library management does not offer order receipt start',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(
        home: const PreparationOrderFormulaScreen(
          orderId: 'formula-set',
          orderCode: 'formula-set',
          productCode: 'P',
          productTitle: 'Mosh',
          materialId: 'pe-pr',
          materialName: 'PE PR',
          manageSavedFormula: true,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Amallar'), findsNothing);
      expect(find.text('Ishlab chiqarishni boshlash'), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async => fixtures.response({
              'warehouses': [],
              'materials': [],
              'history': [],
              'orders': [],
              'formulas': [],
            })));
  });

  testWidgets('receipt action requires existing kirim route permission',
      (tester) async {
    final semantics = tester.ensureSemantics();
    AppSession.instance.profile = fixtures.profile(UserRole.tayyorlovMasteri);
    final api = variants.VariantApi();
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(home: _variantList));
      await tester.pumpAndSettle();
      await tester.tap(
          find.byKey(const ValueKey('preparation-formula-variant-legacy')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Amallar'));
      await tester.pumpAndSettle();
      expect(find.text('Ishlab chiqarishni boshlash'), findsNothing);
      expect(find.text('Shnek formula qo‘shish'), findsWidgets);
      await tester.tap(find.text('Shnek formula qo‘shish').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, () => MockClient(api.respond)).whenComplete(semantics.dispose);
  });
}
