import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/models/production_map_models.dart';
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

  final template = {
    'order_number': '9011',
    'kg': 500,
    'customer': 'Mijoz',
    'product': 'Mahsulot',
    'status': 'rulon',
    'frame_product_size_mm': 300,
    'frame_count': 2,
    'layers': [
      {'material': 'pet', 'micron': '12'}
    ]
  };

  test(
      'pending list and image are authenticated; completion sends same identity',
      () async {
    final calls = <http.Request>[];
    await http.runWithClient(() async {
      final orders = await MobileApi.instance.pendingOrders();
      expect(orders, hasLength(1));
      expect(orders.single.template.kg, 500);
      expect(orders.single.matches('9011'), isTrue);
      expect(orders.single.matches('mijoz'), isTrue);
      expect(orders.single.completed, isFalse);
      expect(await MobileApi.instance.pendingOrderImage(orders.single.id),
          [1, 2, 3]);
      final result = await MobileApi.instance.adminSaveProductionMapWithOrder(
          map: const ProductionMapDefinition(
              id: 'draft-id',
              productCode: 'ITEM',
              title: 'Mahsulot',
              nodes: [],
              edges: []),
          template: orders.single.template,
          pendingOrderId: orders.single.id);
      expect(result.saved.map.id, 'zakaz-9011');
      expect(result.saved.map.orderNumber, '9011');
    },
        () => MockClient((request) async {
              calls.add(request);
              expect(request.headers['authorization'], 'Bearer admin-token');
              if (request.url.path.endsWith('/pending-orders')) {
                return http.Response(
                    jsonEncode([
                      {
                        'id': 'zakaz-9011',
                        'template': template,
                        'manager_name': 'Manager'
                      }
                    ]),
                    200);
              }
              if (request.url.path.endsWith('/pending-orders/image')) {
                expect(request.url.queryParameters['id'], 'zakaz-9011');
                return http.Response.bytes([1, 2, 3], 200,
                    headers: {'content-type': 'image/webp'});
              }
              expect(request.method, 'PUT');
              expect(request.url.path,
                  '/v1/mobile/admin/production-maps/with-order');
              final input = jsonDecode(request.body) as Map<String, dynamic>;
              expect(input['pending_order_id'], 'zakaz-9011');
              expect(input['template']['kg'], 500);
              expect(input['template']['order_number'], '9011');
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'saved': {
                      'map': {
                        ...input['map'] as Map<String, dynamic>,
                        'id': 'zakaz-9011',
                        'order_number': '9011'
                      },
                      'program': {}
                    },
                    'template': template
                  }),
                  200);
            }));
    expect(calls, hasLength(3));
  });

  test('pending list rejects forbidden responses without a fallback', () async {
    var count = 0;
    await http.runWithClient(() async {
      await expectLater(MobileApi.instance.pendingOrders(),
          throwsA(isA<MobileApiException>()));
    },
        () => MockClient((request) async {
              count++;
              return http.Response('{"error":"forbidden"}', 403);
            }));
    expect(count, 1);
  });
}
