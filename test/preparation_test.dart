import 'dart:convert';
import 'dart:async';
import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/preparation/models/preparation_models.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _profile = SessionProfile(
    role: UserRole.tayyorlovMasteri,
    displayName: 'Master',
    legalName: '',
    ref: 'prep-1',
    phone: '',
    avatarUrl: '',
    capabilities: ['preparation.access']);
const _payload = {
  'item_code': 'P1',
  'warehouse': 'Tayyorlov ombori',
  'kg': '60.000000'
};
final _snapshot = {
  'warehouses': ['Tayyorlov ombori'],
  'materials': [
    {
      'item_code': 'P1',
      'name': 'Kley',
      'balances': [
        {'warehouse': 'Tayyorlov ombori', 'kg': '60.000000'}
      ]
    }
  ],
  'orders': [
    {
      'id': 'O1',
      'code': '001',
      'title': 'Etiketka',
      'order_kg': '1000.000000',
      'saved': false
    }
  ],
  'history': <Object>[],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = _profile;
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('preparation role serialization, workspace route and permission gate',
      () {
    expect(userRoleFromJson('tayyorlov_masteri'), UserRole.tayyorlovMasteri);
    expect(userRoleToJson(UserRole.tayyorlovMasteri), 'tayyorlov_masteri');
    expect(SessionProfile.fromJson(_profile.toJson()).accessRole,
        UserRole.tayyorlovMasteri);
    expect(AppSession.instance.homeRoute, AppRoutes.preparation);
    expect(AppRouter.canOpenRoute(AppRoutes.preparation), isTrue);
    AppSession.instance.profile = _profile.copyWith(capabilities: []);
    expect(AppRouter.canOpenRoute(AppRoutes.preparation), isFalse);
    final user = AdminUserListEntry.fromJson({
      'id': 'prep-1',
      'source': 'system_user',
      'principal_role': 'tayyorlov_masteri',
      'name': 'Master',
      'phone': ''
    });
    expect(user.kind, AdminUserKind.tayyorlovMasteri);
    expect(user.roleLabel, 'Tayyorlov masteri');
  });

  test('exact KG calculation shares ERP precision and rounding', () {
    expect(preparationRequiredKg('1250.5', '2,5'), '31.262500');
    expect(preparationRequiredKg('0.000001', '50'), '0.000001');
    expect(preparationRequiredKg('999999999999.999999', '100'),
        '999999999999.999999');
    for (final value in ['NaN', '-1', '0', '1e3', '1.0000001', '101']) {
      expect(() => preparationRequiredKg('100', value), throwsFormatException);
    }
    expect(() => preparationRequiredKg('0.000001', '0.000001'),
        throwsFormatException);
  });

  test('receipt retry survives lost response and keeps request id', () async {
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      expect(request.url.path, '/v1/mobile/preparation/receipts');
      expect(request.headers['Authorization'], 'Bearer token');
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (bodies.length == 1) throw http.ClientException('lost response');
      return http.Response(
          jsonEncode({'id': 'receipt-1', 'kind': 'receipt'}), 200);
    });
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.preparationSubmit('receipts', _payload),
          throwsA(isA<http.ClientException>()));
      final pending = await MobileApi.instance.preparationPendingCommand();
      expect(pending, isNotNull);
      await expectLater(
          MobileApi.instance
              .preparationSubmit('receipts', {..._payload, 'kg': '70'}),
          throwsA(isA<MobileApiException>()));
      await MobileApi.instance
          .preparationSubmit(pending!.kind, pending.payload);
      expect(bodies[0], bodies[1]);
      expect(await MobileApi.instance.preparationPendingCommand(), isNull);
    }, () => client);
  });

  test('insufficient stock response is displayed and is not left pending',
      () async {
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.preparationSubmit('receipts', _payload),
          throwsA(isA<MobileApiException>()
              .having((e) => e.message, 'message', 'Qoldiq yetarli emas')));
      expect(await MobileApi.instance.preparationPendingCommand(), isNull);
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({
              'code': 'preparation_insufficient_stock',
              'error': 'Qoldiq yetarli emas'
            }),
            409,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });

  test('pending commands are isolated by account', () async {
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.preparationSubmit('receipts', _payload),
          throwsA(isA<http.ClientException>()));
      AppSession.instance.profile = _profile.copyWith(ref: 'prep-2');
      expect(await MobileApi.instance.preparationPendingCommand(), isNull);
      AppSession.instance.profile = _profile;
      expect(await MobileApi.instance.preparationPendingCommand(), isNotNull);
    }, () => MockClient((_) async => throw http.ClientException('offline')));
  });

  testWidgets('master can receive by material tap and enter recipe percentages',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: PreparationScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Ombor'), findsOneWidget);
      expect(find.text('Kirim'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('app-primary-navigation-button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kirim'), findsWidgets);
      expect(find.text('Buyurtmalar'), findsWidgets);
      expect(find.text('Tarix'), findsWidgets);
      await tester.tap(find.text('Kirim').last);
      await tester.pumpAndSettle();
      expect(find.text('Kley'), findsOneWidget);
      expect(find.text('Mavjud: 60 kg'), findsOneWidget);
      await tester.tap(find.text('Kley'));
      await tester.pumpAndSettle();
      expect(find.text('Kley — kirim'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '12.5');
      await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
      await tester.pumpAndSettle();
      expect(requests.single['kg'], '12.500000');
      await tester.tap(find.text('Buyurtmalar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Order tanlang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('001 — Etiketka'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Homashyo tanlash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kley'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('preparation-percent-P1')), '3');
      await tester.pump();
      expect(find.text('Sarf: 30 kg'), findsOneWidget);
      final save = find.byKey(const Key('preparation-save-recipe'));
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await tester.enterText(
          find.byKey(const Key('preparation-percent-P1')), '7');
      await tester.pump();
      expect(find.text('Omborda yetarli homashyo yo‘q'), findsOneWidget);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      await tester.enterText(
          find.byKey(const Key('preparation-percent-P1')), '3');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester
          .tap(find.widgetWithText(FilledButton, 'Saqlash va sarflash').last);
      await tester.pumpAndSettle();
      expect(requests.last['order_id'], 'O1');
      expect(requests.last['expected_order_kg'], '1000.000000');
      expect((requests.last['lines'] as List).single,
          {'item_code': 'P1', 'percent': '3.000000'});
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                requests.add(jsonDecode(request.body) as Map<String, dynamic>);
                return http.Response('{"id":"r1","kind":"receipt"}', 200);
              }
              return http.Response(jsonEncode(_snapshot), 200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });

  testWidgets('materials list refreshes automatically after kirim',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var balance = 60.0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
          locale: Locale('uz'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: PreparationScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Homashyo'));
      await tester.pumpAndSettle();
      expect(find.text('60 kg'), findsOneWidget);
      await tester.tap(find.text('Kley'));
      await tester.pumpAndSettle();
      expect(find.text('Kley — kirim'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '10');
      await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
      await tester.pumpAndSettle();
      expect(find.text('70 kg'), findsOneWidget);
      expect(find.text('60 kg'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                balance += double.parse(body['kg'] as String);
                return http.Response('{"id":"r1","kind":"receipt"}', 200);
              }
              return http.Response(
                  jsonEncode({
                    'warehouses': ['Tayyorlov ombori'],
                    'materials': [
                      {
                        'item_code': 'P1',
                        'name': 'Kley',
                        'balances': [
                          {
                            'warehouse': 'Tayyorlov ombori',
                            'kg': balance.toStringAsFixed(6)
                          }
                        ]
                      }
                    ],
                    'orders': [],
                    'history': [],
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'});
            }));
  });

  test('parallel client saves are blocked and auth errors preserve retry state',
      () async {
    final started = Completer<void>(), finish = Completer<void>();
    var count = 0;
    await http.runWithClient(() async {
      final first = MobileApi.instance.preparationSubmit('receipts', _payload);
      final failed = expectLater(first, throwsA(isA<MobileApiException>()));
      await started.future;
      await expectLater(
          MobileApi.instance.preparationSubmit('receipts', _payload),
          throwsStateError);
      finish.complete();
      await failed;
      expect(count, 1);
      expect(await MobileApi.instance.preparationPendingCommand(), isNotNull);
    },
        () => MockClient((_) async {
              count++;
              started.complete();
              await finish.future;
              return http.Response('{"error":"forbidden"}', 403);
            }));
  });
}
