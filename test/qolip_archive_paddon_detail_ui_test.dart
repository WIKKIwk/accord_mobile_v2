import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/navigation/app_root_navigation.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/rps_qr_reprint_sheet.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart'
    show QolipProductContainerCard;
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_storage_screen.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/widgets/qolip_dock.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
      expect(find.byType(QrImageView), findsOneWidget);
      final dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text('QP-00012')),
          findsOneWidget);
      Navigator.of(tester.element(dialog)).pop();
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
