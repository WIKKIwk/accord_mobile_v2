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

  testWidgets('master receipts bound Seriyo from a shared warehouse and sees only its rolls in the second tab',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final receipts = <Map<String, dynamic>>[];
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
      await tester.tap(find.text('Ombor'));
      await tester.pumpAndSettle();
      expect(find.text('Tayyorlov uchun xomashyo'), findsOneWidget);
      expect(find.text('Master granulasi'), findsOneWidget);
      expect(find.text('Katalog ruloni'), findsNothing);
      expect(find.text('Sarfga tayyor · 10 kg'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      expect(find.text('Tarozi kirimi'), findsNothing);
      await tester.tap(find.text('Kirim'));
      await tester.pumpAndSettle();
      final picker = find.byType(BottomSheet);
      expect(find.descendant(of: picker, matching: find.text('Faqat ko‘rish uchun Seriyo')), findsNothing);
      expect(find.descendant(of: picker, matching: find.text('Katalog ruloni')), findsNothing);
      await tester.tap(find.descendant(of: picker, matching: find.text('Master granulasi')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '5');
      await tester.tap(find.text('Saqlash'));
      await tester.pumpAndSettle();
      expect(receipts, hasLength(1));
      expect(receipts.single, containsPair('item_code', 'SER-1'));
      expect(receipts.single, containsPair('warehouse', 'Umumiy ombor'));
      expect(receipts.single, containsPair('kg', '5.000000'));
      expect(find.text('Sarfga tayyor · 15 kg'), findsOneWidget);

      await tester.tap(find.text('Tayyor rulonlar').last);
      await tester.pumpAndSettle();
      expect(find.text('Rulon QR-01'), findsOneWidget);
      expect(find.text('Master granulasi'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
          switch (request.url.path) {
            case '/v1/mobile/preparation/snapshot':
              return _json({
                'warehouses': ['Umumiy ombor'],
                'assigned_warehouses': ['Umumiy ombor'],
                'assigned_warehouse_ids': {'Umumiy ombor': 'shared'},
                'material_warehouses': [],
                'materials': [
                  {
                    'item_code': 'SER-1',
                    'name': 'Master granulasi',
                    'can_receive': true,
                    'is_seriyo': true,
                    'visible_warehouses': ['Umumiy ombor'],
                    'receipt_warehouses': ['Umumiy ombor'],
                    'balances': [
                      {'warehouse': 'Umumiy ombor', 'kg': receipts.isEmpty ? '15' : '20'},
                    ],
                    'consumable_balances': [
                      {'warehouse': 'Umumiy ombor', 'kg': receipts.isEmpty ? '10' : '15'},
                    ],
                  },
                  {
                    'item_code': 'SER-2',
                    'name': 'Faqat ko‘rish uchun Seriyo',
                    'can_receive': false,
                    'is_seriyo': true,
                    'visible_warehouses': ['Umumiy ombor'],
                    'receipt_warehouses': [],
                  },
                  {
                    'item_code': 'ROLL-1',
                    'name': 'Katalog ruloni',
                    'can_receive': false,
                    'is_seriyo': false,
                    'visible_warehouses': ['Umumiy ombor'],
                    'receipt_warehouses': [],
                  },
                ],
                'orders': [],
                'history': [],
              });
            case '/v1/mobile/preparation/receipts':
              expect(request.method, 'POST');
              receipts.add(jsonDecode(request.body) as Map<String, dynamic>);
              return _json({'id': 'receipt-1'});
            case '/v1/mobile/admin/inventory/assets':
              expect(request.url.queryParameters, containsPair('stock_use', 'prepared_roll'));
              expect(request.url.queryParameters, containsPair('warehouse_id', 'shared'));
              return _json([
                {
                  'kind': 'raw_material',
                  'stock_use': 'prepared_roll',
                  'asset_ref': 'roll-1',
                  'item_name': 'Rulon QR-01',
                  'identifier': 'QR-01',
                  'qty': 12,
                  'uom': 'kg',
                },
              ]);
          }
          return _json([]);
        }));
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

  testWidgets('master accepts the received Seriyo through the incoming transfer',
      (tester) async {
    var accepted = 0;
    const transferPath = '/v1/mobile/preparation/transfers/seriyo-transfer/accept';
    final source = find.text('Ta’minot → Tayyorlov ombori');
    final accept = find.widgetWithText(FilledButton, 'Tayyorlovga qabul qilish');

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('uz'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: InventoryMovementsScreen(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiruvchi'));
      await tester.pumpAndSettle();
      expect(find.text('Tayyorlovga qabul qilish · 1 ta'), findsOneWidget);
      await tester.tap(source);
      await tester.pumpAndSettle();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(find.text('Seriyoni tayyorlov sarfiga qabul qilasizmi?'), findsOneWidget);
      await tester.tap(find.text('Ha'));
      await tester.pumpAndSettle();
      expect(accepted, 1);
      expect(find.text('Tayyorlovga qabul qilish · 1 ta'), findsNothing);
      await tester.tap(source);
      await tester.pumpAndSettle();
      expect(accept, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (request.url.path == transferPath) {
        expect(request.method, 'POST');
        accepted++;
        return _json({'transfer_id': 'seriyo-transfer', 'warehouse': 'Tayyorlov ombori'});
      }
      if (request.url.path.endsWith('/inventory/transfers')) {
        expect(request.url.queryParameters['direction'], 'incoming');
        return _json([{
          'id': 'seriyo-transfer',
          'source_warehouse_id': 'supply',
          'source_warehouse': 'Ta’minot',
          'destination_warehouse_id': 'prep',
          'destination_warehouse': 'Tayyorlov ombori',
          'status': 'received',
          'received_by_name': 'Ta’minotchi',
          'pending_preparation_lots': accepted == 0 ? 1 : 0,
        }]);
      }
      if (request.url.path.endsWith('/inventory/locations') ||
          request.url.path.endsWith('/inventory/assets')) {
        return _json([]);
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    }));
  });

  testWidgets('master can link and unlink a warehouse roll to an order',
      (tester) async {
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.tayyorlovMasteri,
      displayName: 'Master',
      legalName: '',
      ref: 'prep-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['preparation.access', 'raw_material.assign'],
      assignedWarehouses: ['Tayyorlov ombori'],
    );
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var linked = false;
    final writes = <String>[];
    final assignment = {
      'order_id': 'zakaz-86',
      'apparatus': 'apparatus:default:bosma_7',
      'barcode': 'QR-1',
      'item_code': 'PE-1',
      'item_name': 'PE PR',
      'item_group': 'Rulon',
      'stock_status': 'available',
    };
    final order = {
      'id': 'zakaz-86',
      'product_code': 'P-1',
      'title': 'Avella 72 sht',
      'code': '0086',
      'nodes': [],
      'edges': [],
    };

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('uz'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: InventoryMovementsScreen(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('inventory-asset-raw:roll-1')));
      await tester.pumpAndSettle();

      expect(find.text('Ulanmagan'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('raw-material-assign-order-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0086 · Avella 72 sht'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('raw-material-confirm-assignment')));
      await tester.pumpAndSettle();
      expect(find.text('Ulangan'), findsOneWidget);
      expect(find.byKey(const ValueKey('raw-material-unlink-button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('raw-material-unlink-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('raw-material-confirm-unlink')));
      await tester.pumpAndSettle();
      expect(find.text('Ulanmagan'), findsOneWidget);
      expect(writes, ['POST', 'DELETE']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/inventory/locations')) {
        return _json([
          {'id': 'loc:a', 'kind': 'warehouse', 'name': 'Tayyorlov ombori',
            'warehouse_id': 'warehouse:a', 'active': true},
        ]);
      }
      if (path.endsWith('/inventory/assets')) {
        return _json([
          {
            'kind': 'raw_material', 'asset_ref': 'raw:roll-1',
            'custody_warehouse_id': 'warehouse:a', 'custody_warehouse': 'Tayyorlov ombori',
            'item_code': 'PE-1', 'item_name': 'PE PR', 'identifier': 'QR-1',
            'qty': 10, 'uom': 'kg', 'status': 'available',
            'physical_location': {'id': 'loc:a', 'kind': 'warehouse', 'name': 'Tayyorlov ombori'},
            'order_assignment': linked
                ? {'order_id': 'zakaz-86', 'order_label': '0086 · Avella 72 sht', 'order_control': 'active'}
                : null,
          },
        ]);
      }
      if (path.endsWith('/raw-material-assignments/lookup')) {
        return _json({'barcode': 'QR-1', 'status': 'available',
          'assignment': linked ? assignment : null, if (linked) 'order': order});
      }
      if (path.endsWith('/raw-material-assignments/candidate-orders')) {
        return _json([
          {'order': {'map': order, 'program': {
            'map_id': 'zakaz-86', 'product_code': 'P-1', 'operations': []}},
            'apparatus_options': ['apparatus:default:bosma_7']},
        ]);
      }
      if (path.endsWith('/admin/apparatus')) return _json([]);
      if (path.endsWith('/raw-material-assignments')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['order_id'], 'zakaz-86');
        expect(body['barcode'], 'QR-1');
        writes.add(request.method);
        if (request.method == 'POST') {
          expect(body['apparatus'], 'apparatus:default:bosma_7');
          linked = true;
          return _json(assignment);
        }
        expect(request.method, 'DELETE');
        linked = false;
        return _json({'ok': true, 'assignment': assignment});
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    }));
  });
}
