import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_calculate_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_calculate_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_home_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/state/calculate_order_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/widgets/profile_avatar_preview.dart';
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

  testWidgets('quick orders list shows templates regardless of source map', (
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
          code: 'Z-MISSING',
          name: 'Missing quick',
          sourceMapId: 'template-zakaz-9999'),
    );
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _template(code: 'Z-NOMAP', name: 'No map quick'),
    );

    await _pumpScreen(tester);

    expect(find.text('Valid quick'), findsOneWidget);
    expect(find.text('Missing quick'), findsOneWidget);
    expect(find.text('No map quick'), findsOneWidget);
    expect(find.text('Saqlangan shablonlar hozircha yo‘q'), findsNothing);
  });

  testWidgets('saved templates load without any production-map access', (
    tester,
  ) async {
    setMobileApiTestModeForceProductionMapMenuLoadFailure(true);
    addTearDown(
        () => setMobileApiTestModeForceProductionMapMenuLoadFailure(false));
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _template(
          code: 'Z-SAVED',
          name: 'Saved template',
          sourceMapId: 'template-deleted-map'),
    );

    await _pumpScreen(tester);

    expect(find.text('Saved template'), findsOneWidget);
    expect(find.text('Saqlangan shablonlar hozircha yo‘q'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'search includes unlinked templates and keeps empty states distinct', (
    tester,
  ) async {
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _template(code: 'Z-MONO', name: 'Mono template'),
    );
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _template(
          code: 'Z-MOKO', name: 'Moko template', sourceMapId: 'deleted-map'),
    );
    await _pumpScreen(tester);

    final search = find.byType(EditableText);
    await tester.enterText(search, '  MoNo  ');
    await tester.pumpAndSettle();
    expect(find.text('Mono template'), findsOneWidget);
    expect(find.text('Moko template'), findsNothing);

    await tester.enterText(search, 'unmatched-product');
    await tester.pumpAndSettle();
    expect(find.text('Mono template'), findsNothing);
    expect(find.text('Moko template'), findsNothing);
    expect(find.text('Saqlangan shablonlar hozircha yo‘q'), findsNothing);

    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(find.text('Mono template'), findsOneWidget);
    expect(find.text('Moko template'), findsOneWidget);
  });

  testWidgets('quick orders list empty state names saved templates', (
    tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Saqlangan shablonlar hozircha yo‘q'), findsOneWidget);
    expect(find.text('Saqlangan zakaz yo‘q'), findsNothing);
  });

  testWidgets('quick order back preserves the filtered list and home',
      (tester) async {
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'production.map.manage'],
    );
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _template(code: 'Z-BACK', name: 'Back navigation'),
    );
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _template(code: 'Z-OTHER', name: 'Other template'),
    );
    await _pumpScreen(
      tester,
      home: const AdminHomeScreen(),
      onGenerateRoute: AppRouter.onGenerateRoute,
    );

    await tester.tap(find.text('Tezkor buyurtmalar'));
    await tester.pumpAndSettle();
    final listState = tester.state(find.byType(AdminCalculateOrdersScreen));
    await tester.enterText(find.byType(EditableText), 'back');
    await tester.pumpAndSettle();
    expect(find.text('Other template'), findsNothing);

    await tester.tap(find.text('Back navigation'));
    await tester.pumpAndSettle();
    expect(find.byType(AdminCalculateScreen), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsNothing);
    final backTooltip = MaterialLocalizations.of(
      tester.element(find.byType(AdminCalculateScreen)),
    ).backButtonTooltip;
    expect(find.byTooltip(backTooltip), findsOneWidget);

    await tester.tap(find.byTooltip(backTooltip));
    await tester.pumpAndSettle();
    expect(find.byType(AdminCalculateScreen), findsNothing);
    expect(
      tester.state(find.byType(AdminCalculateOrdersScreen)),
      same(listState),
    );
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'back',
    );
    expect(find.text('Back navigation'), findsOneWidget);
    expect(find.text('Other template'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AdminCalculateOrdersScreen), findsNothing);
    expect(find.byType(AdminHomeScreen), findsOneWidget);
  });

  testWidgets('sales manager saved orders hide delete', (tester) async {
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _template(code: 'Z-SALES', name: 'Sales template'),
    );
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.salesManager, displayName: 'Sales', legalName: 'Sales',
      ref: 'sales_manager_test', phone: '', avatarUrl: '',
      capabilities: ['sales.access', 'production.order.create'],
    );
    await _pumpScreen(tester);
    expect(find.text('Sales template'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick order image opens profile preview on long press', (
    tester,
  ) async {
    await MobileApi.instance.adminSaveProductionMap(
      _map(id: 'quick-image-map', code: '1002', orderNumber: '1002'),
    );
    await MobileApi.instance.upsertCalculateOrderTemplate(
      _template(
        code: 'Z-IMAGE',
        name: 'Image quick',
        sourceMapId: 'quick-image-map',
        imageUrl: '/v1/mobile/calculate/orders/image/view?id=image-1',
      ),
    );

    await _pumpScreen(tester);

    final imagePreview = find.byType(ProfileAvatarPreview);
    expect(imagePreview, findsOneWidget);
    await tester.longPress(imagePreview);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.maxScale, 8);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  Widget home = const AdminCalculateOrdersScreen(),
  RouteFactory? onGenerateRoute,
}) async {
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
      onGenerateRoute: onGenerateRoute,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

CalculateOrderTemplate _template({
  required String code,
  required String name,
  String sourceMapId = '',
  String imageUrl = '',
}) {
  return CalculateOrderTemplate(
    id: code,
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
    imageUrl: imageUrl,
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
