import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/inventory/inventory_view_store.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/m3_segmented_list.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_summary_card.dart';
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
    final rollLookups = <String>[];
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
      expect(find.text('Seriyo'), findsOneWidget);
      final warehouseFilter =
          find.byKey(const ValueKey('preparation-warehouse-filter-chip'));
      expect(
        tester.getBottomLeft(find.byType(TabBar)).dy,
        lessThanOrEqualTo(tester.getTopLeft(warehouseFilter).dy),
      );
      expect(find.text('Master granulasi'), findsOneWidget);
      expect(find.text('Katalog ruloni'), findsNothing);
      expect(find.text('Sarfga tayyor · 10 kg'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      expect(find.text('Rulonni tortish'), findsNothing);
      await tester.tap(find.text('Seriyo kirimi'));
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
      final fab = find.byKey(const ValueKey('app-primary-navigation-button'));
      await tester.tap(find.text('QR kodisiz kirim'));
      await tester.pumpAndSettle();
      expect(fab, findsNothing);
      await tester.tap(find.text('Boshqa master ruloni'));
      await tester.pumpAndSettle();
      expect(rollLookups, ['other']);
      expect(fab, findsNothing);
      await tester.tap(find.text('Rulon QR-01'));
      await tester.pumpAndSettle();
      await tester.tap(fab);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paddonga biriktirish'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('production-attach-paddon-save')), findsOneWidget);
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
                  'custody_warehouse_id': 'shared',
                  'status': 'available',
                  'preparation_qr': true,
                  'item_name': 'Rulon QR-01',
                  'identifier': 'QR-01',
                  'qty': 12,
                  'uom': 'kg',
                },
                for (final (id, qr) in [('other', true), ('no-qr', false)])
                  {
                    'kind': 'raw_material', 'stock_use': 'prepared_roll',
                    'asset_ref': id, 'identifier': id, 'custody_warehouse_id': 'shared',
                    'item_name': qr ? 'Boshqa master ruloni' : 'Kodsiz rulon',
                    'preparation_qr': qr, 'status': 'available', 'qty': 2, 'uom': 'kg',
                  },
              ]);
            case '/v1/mobile/preparation/production/rolls':
              final search = request.url.queryParameters['q'];
              expect(search, anyOf('qr-01', 'other'));
              rollLookups.add(search!);
              return _json({'has_more': false, 'rolls': [
                if (search == 'qr-01') {
                  'epc': 'QR-01', 'receipt_name': 'REC-1', 'net_kg': '12',
                },
              ]});
            case '/v1/mobile/preparation/production/paddon-options':
              expect(jsonDecode(request.body)['receipt_names'], ['REC-1']);
              return _json({
                'paddons': [], 'has_more': false, 'roll_selection': {
                  'total_rolls': 1, 'batch_ids': [], 'skipped': {},
                  'receipt_names_by_warehouse': {'Umumiy ombor': ['REC-1']},
                },
              });
          }
          return _json([]);
        }));
  });

  testWidgets('home Seriyo receipt continues from the selected warehouse to its materials', (tester) async {
    final writes = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate, GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate, GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: AppRoutes.preparation,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seriyo kirimi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ombor B'));
      await tester.pumpAndSettle();
      expect(find.text('Seriyo A'), findsNothing);
      await tester.tap(find.text('Seriyo B'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '4');
      await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
      await tester.pumpAndSettle();
      expect(writes.single, {
        'warehouse': 'Ombor B', 'item_code': 'B', 'kg': '4.000000', 'request_id': isNotEmpty,
      });
    }, () => MockClient((request) async {
      if (request.url.path.endsWith('/snapshot')) {
        return _json({
          'assigned_warehouses': ['Ombor A', 'Ombor B'],
          'assigned_warehouse_ids': {'Ombor A': 'a', 'Ombor B': 'b'},
          'history': [], 'orders': [],
          'materials': [
            for (final code in ['A', 'B']) {
              'item_code': code, 'name': 'Seriyo $code', 'is_seriyo': true,
              'receipt_warehouses': ['Ombor $code'], 'visible_warehouses': ['Ombor $code'],
            },
          ],
        });
      }
      expect(request.url.path, '/v1/mobile/preparation/receipts');
      writes.add(jsonDecode(request.body) as Map<String, dynamic>);
      return _json({'id': 'receipt'});
    }));
  });

  testWidgets('master sees the order product and moves an internal transfer straight to history',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppSession.instance.profile = AppSession.instance.profile!.copyWith(
      assignedWarehouses: ['Tayyorlov ombori', 'Ikkinchi ombor'],
    );
    Map<String, dynamic>? sentTransfer;
    const completedTransfer = {
      'id': 'transfer:1',
      'source_warehouse_id': 'warehouse:a',
      'source_warehouse': 'Tayyorlov ombori',
      'destination_warehouse_id': 'warehouse:c',
      'destination_warehouse': 'Ikkinchi ombor',
      'status': 'received',
      'lines': [
        {'asset_kind': 'raw_material', 'asset_ref': 'raw:roll-1', 'item_code': 'PE-1', 'item_name': 'PE PR', 'identifier': 'QR-1', 'qty': 10, 'uom': 'kg', 'source_physical_location_id': 'loc:a'},
      ],
    };
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
      await tester.tap(find.text('Transfer va tarix'));
      await tester.pumpAndSettle();
      expect(find.byType(InventoryMovementsScreen), findsOneWidget);
      expect(find.text('State’lar'), findsNothing);
      expect(find.text('Qoldiqlar'), findsOneWidget);
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect((tabBar.tabs[tabBar.controller!.index] as Tab).text, 'Tarix');
      expect(find.text('Tarixda yozuv topilmadi'), findsOneWidget);
      await tester.tap(find.text('Qoldiqlar'));
      await tester.pumpAndSettle();
      expect(find.text('Kutilayotgan'), findsOneWidget);
      expect(find.text('Kiruvchi'), findsNothing);
      expect(find.text('Chiquvchi'), findsNothing);
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
      await tester.tap(find.byKey(const ValueKey('inventory-location-loc:c')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ko‘chirish'));
      await tester.pumpAndSettle();
      expect(sentTransfer?['source_warehouse_id'], 'warehouse:a');
      expect(sentTransfer?['destination_warehouse_id'], 'warehouse:c');
      expect(sentTransfer?['assets'], [
        {'asset_kind': 'raw_material', 'asset_ref': 'raw:roll-1'}
      ]);
      await tester.tap(find.text('Tarix'));
      await tester.pumpAndSettle();
      expect(find.text('10 kg ko‘chirildi'), findsOneWidget);
      expect(find.textContaining('Tayyorlov ombori → Ikkinchi ombor'), findsOneWidget);
      await tester.tap(find.text('Kutilayotgan'));
      await tester.pumpAndSettle();
      expect(find.text('Kutilayotgan transfer yo‘q'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
          if (request.url.path.endsWith('/preparation/snapshot')) {
            return _json({
              'warehouses': ['Tayyorlov ombori', 'Ikkinchi ombor'],
              'assigned_warehouses': ['Tayyorlov ombori', 'Ikkinchi ombor'],
              'material_warehouses': ['Tayyorlov ombori'],
              'materials': [], 'orders': [], 'history': [],
            });
          }
          if (request.url.path.endsWith('/inventory/locations')) {
            return _json([
              {'id': 'loc:a', 'kind': 'warehouse', 'name': 'Tayyorlov ombori', 'warehouse_id': 'warehouse:a', 'active': true},
              {'id': 'loc:b', 'kind': 'warehouse', 'name': 'Boshqa ombor', 'warehouse_id': 'warehouse:b', 'active': true},
              {'id': 'loc:c', 'kind': 'warehouse', 'name': 'Ikkinchi ombor', 'warehouse_id': 'warehouse:c', 'active': true},
            ]);
          }
          if (request.url.path.endsWith('/inventory/assets')) {
            expect(request.url.queryParameters['asset_kind'], 'raw_material');
            expect(request.url.queryParameters['include_order_assignment'], 'true');
            final warehouse = request.url.queryParameters['warehouse_id'];
            final rows = [
              {
                'kind': 'raw_material', 'asset_ref': 'raw:roll-1',
                'custody_warehouse_id': sentTransfer == null ? 'warehouse:a' : 'warehouse:c',
                'custody_warehouse': sentTransfer == null ? 'Tayyorlov ombori' : 'Ikkinchi ombor',
                'item_code': 'PE-1', 'item_name': 'PE PR', 'identifier': 'QR-1',
                'qty': 10, 'uom': 'kg', 'status': 'available',
                'physical_location': {
                  'id': sentTransfer == null ? 'loc:a' : 'loc:c',
                  'kind': 'warehouse',
                  'name': sentTransfer == null ? 'Tayyorlov ombori' : 'Ikkinchi ombor',
                },
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
          if (request.url.path.endsWith('/preparation/history')) {
            return _json({
              'entries': [
                if (sentTransfer != null)
                  {
                    'key': 'transfer:transfer:1',
                    'occurred_at': '2026-11-25T11:00:00Z',
                    'transfer': completedTransfer,
                  },
              ],
            });
          }
          if (request.url.path.endsWith('/inventory/transfers')) {
            if (request.method == 'GET') {
              return _json([if (sentTransfer != null) completedTransfer]);
            }
            sentTransfer = jsonDecode(request.body) as Map<String, dynamic>;
            return _json(completedTransfer);
          }
          fail('Unexpected request: ${request.method} ${request.url}');
        }));
  });

  testWidgets('one waiting tab merges both directions and keeps the Seriyo acceptance',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppSession.instance.profile = AppSession.instance.profile!.copyWith(
      assignedWarehouses: ['Tayyorlov ombori', 'Ikkinchi ombor'],
    );
    var accepted = 0;
    const transferPath = '/v1/mobile/preparation/transfers/seriyo-transfer/accept';
    final seriyo = find.byKey(const ValueKey('inventory-transfer-seriyo-transfer'));
    final sent = find.byKey(const ValueKey('inventory-transfer-sent'));
    final both = find.byKey(const ValueKey('inventory-transfer-both'));
    final finished = find.byKey(const ValueKey('inventory-transfer-finished'));
    final rejected = find.byKey(const ValueKey('inventory-transfer-rejected'));
    final accept = find.widgetWithText(FilledButton, 'Tayyorlovga qabul qilish');
    final transfersCard = find.text('Transfer va tarix');

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
        initialRoute: AppRoutes.preparation,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ));
      await tester.pumpAndSettle();
      await tester.tap(transfersCard);
      await tester.pumpAndSettle();
      expect(find.byType(InventoryMovementsScreen), findsOneWidget);
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      expect(
        tabBar.tabs.cast<Tab>().map((tab) => tab.text),
        ['Qoldiqlar', 'Kutilayotgan', 'Tarix'],
      );
      expect(tabBar.controller!.index, 2);
      expect(seriyo, findsNothing);
      expect(rejected, findsOneWidget);
      await tester.tap(find.text('Kutilayotgan'));
      await tester.pumpAndSettle();
      expect(rejected, findsNothing);
      expect(sent, findsOneWidget);
      expect(both, findsOneWidget);
      expect(finished, findsNothing);
      expect(find.textContaining('Jo‘natish kutilmoqda · Tayyorlov ombori'), findsOneWidget);
      expect(find.textContaining('Qabul qilish kutilmoqda · Ikkinchi ombor'), findsOneWidget);
      expect(find.textContaining('Tayyorlovga qabul qilish kutilmoqda · Tayyorlov ombori'), findsOneWidget);
      await tester.tap(seriyo);
      await tester.pumpAndSettle();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(find.text('Seriyoni tayyorlov sarfiga qabul qilasizmi?'), findsOneWidget);
      await tester.tap(find.text('Ha'));
      await tester.pumpAndSettle();
      expect(accepted, 1);
      expect(seriyo, findsNothing);
      await tester.tap(find.text('Tarix'));
      await tester.pumpAndSettle();
      expect(seriyo, findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(rejected, findsOneWidget);
      await tester.tap(seriyo);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Ko‘chirildi'), findsWidgets);
      expect(find.text('Qabul qilingan'), findsNothing);
      expect(find.text('Tayyorlovga qabul qilingan'), findsOneWidget);
      expect(find.text('PE seriyo'), findsOneWidget);
      expect(find.text('12.5 kg'), findsOneWidget);
      expect(accept, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (request.url.path == transferPath) {
        expect(request.method, 'POST');
        accepted++;
        return _json({'transfer_id': 'seriyo-transfer', 'warehouse': 'Tayyorlov ombori'});
      }
      if (request.url.path.endsWith('/preparation/history')) {
        expect(request.url.queryParameters['kind'], 'all');
        return _json({
          'entries': [
            if (accepted > 0)
              {
                'key': 'transfer:seriyo-transfer',
                'kind': 'transfer',
                'occurred_at': '2026-11-25T11:00:00Z',
                'preparation_received_at': '2026-11-25T11:00:00Z',
                'preparation_receipts': [
                  {
                    'material': 'PE seriyo',
                    'kg': '12.500000',
                    'received_at': '2026-11-25T11:00:00Z',
                  },
                ],
                'transfer': {
                  'id': 'seriyo-transfer',
                  'source_warehouse': 'Ta’minot',
                  'destination_warehouse': 'Tayyorlov ombori',
                  'status': 'received',
                  'created_at_unix': 2,
                },
              },
            {
                'key': 'transfer:rejected',
                'kind': 'transfer',
                'occurred_at': '2026-11-25T10:00:00Z',
                'transfer': {'id': 'rejected', 'status': 'rejected'},
              },
          ],
        });
      }
      if (request.url.path.endsWith('/inventory/transfers')) {
        expect(request.method, 'GET');
        final direction = request.url.queryParameters['direction'];
        expect(direction, anyOf('all', 'incoming', 'outgoing'));
        return _json([
          if (direction != 'outgoing') ...[
            {
              'id': 'seriyo-transfer',
              'source_warehouse_id': 'supply',
              'source_warehouse': 'Ta’minot',
              'destination_warehouse_id': 'prep',
              'destination_warehouse': 'Tayyorlov ombori',
              'status': 'received',
              'created_at_unix': 4,
              'pending_preparation_lots': accepted == 0 ? 1 : 0,
            },
            {
              'id': 'rejected',
              'source_warehouse_id': 'other',
              'source_warehouse': 'Tarqatish ombori',
              'destination_warehouse_id': 'prep',
              'destination_warehouse': 'Tayyorlov ombori',
              'status': 'rejected',
              'created_at_unix': 1,
            },
          ],
          if (direction != 'incoming')
            {
              'id': 'sent',
              'source_warehouse': 'Tayyorlov ombori',
              'destination_warehouse': 'Ta’minot',
              'status': 'approved',
              'created_at_unix': 3,
            },
          {
            'id': 'both',
            'source_warehouse': 'Tayyorlov ombori',
            'destination_warehouse': 'Ikkinchi ombor',
            'status': direction == 'outgoing' ? 'requested' : 'in_transit',
            'created_at_unix': 2,
          },
          {
            'id': 'finished',
            'source_warehouse': 'Tayyorlov ombori',
            'destination_warehouse': 'Ikkinchi ombor',
            'status': direction == 'outgoing' ? 'requested' : 'received',
            'created_at_unix': 1,
          },
        ]);
      }
      if (request.url.path.endsWith('/preparation/snapshot')) {
        return _json({
          'warehouses': ['Tayyorlov ombori'],
          'assigned_warehouses': ['Tayyorlov ombori'],
          'assigned_warehouse_ids': {'Tayyorlov ombori': 'prep'},
          'material_warehouses': [],
          'materials': [],
          'history': [],
          'orders': [],
        });
      }
      if (request.url.path.endsWith('/inventory/locations')) {
        return _json([
          {
            'id': 'location:prep',
            'warehouse_id': 'prep',
            'kind': 'warehouse',
            'name': 'Tayyorlov ombori',
          },
        ]);
      }
      if (request.url.path.endsWith('/inventory/assets')) {
        return _json([]);
      }
      fail('Unexpected request: ${request.method} ${request.url}');
    }));
  });

  testWidgets('unified history pages mixed records and shares the warehouse filter',
      (tester) async {
    AppSession.instance.profile = AppSession.instance.profile!.copyWith(
      assignedWarehouses: ['Tayyorlov ombori', 'Ikkinchi ombor'],
    );
    final queries = <Map<String, String>>[];
    final newer = find.byKey(const ValueKey('inventory-transfer-cancelled'));
    final older = find.byKey(const ValueKey('inventory-transfer-older'));
    final receipt = find.byKey(const ValueKey('operation:direct'));
    final usage = find.byKey(const ValueKey('operation:used'));
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: AppRoutes.preparationTransferHistory,
        onGenerateRoute: AppRouter.onGenerateRoute,
        onGenerateInitialRoutes: (route) => [
          AppRouter.onGenerateRoute(RouteSettings(name: route)),
        ],
      ));
      await tester.pumpAndSettle();
      expect(newer, findsOneWidget);
      expect(receipt, findsOneWidget);
      expect(find.text('PE kirim qilindi'), findsOneWidget);
      expect(find.text('+12 kg'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(older, findsNothing);
      expect(find.byType(EditableText), findsOneWidget);
      expect(find.byKey(const ValueKey('inventory-movements-fab')), findsNothing);
      final historyFilterPosition = tester.getTopLeft(find.byKey(
        const ValueKey('preparation-transfer-history-warehouse'),
      ));

      await tester.tap(find.text('Yana yuklash'));
      await tester.pumpAndSettle();
      expect(queries[1]['before_key'], 'operation:direct');
      expect(queries[1]['before_time'], '2026-11-24T11:00:00Z');
      expect(older, findsOneWidget);
      expect(find.text('111 kg ko‘chirildi'), findsOneWidget);
      expect(tester.getTopLeft(newer).dy, lessThan(tester.getTopLeft(receipt).dy));
      expect(tester.getTopLeft(older).dy - tester.getBottomLeft(receipt).dy,
          M3SegmentedListGeometry.gap);
      expect(tester.widget<AdminSummaryCard>(find.descendant(
        of: older, matching: find.byType(AdminSummaryCard),
      )).slot, M3SegmentVerticalSlot.bottom);

      await tester.tap(find.byKey(
        const ValueKey('preparation-transfer-history-warehouse'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tayyorlov ombori'));
      await tester.pumpAndSettle();
      expect(queries.last['warehouse_id'], 'prep');
      expect(queries.last['before_key'], isNull);
      expect(newer, findsNothing);
      expect(older, findsOneWidget);
      await tester.tap(find.text('Qoldiqlar'));
      await tester.pumpAndSettle();
      expect(find.text('Ombor: Tayyorlov ombori'), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(
        const ValueKey('inventory-warehouse-filter-chip'),
      )), historyFilterPosition);
      await tester.tap(find.text('Tarix'));
      await tester.pumpAndSettle();
      expect(older, findsOneWidget);
      expect(queries, hasLength(3));

      expect(queries.last['kind'], 'all');
      expect(usage, findsOneWidget);
      expect(find.text('Ishlatildi · 0317 Choy'), findsOneWidget);
      expect(find.text('−13 kg'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'QR-EXAMPLE');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(queries.last['q'], 'QR-EXAMPLE');
      expect(queries.last['warehouse_id'], 'prep');
      expect(queries.last['before_key'], isNull);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
      expect(request.method, 'GET');
      if (request.url.path.endsWith('/inventory/locations')) {
        return _json([
          for (final (id, name) in [
            ('prep', 'Tayyorlov ombori'),
            ('secondary', 'Ikkinchi ombor'),
          ])
            {
              'id': 'location:$id',
              'warehouse_id': id,
              'kind': 'warehouse',
              'name': name,
            },
        ]);
      }
      if (request.url.path.endsWith('/inventory/assets') ||
          request.url.path.endsWith('/inventory/transfers')) {
        return _json([]);
      }
      expect(request.url.path, '/v1/mobile/preparation/history');
      final params = request.url.queryParameters;
      queries.add(params);
      const olderTransfer = {
        'key': 'transfer:older',
        'kind': 'transfer',
        'occurred_at': '2026-11-24T10:00:00Z',
        'transfer': {
          'id': 'older',
          'source_warehouse_id': 'prep',
          'source_warehouse': 'Tayyorlov ombori',
          'destination_warehouse': 'Ta’minot',
          'status': 'received',
          'lines': [
            {'asset_kind': 'raw_material', 'item_name': 'PE', 'qty': 50, 'uom': 'kg'},
            {'asset_kind': 'raw_material', 'item_name': 'EVA', 'qty': 61, 'uom': 'kg'},
          ],
        },
      };
      if (params['before_key'] != null) {
        return _json({'entries': [olderTransfer]});
      }
      if (params['warehouse_id'] == 'prep') {
        return _json({
          'entries': [
            {
              'key': 'operation:used',
              'kind': 'consumption',
              'occurred_at': '2026-11-24T12:00:00Z',
              'operation': {
                'id': 'used',
                'kind': 'consumption',
                'order_code': '0317',
                'order_title': 'Choy',
                'order_kg': '300',
                'warehouse': 'Tayyorlov ombori',
                'lines': [
                  {'name': 'PE', 'percent': '40', 'kg': '5.123456'},
                  {'name': 'EVA', 'percent': '60', 'kg': '7.876544'},
                ],
              },
            },
            olderTransfer,
          ],
        });
      }
      return _json({
        'entries': [
          {
            'key': 'transfer:cancelled',
            'kind': 'transfer',
            'occurred_at': '2026-11-25T10:00:00Z',
            'transfer': {
              'id': 'cancelled',
              'source_warehouse': 'Ta’minot',
              'destination_warehouse': 'Ikkinchi ombor',
              'status': 'cancelled',
            },
          },
          {
            'key': 'operation:direct',
            'kind': 'receipt',
            'occurred_at': '2026-11-24T11:00:00Z',
            'operation': {
              'id': 'direct',
              'kind': 'receipt',
              'name': 'PE',
              'warehouse': 'Tayyorlov ombori',
              'kg': '12.000000',
            },
          },
        ],
        'next_cursor': {
          'key': 'operation:direct',
          'time': '2026-11-24T11:00:00Z',
        },
      });
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
