import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
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
        await expectLater(request, throwsA(isA<MobileApiException>()));
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
}
