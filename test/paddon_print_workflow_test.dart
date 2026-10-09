import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/native_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/printing/session_bluetooth_printer.dart';
import 'package:accord_mobile_v2/src/core/production/active_rezka_paddon_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/widgets/active_rezka_paddon_action.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apparatus = 'apparatus:default:asset-010';
const channel = MethodChannel('accord/bluetooth_printer');

class _PrintServer {
  bool locked = false;
  bool printerOk = true;
  bool newlyLocked = true;
  String? active = '00001';
  int confirmations = 0;
  int created = 0;
  final events = <String>[];

  Map<String, dynamic> paddon({String code = '00001', bool? isLocked}) => {
        'id': 'paddon-$code',
        'code': code,
        'created_by_ref': 'original-worker',
        'item_count': 0,
        'created_at_unix': 1,
        'updated_at_unix': 2,
        if (isLocked ?? locked) 'locked_at_unix': 3,
      };

  late final client = MockClient((request) async {
    final endpoint = request.url.path.split('/').last;
    final Map<String, dynamic> payload;
    switch (endpoint) {
      case 'print':
        payload = {
          'ok': true,
          'paddon': paddon(),
          'can_close_after_print': true,
          'qr_payload': '00001',
          'print': {
            'qr_payload': '00001',
            'item_code': '00001',
            'item_name': 'Paddon 00001',
            'label_kind': 'paddon_code',
            'gross_qty': 1,
            'qty': 1,
            'unit': 'dona',
            'print_count': 1,
          }
        };
      case 'confirm':
        expect(events.last, 'printer-success',
            reason: 'lock follows physical print success');
        events.add('lock');
        confirmations++;
        locked = true;
        active = null;
        payload = {
          'ok': true,
          'paddon': paddon(),
          'newly_locked': newlyLocked,
          'apparatus': apparatus,
          'apparatus_options': [
            {'id': apparatus, 'name': 'Rezka'}
          ]
        };
      case 'next':
        expect(jsonDecode(request.body),
            {'code': '00001', 'apparatus': apparatus});
        expect(locked, isTrue);
        events.add('create');
        created++;
        active = '00002';
        payload = {
          'ok': true,
          'paddon': paddon(code: '00002', isLocked: false),
          'apparatus': apparatus,
          'code': '00002'
        };
      case 'active':
        payload = {'ok': true, 'apparatus': apparatus, 'code': active};
      default:
        throw StateError('Unexpected request ${request.url}');
    }
    return http.Response(jsonEncode(payload), 200);
  });

  Future<AdminPaddonSnapshot> snapshot() async =>
      AdminPaddonSnapshot.fromJson({'paddon': paddon(), 'items': []});
}

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _PrintServer server;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Rezka',
        legalName: '',
        ref: 'worker-1',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
        assignedApparatus: [apparatus]);
    server = _PrintServer();
    SessionBluetoothPrinter.remember(
        const BluetoothPrinterProfile(name: 'Printer', address: 'AA:BB'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'pairedPrinters') {
        return [
          {'name': 'Printer', 'address': 'AA:BB'}
        ];
      }
      if (call.method == 'printLabel') {
        server.events
            .add(server.printerOk ? 'printer-success' : 'printer-failure');
        return {'ok': server.printerOk};
      }
      throw StateError(call.method);
    });
  });
  tearDown(() {
    SessionBluetoothPrinter.forget();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> openAndPrint(WidgetTester tester) async {
    await tester.pumpWidget(_app(AparatchiPaddonDetailScreen(
        code: '00001',
        loader: server.snapshot,
        apparatusLoader: () async => const [])));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paddon-print-qr')));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Yes seals the old paddon and selects one new paddon; reprint has no prompt',
      (tester) async {
    await http.runWithClient(() async {
      await openAndPrint(tester);
      expect(find.text('Yangi paddon ochilsinmi?'), findsOneWidget);
      expect(server.locked, isTrue);
      expect(server.active, isNull);
      await tester.tap(find.byKey(const ValueKey('paddon-next-confirm')));
      await tester.pumpAndSettle();
      expect(server.created, 1);
      expect(await ActiveRezkaPaddonStore.load(apparatus), '00002');
      expect(find.text('Qulflangan'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('paddon-print-qr')));
      await tester.pumpAndSettle();
      expect(find.text('Yangi paddon ochilsinmi?'), findsNothing);
      expect(server.created, 1);
      expect(server.confirmations, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  testWidgets('No keeps the old paddon sealed and leaves no active selection',
      (tester) async {
    await http.runWithClient(() async {
      await openAndPrint(tester);
      await tester.tap(find.byKey(const ValueKey('paddon-next-cancel')));
      await tester.pumpAndSettle();
      expect(server.locked, isTrue);
      expect(server.created, 0);
      expect(await ActiveRezkaPaddonStore.load(apparatus), isNull);
      expect(find.text('Qulflangan'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  testWidgets('different profiles can reprint another worker\'s locked paddon',
      (tester) async {
    server.locked = true;
    for (final role in [
      UserRole.aparatchi,
      UserRole.boyoqchi,
      UserRole.werka
    ]) {
      AppSession.instance.profile = SessionProfile(
          role: role,
          displayName: 'Other user',
          legalName: '',
          ref: 'other-user',
          phone: '',
          avatarUrl: '',
          capabilities: const []);
      SessionBluetoothPrinter.remember(
          const BluetoothPrinterProfile(name: 'Printer', address: 'AA:BB'));
      await http.runWithClient(() async {
        await openAndPrint(tester);
        expect(server.events.last, 'printer-success');
        expect(server.locked, isTrue);
        expect(server.confirmations, 0);
        expect(server.created, 0);
        expect(find.text('Yangi paddon ochilsinmi?'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => server.client);
    }
  });

  testWidgets('a concurrent print confirmation does not repeat the prompt',
      (tester) async {
    server.newlyLocked = false;
    await http.runWithClient(() async {
      await openAndPrint(tester);
      expect(server.locked, isTrue);
      expect(find.text('Yangi paddon ochilsinmi?'), findsNothing);
      expect(server.created, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  testWidgets('home active selection refreshes when a printed paddon is sealed',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(const Scaffold(
          body: ActiveRezkaPaddonAction(apparatusId: apparatus))));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Faol paddon: 00001'), findsOneWidget);
      server.active = null;
      ActiveRezkaPaddonStore.notifyChanged();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Faol paddon: 00001'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  testWidgets(
      'printer failure does not seal, clear selection or offer another paddon',
      (tester) async {
    server.printerOk = false;
    await http.runWithClient(() async {
      await openAndPrint(tester);
      expect(server.locked, isFalse);
      expect(server.active, '00001');
      expect(server.confirmations, 0);
      expect(find.text('Yangi paddon ochilsinmi?'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  testWidgets('home picker excludes locked paddons', (tester) async {
    server.locked = true;
    server.active = null;
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(Scaffold(
          body: ActiveRezkaPaddonAction(
              apparatusId: apparatus,
              loader: () async => [
                    AdminPaddon.fromJson(server.paddon()),
                    AdminPaddon.fromJson(
                        server.paddon(code: '00002', isLocked: false))
                  ]))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rezka-active-paddon')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rezka-paddon-00001')), findsNothing);
      expect(find.byKey(const ValueKey('rezka-paddon-00002')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });
}
