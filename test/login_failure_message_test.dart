import 'dart:async';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final language in ['uz', 'en', 'ru']) {
    final l10n = AppLocalizations(Locale(language));
    test('$language: transport errors never assert that internet is absent',
        () {
      for (final error in [
        http.ClientException('Failed to fetch'),
        http.ClientException('net::ERR_QUIC_PROTOCOL_ERROR'),
        TimeoutException('request deadline exceeded'),
      ]) {
        expect(loginFailureMessage(error, l10n), l10n.loginConnectionFailed);
        expect(loginFailureMessage(error, l10n),
            isNot(l10n.connectInternetPrompt));
      }
    });
    test('$language: rejected credentials are not a connectivity failure', () {
      expect(loginFailureMessage(Exception('Login failed: 401'), l10n),
          l10n.loginFailed);
    });
  }

  testWidgets(
      'failed connection leaves login editable and retryable without an offline dialog',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var requests = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: LoginScreen(),
      ));
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(TextField).at(0), '000000000000');
      await tester.enterText(find.byType(TextField).at(1), '000000');
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Login'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Could not connect to the server. Try again.'),
          findsOneWidget);
      expect(find.text('Internet kerak'), findsNothing);
      expect(
          tester
              .widget<TextField>(find.byType(TextField).at(0))
              .controller!
              .text,
          '000000000000');
      await tester.tap(find.text('Login'));
      await tester.pump(const Duration(seconds: 1));
      expect(requests, 2);
      expect(find.text('Login failed'), findsOneWidget);
      expect(find.text('Internet kerak'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              requests++;
              if (requests == 1) throw http.ClientException('Failed to fetch');
              return http.Response('{"error":"unauthorized"}', 401);
            }));
  });
}
