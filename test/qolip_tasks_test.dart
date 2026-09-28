import 'dart:async';
import 'dart:convert';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_base.dart';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/printing/session_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/rps_qr_reprint_sheet.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/state/admin_sequence_apparatus_store.dart';
import 'package:accord_mobile_v2/src/features/qolip/state/qolip_data_revision.dart';
import 'package:accord_mobile_v2/src/features/gscale/presentation/gscale_mode_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const machine = AdminApparatus(
    id: 'apparatus:test:bosma',
    name: 'Bosma',
    operation: 'print',
    capabilities: ['print', 'tooling']);
final orders = [
  for (var i = 1; i <= 6; i++)
    ProductionMapSaved.fromJson({
      'map': {
        'id': 'zakaz-$i',
        'product_code': 'ITEM-$i',
        'title': 'Product $i',
        'width_mm': 384,
        'nodes': [
          {'id': 'stage-$i', 'kind': 'apparatus', 'apparatus_id': machine.id}
        ],
        'edges': []
      },
      'program': <String, dynamic>{},
    })
];

Widget screen({bool materialMode = false, bool sequenceMode = false,
    RouteFactory? onGenerateRoute}) => MaterialApp(
      onGenerateRoute: onGenerateRoute,
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminProductionMapOrdersScreen(
        readOnly: true,
        supplyViewerMode: true,
        qolipTasksMode: !materialMode && !sequenceMode,
        materialTasksMode: materialMode && !sequenceMode,
        apparatusLoader: () async => [machine],
        liveEventsLoader: () => const Stream.empty(),
        queueSnapshotLoader: () async => AdminApparatusQueueSnapshot(
          maps: orders,
          revision: 1,
          epoch: 'tasks-test',
          sequences: {
            machine.id: [for (final order in orders) order.map.id]
          },
          visibleOrderIds: {
            machine.id: [for (final order in orders) order.map.id]
          },
          queueStates: {
            machine.id: {for (final order in orders) order.map.id: 'pending'}
          },
          queuePolicies: const {},
          orderControls: const {},
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    OrderImageCache.debugOverride = OrderImageCache(disk: _NoImageDisk());
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AdminSequenceApparatusStore.instance.clearCache();
    AppSession.instance.token = 'tasks-token';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        displayName: 'Qolipchi',
        legalName: '',
        ref: 'qolipchi',
        phone: '',
        avatarUrl: '',
        capabilities: ['qolip.manage']);
  });
  tearDown(() {
    OrderImageCache.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('assigned material reprint sends the order and preserves its barcode', () async {
    await http.runWithClient(() async {
      final prepared = await MobileApi.instance.adminPrepareRawMaterialStockReprint(
        barcode: '30AA', orderId: 'zakaz-3');
      expect(prepared.stock.barcode, '30AA');
      expect(prepared.printRequest.epc, '30AA');
      expect(prepared.printRequest.grossQty, 12);
    }, () => MockClient((request) async {
      expect(request.url.path, '/v1/mobile/admin/raw-material-stock/reprint/prepare');
      expect(jsonDecode(request.body), {'barcode': '30AA', 'order_id': 'zakaz-3'});
      return http.Response(jsonEncode({
        'reprint_id': 'reprint-test',
        'stock': {'barcode': '30AA', 'item_code': 'PET', 'qty': 12,
          'status': 'reserved', 'reserved_order_id': 'zakaz-3'},
        'print': {'epc': '30AA', 'item_code': 'PET', 'gross_qty': 12,
          'label_kind': 'material_product', 'printer': 'godex'},
      }), 200);
    }));
  });

  for (final printFails in [false, true]) {
    testWidgets('admin iOS material reprint uses Bluetooth (failure: $printFails)',
        (tester) async {
      AppSession.instance.profile = AppSession.instance.profile!.copyWith(
          role: UserRole.admin, capabilities: ['admin.access', 'gscale.print']);
      SessionBluetoothPrinter.remember(const BluetoothPrinterProfile(
          name: 'XP-P323B', address: 'printer-ios-uuid'));
      final bluetoothCalls = <MethodCall>[];
      final usbCalls = <MethodCall>[];
      var confirmed = false;
      const bluetoothChannel = MethodChannel('accord/bluetooth_printer');
      const usbChannel = MethodChannel('accord/usb_printer');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          bluetoothChannel, (call) async {
        bluetoothCalls.add(call);
        if (printFails) {
          throw PlatformException(code: 'bluetooth_disconnected',
              message: 'Printer bilan aloqa uzildi');
        }
        return {'ok': true};
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          usbChannel, (call) async {
        usbCalls.add(call);
        throw MissingPluginException('USB is unavailable on iOS');
      });
      addTearDown(() {
        SessionBluetoothPrinter.forget();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(bluetoothChannel, null);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(usbChannel, null);
      });
      await http.runWithClient(() async {
        await tester.pumpWidget(screen(materialMode: true));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('material-task-zakaz-3')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('production-materials-expansion')));
        await tester.pumpAndSettle();
        final material = find.textContaining('30AA', findRichText: true);
        await tester.ensureVisible(material);
        await tester.longPress(material);
        await tester.pumpAndSettle();
        final reprint = find.byKey(const ValueKey('assigned-material-qr-reprint-30AA'));
        await tester.ensureVisible(reprint);
        await tester.tap(reprint);
        await tester.pumpAndSettle();
        expect(usbCalls, isEmpty);
        expect(bluetoothCalls, hasLength(1));
        expect(bluetoothCalls.single.method, 'printLabel');
        final printed = bluetoothCalls.single.arguments as Map;
        expect(printed['epc'], '30AA');
        expect(printed['gross_qty'], 100);
        expect(printed['mac_address'], 'printer-ios-uuid');
        expect(printed['material_data_matrix'], isTrue);
        expect(confirmed, !printFails);
        if (printFails) {
          expect(find.text('Printer bilan aloqa uzildi'), findsOneWidget);
          expect(SessionBluetoothPrinter.cached, isNull);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }, () => MockClient((request) async {
        if (request.url.path.endsWith('/gscale/material-tasks')) {
          return http.Response(jsonEncode({'orders': [for (final order in orders) {
            'order_id': order.map.id,
            'materials': [{'material': 'OPP', 'micron': 30, 'assigned': false}],
          }]}), 200);
        }
        if (request.url.path.endsWith('/raw-material-assignments')) {
          return http.Response(jsonEncode([{
            'order_id': 'zakaz-3', 'apparatus': machine.id, 'barcode': '30AA',
            'item_code': 'OPP', 'item_name': 'OPP 815/30', 'stock_status': 'available',
            'stock_qty': 100, 'received_qty': 100, 'remaining_qty': 100,
          }]), 200);
        }
        if (request.url.path.endsWith('/reprint/prepare')) {
          expect(jsonDecode(request.body), {'barcode': '30AA', 'order_id': 'zakaz-3'});
          return http.Response(jsonEncode({
            'reprint_id': 'reprint-ios',
            'stock': {'barcode': '30AA', 'item_code': 'OPP', 'qty': 100},
            'print': {'epc': '30AA', 'item_code': 'OPP', 'item_name': 'OPP 815/30',
              'gross_qty': 100, 'label_kind': 'material_product', 'printer': 'godex'},
          }), 200);
        }
        if (request.url.path.endsWith('/reprint/confirm')) {
          expect(jsonDecode(request.body), {'barcode': '30AA', 'reprint_id': 'reprint-ios'});
          confirmed = true;
          return http.Response('{"ok":true}', 200);
        }
        if (request.url.path.endsWith('/qolip/order-products')) {
          return http.Response('{"orders":[]}', 200);
        }
        if (request.url.path.contains('order-image')) return http.Response('', 404);
        return http.Response('{}', 200);
      }));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  for (final sequenceMode in [false, true]) {
    testWidgets(
        'empty material detail opens prepared receipt from ${sequenceMode ? 'sequence' : 'tasks'}',
        (tester) async {
      AppSession.instance.profile = AppSession.instance.profile!.copyWith(
          role: UserRole.materialTaminotchi,
          capabilities: ['raw_material.assign']);
      var received = false;
      GScaleModeArgs? selected;
      await http.runWithClient(() async {
        await tester.pumpWidget(screen(
          materialMode: true,
          sequenceMode: sequenceMode,
          onGenerateRoute: (settings) {
            expect(settings.name, AppRoutes.gscaleMode);
            selected = settings.arguments as GScaleModeArgs;
            return MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('Receipt')));
          },
        ));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey(sequenceMode
            ? 'sequence-static-${machine.id}-zakaz-3'
            : 'material-task-zakaz-3')));
        await tester.pumpAndSettle();
        expect(find.text('Homashyo biriktirilmagan'), findsOneWidget);
        final receive = find.byKey(const ValueKey('production-material-receive'));
        expect(find.descendant(
          of: find.byKey(const ValueKey('production-materials-expansion')),
          matching: receive,
        ), findsOneWidget);
        await tester.tap(receive);
        await tester.pumpAndSettle();
        expect(find.text('Receipt'), findsOneWidget);
        expect(selected!.order!.id, 'zakaz-3');
        expect(selected!.order!.widthMm, 384);
        expect(selected!.order!.title, 'Product 3');
        received = true;
        Navigator.of(tester.element(find.text('Receipt'))).pop();
        await tester.pumpAndSettle();
        expect(receive, findsNothing);
        expect(find.text('Homashyo biriktirilmagan'), findsNothing);
        expect(find.byKey(const ValueKey('production-materials-expansion')),
            findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }, () => MockClient((request) async {
        if (request.url.path.endsWith('/gscale/material-tasks')) {
          final ids = (jsonDecode(request.body)['order_ids'] as List).cast<String>();
          return http.Response(jsonEncode({'orders': [for (final id in ids) {
            'order_id': id,
            'materials': [{'material': 'PET', 'micron': 12, 'assigned': false}],
          }]}), 200);
        }
        if (request.url.path.endsWith('/raw-material-assignments')) {
          expect(request.url.queryParameters['order_id'], 'zakaz-3');
          return http.Response(jsonEncode(received ? [{
            'order_id': 'zakaz-3', 'apparatus': machine.id, 'barcode': '30AA',
            'item_code': 'PET', 'item_name': 'PET', 'stock_status': 'reserved',
            'stock_qty': 12, 'received_qty': 12, 'remaining_qty': 12,
          }] : []), 200);
        }
        if (request.url.path.endsWith('/qolip/order-products')) {
          return http.Response('{"orders":[]}', 200);
        }
        if (request.url.path.contains('order-image')) return http.Response('', 404);
        return http.Response('{}', 200);
      }));
    });
  }

  testWidgets('material task tap shows details and QR permissions, long press opens receipt', (tester) async {
    AppSession.instance.profile = AppSession.instance.profile!.copyWith(
      role: UserRole.materialTaminotchi, capabilities: ['raw_material.assign']);
    final requests = <List<String>>[];
    var completed = false;
    GScaleModeArgs? selected;
    await http.runWithClient(() async {
      await tester.pumpWidget(screen(materialMode: true, onGenerateRoute: (settings) {
        expect(settings.name, AppRoutes.gscaleMode);
        selected = settings.arguments as GScaleModeArgs;
        return MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Receipt')));
      }));
      await tester.pumpAndSettle();
      expect(AppRouter.canOpenRoute(AppRoutes.materialTasks), isTrue);
      expect(find.byKey(const ValueKey('material-task-zakaz-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('material-task-zakaz-6')), findsOneWidget);
      expect(find.textContaining('mkm'), findsNothing);
      expect(find.text('Kutilmoqda'), findsNothing);
      expect(find.text('Qisman'), findsWidgets);
      expect(find.byKey(const ValueKey('material-task-zakaz-1')), findsNothing);
      expect(find.byKey(const ValueKey('material-task-zakaz-2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('material-tasks-limit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('material-tasks-limit-5 ta')));
      await tester.pumpAndSettle();
      expect(requests.last, ['zakaz-1', 'zakaz-2', 'zakaz-3', 'zakaz-4', 'zakaz-5']);
      expect(find.byKey(const ValueKey('material-task-zakaz-6')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('material-task-zakaz-3')));
      await tester.pumpAndSettle();
      expect(selected, isNull);
      expect(find.byKey(const ValueKey('production-material-receive')), findsNothing);
      final materials = find.byKey(const ValueKey('production-materials-expansion'));
      await tester.ensureVisible(materials);
      await tester.tap(materials);
      await tester.pumpAndSettle();
      final attached = find.textContaining('30AA', findRichText: true);
      expect(attached, findsOneWidget);
      expect(find.textContaining('12 kg'), findsWidgets);
      await tester.ensureVisible(attached);
      await tester.longPress(attached);
      await tester.pumpAndSettle();
      final materialQr = tester.widget<RpsQrReprintSheet>(find.byType(RpsQrReprintSheet));
      expect(materialQr.payload, '30AA');
      expect(materialQr.onReprint, isNotNull);
      Navigator.of(tester.element(find.byType(RpsQrReprintSheet))).pop();
      await tester.pumpAndSettle();
      final molds = find.byKey(const ValueKey('production-attached-qolips-expansion'));
      await tester.ensureVisible(molds);
      await tester.tap(molds);
      await tester.pumpAndSettle();
      final mold = find.textContaining('QOLIP-3');
      await tester.ensureVisible(mold);
      await tester.longPress(mold);
      await tester.pumpAndSettle();
      expect(tester.widget<RpsQrReprintSheet>(find.byType(RpsQrReprintSheet)).onReprint, isNull);
      Navigator.of(tester.element(find.byType(RpsQrReprintSheet))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('production-order-detail-close')));
      await tester.pumpAndSettle();
      await tester.longPress(find.byKey(const ValueKey('material-task-zakaz-3')));
      await tester.pumpAndSettle();
      expect(find.text('Kirim qilish'), findsOneWidget);
      expect(selected, isNull);
      await tester.tap(find.byKey(const ValueKey('material-task-receive')));
      await tester.pumpAndSettle();
      expect(selected!.order!.id, 'zakaz-3');
      expect(selected!.order!.widthMm, 384);
      completed = true;
      Navigator.of(tester.element(find.text('Receipt'))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('material-task-zakaz-3')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }, () => MockClient((request) async {
      if (request.url.path.endsWith('/gscale/material-tasks')) {
        final ids = (jsonDecode(request.body)['order_ids'] as List).cast<String>();
        requests.add(ids);
        return http.Response(jsonEncode({'orders': [for (final id in ids) {
          'order_id': id,
          'materials': id == 'zakaz-2' ? [] : [
            {'material': 'PET', 'micron': 12, 'assigned': true},
            {'material': 'PET', 'micron': 20,
             'assigned': completed || !['zakaz-3', 'zakaz-6'].contains(id)},
          ],
        }]}), 200);
      }
      if (request.url.path.endsWith('/raw-material-assignments')) {
        expect(request.url.queryParameters['order_id'], 'zakaz-3');
        return http.Response(jsonEncode([{
          'order_id': 'zakaz-3', 'apparatus': machine.id, 'barcode': '30AA',
          'item_code': 'PET', 'item_name': 'PET', 'item_group': 'Rulon',
          'stock_status': 'reserved', 'reserved_order_id': 'zakaz-3',
          'stock_qty': 12, 'stock_uom': 'kg', 'stock_warehouse': 'Ombor',
          'received_qty': 12, 'remaining_qty': 12,
        }]), 200);
      }
      if (request.url.path.endsWith('/qolip/order-products')) {
        return http.Response(jsonEncode({'orders': [{
          'order_id': 'zakaz-3', 'product': {
            'code': 'ITEM-3', 'name': 'Product 3', 'qolip_code': 'QOLIP-3',
            'has_qolip_spec': true, 'qolip_size': 42,
          },
        }]}), 200);
      }
      if (request.url.path.contains('order-image')) return http.Response('', 404);
      return http.Response('{}', 200);
    }));
  });

  testWidgets(
      'window is taken before QR/search filters, preserves rank and refreshes after assignment',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final missing = {'zakaz-3', 'zakaz-6'};
    final requests = <List<String>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qolip-task-zakaz-3')), findsOneWidget);
      expect(find.byKey(const ValueKey('qolip-task-zakaz-6')), findsOneWidget);
      expect(find.text('Profil'), findsNothing);
      expect(find.text('Vazifalar'), findsWidgets);
      expect(AppRouter.canOpenRoute(AppRoutes.qolipTasks), isTrue);
      await tester.tap(find.byKey(const ValueKey('qolip-tasks-limit')));
      await tester.pumpAndSettle();
      for (final count in [5, 10, 20, 50]) {
        expect(find.text('$count ta'), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('qolip-tasks-limit-5 ta')));
      await tester.pumpAndSettle();
      expect(requests.last,
          ['zakaz-1', 'zakaz-2', 'zakaz-3', 'zakaz-4', 'zakaz-5']);
      final third = find.byKey(const ValueKey('qolip-task-zakaz-3'));
      expect(third, findsOneWidget);
      expect(
          find.descendant(of: third, matching: find.text('3')), findsOneWidget);
      expect(find.byKey(const ValueKey('qolip-task-zakaz-6')), findsNothing);
      await tester.enterText(find.byType(EditableText).first, 'Product 6');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qolip-task-zakaz-6')), findsNothing);
      await tester.enterText(find.byType(EditableText).first, '');
      await tester.pumpAndSettle();
      await tester.tap(third);
      await tester.pumpAndSettle();
      expect(requests.last, ['zakaz-3']);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.textContaining('ITEM-3'), findsWidgets);
      // Simulate a colleague registering the exact product while its form is open.
      missing.remove('zakaz-3');
      Navigator.of(tester.element(find.byIcon(Icons.lock_outline_rounded)))
          .pop();
      await tester.pumpAndSettle();
      expect(third, findsNothing);
      expect(
          find.text(
              'Tanlangan orderlarning barchasiga qolip QR’i biriktirilgan.'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/qolip/order-products')) {
                final ids = (jsonDecode(request.body)['order_ids'] as List)
                    .cast<String>();
                requests.add(ids);
                return http.Response(
                    jsonEncode({
                      'orders': [
                        for (final id in ids)
                          {
                            'order_id': id,
                            'product': {
                              'code': 'ITEM-${id.split('-').last}',
                              'name': 'Product ${id.split('-').last}',
                              'item_group': 'Tayyor mahsulot',
                              'has_qolip_spec': !missing.contains(id)
                            },
                          }
                      ]
                    }),
                    200);
              }
              if (request.url.path.endsWith('/qolip/blocks')) {
                return http.Response(
                    '{"warehouses":["Qolip ombori"],"blocks":[]}', 200);
              }
              if (request.url.path.contains('order-image')) {
                return http.Response('', 404);
              }
              return http.Response('{}', 200);
            }));
  });

  testWidgets('read failure is retryable and never reported as all ready',
      (tester) async {
    var failing = true;
    await http.runWithClient(() async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Qolip QR holatini tekshirib bo‘lmadi. Qayta urinib ko‘ring.'),
          findsOneWidget);
      expect(find.textContaining('barchasiga qolip QR'), findsNothing);
      failing = false;
      QolipDataRevision.notifyLocationsChanged();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qolip-task-zakaz-1')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/qolip/order-products')) {
                if (failing) {
                  return http.Response('{"error":"store_failed"}', 500);
                }
                final ids = jsonDecode(request.body)['order_ids'] as List;
                return http.Response(
                    jsonEncode({
                      'orders': [
                        for (final id in ids) {'order_id': id, 'product': null}
                      ]
                    }),
                    200);
              }
              if (request.url.path.contains('order-image')) {
                return http.Response('', 404);
              }
              return http.Response('{}', 200);
            }));
  });

  test('partial readiness responses fail instead of hiding tasks', () async {
    await http.runWithClient(() async {
      await expectLater(MobileApi.instance.qolipOrderProducts(['zakaz-1']),
          throwsFormatException);
    }, () => MockClient((_) async => http.Response('{"orders":[]}', 200)));
  });
}

class _NoImageDisk implements OrderImageDiskStore {
  @override
  Future<Uint8List?> read(String key) async => null;
  @override
  Future<void> write(String key, Uint8List bytes) async {}
  @override
  Future<void> remove(String key) async {}
  @override
  Future<void> clear() async {}
}
