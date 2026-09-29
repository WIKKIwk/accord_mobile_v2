import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/widgets/order_alert_button.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app(OrderAlertKind kind) => MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          body: OrderAlertButton(
        orderId: 'order-123',
        apparatusId: 'apparatus:default:bosma_7',
        kind: kind,
      )),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'worker-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      ref: 'worker-1',
      displayName: 'Ali',
      legalName: '',
      phone: '',
      avatarUrl: '',
    );
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  for (final kind in OrderAlertKind.values) {
    testWidgets('order alert $kind sends directly without resource selection',
        (tester) async {
      final calls = <Map<String, dynamic>>[];
      final release = Completer<void>();
      await http.runWithClient(() async {
        await tester.pumpWidget(app(kind));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byWidgetPredicate((widget) => widget is OutlinedButton));
        await tester.pump();
        expect(find.text('Yuborilmoqda…'), findsOneWidget);
        expect(
            tester
                .widget<OutlinedButton>(find
                    .byWidgetPredicate((widget) => widget is OutlinedButton))
                .onPressed,
            isNull);
        release.complete();
        await tester.pumpAndSettle();
        expect(find.text('Xabar yuborildi'), findsOneWidget);
        expect(calls, hasLength(1));
        expect(calls.single.keys.toSet(),
            {'order_id', 'apparatus', 'kind', 'request_id'});
        expect(calls.single['order_id'], 'order-123');
        expect(calls.single['apparatus'], 'apparatus:default:bosma_7');
        expect(calls.single['kind'],
            kind == OrderAlertKind.rawMaterial ? 'raw_material' : 'qolip');
        expect(
            tester
                .widget<OutlinedButton>(find
                    .byWidgetPredicate((widget) => widget is OutlinedButton))
                .onPressed,
            isNull);
      },
          () => MockClient((request) async {
                expect(request.headers['authorization'], 'Bearer worker-token');
                expect(request.url.path,
                    '/v1/mobile/admin/production-maps/order-alert');
                calls.add(
                    (jsonDecode(request.body) as Map).cast<String, dynamic>());
                await release.future;
                return http.Response('{"ok":true,"recipient_count":2}', 200);
              }));
    });
  }

  testWidgets(
      'failed delivery retries with the same ID and never claims success early',
      (tester) async {
    final ids = <String>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(app(OrderAlertKind.qolip));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byWidgetPredicate((widget) => widget is OutlinedButton));
      await tester.pumpAndSettle();
      expect(find.text('Xabar yuborildi'), findsNothing);
      expect(
          find.text('Xabar yuborilmadi. Qayta urinib ko‘ring'), findsOneWidget);
      await tester
          .tap(find.byWidgetPredicate((widget) => widget is OutlinedButton));
      await tester.pumpAndSettle();
      expect(find.text('Xabar yuborildi'), findsOneWidget);
      expect(ids, hasLength(2));
      expect(ids[1], ids[0]);
    },
        () => MockClient((request) async {
              ids.add(jsonDecode(request.body)['request_id'] as String);
              return ids.length == 1
                  ? http.Response('{"error":"order_alert_send_failed"}', 500)
                  : http.Response('{"ok":true,"recipient_count":1}', 200);
            }));
  });

  testWidgets('no recipient is displayed as an error', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(app(OrderAlertKind.rawMaterial));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byWidgetPredicate((widget) => widget is OutlinedButton));
      await tester.pumpAndSettle();
      expect(find.text('Xabar yuboriladigan faol xodim topilmadi'),
          findsOneWidget);
      expect(find.text('Xabar yuborildi'), findsNothing);
    },
        () => MockClient((_) async =>
            http.Response('{"error":"order_alert_no_recipients"}', 400)));
  });

  test('test mode cannot send a real alert', () async {
    await TestModeController.instance.setEnabled(true);
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.sendOrderAlert(
            orderId: 'order-123',
            apparatus: 'apparatus:default:bosma_7',
            kind: OrderAlertKind.qolip,
            requestId: 'request-1',
          ),
          throwsA(isA<MobileApiException>()
              .having((e) => e.code, 'code', 'order_alert_test_mode')));
    }, () => MockClient((_) async => throw StateError('must not send')));
  });
}
