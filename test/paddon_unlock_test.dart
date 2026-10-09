import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

SessionProfile _profile(String ref) => SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Worker',
      legalName: '',
      ref: ref,
      phone: '',
      avatarUrl: '',
      capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
    );

class _UnlockServer {
  bool locked = true;
  bool allowed = true;
  bool freeMode = false;
  bool rejectUnlock = false;
  int writes = 0;

  Map<String, dynamic> payload() => {
        'ok': true,
        'paddon': {
          'id': 'paddon-1',
          'code': '00001',
          'created_by_ref': 'original-worker',
          'item_count': 1,
          if (locked) 'locked_at_unix': 3,
        },
        'items': [
          {
            'batch_id': 'roll-1',
            'apparatus': 'apparatus:default:asset-010',
            'qr_payload': 'ROLL-QR'
          }
        ],
        'available_items': [],
        'free_movement_enabled': freeMode,
        'can_manage_items': !locked || freeMode,
        'can_unlock': locked && allowed,
      };

  Future<AdminPaddonSnapshot> load() async =>
      AdminPaddonSnapshot.fromJson(payload());

  late final client = MockClient((request) async {
    expect(request.method, 'POST');
    expect(request.url.path, '/v1/mobile/admin/production-maps/paddons/unlock');
    expect(request.headers['Authorization'], 'Bearer token');
    expect(jsonDecode(request.body), {'code': '00001'});
    writes++;
    if (rejectUnlock) {
      allowed = false;
      return http.Response('{"error":"paddon_unlock_forbidden"}', 403);
    }
    locked = false;
    return http.Response(jsonEncode(payload()), 200);
  });
}

Widget _app(_UnlockServer server) => MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: AparatchiPaddonDetailScreen(
        code: '00001',
        snapshot: AdminPaddonSnapshot.fromJson(server.payload()),
        loader: server.load,
        apparatus: const [],
      ),
    );

void main() {
  late _UnlockServer server;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = _profile('lock-owner');
    server = _UnlockServer();
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  Future<void> openConfirmation(WidgetTester tester) async {
    await tester.pumpWidget(_app(server));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('paddon-unlock')));
    await tester.pumpAndSettle();
    expect(find.text('Qulfdan chiqarasizmi?'), findsOneWidget);
    expect(server.writes, 0);
  }

  for (final freeMode in [false, true]) {
    testWidgets(
        'confirms unlock and refreshes the supplied snapshot; free mode: $freeMode',
        (tester) async {
      server.freeMode = freeMode;
      if (freeMode) AppSession.instance.profile = _profile('other-worker');
      await http.runWithClient(() async {
        await openConfirmation(tester);
        await tester.tap(find.byKey(const ValueKey('paddon-unlock-confirm')));
        await tester.pumpAndSettle();
        expect(server.writes, 1);
        expect(server.locked, isFalse);
        expect(find.byKey(const ValueKey('paddon-unlock')), findsNothing);
        expect(find.byKey(const ValueKey('paddon-wip-card-roll-1')),
            findsOneWidget);
        expect(find.text('Paddon qulfdan chiqarildi.'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => server.client);
    });
  }

  testWidgets('No preserves the lock and sends no mutation', (tester) async {
    await http.runWithClient(() async {
      await openConfirmation(tester);
      await tester.tap(find.byKey(const ValueKey('paddon-unlock-cancel')));
      await tester.pumpAndSettle();
      expect(server.writes, 0);
      expect(server.locked, isTrue);
      expect(find.byKey(const ValueKey('paddon-unlock')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  testWidgets('uses server permission even when free mode is enabled',
      (tester) async {
    server.freeMode = true;
    server.allowed = false;
    await tester.pumpWidget(_app(server));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ActionChip>(find.byKey(const ValueKey('paddon-unlock')))
            .onPressed,
        isNull);
    expect(server.writes, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'a revoked permission keeps the lock and refreshes the disabled action',
      (tester) async {
    server.rejectUnlock = true;
    await http.runWithClient(() async {
      await openConfirmation(tester);
      await tester.tap(find.byKey(const ValueKey('paddon-unlock-confirm')));
      await tester.pumpAndSettle();
      expect(server.writes, 1);
      expect(server.locked, isTrue);
      expect(
          tester
              .widget<ActionChip>(find.byKey(const ValueKey('paddon-unlock')))
              .onPressed,
          isNull);
      expect(
          find.text(
              'Boshqa ishchining qulfini ochish uchun admin erkin boshqarish sozlamasini yoqishi kerak.'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  testWidgets(
      'switching profile while confirming does not unlock the old profile paddon',
      (tester) async {
    await http.runWithClient(() async {
      await openConfirmation(tester);
      AppSession.instance.profile = _profile('another-profile');
      await tester.tap(find.byKey(const ValueKey('paddon-unlock-confirm')));
      await tester.pumpAndSettle();
      expect(server.writes, 0);
      expect(server.locked, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => server.client);
  });

  test('missing unlock permission fails closed', () {
    final payload = server.payload()..remove('can_unlock');
    expect(AdminPaddonSnapshot.fromJson(payload).canUnlock, isFalse);
  });
}
