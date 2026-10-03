import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/telegram/models/telegram_models.dart';
import 'package:accord_mobile_v2/src/features/admin/telegram/presentation/telegram_alert_settings_card.dart';
import 'package:accord_mobile_v2/src/features/admin/telegram/presentation/admin_telegram_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'admin-token';
  });
  tearDown(() => AppSession.instance.token = null);

  final payload = <String, dynamic>{
    'alerts': {
      'sender_user_id': '101',
      'group': {'chat_id': '111', 'title': 'Printing'},
      'raw_material_members': [
        {'user_id': 201, 'display_name': 'Supplier', 'username': 'supplier'},
      ],
      'qolip_members': [
        {'user_id': 301, 'display_name': 'Mold operator', 'username': ''},
      ],
    },
  };

  test('overview reads separate alert roles and accepts old backend responses',
      () {
    final settings = TelegramAdminOverview.fromJson(payload).alerts;
    expect(settings.senderUserId, '101');
    expect(settings.groupTitle, 'Printing');
    expect(settings.materialMembers, ['@supplier']);
    expect(settings.qolipMembers, ['Mold operator']);
    final old = TelegramAdminOverview.fromJson({}).alerts;
    expect(old.senderUserId, isNull);
    expect(old.materialMembers, isEmpty);
    expect(old.qolipMembers, isEmpty);
  });

  test('alert sender is a separate invite role for links and QR login',
      () async {
    final sent = <String>[];
    await http.runWithClient(() async {
      final invite = await MobileApi.instance
          .createTelegramInvite(TelegramInviteRole.alertSender);
      expect(invite.role, TelegramInviteRole.alertSender);
      expect(invite.inviteUrl, 'https://t.me/accord_bot?start=notifier-token');
      final login = await MobileApi.instance
          .startTelegramQrLogin(TelegramInviteRole.alertSender);
      expect(login.status, 'waiting');
    },
        () => MockClient((request) async {
              expect(request.method, 'POST');
              expect(request.headers['authorization'], 'Bearer admin-token');
              expect((jsonDecode(request.body) as Map)['role'], 'alert_sender');
              sent.add(request.url.path);
              return http.Response(
                  jsonEncode(request.url.path.endsWith('/invites')
                      ? {
                          'role': 'alert_sender',
                          'invite_url':
                              'https://t.me/accord_bot?start=notifier-token'
                        }
                      : {
                          'login_id': 'notifier-login',
                          'status': 'waiting',
                          'qr_url': 'tg://login?token=abcd',
                          'expires_at_unix':
                              DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60
                        }),
                  200);
            }));
    expect(sent, [
      '/v1/mobile/admin/telegram/invites',
      '/v1/mobile/admin/telegram/qr-logins'
    ]);
    expect(TelegramInviteRole.fromJson('alert_sender'),
        TelegramInviteRole.alertSender);
  });

  testWidgets(
      'admin Telegram screen has an alert sender invite row and working QR action',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.admin,
        ref: 'admin',
        displayName: 'Admin',
        legalName: '',
        phone: '',
        avatarUrl: '');
    addTearDown(() => AppSession.instance.profile = null);
    final roles = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate
        ],
        home: AdminTelegramScreen(),
      ));
      await tester.pumpAndSettle();
      final row = find.byKey(const ValueKey('telegram-alert-sender-invite'));
      await tester.scrollUntilVisible(row, 250);
      expect(find.descendant(of: row, matching: find.text('Alert sender')),
          findsOneWidget);
      expect(
          find.descendant(
              of: row, matching: find.byIcon(Icons.ios_share_rounded)),
          findsOneWidget);
      await tester.tap(find.descendant(
          of: row, matching: find.byIcon(Icons.qr_code_2_rounded)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('telegram-login-qr')), findsOneWidget);
      expect(roles, ['alert_sender']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/qr-logins') &&
                  request.method == 'POST') {
                roles.add((jsonDecode(request.body) as Map)['role'] as String);
                return http.Response(
                    jsonEncode({
                      'login_id': 'notifier-login',
                      'status': 'waiting',
                      'qr_url': 'tg://login?token=abcd',
                      'expires_at_unix':
                          DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60
                    }),
                    200);
              }
              if (request.url.path.contains('/qr-logins/')) {
                return http.Response('{}', 200);
              }
              return http.Response(
                  jsonEncode(
                      {'bot': {}, 'userbot': {}, 'users': [], 'chats': []}),
                  200);
            }));
  });

  test('sender selection and disable use authenticated dedicated endpoint',
      () async {
    final sent = <String?>[];
    await http.runWithClient(() async {
      final saved = await MobileApi.instance.updateTelegramAlertSender('101');
      expect(saved.alerts.senderUserId, '101');
      await MobileApi.instance.updateTelegramAlertSender(null);
    },
        () => MockClient((request) async {
              expect(request.method, 'PUT');
              expect(
                  request.url.path, '/v1/mobile/admin/telegram/alert-settings');
              expect(request.headers['authorization'], 'Bearer admin-token');
              sent.add((jsonDecode(request.body) as Map)['sender_user_id']
                  as String?);
              return http.Response(jsonEncode(payload), 200,
                  headers: {'content-type': 'application/json'});
            }));
    expect(sent, ['101', null]);
  });

  test('test mode prevents a real sender update', () async {
    await TestModeController.instance.setEnabled(true);
    var calls = 0;
    await http.runWithClient(
      () => expectLater(MobileApi.instance.updateTelegramAlertSender('101'),
          throwsA(isA<MobileApiException>())),
      () => MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    expect(calls, 0);
  });

  testWidgets('card selects only linked profiles and exposes bot setup',
      (tester) async {
    final selected = <String?>[];
    TelegramUserAccount user(String id, bool linked) => TelegramUserAccount(
          telegramUserId: id,
          username: '',
          displayName: linked ? 'Linked profile' : 'Unlinked profile',
          role: TelegramInviteRole.admin,
          inviteToken: '',
          joinedAtUnix: 0,
          userProfileConnected: linked,
        );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TelegramAlertSettingsCard(
            settings: const TelegramAlertSettings(
              groupTitle: 'Printing',
              materialMembers: ['Supplier'],
              qolipMembers: ['Mold operator'],
            ),
            users: [user('101', true), user('102', false)],
            onSelectSender: (id) async => selected.add(id),
          ),
        ),
      ),
    ));
    expect(find.textContaining('/alerts'), findsOneWidget);
    expect(find.text('Group: Printing'), findsOneWidget);
    expect(find.text('Material supplier: Supplier'), findsOneWidget);
    expect(find.text('Mold operator: Mold operator'), findsOneWidget);
    await tester.tap(find.text('Alert sender'));
    await tester.pumpAndSettle();
    expect(find.text('Unlinked profile'), findsNothing);
    await tester.tap(find.text('Linked profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alert sender'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disable'));
    await tester.pumpAndSettle();
    expect(selected, ['101', null]);
    expect(tester.takeException(), isNull);
  });
}
