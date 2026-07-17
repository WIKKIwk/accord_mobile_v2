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

  testWidgets('admin warehouses page groups catalog items by warehouse', (
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
    expect(find.text('Demo ichimlik'), findsOneWidget);
    expect(find.textContaining('Dona'), findsWidgets);

    await _openWarehouseFilter(tester);
    await tester.tap(find.text('Xomashyo ombori - DEMO'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Mahsulotlar'), findsWidgets);
    expect(find.textContaining('(3)'), findsOneWidget);
    expect(find.text('Demo kraska'), findsOneWidget);
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

    expect(find.byType(TextField), findsOneWidget);
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

    expect(find.text('Omborlarim'), findsOneWidget);
    expect(find.text('Ombor yaratish'), findsNothing);

    await _openWarehouseFilter(tester);

    expect(find.text('Xomashyo ombori - DEMO'), findsOneWidget);
    expect(find.text('Tayyor mahsulot ombori - DEMO'), findsNothing);

    await tester.tap(find.text('Xomashyo ombori - DEMO'));
    await tester.pumpAndSettle();

    expect(find.text('Demo kraska'), findsOneWidget);
    expect(find.text('Hotlunch'), findsNothing);
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
