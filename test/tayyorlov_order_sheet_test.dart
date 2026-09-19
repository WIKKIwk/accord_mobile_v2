import 'dart:convert';

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
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _godexId = 'apparatus:test:godex-demo';
const _tayyorlovProfile = SessionProfile(
  role: UserRole.tayyorlovMasteri,
  displayName: 'Tayyorlov masteri',
  legalName: '',
  ref: 'tayyorlov-1',
  phone: '',
  avatarUrl: '',
  capabilities: ['preparation.access'],
);

MockClient _preparationClient({
  List<String> allowedIds = const ['zakaz-tayyorlov-summary-only'],
  int materialsStatus = 200,
  int snapshotStatus = 200,
}) {
  return MockClient((request) async {
    final snapshot = request.url.path == '/v1/mobile/preparation/snapshot';
    expect(
      request.url.path,
      snapshot
          ? '/v1/mobile/preparation/snapshot'
          : '/v1/mobile/preparation/order-materials',
    );
    return http.Response(
      jsonEncode(snapshot
          ? {
              'materials': [],
              'history': [],
              'orders': [
                for (final id in allowedIds)
                  {'id': id, 'code': id, 'title': id, 'order_kg': '100'},
              ],
              'responsibilities': [
                {'material_id': 'builtin-pe', 'material_name': 'PE'},
              ],
            }
          : {
              'order_id': request.url.queryParameters['order_id'],
              'materials': [],
              'error': 'Homashyoni yuklab bo‘lmadi',
            }),
      snapshot ? snapshotStatus : materialsStatus,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

ProductionMapDefinition _tayyorlovOrderMap({
  String id = 'zakaz-tayyorlov-summary-only',
  String title = 'Tayyorlov summary order',
  String orderNumber = '0003',
}) {
  return ProductionMapDefinition(
    id: id,
    productCode: 'SUPPLY-TAYYORLOV',
    title: title,
    orderNumber: orderNumber,
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
    (tester) => http.runWithClient(() async {
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
    }, _preparationClient),
  );

  for (final snapshotStatus in [200, 503]) {
    testWidgets(
        'tayyorlov list respects material scope ($snapshotStatus)',
        (tester) => http.runWithClient(() async {
              await TestModeController.instance.setEnabled(true);
              await MobileApi.instance
                  .adminSaveProductionMap(_tayyorlovOrderMap());
              await MobileApi.instance
                  .adminSaveProductionMap(_tayyorlovOrderMap(
                id: 'zakaz-unassigned',
                title: 'Unassigned material order',
                orderNumber: '0004',
              ));
              AppSession.instance.profile = _tayyorlovProfile;
              await _pumpSupplySequence(tester);
              expect(find.textContaining('Unassigned material order'),
                  findsNothing);
              expect(find.textContaining('Tayyorlov summary order'),
                  snapshotStatus == 200 ? findsOneWidget : findsNothing);
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
            }, () => _preparationClient(snapshotStatus: snapshotStatus)));
  }

  for (final materialsStatus in [200, 503]) {
    testWidgets(
        'formula notice appears above the open sheet ($materialsStatus)',
        (tester) => http.runWithClient(() async {
              await TestModeController.instance.setEnabled(true);
              await MobileApi.instance
                  .adminSaveProductionMap(_tayyorlovOrderMap());
              AppSession.instance.profile = _tayyorlovProfile;
              await _pumpSupplySequence(tester);
              await _openOrderSheet(tester);
              await tester
                  .tap(find.byKey(const ValueKey('tayyorlov-formula-button')));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              final notice = find.textContaining(materialsStatus == 200
                  ? 'Bu orderda sizga biriktirilgan homashyo topilmadi.'
                  : 'Homashyoni yuklab bo‘lmadi');
              expect(notice, findsOneWidget,
                  reason: tester
                      .widgetList<Text>(find.byType(Text))
                      .map((text) => text.data)
                      .join(' | '));
              expect(find.byType(SnackBar), findsNothing);
              expect(find.text('Zakaz kodi'), findsOneWidget);
              final sheetRect = tester.getRect(find.byType(BottomSheet).last);
              expect(sheetRect.contains(tester.getCenter(notice)), isTrue);
              // Notices live in the root overlay, not in the covered page scaffold.
              final banner = tester.element(find.ancestor(
                of: notice,
                matching: find.byType(MaterialBanner),
              ));
              expect(banner.findAncestorWidgetOfExactType<Scaffold>(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pumpAndSettle();
            }, () => _preparationClient(materialsStatus: materialsStatus)));
  }

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
