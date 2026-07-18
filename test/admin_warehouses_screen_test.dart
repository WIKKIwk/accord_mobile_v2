import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_warehouses_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'catalog.item.read'],
    );
  });

  tearDown(() async {
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('warehouse stock pages filter, search, and paginate server-style',
      () async {
    final first = await MobileApi.instance.adminWarehouseItemsPage(
      warehouse: 'Tayyor mahsulot ombori - DEMO',
      limit: 1,
    );
    final second = await MobileApi.instance.adminWarehouseItemsPage(
      warehouse: 'Tayyor mahsulot ombori - DEMO',
      limit: 1,
      offset: 1,
    );
    final searched = await MobileApi.instance.adminWarehouseItemsPage(
      warehouse: 'Tayyor mahsulot ombori - DEMO',
      query: 'salat',
      limit: 80,
    );
    final catalogOnly = await MobileApi.instance.adminWarehouseItemsPage(
      warehouse: 'Tayyor mahsulot ombori - DEMO',
      query: 'ichimlik',
      limit: 80,
    );

    expect(first, hasLength(1));
    expect(second, hasLength(1));
    expect(first.single.code, isNot(second.single.code));
    expect(searched.map((item) => item.code), ['DEMO-SALAD']);
    expect(searched.single.onHandQty, 10);
    expect(searched.single.packageCount, 1);
    expect(catalogOnly, isEmpty);
    expect(
      [...first, ...second]
          .every((item) => item.warehouse.contains('Tayyor mahsulot')),
      isTrue,
    );
  });

  test('raw material correction preserves barcode and receipt identity',
      () async {
    final updated = await MobileApi.instance.adminUpdateRawMaterialStock(
      barcode: '30AA',
      itemCode: 'DEMO-INK',
      qty: 10.5,
    );

    expect(updated.itemCode, 'DEMO-INK');
    expect(updated.itemName, 'Demo kraska');
    expect(updated.qty, 10.5);
    expect(updated.barcode, '30AA');
    expect(updated.sourceReceiptId, 'GSR-30AA');
  });

  test('raw material reprint preparation reuses barcode and receipt identity',
      () async {
    final prepared = await MobileApi.instance
        .adminPrepareRawMaterialStockReprint(barcode: '30AA');

    expect(prepared.stock.barcode, '30AA');
    expect(prepared.stock.sourceReceiptId, 'GSR-30AA');
    expect(prepared.printRequest.epc, '30AA');
    expect(prepared.printRequest.itemCode, 'DEMO-RAW-001');
    expect(prepared.printRequest.grossQty, 12);
    expect(prepared.printRequest.printCount, 1);
  });

  testWidgets('admin warehouses page shows only real warehouse stock', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        home: const AdminWarehousesScreen(),
      ),
    );

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(_warehouseFilterKey).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Ombor'), findsOneWidget);
    expect(find.textContaining('Ombor: Tanlanmagan'), findsOneWidget);

    await _openWarehouseFilter(tester);
    expect(find.text('Tayyor mahsulot ombori - DEMO'), findsOneWidget);
    expect(find.text('Hotlunch'), findsNothing);

    await tester.tap(find.text('Tayyor mahsulot ombori - DEMO'));
    await tester.pumpAndSettle();

    expect(find.text('Hotlunch'), findsOneWidget);
    expect(find.text('DEMO-HOTLUNCH'), findsNothing);
    expect(find.textContaining('DEMO-HOTLUNCH'), findsWidgets);
    expect(find.text('Demo ichimlik'), findsNothing);
    expect(find.textContaining('24 Dona'), findsOneWidget);

    await _openWarehouseFilter(tester);
    await tester.tap(find.text('Xomashyo ombori - DEMO'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mahsulotlar'), findsWidgets);
    expect(find.textContaining('(1)'), findsOneWidget);
    expect(find.text('Demo kraska'), findsNothing);
    expect(find.text('Demo xomashyo rulon'), findsOneWidget);

    await tester.tap(find.text('Demo xomashyo rulon'));
    await tester.pumpAndSettle();

    expect(find.text('Mahsulot kodi'), findsOneWidget);
    expect(find.text('DEMO-RAW-001'), findsOneWidget);
    expect(find.text('Shtrix-kod'), findsOneWidget);
    expect(find.text('30AA'), findsOneWidget);
    expect(find.text('Holati'), findsOneWidget);
    expect(find.text('Mavjud'), findsOneWidget);
    expect(find.text('Kirim raqami'), findsOneWidget);
    expect(find.text('GSR-30AA'), findsOneWidget);
    expect(find.byKey(const ValueKey('raw-stock-edit-30AA')), findsNothing);
    expect(find.byKey(const ValueKey('raw-stock-qr-30AA')), findsNothing);
  });

  testWidgets('admin warehouses page has list and create tabs with detail', (
    tester,
  ) async {
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
        home: const AdminWarehousesScreen(),
      ),
    );

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(_warehouseFilterKey).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Ombor'), findsOneWidget);
    expect(find.textContaining('Ombor: Tanlanmagan'), findsOneWidget);
    expect(find.byKey(_primaryNavigationButtonKey), findsOneWidget);

    await _openWarehouseFilter(tester);
    await tester.tap(find.text('Tayyor mahsulot ombori - DEMO'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mahsulotlar'), findsWidgets);
    expect(find.text('Hotlunch'), findsOneWidget);

    await tester.tap(find.byKey(_primaryNavigationButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ombor yaratish'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Ombor nomi'), findsOneWidget);
    expect(find.text('Tanlash uchun bosing'), findsOneWidget);
    expect(find.text('Assign qilish'), findsOneWidget);
  });

  testWidgets('warehouse assignee search includes active qolipchi users', (
    tester,
  ) async {
    await MobileApi.instance.adminCreateSystemUser(
      role: UserRole.qolipchi,
      name: 'Jumaniyoz qolipchi',
      phone: '+998110000011',
    );

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
        home: const AdminWarehousesScreen(),
      ),
    );

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(_primaryNavigationButtonKey).evaluate().isNotEmpty) {
        break;
      }
    }

    await tester.tap(find.byKey(_primaryNavigationButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ombor yaratish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tanlash uchun bosing'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'jumaniyoz');
    await tester.pumpAndSettle();

    expect(find.text('Jumaniyoz qolipchi'), findsOneWidget);
    expect(find.text('Qolipchi'), findsOneWidget);

    await tester.tap(find.text('Jumaniyoz qolipchi'));
    await tester.pumpAndSettle();

    expect(find.text('Jumaniyoz qolipchi'), findsOneWidget);
    expect(find.text('Tanlash uchun bosing'), findsNothing);
  });

  testWidgets('warehouse assignee picker shows only allowed user types', (
    tester,
  ) async {
    await MobileApi.instance.adminCreateWorker(
      name: 'Brigader Candidate',
      level: 'Brigader',
    );
    await MobileApi.instance.adminCreateWorker(
      name: 'Master Candidate',
      level: 'Master',
    );
    await MobileApi.instance.adminCreateSystemUser(
      role: UserRole.materialTaminotchi,
      name: 'Material Candidate',
      phone: '+998110000012',
    );
    await MobileApi.instance.adminCreateSystemUser(
      role: UserRole.qolipchi,
      name: 'Qolipchi Candidate',
      phone: '+998110000013',
    );

    await _pumpWarehousesScreen(tester);
    await _selectWarehouse(tester, 'Tayyor mahsulot ombori - DEMO');
    await tester.tap(find.text('Sozlamalar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('warehouse-assign-user')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Werka');
    await tester.pumpAndSettle();
    expect(find.text('Werka'), findsWidgets);

    await tester.enterText(find.byType(TextField).last, 'Candidate');
    await tester.pumpAndSettle();

    expect(find.text('Brigader Candidate'), findsOneWidget);
    expect(find.text('Brigader'), findsOneWidget);
    expect(find.text('Material Candidate'), findsOneWidget);
    expect(find.text('Qolipchi Candidate'), findsOneWidget);
    expect(find.text('Master Candidate'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'Demo');
    await tester.pumpAndSettle();
    expect(find.text('Demo ta’minotchi'), findsNothing);
    expect(find.text('Demo haridor'), findsNothing);
  });

  testWidgets('warehouse assignee picker hides already assigned users', (
    tester,
  ) async {
    final assigned = await MobileApi.instance.adminCreateSystemUser(
      role: UserRole.materialTaminotchi,
      name: 'Already Assigned Material',
      phone: '+998110000014',
    );
    await MobileApi.instance.adminCreateSystemUser(
      role: UserRole.qolipchi,
      name: 'Available Qolipchi',
      phone: '+998110000015',
    );
    await MobileApi.instance.adminAssignWarehouse(
      warehouse: 'Tayyor mahsulot ombori - DEMO',
      principalRole: assigned.role,
      principalRef: assigned.id,
      displayName: assigned.name,
    );

    await _pumpWarehousesScreen(tester);
    await _selectWarehouse(tester, 'Tayyor mahsulot ombori - DEMO');
    await tester.tap(find.text('Sozlamalar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('warehouse-assign-user')));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextField)),
      'Already Assigned Material',
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: sheet,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.data == 'Already Assigned Material',
        ),
      ),
      findsNothing,
    );

    await tester.enterText(
      find.descendant(of: sheet, matching: find.byType(TextField)),
      'Available Qolipchi',
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: sheet,
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Available Qolipchi',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('warehouse page separates products and settings tabs', (
    tester,
  ) async {
    await _pumpWarehousesScreen(tester);

    expect(find.text('Mahsulotlar'), findsOneWidget);
    expect(find.text('Sozlamalar'), findsOneWidget);

    await _selectWarehouse(tester, 'Tayyor mahsulot ombori - DEMO');
    await tester.tap(find.text('Sozlamalar'));
    await tester.pumpAndSettle();

    expect(find.text('Ombor ma’lumoti'), findsOneWidget);
    expect(find.text('Assign qilinganlar'), findsOneWidget);
    expect(find.text('Kimga assign qilish'), findsOneWidget);
    expect(find.text('Omborni o‘chirish'), findsOneWidget);
  });

  testWidgets('warehouse settings assigns a qolipchi user', (
    tester,
  ) async {
    await MobileApi.instance.adminCreateSystemUser(
      role: UserRole.qolipchi,
      name: 'Jumaniyoz qolipchi',
      phone: '+998110000011',
    );
    await _pumpWarehousesScreen(tester);
    await _selectWarehouse(tester, 'Tayyor mahsulot ombori - DEMO');
    await tester.tap(find.text('Sozlamalar'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('warehouse-assign-user')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'jumaniyoz');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jumaniyoz qolipchi'));
    await tester.pumpAndSettle();

    expect(find.text('Jumaniyoz qolipchi'), findsOneWidget);
    expect(find.text('Qolipchi'), findsOneWidget);
  });

  testWidgets('warehouse settings removes one assignment after confirmation', (
    tester,
  ) async {
    await MobileApi.instance.adminAssignWarehouse(
      warehouse: 'Tayyor mahsulot ombori - DEMO',
      principalRole: UserRole.werka,
      principalRef: 'werka',
      displayName: 'Werka',
    );
    await _pumpWarehousesScreen(tester);
    await _selectWarehouse(tester, 'Tayyor mahsulot ombori - DEMO');
    await tester.tap(find.text('Sozlamalar'));
    await tester.pumpAndSettle();

    expect(find.text('Werka'), findsWidgets);
    await tester.tap(find.byTooltip('Assigndan chiqarish'));
    await tester.pumpAndSettle();

    expect(find.text('Assigndan chiqarish'), findsOneWidget);
    expect(find.textContaining('omboridan chiqarasizmi'), findsOneWidget);
    await tester.tap(find.text('Olib tashlash'));
    await tester.pumpAndSettle();

    expect(find.text('Hech kim assign qilinmagan'), findsOneWidget);
    expect(find.text('Werka assigndan chiqarildi'), findsOneWidget);
  });

  testWidgets('warehouse deletion warns when products will be deleted', (
    tester,
  ) async {
    await _pumpWarehousesScreen(tester);
    await _selectWarehouse(tester, 'Tayyor mahsulot ombori - DEMO');
    await tester.tap(find.text('Sozlamalar'));
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(const ValueKey('warehouse-delete-button'));
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('mahsulot bor'), findsOneWidget);
    expect(find.textContaining('o‘chib ketadi'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('warehouse-delete-confirm')), findsOneWidget);
  });

  testWidgets('confirmed deletion removes an empty warehouse immediately', (
    tester,
  ) async {
    await MobileApi.instance.adminCreateWarehouse('Bo‘sh ombor');
    await _pumpWarehousesScreen(tester);
    await _selectWarehouse(tester, 'Bo‘sh ombor');
    await tester.tap(find.text('Sozlamalar'));
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(const ValueKey('warehouse-delete-button'));
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('warehouse-delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Ombor o‘chirildi'), findsOneWidget);
    expect(find.text('Ombor tanlanmagan'), findsOneWidget);
    await _openWarehouseFilter(tester);
    expect(find.text('Bo‘sh ombor'), findsNothing);
  });

  testWidgets('material scoped warehouses page shows only assigned warehouses',
      (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'material_taminotchi',
      phone: '',
      avatarUrl: '',
      capabilities: [
        'gscale.catalog.read',
        'gscale.print',
        'rps.batch.manage',
        'raw_material.assign',
      ],
      assignedItemGroups: ['Kraska'],
      assignedWarehouses: ['Xomashyo ombori - DEMO'],
    );

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
        home: const AdminWarehousesScreen(),
      ),
    );

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byKey(_warehouseFilterKey).evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Ombordagi mahsulotni qidirish'), findsOneWidget);
    expect(find.text('Ombor yaratish'), findsNothing);

    await _openWarehouseFilter(tester);

    expect(find.text('Xomashyo ombori - DEMO'), findsOneWidget);
    expect(find.text('Tayyor mahsulot ombori - DEMO'), findsNothing);

    await tester.tap(find.text('Xomashyo ombori - DEMO'));
    await tester.pumpAndSettle();

    expect(find.text('Demo kraska'), findsNothing);
    expect(find.text('Demo xomashyo rulon'), findsOneWidget);
    expect(find.text('Hotlunch'), findsNothing);

    await tester.tap(find.text('Demo xomashyo rulon'));
    await tester.pumpAndSettle();

    final qrButton = find.byKey(const ValueKey('raw-stock-qr-30AA'));
    final editButton = find.byKey(const ValueKey('raw-stock-edit-30AA'));
    expect(qrButton, findsOneWidget);
    expect(editButton, findsOneWidget);
    expect(tester.getCenter(qrButton).dx,
        lessThan(tester.getCenter(editButton).dx));

    await tester.tap(qrButton);
    await tester.pumpAndSettle();

    expect(find.text('Chop etilgan QR'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('raw-stock-qr-preview-30AA')),
      findsOneWidget,
    );
    expect(find.text('GSR-30AA'), findsWidgets);
    expect(find.byKey(const ValueKey('raw-stock-qr-reprint')), findsOneWidget);

    await tester.tap(find.byTooltip('Yopish'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('raw-stock-edit-30AA')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('raw-stock-edit-30AA')));
    await tester.pumpAndSettle();

    expect(find.text('Homashyoni tahrirlash'), findsOneWidget);
    expect(find.textContaining('Shtrix-kod 30AA'), findsOneWidget);
    expect(find.byKey(const ValueKey('raw-stock-edit-qty')), findsOneWidget);
    expect(find.byKey(const ValueKey('raw-stock-edit-save')), findsOneWidget);
  });

  test('admin warehouse live url uses websocket scheme and session token', () {
    final uri = MobileApi.instance.adminWarehouseLiveUri();

    expect(uri.scheme, 'wss');
    expect(uri.path, '/v1/mobile/admin/warehouses/live');
    expect(uri.queryParameters['token'], 'token');
  });
}

const _warehouseFilterKey = ValueKey('admin-warehouse-filter-chip');
const _primaryNavigationButtonKey = ValueKey('app-primary-navigation-button');

Future<void> _openWarehouseFilter(WidgetTester tester) async {
  await tester.tap(find.byKey(_warehouseFilterKey));
  await tester.pumpAndSettle();
}

Future<void> _pumpWarehousesScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
      home: const AdminWarehousesScreen(),
    ),
  );
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.byKey(_warehouseFilterKey).evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> _selectWarehouse(WidgetTester tester, String warehouse) async {
  await _openWarehouseFilter(tester);
  await tester.tap(find.text(warehouse));
  await tester.pumpAndSettle();
}
