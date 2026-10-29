import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/inventory/inventory_view_store.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/inventory/presentation/inventory_movements_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object value) => http.Response(jsonEncode(value), 200,
    headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
      capabilities: ['preparation.access'],
      assignedWarehouses: ['Tayyorlov ombori'],
    );
    InventoryViewStore.debugOverride = InventoryViewStore(liveEnabled: () => false);
  });

  tearDown(() {
    InventoryViewStore.debugOverride?.reset();
    InventoryViewStore.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('master opens inventory, sees the order product and transfers a roll',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? sentTransfer;
    var reserved = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: AppRoutes.preparation,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ));
      await tester.pumpAndSettle();
      expect(AppRouter.canOpenRoute(AppRoutes.inventoryMovements), isTrue);
      await tester.tap(find.text('Ishlab chiqarilgan homashyolar'));
      await tester.pumpAndSettle();
      expect(find.byType(InventoryMovementsScreen), findsOneWidget);
      expect(find.text('State’lar'), findsNothing);
      expect(find.text('Mahsulotlar'), findsOneWidget);
      expect(find.text('Kiruvchi'), findsOneWidget);
      expect(find.text('Chiquvchi'), findsOneWidget);
      expect(find.text('0086 · Avella 72 sht'), findsOneWidget);
      expect(find.text('0087 · Boshqa mahsulot'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('inventory-asset-raw:roll-2')));
      await tester.pumpAndSettle();
      expect(find.text('0087 · Boshqa mahsulot'), findsWidgets);
      expect(find.text('Joylashtirish'), findsNothing);
      expect(find.text('Transfer'), findsNothing);
      Navigator.of(tester.element(find.text('0087 · Boshqa mahsulot').last)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('inventory-warehouse-filter-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('inventory-warehouse-option-warehouse:b')));
      await tester.pumpAndSettle();
      expect(find.text('0086 · Avella 72 sht'), findsNothing);
      expect(find.text('0087 · Boshqa mahsulot'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('inventory-warehouse-filter-chip')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Barcha omborlar'));
      await tester.pumpAndSettle();
      expect(find.text('0086 · Avella 72 sht'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('inventory-asset-raw:roll-1')));
      await tester.pumpAndSettle();
      expect(find.text('0086 · Avella 72 sht'), findsWidgets);
      expect(find.text('Joylashtirish'), findsNothing);
      expect(find.text('Transfer'), findsOneWidget);
      await tester.tap(find.text('Transfer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('inventory-location-loc:b')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('So‘rov yuborish'));
      await tester.pumpAndSettle();
      expect(sentTransfer?['source_warehouse_id'], 'warehouse:a');
      expect(sentTransfer?['destination_warehouse_id'], 'warehouse:b');
      expect(sentTransfer?['assets'], [
        {'asset_kind': 'raw_material', 'asset_ref': 'raw:roll-1'}
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
          if (request.url.path.endsWith('/preparation/snapshot')) {
            return _json({
              'warehouses': ['Tayyorlov ombori'],
              'assigned_warehouses': ['Tayyorlov ombori'],
              'material_warehouses': ['Tayyorlov ombori'],
              'materials': [], 'orders': [], 'history': [],
            });
          }
          if (request.url.path.endsWith('/inventory/locations')) {
            return _json([
              {'id': 'loc:a', 'kind': 'warehouse', 'name': 'Tayyorlov ombori', 'warehouse_id': 'warehouse:a', 'active': true},
              {'id': 'loc:b', 'kind': 'warehouse', 'name': 'Boshqa ombor', 'warehouse_id': 'warehouse:b', 'active': true},
            ]);
          }
          if (request.url.path.endsWith('/inventory/assets')) {
            expect(request.url.queryParameters['asset_kind'], 'raw_material');
            expect(request.url.queryParameters['include_order_assignment'], 'true');
            final warehouse = request.url.queryParameters['warehouse_id'];
            final rows = [
              {
                'kind': 'raw_material', 'asset_ref': 'raw:roll-1',
                'custody_warehouse_id': 'warehouse:a', 'custody_warehouse': 'Tayyorlov ombori',
                'item_code': 'PE-1', 'item_name': 'PE PR', 'identifier': 'QR-1',
                'qty': 10, 'uom': 'kg', 'status': reserved ? 'transfer_reserved' : 'available',
                'physical_location': {'id': 'loc:a', 'kind': 'warehouse', 'name': 'Tayyorlov ombori'},
                'order_assignment': {'order_id': 'zakaz-86', 'order_label': '0086 · Avella 72 sht', 'order_control': 'active'},
              },
              {
                'kind': 'raw_material', 'asset_ref': 'raw:roll-2',
                'custody_warehouse_id': 'warehouse:b', 'custody_warehouse': 'Boshqa ombor',
                'item_code': 'PE-2', 'item_name': 'PE boshqa', 'identifier': 'QR-2',
                'qty': 10, 'uom': 'kg', 'status': 'available',
                'physical_location': {'id': 'loc:b', 'kind': 'warehouse', 'name': 'Boshqa ombor'},
                'order_assignment': {'order_id': 'zakaz-87', 'order_label': '0087 · Boshqa mahsulot', 'order_control': 'active'},
              }
            ];
            return _json(rows.where((row) =>
                warehouse == null || row['custody_warehouse_id'] == warehouse).toList());
          }
          if (request.url.path.endsWith('/inventory/transfers')) {
            if (request.method == 'GET') return _json([]);
            sentTransfer = jsonDecode(request.body) as Map<String, dynamic>;
            reserved = true;
            return _json({
              'id': 'transfer:1', 'source_warehouse_id': 'warehouse:a',
              'source_warehouse': 'Tayyorlov ombori', 'destination_warehouse_id': 'warehouse:b',
              'destination_warehouse': 'Boshqa ombor', 'status': 'requested',
              'lines': [{'asset_kind': 'raw_material', 'asset_ref': 'raw:roll-1', 'item_code': 'PE-1', 'item_name': 'PE PR', 'identifier': 'QR-1', 'qty': 10, 'uom': 'kg', 'source_physical_location_id': 'loc:a'}],
            });
          }
          fail('Unexpected request: ${request.method} ${request.url}');
        }));
  });
}
