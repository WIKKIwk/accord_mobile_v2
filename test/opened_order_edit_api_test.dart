import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/opened_order_edit_error_dialog.dart';
import 'package:flutter/material.dart';
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
  final json = <String, dynamic>{
    'revision': 4,
    'map': {
      'id': 'zakaz-1234',
      'order_number': '1234',
      'unknown_field': 'preserve'
    },
    'template': {
      'order_number': '1234',
      'source_map_id': 'zakaz-1234',
      'kg': 500,
      'product': 'Mahsulot',
      'frame_product_size_mm': 300,
      'frame_count': 2,
      'layers': [
        {'material': 'pet', 'micron': '12'}
      ],
      'unknown_field': 'also preserve',
    },
  };

  test(
      'opened order edit uses dedicated authenticated endpoint and exact snapshot',
      () async {
    final methods = <String>[];
    await http.runWithClient(() async {
      final source =
          await MobileApi.instance.adminOpenedOrderEditSource('zakaz-1234');
      expect(source.template.kg, 500);
      final saved = await MobileApi.instance.adminSaveOpenedOrderEdit(
        source: source,
        template: source.template.copyWith(kg: 600),
      );
      expect(saved.orderId, 'zakaz-1234');
    },
        () => MockClient((request) async {
              methods.add(request.method);
              expect(request.url.path,
                  '/v1/mobile/admin/production-maps/order-edit');
              expect(request.url.queryParameters['id'], 'zakaz-1234');
              expect(request.headers['authorization'], 'Bearer admin-token');
              if (request.method == 'PUT') {
                final body = jsonDecode(request.body) as Map;
                expect(body['original'], json);
                expect(body['template']['kg'], 600);
              }
              return http.Response(jsonEncode(json), 200,
                  headers: {'content-type': 'application/json'});
            }));
    expect(methods, ['GET', 'PUT']);
  });

  for (final method in ['GET', 'PUT']) {
    test(
        '$method conflict remains blocked without retries or creating an order',
        () async {
      var calls = 0;
      await http.runWithClient(() async {
        final source = OpenedOrderEditSource.fromJson(json);
        final request = method == 'GET'
            ? MobileApi.instance.adminOpenedOrderEditSource(source.orderId)
            : MobileApi.instance.adminSaveOpenedOrderEdit(
                source: source, template: source.template);
        await expectLater(
          request,
          throwsA(isA<MobileApiException>()
              .having((error) => error.statusCode, 'status', 409)
              .having((error) => error.message, 'server reason',
                  'Buyurtmada opening WIP ochilgan')
              .having(openedOrderEditErrorReason, 'dialog reason',
                  'Buyurtmada opening WIP ochilgan')),
        );
      },
          () => MockClient((request) async {
                calls++;
                expect(request.method, method);
                expect(request.url.path,
                    '/v1/mobile/admin/production-maps/order-edit');
                return http.Response(
                    jsonEncode({'error': 'Buyurtmada opening WIP ochilgan'}),
                    409);
              }));
      expect(calls, 1);
    });
  }

  for (final status in [400, 404, 409, 422]) {
    test('edit preserves a business reason for HTTP $status', () async {
      const reason = 'Buyurtmaga xomashyo biriktirilgan. '
          'Xomashyo tarixini tekshiring.';
      await http.runWithClient(
        () => expectLater(
          MobileApi.instance.adminOpenedOrderEditSource('zakaz-1234'),
          throwsA(isA<MobileApiException>()
              .having((error) => error.message, 'reason', reason)
              .having((error) => error.statusCode, 'status', status)),
        ),
        () => MockClient((_) async => http.Response(
            jsonEncode({'error': reason}), status,
            headers: {'content-type': 'application/json; charset=utf-8'})),
      );
    });
  }

  for (final scenario in [
    (403, jsonEncode({'error': 'private authorization details'})),
    (500, jsonEncode({'error': 'private database details'})),
    (
      500,
      jsonEncode({
        'error': 'order_edit_database_failed',
        'message': '<html>private proxy response</html>'
      })
    ),
    (409, jsonEncode({'error': 'private_unknown_error_code'})),
    (409, '<html>private proxy response</html>'),
    (409, jsonEncode({'error': '<html>private proxy response</html>'})),
    (409, '{}'),
  ]) {
    test('edit keeps a safe fallback for $scenario', () async {
      await http.runWithClient(
        () => expectLater(
          MobileApi.instance.adminOpenedOrderEditSource('zakaz-1234'),
          throwsA(isA<MobileApiException>()
              .having((error) => error.message, 'safe message',
                  isNot(contains('private')))
              .having(openedOrderEditErrorReason, 'safe dialog',
                  isNot(contains('private')))),
        ),
        () => MockClient((_) async => http.Response(scenario.$2, scenario.$1)),
      );
    });
  }

  for (final method in ['GET', 'PUT']) {
    test('$method preserves the actual explained database failure', () async {
      const reason = 'Serverning baza hisobi saqlash uchun tarix yozuvlarini '
          'himoyalay olmadi. Administrator baza sozlamalarini tekshirishi kerak.';
      var calls = 0;
      await http.runWithClient(() async {
        final source = OpenedOrderEditSource.fromJson(json);
        await expectLater(
          method == 'GET'
              ? MobileApi.instance.adminOpenedOrderEditSource(source.orderId)
              : MobileApi.instance.adminSaveOpenedOrderEdit(
                  source: source, template: source.template.copyWith(kg: 600)),
          throwsA(isA<MobileApiException>()
              .having((error) => error.statusCode, 'status', 500)
              .having((error) => error.code, 'cause',
                  'order_edit_database_permission')
              .having(openedOrderEditErrorReason, 'displayed reason', reason)),
        );
      },
          () => MockClient((request) async {
                calls++;
                expect(request.method, method);
                return http.Response(
                    jsonEncode({
                      'error': 'order_edit_database_permission',
                      'message': reason,
                    }),
                    500,
                    headers: {
                      'content-type': 'application/json; charset=utf-8'
                    });
              }));
      expect(calls, 1,
          reason: 'An unsuccessful write must not be retried automatically');
    });
  }

  test('edit keeps the existing translation for a known server error',
      () async {
    await http.runWithClient(
      () => expectLater(
        MobileApi.instance.adminOpenedOrderEditSource('zakaz-1234'),
        throwsA(isA<MobileApiException>().having(
          (error) => error.message,
          'translated reason',
          'Aparat yoki buyurtma ma’lumoti topilmadi. Oynani yangilang.',
        )),
      ),
      () => MockClient((_) async => http.Response(
          jsonEncode({'error': 'apparatus and order_id are required'}), 400)),
    );
  });

  testWidgets('actual API business reason reaches the edit dialog',
      (tester) async {
    const reason = 'Buyurtmada ish sessiyasi ochilgan. '
        'Ish tarixini tekshiring.';
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return TextButton(
              onPressed: () async {
                try {
                  await MobileApi.instance
                      .adminOpenedOrderEditSource('zakaz-1234');
                } catch (error) {
                  if (!context.mounted) return;
                  await showOpenedOrderEditErrorDialog(context,
                      error: error, orderNumber: '1234');
                }
              },
              child: const Text('Edit'),
            );
          }),
        ),
      ));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text(reason), findsOneWidget);
      expect(find.textContaining('Server sababini batafsil yubormadi'),
          findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((_) async => http.Response(
            jsonEncode({'error': reason}), 409,
            headers: {'content-type': 'application/json; charset=utf-8'})));
  });
}
