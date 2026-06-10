import 'package:erpnext_stock_mobile/src/core/api/mobile_api.dart';
import 'package:erpnext_stock_mobile/src/core/localization/app_localizations.dart';
import 'package:erpnext_stock_mobile/src/core/session/session.dart';
import 'package:erpnext_stock_mobile/src/core/test_mode/test_mode_controller.dart';
import 'package:erpnext_stock_mobile/src/features/admin/logic/production_map_pechat_rules.dart';
import 'package:erpnext_stock_mobile/src/features/admin/models/production_map_models.dart';
import 'package:erpnext_stock_mobile/src/features/admin/presentation/admin_production_map_test_screen.dart';
import 'package:erpnext_stock_mobile/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
    );
    await TestModeController.instance.setEnabled(true);
    setMobileApiTestModeForceSequenceSaveFailure(false);
    setMobileApiTestModeForceCalculateTemplateSaveFailure(false);
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    setMobileApiTestModeForceSequenceSaveFailure(false);
    setMobileApiTestModeForceCalculateTemplateSaveFailure(false);
  });

  testWidgets('re-saving opened zakaz skips order number dialog', (tester) async {
    final saved = await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-4444',
        title: 'Locked order',
        productCode: 'LOCK-4444',
        apparatus: '7 ta rangli pechat',
        product: 'locked product',
        orderNumber: '4444',
      ),
    );
    await _usePhoneViewport(tester);
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
        home: AdminProductionMapTestScreen(savedMap: saved.map),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('production-map-save')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(const ValueKey('production-map-order-number-field')),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(find.text('Production map saqlandi'), findsOneWidget);

    final maps = await MobileApi.instance.adminProductionMaps();
    final updated = maps.firstWhere((item) => item.map.id == 'zakaz-4444');
    expect(updated.map.orderNumber, '4444');
    await tester.pump(const Duration(seconds: 2));
  });

  test('pechat move allows dual-compatible order from 7 to 8 color', () {
    expect(
      productionMapPechatCanMoveOrder(
        apparatusColorCount: 8,
        rollCount: 7,
        widthMm: 650,
        sourceApparatusColorCount: 7,
      ),
      isTrue,
    );
  });

  test('batch move allows 7-color order with suffix title to 8-color pechat',
      () async {
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-7100',
        title: 'Seven to eight',
        productCode: 'SE-7100',
        apparatus: '7 ta rangli pechat - A',
        product: 'dual pechat order',
        orderNumber: '7100',
        rollCount: 7,
        widthMm: 650,
      ),
    );

    final moved = await MobileApi.instance.adminMoveProductionMapOrdersBatch(
      mapIds: const ['zakaz-7100'],
      fromApparatus: '7 ta rangli pechat',
      toApparatus: '8 ta rangli pechat',
    );
    expect(moved, hasLength(1));
    expect(
      moved.first.map.nodes
          .where((node) => node.kind == 'apparatus')
          .map((node) => node.title)
          .first,
      '8 ta rangli pechat',
    );
  });

  test('batch move is all-or-nothing for pechat orders', () async {
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-7001',
        title: 'Batch A',
        productCode: 'B-A',
        apparatus: '7 ta rangli pechat',
        product: 'batch A',
        orderNumber: '7001',
        rollCount: 7,
        widthMm: 650,
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-7002',
        title: 'Batch B',
        productCode: 'B-B',
        apparatus: '7 ta rangli pechat',
        product: 'batch B',
        orderNumber: '7002',
        rollCount: 7,
        widthMm: 650,
      ),
    );

    await expectLater(
      MobileApi.instance.adminMoveProductionMapOrdersBatch(
        mapIds: const ['zakaz-7001', 'zakaz-missing'],
        fromApparatus: '7 ta rangli pechat',
        toApparatus: '8 ta rangli pechat',
      ),
      throwsA(isA<MobileApiException>()),
    );

    final maps = await MobileApi.instance.adminProductionMaps();
    for (final id in ['zakaz-7001', 'zakaz-7002']) {
      final map = maps.firstWhere((item) => item.map.id == id);
      final apparatus = map.map.nodes
          .where((node) => node.kind == 'apparatus')
          .map((node) => node.title)
          .first;
      expect(apparatus, '7 ta rangli pechat');
    }

    final moved = await MobileApi.instance.adminMoveProductionMapOrdersBatch(
      mapIds: const ['zakaz-7001', 'zakaz-7002'],
      fromApparatus: '7 ta rangli pechat',
      toApparatus: '8 ta rangli pechat',
    );
    expect(moved, hasLength(2));
    for (final saved in moved) {
      final apparatus = saved.map.nodes
          .where((node) => node.kind == 'apparatus')
          .map((node) => node.title)
          .first;
      expect(apparatus, '8 ta rangli pechat');
    }
  });

  test('batch move stress handles many pechat orders without partial updates',
      () async {
    for (var index = 0; index < 30; index++) {
      final number = (8000 + index).toString();
      await MobileApi.instance.adminSaveProductionMap(
        _productionOrderMap(
          id: 'zakaz-$number',
          title: 'Stress $number',
          productCode: 'S-$number',
          apparatus: '7 ta rangli pechat',
          product: 'stress $number',
          orderNumber: number,
          rollCount: 7,
          widthMm: 650,
        ),
      );
    }

    final ids = [
      for (var index = 0; index < 30; index++) 'zakaz-${8000 + index}',
    ];
    final moved = await MobileApi.instance.adminMoveProductionMapOrdersBatch(
      mapIds: ids,
      fromApparatus: '7 ta rangli pechat',
      toApparatus: '8 ta rangli pechat',
    );
    expect(moved, hasLength(30));

    final maps = await MobileApi.instance.adminProductionMaps();
    for (final id in ids) {
      final map = maps.firstWhere((item) => item.map.id == id);
      final apparatus = map.map.nodes
          .where((node) => node.kind == 'apparatus')
          .map((node) => node.title)
          .first;
      expect(apparatus, '8 ta rangli pechat');
    }
  });

  test('with-order rolls back map when template upsert fails in test mode', () async {
    setMobileApiTestModeForceCalculateTemplateSaveFailure(true);
    await expectLater(
      MobileApi.instance.adminSaveProductionMapWithOrder(
        map: _productionOrderMap(
          id: 'zakaz-9001',
          title: 'Atomic fail',
          productCode: 'AF-9001',
          apparatus: '7 ta rangli pechat',
          product: 'atomic fail',
          orderNumber: '9001',
        ),
        template: CalculateOrderTemplate(
          id: '',
          code: '',
          name: 'valid template',
          savedAt: DateTime.now().toUtc(),
          orderNumber: '',
          customerRef: '',
          customer: '',
          itemCode: 'AF-9001',
          product: 'atomic fail',
          status: '',
          materialDisplay: '',
          color: '',
          imageId: '',
          imageName: '',
          imageMime: '',
          imageSizeBytes: 0,
          imageUrl: '',
          widthMm: 650,
          wastePercent: 5,
          rollCount: null,
          firstLayerMaterial: 'pet',
          firstLayerMicron: '12',
          secondLayerMaterial: 'pe oq',
          secondLayerMicron: '30',
          thirdLayerMaterial: '',
          thirdLayerMicron: '',
          note: '',
        ),
      ),
      throwsA(isA<MobileApiException>()),
    );

    final maps = await MobileApi.instance.adminProductionMaps();
    expect(maps.where((item) => item.map.id == 'zakaz-9001'), isEmpty);
  });

  test('sequence save failure does not persist reordered ids on server', () async {
    setMobileApiTestModeForceSequenceSaveFailure(true);
    await expectLater(
      MobileApi.instance.adminSaveProductionMapSequence(
        apparatus: '8 ta rangli pechat',
        orderIds: const ['zakaz-seq-b', 'zakaz-seq-a'],
      ),
      throwsA(isA<MobileApiException>()),
    );
    final sequences = await MobileApi.instance.adminProductionMapSequences();
    expect(sequences['8 ta rangli pechat'], isNull);
  });
}

ProductionMapDefinition _productionOrderMap({
  required String id,
  required String title,
  required String productCode,
  required String apparatus,
  required String product,
  String orderNumber = '',
  double? rollCount,
  double? widthMm,
}) {
  return ProductionMapDefinition(
    id: id,
    productCode: productCode,
    title: title,
    orderNumber: orderNumber,
    rollCount: rollCount,
    widthMm: widthMm,
    nodes: [
      const ProductionMapNode(
        id: 'start',
        kind: 'start',
        title: 'Start',
      ),
      ProductionMapNode(
        id: 'apparatus',
        kind: 'apparatus',
        title: apparatus,
      ),
      ProductionMapNode(
        id: 'end',
        kind: 'end',
        title: product,
        itemCode: productCode,
      ),
    ],
    edges: const [
      ProductionMapEdge(from: 'start', to: 'apparatus'),
      ProductionMapEdge(from: 'apparatus', to: 'end'),
    ],
  );
}

Future<void> _usePhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
