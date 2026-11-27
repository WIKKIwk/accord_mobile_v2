import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/app_segment_surface_card.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/m3_segmented_list.dart';
import 'package:accord_mobile_v2/src/core/widgets/navigation/app_navigation_bar.dart';
import 'package:accord_mobile_v2/src/core/widgets/navigation/role_dock.dart';
import 'package:accord_mobile_v2/src/core/widgets/printing/bluetooth_printer_list.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_list_row.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/waste/presentation/waste_receiving_screen.dart';
import 'package:accord_mobile_v2/src/features/waste/presentation/waste_warehouses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _rezka = 'apparatus:default:asset-010';
const _laminatsiya = 'apparatus:default:asset-007';
const _bosma = 'apparatus:default:bosma_7';
const _options = {
  'apparatuses': [
    {'id': _rezka, 'name': 'Rezka A'},
    {'id': _laminatsiya, 'name': 'Laminatsiya B'},
    {'id': _bosma, 'name': 'Bosma C'},
  ],
};

Widget _receiver() => MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const WasteReceivingScreen(),
      routes: {
        AppRoutes.wasteWarehouses: (_) => const WasteWarehousesScreen(),
      },
    );

http.Response _json(Object response) => http.Response(
      jsonEncode(response),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'waste-layout-token';
    AppSession.instance.profile = SessionProfile.fromJson({
      'role': 'chiqindi_qabulchi',
      'ref': 'waste-layout-worker',
      'display_name': 'Chiqindi qabul qiluvchi',
      'capabilities': ['waste.receive'],
    });
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('receiver uses the shared list, dock and wide form on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bins = [
      for (var index = 1; index <= 3; index++)
        {
          'code': 'CQ-00$index',
          'name': 'Quti $index',
          'qr_payload': 'ACCORD-WASTE:CQ-00$index',
          'tare_kg': index,
          'tolerance_kg': 0.5,
          'status': 'empty',
          'configured': true,
          'apparatus_ids': [_rezka],
        },
    ];
    final paths = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_receiver());
      await tester.pumpAndSettle();

      expect(find.byType(RoleDock), findsOneWidget);
      final navigation =
          tester.widget<AppNavigationBar>(find.byType(AppNavigationBar));
      expect(navigation.destinations.map((item) => item.label),
          ['Qabul', 'Omborlar', 'Profil', 'Chat']);

      final rows = find.descendant(
        of: find.byType(M3SegmentSpacedColumn),
        matching: find.byType(AdminCatalogListRow),
      );
      expect(
          tester.widgetList<AdminCatalogListRow>(rows).map((row) => row.slot), [
        M3SegmentVerticalSlot.top,
        M3SegmentVerticalSlot.middle,
        M3SegmentVerticalSlot.bottom,
      ]);
      expect(
        tester.getRect(rows.at(1)).top - tester.getRect(rows.first).bottom,
        M3SegmentedListGeometry.gap,
      );

      final newBin = find.text('Yangi quti');
      final actionCard = find.ancestor(
          of: newBin, matching: find.byType(AppSegmentSurfaceCard));
      expect(tester.getSize(actionCard).width, greaterThan(365));
      await tester.tap(newBin);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Quti kodi'), findsNothing);
      final fields = [
        for (final label in [
          'Quti nomi',
          'Bo‘sh quti vazni (kg)',
          'Ruxsat etilgan farq (kg)',
        ])
          tester.getRect(find.widgetWithText(TextFormField, label)),
      ];
      expect(fields.first.width, greaterThanOrEqualTo(290));
      for (var i = 1; i < fields.length; i++) {
        expect(fields[i].top - fields[i - 1].bottom, greaterThanOrEqualTo(12));
      }

      await tester.ensureVisible(find.text('Bekor qilish'));
      await tester.tap(find.text('Bekor qilish'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quti 2 · CQ-002'));
      await tester.pumpAndSettle();
      expect(find.text('Bo‘sh · Tara 2 kg'), findsOneWidget);
      expect(find.text('Qutini sozlash'), findsOneWidget);
      expect(tester.widget<AdminCatalogListRow>(rows.at(1)).backgroundColor,
          isNotNull);

      navigation.onDestinationSelected(1);
      // RoleDock uses AppRootNavigation, which schedules the route after a frame.
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('G‘arbiy chiqindi ombori'), findsOneWidget);
      expect(find.text('18 kg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              paths.add(request.url.path);
              return _json(switch (request.url.path) {
                '/v1/mobile/waste/warehouses' => {
                    'warehouses': [
                      {
                        'id': 'warehouse-waste-west',
                        'warehouse': 'G‘arbiy chiqindi ombori',
                        'on_hand_kg': 18,
                        'receipt_count': 1,
                      },
                    ],
                  },
                '/v1/mobile/waste/bins/options' => _options,
                '/v1/mobile/waste/bins/detail' => bins.singleWhere((bin) =>
                    bin['code'] == request.url.queryParameters['code']),
                _ => {'bins': bins},
              });
            }));
    expect(paths, [
      '/v1/mobile/waste/bins',
      '/v1/mobile/waste/bins/options',
      '/v1/mobile/waste/bins/detail',
      '/v1/mobile/waste/warehouses',
    ]);
  });

  testWidgets(
      'receiver registers, prints the QR over Bluetooth, and renames a bin',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? bin;
    final writes = <(String, Map<String, dynamic>)>[];
    final printJobs = <Map<Object?, Object?>>[];
    const printerChannel = MethodChannel('accord/bluetooth_printer');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(printerChannel, (call) async {
      if (call.method == 'pairedPrinters') {
        return [
          {'name': 'Printer A', 'address': '00:11:22:33:44:55'},
          {'name': 'Printer B', 'address': '00:11:22:33:44:66'},
        ];
      }
      expect(call.method, 'printLabel');
      printJobs.add(Map<Object?, Object?>.from(call.arguments as Map));
      return {'ok': printJobs.length > 1};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(printerChannel, null));
    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer waste-layout-token');
      final action = request.url.pathSegments.last;
      if (action == 'bins') {
        return _json({
          'bins': [if (bin case final b?) b]
        });
      }
      if (action == 'options') {
        expect(request.url.queryParameters['apparatus_only'], 'true');
        return _json(_options);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      writes.add((action, body));
      bin = {
        ...?bin,
        ...body,
        'code': 'CQ-001',
        'qr_payload': 'ACCORD-WASTE:CQ-001',
        'tolerance_kg': 0.5,
        'status': 'empty',
        'configured': true,
      }..remove('request_id');
      return _json(bin!);
    });

    Future<void> tap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await http.runWithClient(() async {
      await tester.pumpWidget(_receiver());
      await tester.pumpAndSettle();
      await tap(find.text('Yangi quti'));
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Quti nomi'), 'Bo‘sh quti A');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Bo‘sh quti vazni (kg)'), '5');
      expect(find.text('Aparatchilarni tanlash'), findsNothing);
      await tap(find.text('Saqlash'));
      expect(writes, isEmpty);
      expect(find.text('Kamida bitta apparatni tanlang.'), findsOneWidget);
      await tap(find.text('Apparatlarni tanlash'));
      await tap(find.widgetWithText(CheckboxListTile, 'Rezka A'));
      await tap(find.widgetWithText(CheckboxListTile, 'Laminatsiya B'));
      await tap(find.text('Tanlash'));
      await tap(find.text('Saqlash'));
      expect(writes.single.$1, 'register');
      final requestId = writes.single.$2['request_id'];
      expect(requestId, matches(RegExp(r'^waste-[a-f0-9]{32}$')));
      expect(writes.single.$2, {
        'request_id': requestId,
        'tare_kg': 5,
        'name': 'Bo‘sh quti A',
        'apparatus_ids': [_rezka, _laminatsiya],
      });
      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Bo‘sh quti A · CQ-001')),
        findsOneWidget,
      );
      await tap(find.text('Chop etish'));
      final printerList = find.byType(BluetoothPrinterList);
      expect(printerList, findsOneWidget);
      Navigator.of(tester.element(printerList)).pop();
      await tester.pumpAndSettle();
      expect(printJobs, isEmpty);

      await tap(find.text('Chop etish'));
      await tap(find.text('Printer B'));
      expect(find.text('QR yorlig‘ini chop etib bo‘lmadi'), findsOneWidget);
      await tap(find.text('Chop etish'));
      await tap(find.text('Printer B'));
      expect(find.text('QR yorlig‘i printerga yuborildi'), findsOneWidget);
      expect(printJobs, hasLength(2));
      for (final job in printJobs) {
        expect(job['mac_address'], '00:11:22:33:44:66');
        expect(job['epc'], 'ACCORD-WASTE:CQ-001');
        expect(job['print_count'], 1);
        expect(job['label_kind'], 'waste_bin');
        expect(job['item_code'], 'CQ-001');
        expect(job['item_name'], "BO'SH QUTI A");
        expect(job, isNot(contains('material_data_matrix')));
      }
      expect(writes, hasLength(1));
      await tap(find.text('Yopish'));
      await tap(find.text('Qutini sozlash'));
      expect(find.text('Bo‘sh quti A'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Quti kodi'))
            .initialValue,
        'CQ-001',
      );
      expect(find.text('Rezka A, Laminatsiya B'), findsOneWidget);
      expect(find.text('Aparatchilarni tanlash'), findsNothing);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Quti nomi'), 'Umumiy quti');
      await tap(find.text('Saqlash'));
      expect(writes.last.$1, 'configure');
      expect(
          writes.last.$2,
          {
            ...writes.first.$2,
            'code': 'CQ-001',
            'name': 'Umumiy quti',
          }
            ..remove('tare_kg')
            ..remove('request_id'));
      expect(find.text('Umumiy quti · CQ-001'), findsWidgets);
      await tap(find.text('QR'));
      await tap(find.text('Chop etish'));
      await tap(find.text('Printer A'));
      expect(printJobs, hasLength(3));
      expect(printJobs.last['mac_address'], '00:11:22:33:44:55');
      expect(printJobs.last['epc'], 'ACCORD-WASTE:CQ-001');
      expect(printJobs.last['label_kind'], 'waste_bin');
      expect(printJobs.last['item_code'], 'CQ-001');
      expect(printJobs.last['item_name'], 'UMUMIY QUTI');
      expect(writes, hasLength(2));
      expect(tester.takeException(), isNull);
    }, () => client);
  });
}
