import 'package:erpnext_stock_mobile/src/core/localization/app_localizations.dart';
import 'package:erpnext_stock_mobile/src/core/api/mobile_api.dart';
import 'package:erpnext_stock_mobile/src/core/session/session.dart';
import 'package:erpnext_stock_mobile/src/core/test_mode/test_mode_controller.dart';
import 'package:erpnext_stock_mobile/src/features/admin/models/production_map_models.dart';
import 'package:erpnext_stock_mobile/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:erpnext_stock_mobile/src/features/admin/presentation/admin_production_map_test_screen.dart';
import 'package:erpnext_stock_mobile/src/features/shared/models/app_models.dart';
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

  testWidgets('production map order flow saves current map', (tester) async {
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
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('production-map-save')));
    await tester.pumpAndSettle();

    expect(find.text('Production map saqlandi'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
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

    await tester.tap(find.text('Godex aparat - DEMO'));
    await tester.pumpAndSettle();

    expect(find.text('Paket order A'), findsOneWidget);
    expect(find.text('Paket order B'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsWidgets);
  });

  testWidgets('apparatus queue worker view is read only', (tester) async {
    await TestModeController.instance.setEnabled(true);
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
}) {
  return ProductionMapDefinition(
    id: id,
    productCode: productCode,
    title: title,
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

Future<void> _tapMapTool(WidgetTester tester, String label) async {
  await tester.tap(find.bySemanticsLabel('Element qo‘shish'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('admin-fab-menu-$label')));
}
