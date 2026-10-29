import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/navigation/app_root_navigation.dart';
import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/printing/session_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/rps_qr_reprint_sheet.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart'
    show QolipProductContainerCard;
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_storage_screen.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/widgets/qolip_dock.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> archivedPallet({bool restored = false}) => {
      'id': 'visit-1',
      'kind': 'paddon',
      'code': 'QP-00012',
      'warehouse': 'Mold store',
      'archived_at': '2026-10-29T10:00:00Z',
      'archived_by_name': 'Worker',
      if (restored) 'restored_at': '2026-10-30T10:00:00Z',
      'snapshot': {
        'paddon': {'location': 'A1'},
        'items': [
          {
            'qolip_code': 'Q-ONE',
            'warehouse': 'Mold store',
            'qolip_set_id': 'SET-OLD',
            'item_code': 'SNAPSHOT',
            'item_name': 'Old item',
            'size': 40,
            'products': [
              {'code': 'ITEM-A', 'name': 'Alpha'}
            ],
          },
          {
            'qolip_code': 'Q-TWO',
            'warehouse': 'Mold store',
            'qolip_set_id': 'SET-OLD',
            'item_name': 'Old item',
            'size': 40,
            'products': [
              {'code': 'ITEM-A', 'name': 'Alpha'}
            ],
          }
        ]
      }
    };

Widget app(QolipArchiveEntry entry) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: QolipArchiveDetailScreen(entry: entry),
    );

http.Response response(Map<String, dynamic> json, [int status = 200]) =>
    http.Response(jsonEncode(json), status,
        headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = 'paddon-detail-test';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      ref: 'worker',
      displayName: 'Worker',
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
      assignedWarehouses: ['Mold store'],
    );
    AppSession.instance.revision.value++;
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    QolipCatalogStore.instance.reset();
  });

  testWidgets('archive pallet uses the standard shell, dock and back button',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => QolipArchiveDetailScreen(
                    entry: QolipArchiveEntry.fromJson(archivedPallet()),
                  ),
                ),
              ),
              child: const Text('Open archive'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open archive'));
      await tester.pumpAndSettle();

      final shell = tester.widget<AppShell>(find.byType(AppShell));
      expect(shell.nativeTopBar, isTrue);
      expect(shell.showProfileAction, isFalse);
      expect(shell.bottom, isA<QolipDock>());
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      final summary =
          find.byKey(const ValueKey('qolip-archive-paddon-summary'));
      final clips = tester.widgetList<ClipRRect>(
          find.ancestor(of: summary, matching: find.byType(ClipRRect)));
      expect(
          clips.any((clip) =>
              clip.borderRadius ==
              const BorderRadius.vertical(
                  top: Radius.circular(18), bottom: Radius.circular(18))),
          isTrue);

      final group = find
          .byKey(const ValueKey('qolip-archive-product-expand-product:item-a'));
      await tester.ensureVisible(group);
      await tester.tap(group);
      await tester.pumpAndSettle();
      final lastMold =
          find.byKey(const ValueKey('qolip-archive-mold-visit-1-Q-TWO'));
      await tester.ensureVisible(lastMold);
      await tester.pumpAndSettle();
      final dock = find.byKey(const ValueKey('app-navigation-bar-shell'));
      expect(tester.getRect(lastMold).bottom,
          lessThanOrEqualTo(tester.getRect(dock).top));

      await tester.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.qr_code_2_rounded)));
      await tester.pumpAndSettle();
      final qrSheet = find.byType(RpsQrReprintSheet);
      expect(qrSheet, findsOneWidget);
      expect(tester.widget<RpsQrPreview>(find.byType(RpsQrPreview)).payload,
          'qolip-paddon:QP-00012');
      expect(find.descendant(of: qrSheet, matching: find.text('QP-00012')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('qolip-archive-paddon-qr-print-QP-00012')),
          findsOneWidget);
      Navigator.of(tester.element(qrSheet)).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Open archive'), findsOneWidget);
    },
        () => MockClient((request) async =>
            response({'ok': true, 'items': [], 'has_more': false})));
  });

  testWidgets('archive pallet dock navigates to every role destination',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const destinations = <String, String>{
      'Home': AppRoutes.qolipHome,
      'Molds': AppRoutes.qolipProducts,
      'Tasks': AppRoutes.qolipTasks,
      'Chat': AppRoutes.chat,
    };
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        navigatorObservers: [AppRootNavigation.navigatorObserver],
        routes: {
          for (final destination in destinations.entries)
            destination.value: (_) => Scaffold(
                appBar: AppBar(), body: Text('${destination.key} destination')),
        },
        home: QolipArchiveDetailScreen(
            entry: QolipArchiveEntry.fromJson(archivedPallet())),
      ));
      await tester.pumpAndSettle();
      for (final destination in destinations.keys) {
        final tab = find.descendant(
            of: find.byType(NavigationBar), matching: find.text(destination));
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(find.text('$destination destination'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(QolipDock), findsOneWidget);
      }
    },
        () => MockClient((request) async =>
            response({'ok': true, 'items': [], 'has_more': false})));
  });

  testWidgets('archive pallet QR prints the typed label over Bluetooth once',
      (tester) async {
    const channel = MethodChannel('accord/bluetooth_printer');
    const address = '00:11:22:33:44:55';
    final messenger = tester.binding.defaultBinaryMessenger;
    final pending = Completer<http.Response>();
    final requests = <http.Request>[];
    final printed = <Map<dynamic, dynamic>>[];
    String? copied;
    SessionBluetoothPrinter.remember(
        const BluetoothPrinterProfile(name: 'XP-P323B', address: address));
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pairedPrinters') {
        return [
          {'name': 'XP-P323B', 'address': address}
        ];
      }
      if (call.method == 'printLabel') {
        printed.add(call.arguments as Map);
        return {'ok': true, 'bytes': 1};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      SessionBluetoothPrinter.forget();
    });

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester
          .pumpWidget(app(QolipArchiveEntry.fromJson(archivedPallet())));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.qr_code_2_rounded)));
      await tester.pumpAndSettle();
      final sheet =
          tester.widget<RpsQrReprintSheet>(find.byType(RpsQrReprintSheet));
      expect(sheet.payload, 'qolip-paddon:QP-00012');
      expect(sheet.displayPayload, 'QP-00012');
      expect(sheet.details.map((detail) => detail.value),
          containsAll(['Mold store', '2']));
      final copy =
          find.byKey(const ValueKey('qolip-archive-paddon-qr-copy-QP-00012'));
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pump();
      expect(copied, 'QP-00012');

      final print =
          find.byKey(const ValueKey('qolip-archive-paddon-qr-print-QP-00012'));
      await tester.ensureVisible(print);
      await tester.tap(print);
      await tester.pump();
      await tester.pump();
      expect(requests, hasLength(1));
      expect(tester.widget<FilledButton>(print).onPressed, isNull);
      pending.complete(response({
        'ok': true,
        'paddon': {'code': 'QP-00012', 'item_count': 2},
        'qr_payload': 'qolip-paddon:QP-00012',
        'print': {
          'qr_payload': 'qolip-paddon:QP-00012',
          'label_kind': 'paddon_code',
          'item_code': 'QP-00012',
          'item_name': 'Qolip paddoni QP-00012',
        },
      }));
      await tester.pumpAndSettle();
      final body = jsonDecode(requests.single.body) as Map;
      expect(body['qolip_code'], 'QP-00012');
      expect(body['print_transport'], 'offline');
      expect(printed, hasLength(1));
      expect(printed.single['epc'], 'qolip-paddon:QP-00012');
      expect(printed.single['label_kind'], 'paddon_code');
      expect(printed.single['paddon_label_lines'],
          ['QOLIP PADDONI: QP-00012', 'QOLIPLAR SONI: 2']);
      expect(tester.widget<FilledButton>(print).onPressed, isNotNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                expect(request.url.path, '/v1/mobile/qolip/paddons/qr/print');
                requests.add(request);
                return pending.future;
              }
              return response({'ok': true, 'items': [], 'has_more': false});
            }));
  });

  testWidgets('account change during QR preparation cannot print',
      (tester) async {
    const channel = MethodChannel('accord/bluetooth_printer');
    const address = '00:11:22:33:44:55';
    final messenger = tester.binding.defaultBinaryMessenger;
    final pending = Completer<http.Response>();
    var requests = 0;
    var printed = 0;
    SessionBluetoothPrinter.remember(
        const BluetoothPrinterProfile(name: 'XP-P323B', address: address));
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pairedPrinters') {
        return [
          {'name': 'XP-P323B', 'address': address}
        ];
      }
      if (call.method == 'printLabel') printed++;
      return {'ok': true};
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      SessionBluetoothPrinter.forget();
    });

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester
          .pumpWidget(app(QolipArchiveEntry.fromJson(archivedPallet())));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.qr_code_2_rounded)));
      await tester.pumpAndSettle();
      final print =
          find.byKey(const ValueKey('qolip-archive-paddon-qr-print-QP-00012'));
      await tester.ensureVisible(print);
      await tester.tap(print);
      await tester.pump();
      await tester.pump();
      expect(requests, 1);
      AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        ref: 'different-worker',
        displayName: 'Different worker',
        legalName: '',
        phone: '',
        avatarUrl: '',
      );
      AppSession.instance.revision.value++;
      await tester.pump();
      pending.complete(response({
        'ok': true,
        'paddon': {'code': 'QP-00012', 'item_count': 2},
        'qr_payload': 'qolip-paddon:QP-00012',
        'print': {
          'qr_payload': 'qolip-paddon:QP-00012',
          'label_kind': 'paddon_code',
        },
      }));
      await tester.pumpAndSettle();
      expect(printed, 0);
      expect(find.byType(RpsQrReprintSheet), findsNothing);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                requests++;
                return pending.future;
              }
              return response({'ok': true, 'items': [], 'has_more': false});
            }));
  });

  testWidgets('a failed pallet QR print can be retried', (tester) async {
    const channel = MethodChannel('accord/bluetooth_printer');
    const address = '00:11:22:33:44:55';
    final messenger = tester.binding.defaultBinaryMessenger;
    var requests = 0;
    var printed = 0;
    SessionBluetoothPrinter.remember(
        const BluetoothPrinterProfile(name: 'XP-P323B', address: address));
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pairedPrinters') {
        return [
          {'name': 'XP-P323B', 'address': address}
        ];
      }
      if (call.method == 'printLabel') printed++;
      return {'ok': true};
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
      SessionBluetoothPrinter.forget();
    });

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester
          .pumpWidget(app(QolipArchiveEntry.fromJson(archivedPallet())));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.qr_code_2_rounded)));
      await tester.pumpAndSettle();
      final print =
          find.byKey(const ValueKey('qolip-archive-paddon-qr-print-QP-00012'));
      await tester.ensureVisible(print);
      await tester.tap(print);
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(printed, 0);
      expect(find.text('Paddon QR could not be printed'), findsOneWidget);
      expect(tester.widget<FilledButton>(print).onPressed, isNotNull);

      await tester.ensureVisible(print);
      await tester.tap(print);
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(printed, 1);
      expect(find.text('Paddon QR could not be printed'), findsNothing);
    },
        () => MockClient((request) async {
              if (request.method != 'POST') {
                return response({'ok': true, 'items': [], 'has_more': false});
              }
              requests++;
              if (requests == 1) {
                return response({'ok': false, 'error': 'print_failed'}, 500);
              }
              return response({
                'ok': true,
                'paddon': {'code': 'QP-00012', 'item_count': 2},
                'qr_payload': 'qolip-paddon:QP-00012',
                'print': {
                  'qr_payload': 'qolip-paddon:QP-00012',
                  'label_kind': 'paddon_code',
                },
              });
            }));
  });

  testWidgets(
      'archive pallet shows grouped saved contents and read-only mold details',
      (tester) async {
    final reads = <String>[];
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(450, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester
          .pumpWidget(app(QolipArchiveEntry.fromJson(archivedPallet())));
      await tester.pumpAndSettle();
      final summary =
          find.byKey(const ValueKey('qolip-archive-paddon-summary'));
      expect(summary, findsOneWidget);
      expect(find.descendant(of: summary, matching: find.text('Mold store')),
          findsOneWidget);
      expect(find.descendant(of: summary, matching: find.text('A1')),
          findsOneWidget);
      expect(find.descendant(of: summary, matching: find.text('Archived')),
          findsOneWidget);
      expect(find.descendant(of: summary, matching: find.text('Molds: 2')),
          findsOneWidget);
      expect(find.byType(QolipProductContainerCard), findsOneWidget);
      expect(find.text('Q-ONE'), findsNothing);
      final group = find
          .byKey(const ValueKey('qolip-archive-product-expand-product:item-a'));
      await tester.ensureVisible(group);
      await tester.tap(group);
      await tester.pumpAndSettle();
      expect(find.text('Q-ONE'), findsOneWidget);
      expect(find.text('Q-TWO'), findsOneWidget);
      final before = reads.length;
      final row =
          find.byKey(const ValueKey('qolip-archive-mold-visit-1-Q-ONE'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      final sheet =
          tester.widget<RpsQrReprintSheet>(find.byType(RpsQrReprintSheet));
      expect(sheet.payload, 'Q-ONE');
      expect(sheet.details.map((d) => d.value), contains('SET-OLD'));
      expect(sheet.onReprint, isNull);
      expect(reads.length, before);
    },
        () => MockClient((request) async {
              reads.add(request.url.path);
              return response({'ok': true, 'items': [], 'has_more': false});
            }));
  });

  testWidgets('restore refuses a different archive visit and sends no write',
      (tester) async {
    var writes = 0;
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(450, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester
          .pumpWidget(app(QolipArchiveEntry.fromJson(archivedPallet())));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Restore'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(find.widgetWithText(OutlinedButton, 'Restore'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') writes++;
              if (request.url.path.endsWith('/paddons/detail')) {
                return response({
                  'ok': true,
                  'paddon': {
                    'code': 'QP-00012',
                    'warehouse': 'Mold store',
                    'locked': false,
                    'archived': true,
                    'revision': 9,
                    'item_count': 2,
                    'archive_entry_id': 'different-visit',
                  },
                  'items': [],
                  'history': [],
                });
              }
              return response({'ok': true, 'items': [], 'has_more': false});
            }));
  });

  testWidgets('pallet QR is unavailable during a restore request',
      (tester) async {
    final pending = Completer<http.Response>();
    var writes = 0;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester
          .pumpWidget(app(QolipArchiveEntry.fromJson(archivedPallet())));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Restore'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();
      final qrButton = find.descendant(
        of: find.byType(AppBar),
        matching: find.widgetWithIcon(IconButton, Icons.qr_code_2_rounded),
      );
      expect(tester.widget<IconButton>(qrButton).onPressed, isNull);
      pending.complete(response({
        'ok': true,
        'paddon': {
          'code': 'QP-00012',
          'warehouse': 'Mold store',
          'locked': false,
          'archived': true,
          'revision': 9,
          'item_count': 2,
          'archive_entry_id': 'different-visit',
        },
        'items': [],
        'history': [],
      }));
      await tester.pumpAndSettle();
      expect(writes, 0);
      expect(tester.widget<IconButton>(qrButton).onPressed, isNotNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') writes++;
              if (request.url.path.endsWith('/paddons/detail')) {
                return pending.future;
              }
              return response({'ok': true, 'items': [], 'has_more': false});
            }));
  });

  testWidgets('restored historical pallet has no restore action',
      (tester) async {
    await http.runWithClient(() async {
      await tester.binding.setSurfaceSize(const Size(450, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
          app(QolipArchiveEntry.fromJson(archivedPallet(restored: true))));
      await tester.pumpAndSettle();
      expect(find.text('Restored'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Restore'), findsNothing);
      expect(find.text('Current pallet state'), findsOneWidget);
    },
        () => MockClient((request) async =>
            response({'ok': true, 'items': [], 'has_more': false})));
  });
}
