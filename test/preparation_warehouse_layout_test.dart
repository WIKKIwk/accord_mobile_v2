import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.tayyorlovMasteri,
      displayName: 'Master',
      legalName: '',
      ref: 'prep-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['preparation.access'],
    );
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('warehouse assignment sends and parses the preparation role', () async {
    await http.runWithClient(() async {
      final result = await MobileApi.instance.adminAssignWarehouse(
        warehouse: ' Tayyorlov ombori ',
        principalRole: UserRole.tayyorlovMasteri,
        principalRef: ' prep-1 ',
        displayName: 'Master',
      );
      expect(result.principalRole, UserRole.tayyorlovMasteri);
      expect(result.principalRef, 'prep-1');
      expect(result.warehouse, 'Tayyorlov ombori');
    },
        () => MockClient((request) async {
              expect(request.method, 'POST');
              expect(
                  request.url.path, '/v1/mobile/admin/warehouses/assignments');
              expect(request.headers['Authorization'], 'Bearer token');
              expect(jsonDecode(request.body), {
                'warehouse': 'Tayyorlov ombori',
                'principal_role': 'tayyorlov_masteri',
                'principal_ref': 'prep-1',
                'display_name': 'Master',
              });
              return http.Response(request.body, 200);
            }));
  });

  for (final rejection in [
    (
      status: 400,
      body: '{"error":"warehouse_assignee_not_allowed"}',
      code: 'warehouse_assignee_not_allowed',
      message: 'Bu rolga ombor biriktirishga server ruxsat bermadi',
    ),
    (
      status: 502,
      body: '<html>Bad gateway</html>',
      code: 'warehouse_assignment_failed',
      message: 'Ombor biriktirilmadi (HTTP 502)',
    ),
  ]) {
    test('warehouse assignment preserves error ${rejection.status}', () async {
      await http.runWithClient(() async {
        await expectLater(
          MobileApi.instance.adminAssignWarehouse(
            warehouse: 'Tayyorlov ombori',
            principalRole: UserRole.tayyorlovMasteri,
            principalRef: 'prep-1',
            displayName: 'Master',
          ),
          throwsA(isA<MobileApiException>()
              .having((e) => e.code, 'code', rejection.code)
              .having((e) => e.message, 'message', rejection.message)
              .having((e) => e.statusCode, 'status', rejection.status)),
        );
      },
          () => MockClient((_) async => http.Response(
                rejection.body,
                rejection.status,
              )));
    });
  }

  for (final width in [320.0, 375.0]) {
    for (final textScale in [1.0, 1.4]) {
      testWidgets('preparation fits phone $width at text scale $textScale',
          (tester) async {
        tester.view.physicalSize = Size(width, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var warehouses = <String>[];
        await http.runWithClient(() async {
          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('uz'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: const PreparationScreen(),
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.textContaining('Sizga ombor biriktirilmagan.'),
              findsOneWidget);
          expect(find.text('Ombor tanlang'), findsNothing);
          final label =
              tester.renderObject<RenderParagraph>(find.text('Homashyo'));
          final boxes = label.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: 8),
          );
          expect(boxes, isNotEmpty);
          expect(boxes.map((box) => box.top).toSet(), hasLength(1));
          expect(label.didExceedMaxLines, isFalse);

          await tester.tap(find.text('Buyurtmalar'));
          await tester.pumpAndSettle();
          expect(find.text('Order tanlang'), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          final history = find.text('Tarix');
          await tester.ensureVisible(history);
          await tester.pumpAndSettle();
          await tester.tap(history);
          await tester.pumpAndSettle();
          expect(find.text('Hali kirim yoki sarf yo‘q.'), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          warehouses = ['Tayyorlov ombori'];
          await tester.tap(find.byTooltip('Yangilash'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Tayyorlov ombori'), findsOneWidget);
          expect(find.textContaining('Sizga ombor biriktirilmagan.'),
              findsNothing);
          await tester.ensureVisible(find.text('Tayyorlov ombori'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Tayyorlov ombori'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Qidirish'), findsOneWidget);
          expect(find.text('Bu omborda hali kirim yo‘q.'), findsOneWidget);
          await tester.tap(
            find.byKey(const ValueKey('app-primary-navigation-button')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Kirim'), findsOneWidget);
          expect(find.text('Homashyo'), findsNothing);
          expect(find.text('Buyurtmalar'), findsNothing);
          expect(find.text('Tarix'), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
            () => MockClient((request) async {
                  expect(request.url.path, '/v1/mobile/preparation/snapshot');
                  return http.Response(
                      jsonEncode({
                        'warehouses': warehouses,
                        'materials': [],
                        'orders': [],
                        'history': [],
                      }),
                      200,
                      headers: {
                        'content-type': 'application/json; charset=utf-8'
                      });
                }));
      });
    }
  }
}
