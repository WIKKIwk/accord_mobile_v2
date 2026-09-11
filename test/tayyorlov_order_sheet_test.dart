import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _godexId = 'apparatus:test:godex-demo';

ProductionMapDefinition _tayyorlovOrderMap() {
  return const ProductionMapDefinition(
    id: 'zakaz-tayyorlov-summary-only',
    productCode: 'SUPPLY-TAYYORLOV',
    title: 'Tayyorlov summary order',
    orderNumber: '0003',
    rollCount: 6,
    widthMm: 1265,
    orderKg: 100,
    baseLength: 8000,
    nodes: const [
      ProductionMapNode(id: 'start', kind: 'start', title: 'Start'),
      ProductionMapNode(
        id: 'apparatus',
        kind: 'apparatus',
        title: 'Laminatsiya 1',
        apparatusId: _godexId,
      ),
      ProductionMapNode(
        id: 'end',
        kind: 'end',
        title: 'Candy Gold • Nilo maffin 180 gr',
        itemCode: 'SUPPLY-TAYYORLOV',
      ),
    ],
    edges: const [
      ProductionMapEdge(from: 'start', to: 'apparatus'),
      ProductionMapEdge(from: 'apparatus', to: 'end'),
    ],
  );
}

Future<void> _pumpSupplySequence(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    const MaterialApp(
      locale: Locale('uz'),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        supplyViewerMode: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byType(FilterChip).first);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(
      const ValueKey('admin-filter-option-Godex aparat - DEMO'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openOrderSheet(WidgetTester tester) async {
  expect(find.textContaining('Tayyorlov summary order'), findsOneWidget);
  await tester.tap(find.byTooltip('Buyurtma ma’lumotlari'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    resetMobileApiTestModeData();
    AppSession.instance.token = 'token';
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets(
    'tayyorlov masteri sheet shows only expected order metrics',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      await MobileApi.instance.adminSaveProductionMap(_tayyorlovOrderMap());
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.tayyorlovMasteri,
        displayName: 'Tayyorlov masteri',
        legalName: '',
        ref: 'tayyorlov-1',
        phone: '',
        avatarUrl: '',
        capabilities: ['preparation.access'],
      );
      await _pumpSupplySequence(tester);
      await _openOrderSheet(tester);

      // Sarlavha + ko'rsatkichlar darhol ko'rinadi (bosmasdan).
      expect(find.text('Zakaz kodi'), findsOneWidget);
      expect(
        find.text('Kutilayotgan buyurtma ko‘rsatkichlari'),
        findsOneWidget,
      );
      expect(find.text('Metraj'), findsOneWidget);
      expect(find.text('Og‘irlik'), findsOneWidget);
      expect(find.text('Val'), findsOneWidget);

      // Ortiqcha bo'limlar bu rol uchun yashiriladi.
      expect(find.text('Biriktirilgan homashyolar'), findsNothing);
      expect(find.text('Biriktirilgan qoliplar'), findsNothing);
      expect(find.text('Mapni ko‘rish'), findsNothing);
      expect(
        find.byKey(const ValueKey('production-materials-expansion')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('production-attached-qolips-expansion')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'qolipchi sheet still shows full order sections',
    (tester) async {
      await TestModeController.instance.setEnabled(true);
      await MobileApi.instance.adminSaveProductionMap(_tayyorlovOrderMap());
      await MobileApi.instance.qolipSaveProductSpec(
        product: const QolipProduct(
          code: 'SUPPLY-TAYYORLOV',
          name: 'Tayyorlov summary product',
          itemGroup: 'Tayyor mahsulotlar',
        ),
        qolipCode: 'QOLIP-TAYYORLOV-1',
        size: 40,
      );
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        displayName: 'Qolipchi',
        legalName: '',
        ref: 'qolipchi-1',
        phone: '',
        avatarUrl: '',
        capabilities: ['qolip.manage'],
      );
      await _pumpSupplySequence(tester);
      await _openOrderSheet(tester);

      // Boshqa rollar uchun to'liq sheet o'zgarishsiz qoladi.
      expect(find.text('Zakaz kodi'), findsOneWidget);
      // Homashyo bo'limi sarlavhasi yuklanish holatiga qarab o'zgaradi,
      // shuning uchun mavjudligini kalit orqali tekshiramiz.
      expect(
        find.byKey(const ValueKey('production-materials-expansion')),
        findsOneWidget,
      );
      expect(find.text('Biriktirilgan qoliplar'), findsOneWidget);
      expect(
        find.text('Kutilayotgan buyurtma ko‘rsatkichlari'),
        findsOneWidget,
      );
      // Qolipchida ko'rsatkichlar yig'ilgan holda ochiladi.
      expect(find.text('Metraj'), findsNothing);
      expect(find.text('Mapni ko‘rish'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
