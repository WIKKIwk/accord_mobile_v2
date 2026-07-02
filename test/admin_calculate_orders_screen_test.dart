import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_calculate_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/state/calculate_order_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestModeController.instance.setEnabled(true);
    resetMobileApiTestModeData();
    await CalculateOrderTemplateStore.instance.debugReset();
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('quick orders list hides templates without existing source map', (
    tester,
  ) async {
    await MobileApi.instance.adminSaveProductionMap(
      _map(id: 'quick-valid-map', code: '1001', orderNumber: '1001'),
    );
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _template(
          code: 'Z-VALID', name: 'Valid quick', sourceMapId: 'quick-valid-map'),
    );
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _template(
          code: 'Z-MISSING', name: 'Missing quick', sourceMapId: 'zakaz-9999'),
    );
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _template(code: 'Z-NOMAP', name: 'No map quick'),
    );

    await _pumpScreen(tester);

    expect(find.text('Valid quick'), findsOneWidget);
    expect(find.text('Missing quick'), findsNothing);
    expect(find.text('No map quick'), findsNothing);
  });

  testWidgets('quick orders list empty state names saved templates', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Saqlangan shablonlar hozircha yo‘q'), findsOneWidget);
    expect(find.text('Saqlangan zakaz yo‘q'), findsNothing);
  });
}

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AdminCalculateOrdersScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

CalculateOrderTemplate _template({
  required String code,
  required String name,
  String sourceMapId = '',
}) {
  return CalculateOrderTemplate(
    id: '',
    code: code,
    name: name,
    savedAt: DateTime.utc(2026, 7, 2),
    orderNumber: '',
    customerRef: 'CUST-001',
    customer: 'Mijoz',
    itemCode: 'ITEM-001',
    product: name,
    status: 'Ready',
    materialDisplay: '',
    color: '',
    imageId: '',
    imageName: '',
    imageMime: '',
    imageSizeBytes: 0,
    imageUrl: '',
    frameProductSizeMm: 615,
    frameCount: 1,
    widthMm: 630,
    wastePercent: 5,
    rollCount: 7,
    firstLayerMaterial: 'pet',
    firstLayerMicron: '12',
    secondLayerMaterial: 'pe oq',
    secondLayerMicron: '30',
    thirdLayerMaterial: '',
    thirdLayerMicron: '',
    note: '',
    sourceMapId: sourceMapId,
  );
}

ProductionMapDefinition _map({
  required String id,
  required String code,
  required String orderNumber,
}) {
  return ProductionMapDefinition(
    id: id,
    productCode: 'ITEM-001',
    title: 'Valid quick',
    code: code,
    orderNumber: orderNumber,
    rollCount: 7,
    widthMm: 630,
    nodes: const [
      ProductionMapNode(id: 'start', kind: 'start', title: 'Start', x: 0, y: 0),
      ProductionMapNode(id: 'end', kind: 'end', title: 'End', x: 0, y: 100),
    ],
    edges: const [ProductionMapEdge(from: 'start', to: 'end')],
  );
}
