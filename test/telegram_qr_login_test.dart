import 'dart:async';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/admin/telegram/models/telegram_models.dart';
import 'package:accord_mobile_v2/src/features/admin/telegram/presentation/telegram_invite_qr_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

TelegramQrLogin waiting(
        {String token = 'real-telegram-token', bool expired = false}) =>
    TelegramQrLogin(
      loginId: 'challenge',
      status: 'waiting',
      qrUrl: 'tg://login?token=$token',
      expiresAtUnix:
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -10 : 30),
    );
const authorized = TelegramQrLogin(loginId: 'challenge', status: 'authorized');

Future<void> openSheet(
  WidgetTester tester, {
  required Future<TelegramQrLogin> Function() start,
  required Future<TelegramQrLogin> Function(String) poll,
  Future<TelegramQrLogin> Function(String, String)? password,
  Future<void> Function(String)? cancel,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  bool connected = false;
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate
    ],
    home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
                body: Column(children: [
              if (connected) const Text('new user in list'),
              TextButton(
                  child: const Text('Open QR'),
                  onPressed: () async {
                    final result = await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        showDragHandle: true,
                        builder: (_) => TelegramInviteQrSheet(
                              role: TelegramInviteRole.salesManager,
                              start: start,
                              poll: poll,
                              submitPassword:
                                  password ?? (_, __) async => authorized,
                              cancel: cancel ?? (_) async {},
                            ));
                    if (result == true && context.mounted) {
                      setState(() => connected = true);
                    }
                  }),
            ]))),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open QR'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  test('model rejects bot invite QR and accepts MTProto login URL', () {
    final json = {
      'login_id': 'challenge',
      'status': 'waiting',
      'expires_at_unix': 123,
      'qr_url': 'https://t.me/bot?start=invite'
    };
    expect(() => TelegramQrLogin.fromJson(json),
        throwsA(isA<TelegramQrException>()));
    json['qr_url'] = 'tg://login?token=abcd_-';
    expect(TelegramQrLogin.fromJson(json).qrUrl, 'tg://login?token=abcd_-');
  });

  testWidgets('scan success closes sheet and returns result for list refresh',
      (tester) async {
    final cancelled = <String>[];
    await openSheet(tester,
        start: () async => waiting(),
        poll: (_) async => authorized,
        cancel: (id) async {
          cancelled.add(id);
        });
    expect(find.byKey(const ValueKey('telegram-login-qr')), findsOneWidget);
    expect(find.text('Sotuv manageri'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(TelegramInviteQrSheet), findsNothing);
    expect(find.text('new user in list'), findsOneWidget);
    expect(cancelled, ['challenge']);
  });

  testWidgets(
      'Telegram 2FA remains in sheet until the correct password succeeds',
      (tester) async {
    const requiredPassword = TelegramQrLogin(
        loginId: 'challenge',
        status: 'password_required',
        passwordHint: 'hint');
    final submitted = <String>[];
    await openSheet(tester,
        start: () async => waiting(),
        poll: (_) async => requiredPassword,
        password: (id, value) async {
          submitted.add(value);
          return submitted.length == 1
              ? const TelegramQrLogin(
                  loginId: 'challenge',
                  status: 'password_required',
                  errorCode: 'invalid_password')
              : authorized;
        });
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    final field = find.byKey(const ValueKey('telegram-2fa-password'));
    expect(tester.widget<TextField>(field).obscureText, isTrue);
    await tester.enterText(field, 'wrong');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    expect(
        find.text('Incorrect Telegram password. Try again.'), findsOneWidget);
    expect(find.text('new user in list'), findsNothing);
    await tester.enterText(field, 'right');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(submitted, ['wrong', 'right']);
    expect(find.text('new user in list'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('expired QR is hidden and replaced with refreshed Telegram token',
      (tester) async {
    await openSheet(tester,
        start: () async => waiting(expired: true),
        poll: (_) async => waiting(token: 'refreshed-token'));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.byKey(const ValueKey('telegram-login-qr')), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets(
      'closing during start cancels a late login without reopening sheet',
      (tester) async {
    final pending = Completer<TelegramQrLogin>();
    final cancelled = <String>[];
    await openSheet(tester,
        start: () => pending.future,
        poll: (_) async => authorized,
        cancel: (id) async {
          cancelled.add(id);
        });
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    pending.complete(waiting());
    await tester.pump();
    expect(cancelled, ['challenge']);
    expect(find.byType(TelegramInviteQrSheet), findsNothing);
    expect(find.text('new user in list'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late poll while closing cannot pop the underlying screen',
      (tester) async {
    final pending = Completer<TelegramQrLogin>();
    await openSheet(tester,
        start: () async => waiting(), poll: (_) => pending.future);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(milliseconds: 50));
    pending.complete(authorized);
    await tester.pumpAndSettle();
    expect(find.text('Open QR'), findsOneWidget);
    expect(find.text('new user in list'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
