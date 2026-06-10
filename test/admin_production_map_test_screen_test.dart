import 'package:erpnext_stock_mobile/src/core/localization/app_localizations.dart';
import 'package:erpnext_stock_mobile/src/core/api/mobile_api.dart';
import 'package:erpnext_stock_mobile/src/core/session/session.dart';
import 'package:erpnext_stock_mobile/src/core/test_mode/test_mode_controller.dart';
import 'package:erpnext_stock_mobile/src/features/admin/logic/production_map_pechat_rules.dart';
import 'package:erpnext_stock_mobile/src/features/admin/models/production_map_models.dart';
import 'package:erpnext_stock_mobile/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:erpnext_stock_mobile/src/features/admin/presentation/admin_production_map_test_screen.dart';
import 'package:erpnext_stock_mobile/src/features/shared/models/app_models.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
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
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('production map page can add and select an apparatus node',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
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
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapMapTool(tester, 'Aparat');
    await tester.pumpAndSettle();
    expect(find.text('Aparat tanlang'), findsOneWidget);

    await tester.ensureVisible(find.text('Aparat tanlang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aparat tanlang'));
    await tester.pumpAndSettle();
    expect(find.text('Aparat tanlang'), findsWidgets);

    await tester.tap(find.text('Godex aparat - DEMO').last);
    await tester.pumpAndSettle();

    expect(find.text('Godex aparat - DEMO'), findsWidgets);
  });

  testWidgets('production map opened from zakaz uses linear apparatus flow',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
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
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            orderName: 'Zenit order',
            productName: 'zenit frutto ninja 70gr',
            itemCode: 'ITEM-001',
            rollCount: 7,
            widthMm: 650,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Zenit order'), findsOneWidget);
    expect(find.text('zenit frutto ninja 70gr'), findsOneWidget);
    expect(find.text('CPP hisob'), findsNothing);
    expect(find.text('Katta partiyami?'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Element qo‘shish'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('admin-fab-menu-Aparat')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('admin-fab-menu-kk li mahsulot')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('admin-fab-menu-Formula')), findsNothing);
    expect(
        find.byKey(const ValueKey('admin-fab-menu-Condition')), findsNothing);
    expect(find.byKey(const ValueKey('admin-fab-menu-Ishlov')), findsNothing);
  });

  testWidgets('production map can add kk product and pick item',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
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
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            orderName: 'Zenit order',
            productName: 'zenit frutto ninja 70gr',
            itemCode: 'ITEM-001',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapMapTool(tester, 'kk li mahsulot');
    await tester.pumpAndSettle();
    expect(find.text('KK li mahsulot tanlang'), findsOneWidget);

    await tester.tap(find.text('KK li mahsulot tanlang'));
    await tester.pumpAndSettle();
    expect(find.text('Mahsulot qidiring'), findsOneWidget);

    await tester.tap(find.text('Hotlunch').last);
    await tester.pumpAndSettle();

    expect(find.text('Hotlunch'), findsWidgets);
    expect(find.text('DEMO-HOTLUNCH'), findsWidgets);
  });

  testWidgets('production map apparatus picker shows only recommended pechat',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
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
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            orderName: 'Zenit order',
            productName: 'zenit frutto ninja 70gr',
            itemCode: 'ITEM-001',
            rollCount: 8,
            widthMm: 700,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapMapTool(tester, 'Aparat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aparat tanlang'));
    await tester.pumpAndSettle();

    expect(find.text('8 ta rangli pechat'), findsOneWidget);
    expect(find.text('7 ta rangli pechat'), findsNothing);
    expect(find.text('9 ta rangli pechat'), findsNothing);
    expect(find.text('Godex aparat - DEMO'), findsOneWidget);
  });

  test('kk product edges are allowed only with apparatus nodes', () {
    const kk = ProductionMapNode(
      id: 'kk_product_1',
      kind: 'kk_product',
      title: 'Hotlunch',
    );
    const apparatus = ProductionMapNode(
      id: 'apparatus_1',
      kind: 'apparatus',
      title: 'Godex aparat - DEMO',
    );
    const task = ProductionMapNode(
      id: 'task_1',
      kind: 'task',
      title: 'Ishlov jarayoni',
    );
    const start = ProductionMapNode(
      id: 'start',
      kind: 'start',
      title: 'Start',
    );

    expect(productionMapCanCreateEdge(kk, apparatus), isTrue);
    expect(productionMapCanCreateEdge(apparatus, kk), isTrue);
    expect(productionMapCanCreateEdge(kk, task), isFalse);
    expect(productionMapCanCreateEdge(start, kk), isFalse);
    expect(productionMapCanCreateEdge(task, apparatus), isTrue);
  });

  test('production map pechat recommendation prioritizes val then rubber', () {
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 7, widthMm: 700),
      7,
    );
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 7, widthMm: 900),
      8,
    );
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 8, widthMm: 700),
      8,
    );
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 9, widthMm: 700),
      9,
    );
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 6, widthMm: 1200),
      9,
    );
    expect(
      productionMapRecommendedPechatColorCount(rollCount: 10, widthMm: 700),
      isNull,
    );
  });

  test('production map pechat filter allows compatible higher pechat capacity',
      () {
    const context = ProductionMapOrderContext(
      orderName: 'Zenit order',
      productName: 'zenit frutto ninja 70gr',
      itemCode: 'ITEM-001',
      rollCount: 7,
      widthMm: 650,
    );

    expect(
      productionMapApparatusMatchesOrder(
        const AdminWarehouse(
          warehouse: '7 ta rangli pechat',
          parentWarehouse: 'aparat - A',
        ),
        context,
      ),
      isTrue,
    );
    expect(
      productionMapApparatusMatchesOrder(
        const AdminWarehouse(
          warehouse: '8 ta rangli pechat',
          parentWarehouse: 'aparat - A',
        ),
        context,
      ),
      isTrue,
    );
    expect(
      productionMapApparatusMatchesOrder(
        const AdminWarehouse(
          warehouse: '9 ta rangli pechat',
          parentWarehouse: 'aparat - A',
        ),
        context,
      ),
      isFalse,
    );
    expect(
      productionMapApparatusMatchesOrder(
        const AdminWarehouse(
          warehouse: 'Godex aparat - DEMO',
          parentWarehouse: 'aparat - A',
        ),
        context,
      ),
      isTrue,
    );

    const smallRubberContext = ProductionMapOrderContext(
      orderName: 'Small order',
      productName: 'small product',
      itemCode: 'ITEM-002',
      rollCount: 7,
      widthMm: 100,
    );

    expect(
      productionMapApparatusMatchesOrder(
        const AdminWarehouse(
          warehouse: '8 ta rangli pechat',
          parentWarehouse: 'aparat - A',
        ),
        smallRubberContext,
      ),
      isFalse,
    );
  });

  test('production map pechat move blocks missing or incompatible order data',
      () {
    expect(
      productionMapPechatCanMoveOrder(
        apparatusColorCount: 8,
        rollCount: null,
        widthMm: 900,
      ),
      isTrue,
    );
    expect(
      productionMapPechatCanMoveOrder(
        apparatusColorCount: 8,
        rollCount: 7,
        widthMm: null,
      ),
      isTrue,
    );
    expect(
      productionMapPechatCanMoveOrder(
        apparatusColorCount: 9,
        rollCount: null,
        widthMm: 900,
      ),
      isFalse,
    );
    expect(
      productionMapPechatCanMoveOrder(
        apparatusColorCount: 9,
        rollCount: 7,
        widthMm: null,
      ),
      isFalse,
    );
    expect(
      productionMapPechatCanMoveOrder(
        apparatusColorCount: 9,
        rollCount: 7,
        widthMm: 650,
      ),
      isFalse,
    );
    expect(
      productionMapPechatCanMoveOrder(
        apparatusColorCount: 9,
        rollCount: 9,
        widthMm: 900,
      ),
      isTrue,
    );
  });

  testWidgets('production map order flow requires four digit order number',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
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
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            templateId: 'ORDER-1',
            orderName: 'Zenit order',
            productName: 'zenit frutto ninja 70gr',
            itemCode: 'ITEM-001',
            rollCount: 7,
            widthMm: 650,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('production-map-save')));
    await tester.pumpAndSettle();

    expect(find.text('Zakaz raqami'), findsOneWidget);
    expect(find.byKey(const ValueKey('production-map-order-number-field')),
        findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('production-map-order-number-field')),
      '12',
    );
    await tester.tap(find.byKey(const ValueKey('production-map-confirm-save')));
    await tester.pumpAndSettle();

    expect(find.text('4 xonali raqam kiriting'), findsOneWidget);
    expect(find.text('Production map saqlandi'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('production-map-order-number-field')),
      '1234',
    );
    await tester.tap(find.byKey(const ValueKey('production-map-confirm-save')));
    await tester.pumpAndSettle();

    expect(find.text('Production map saqlandi'), findsOneWidget);
    final maps = await MobileApi.instance.adminProductionMaps();
    expect(maps.first.map.orderNumber, '1234');
    expect(maps.first.map.id, 'zakaz-1234');
    expect(maps.first.map.rollCount, 7);
    expect(maps.first.map.widthMm, 650);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('production map order number must be unique per zakaz',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-9876',
        title: 'Old zakaz',
        productCode: 'OLD-ITEM',
        apparatus: 'Paket aparat',
        product: 'old product',
        orderNumber: '9876',
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
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            templateId: 'ORDER-NEW',
            orderName: 'New zakaz',
            productName: 'new product',
            itemCode: 'NEW-ITEM',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('production-map-save')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('production-map-order-number-field')),
      '9876',
    );
    await tester.tap(find.byKey(const ValueKey('production-map-confirm-save')));
    await tester.pumpAndSettle();

    expect(find.text('Bu raqam boshqa zakazga berilgan'), findsOneWidget);
    expect(find.text('Production map saqlandi'), findsNothing);
    final maps = await MobileApi.instance.adminProductionMaps();
    expect(maps.where((item) => item.map.orderNumber == '9876'), hasLength(1));
    expect(maps.first.map.title, 'Old zakaz');
  });

  testWidgets('opened production map orders page lists saved zakaz',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
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
        home: const AdminProductionMapTestScreen(
          orderContext: ProductionMapOrderContext(
            templateId: 'ORDER-2',
            orderName: 'Zenit opened',
            productName: 'zenit frutto ninja 70gr',
            itemCode: 'ITEM-002',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('production-map-save')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('production-map-order-number-field')),
      '2222',
    );
    await tester.tap(find.byKey(const ValueKey('production-map-confirm-save')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

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
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ochilgan zakazlar'), findsOneWidget);
    expect(find.text('Zenit opened'), findsOneWidget);
    expect(
      find.textContaining('zenit frutto ninja 70gr • ITEM-002'),
      findsOneWidget,
    );
  });

  testWidgets('opened orders page shows apparatus and sequence modules',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-sequence-a',
        title: 'Paket order A',
        productCode: 'PKT-A',
        apparatus: 'Godex aparat - DEMO',
        product: 'paket mahsulot A',
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-sequence-b',
        title: 'Paket order B',
        productCode: 'PKT-B',
        apparatus: 'Godex aparat - DEMO',
        product: 'paket mahsulot B',
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
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zakazlar'), findsOneWidget);
    expect(find.text('Aparatlar'), findsOneWidget);
    expect(find.text('Ketma-ketlik'), findsOneWidget);

    await tester.tap(find.text('Aparatlar'));
    await tester.pumpAndSettle();
    expect(find.text('Godex aparat - DEMO'), findsOneWidget);

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tester.tap(find.text('Godex aparat - DEMO'));
    await tester.pumpAndSettle();

    expect(find.text('Paket order A'), findsOneWidget);
    expect(find.text('Paket order B'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsWidgets);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('opened orders move module moves only compatible pechat orders',
      (tester) async {
    await TestModeController.instance.setEnabled(true);
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-move-ok',
        title: 'Move ok order',
        productCode: 'MOVE-OK',
        apparatus: '8 ta rangli pechat',
        product: 'move ok product',
        rollCount: 7,
        widthMm: 650,
        apparatusCopies: 2,
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-move-blocked',
        title: 'Move blocked order',
        productCode: 'MOVE-BLOCK',
        apparatus: '8 ta rangli pechat',
        product: 'move blocked product',
        rollCount: 8,
        widthMm: 700,
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
        home: const AdminProductionMapOrdersScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ko‘chirish'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    await tester.tap(find.text('Ko‘chirish'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add_rounded), findsNothing);

    await _dragOrderTitleToTopZone(
      tester,
      orderTitle: 'Move ok order',
      targetText: '7 ta rangli pechat uchun zakaz yo‘q',
    );
    var maps = await MobileApi.instance.adminProductionMaps();
    expect(_apparatusTitle(maps, 'zakaz-move-ok'), '8 ta rangli pechat');
    expect(
      find.text('7 ta rangli pechat uchun zakaz yo‘q'),
      findsOneWidget,
    );

    await _dragOrderHandleToTopZone(
      tester,
      orderTitle: 'Move ok order',
      targetText: '7 ta rangli pechat uchun zakaz yo‘q',
    );
    expect(
      find.text('7 ta rangli pechat uchun zakaz yo‘q'),
      findsNothing,
    );
    expect(find.text('Move ok order'), findsOneWidget);
    maps = await MobileApi.instance.adminProductionMaps();
    expect(_apparatusTitle(maps, 'zakaz-move-ok'), '7 ta rangli pechat');
    expect(
      _apparatusTitles(maps, 'zakaz-move-ok'),
      isNot(contains('8 ta rangli pechat')),
    );

    await _dragOrderHandleToTopZone(
      tester,
      orderTitle: 'Move blocked order',
      targetText: 'Move ok order',
    );
    maps = await MobileApi.instance.adminProductionMaps();
    expect(
      _apparatusTitle(maps, 'zakaz-move-blocked'),
      '8 ta rangli pechat',
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('apparatus queue worker view is read only', (tester) async {
    await TestModeController.instance.setEnabled(true);
    await AppSession.instance.setSession(
      token: 'worker-token',
      profile: const SessionProfile(
        role: UserRole.werka,
        displayName: 'Aparatchi',
        legalName: '',
        ref: 'werka',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read'],
        assignedApparatus: ['Godex aparat - DEMO'],
      ),
    );
    await MobileApi.instance.adminSaveProductionMap(
      _productionOrderMap(
        id: 'zakaz-worker-queue',
        title: 'Worker queue order',
        productCode: 'WRK-A',
        apparatus: 'Godex aparat - DEMO',
        product: 'worker mahsulot',
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
        home: const AdminProductionMapOrdersScreen(
          readOnly: true,
          workerMode: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zakazlar'), findsNothing);
    expect(find.text('Aparatlar'), findsWidgets);
    expect(find.text('Ketma-ketlik'), findsOneWidget);
    expect(find.text('Godex aparat - DEMO'), findsOneWidget);

    await tester.tap(find.text('Godex aparat - DEMO'));
    await tester.pumpAndSettle();

    expect(find.text('Worker queue order'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNothing);

    await tester.tap(find.text('Worker queue order'));
    await tester.pumpAndSettle();

    expect(find.text('Ketma-ketlik'), findsWidgets);
    expect(find.text('Zakaz detail'), findsNothing);
    expect(find.text('worker mahsulot'), findsWidgets);
  });

  testWidgets('production map sheet closes when tapping the dimmed barrier',
      (tester) async {
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
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Katta partiyami?'));
    await tester.pumpAndSettle();

    expect(find.text('Node sozlash'), findsOneWidget);

    await tester.tapAt(const Offset(200, 90));
    await tester.pumpAndSettle();

    expect(find.text('Node sozlash'), findsNothing);
  });

  testWidgets('production map page shows default condition flow',
      (tester) async {
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
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Katta partiyami?'), findsOneWidget);
    expect(find.text('Katta partiya'), findsNothing);
    expect(find.text('Rezkaga yuborish'), findsNothing);
    expect(
      find.byKey(const ValueKey('production-map-branch-add-true')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('production-map-branch-add-false')),
      findsWidgets,
    );
  });

  testWidgets('production map formula field shows human variable editor',
      (tester) async {
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
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CPP hisob'));
    await tester.pumpAndSettle();

    expect(find.text('Node sozlash'), findsOneWidget);
    expect(find.text('Buyurtma miqdori * 1.08'), findsOneWidget);
    expect(find.text('order_qty * 1.08'), findsNothing);

    await tester.tap(find.text('Buyurtma miqdori * 1.08'));
    await tester.pumpAndSettle();

    expect(find.text('Formula yozish'), findsOneWidget);
    expect(find.text('Buyurtma miqdori'), findsWidgets);

    await tester.enterText(find.byType(TextField).last, 'buyu');
    await tester.pump();
    final formulaField = tester.widget<TextField>(find.byType(TextField).last);
    final formulaSpan = formulaField.controller!.buildTextSpan(
      context: tester.element(find.byType(TextField).last),
      style: const TextStyle(),
      withComposing: false,
    );
    expect(formulaSpan.toPlainText(), 'buyurtma miqdori');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Formula yozish'), findsOneWidget);
    expect(formulaField.focusNode?.hasFocus, isTrue);
    expect(formulaField.controller!.text, 'Buyurtma miqdori ');

    await tester.tap(find.text('Saqlash').last);
    await tester.pumpAndSettle();

    expect(find.text('Buyurtma miqdori'), findsWidgets);
  });

  testWidgets('production map edge delete button removes an outgoing edge',
      (tester) async {
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
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapMapTool(tester, 'Ishlov');
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(
      const ValueKey('production-map-edge-delete-task_1-end-'),
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(deleteButton, findsNothing);
  });

  testWidgets('production map branch adds condition with open branch handles',
      (tester) async {
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
        home: const AdminProductionMapTestScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await _tapMapTool(tester, 'Condition');
    await tester.pumpAndSettle();

    expect(find.text('Shart'), findsOneWidget);
    expect(find.text('Shunda yo‘liga qo‘shish'), findsNothing);
    expect(find.text('Bajariladigan ish'), findsNothing);
    expect(find.text('Boshqa holatdagi ish'), findsNothing);
    expect(
      find.byKey(const ValueKey('production-map-branch-add-true')),
      findsWidgets,
    );
    expect(
      find.byKey(const ValueKey('production-map-branch-add-false')),
      findsWidgets,
    );
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
  int apparatusCopies = 1,
}) {
  final apparatusNodes = [
    for (var index = 0; index < apparatusCopies; index++)
      ProductionMapNode(
        id: index == 0 ? 'apparatus' : 'apparatus-$index',
        kind: 'apparatus',
        title: apparatus,
      ),
  ];
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
      ...apparatusNodes,
      ProductionMapNode(
        id: 'end',
        kind: 'end',
        title: product,
        itemCode: productCode,
      ),
    ],
    edges: [
      ProductionMapEdge(from: 'start', to: apparatusNodes.first.id),
      for (var index = 0; index < apparatusNodes.length - 1; index++)
        ProductionMapEdge(
          from: apparatusNodes[index].id,
          to: apparatusNodes[index + 1].id,
        ),
      ProductionMapEdge(from: apparatusNodes.last.id, to: 'end'),
    ],
  );
}

Future<void> _usePhoneViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(430, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapMapTool(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel('Element qo‘shish'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('admin-fab-menu-$label')));
}

Future<void> _dragOrderTitleToTopZone(
  WidgetTester tester, {
  required String orderTitle,
  required String targetText,
}) async {
  final order = find.text(orderTitle);
  await tester.ensureVisible(order);
  await tester.pumpAndSettle();
  final gesture = await tester.startGesture(tester.getCenter(order));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 120));
  await gesture.moveTo(tester.getCenter(find.text(targetText).first));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _dragOrderHandleToTopZone(
  WidgetTester tester, {
  required String orderTitle,
  required String targetText,
}) async {
  final order = find.text(orderTitle);
  await tester.ensureVisible(order);
  await tester.pumpAndSettle();
  final orderCenter = tester.getCenter(order);
  final handles = tester
      .widgetList<Icon>(find.byIcon(Icons.drag_handle_rounded))
      .toList(growable: false);
  final handleFinders = [
    for (var index = 0; index < handles.length; index++)
      find.byIcon(Icons.drag_handle_rounded).at(index),
  ];
  Finder? matchingHandle;
  var minDistance = double.infinity;
  for (final handle in handleFinders) {
    final center = tester.getCenter(handle);
    final distance = (center.dy - orderCenter.dy).abs();
    if (distance < minDistance) {
      minDistance = distance;
      matchingHandle = handle;
    }
  }
  final gesture = await tester.startGesture(tester.getCenter(matchingHandle!));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 120));
  await gesture.moveTo(tester.getCenter(find.text(targetText).first));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

String _apparatusTitle(List<ProductionMapSaved> maps, String id) {
  final map = maps.singleWhere((item) => item.map.id == id).map;
  return map.nodes.firstWhere((node) => node.kind == 'apparatus').title.trim();
}

List<String> _apparatusTitles(List<ProductionMapSaved> maps, String id) {
  final map = maps.singleWhere((item) => item.map.id == id).map;
  return map.nodes
      .where((node) => node.kind == 'apparatus')
      .map((node) => node.title.trim())
      .toList(growable: false);
}
