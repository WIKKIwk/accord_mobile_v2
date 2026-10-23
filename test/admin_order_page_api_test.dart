import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => AppSession.instance.token = 'page-token');
  tearDown(() => AppSession.instance.token = null);

  Map<String, dynamic> payload(int count) => {
        'version': 'page-1',
        'epoch': 'server',
        'rev': 1,
        'offset': 0,
        'total': count,
        'next_cursor': null,
        'closed_orders': [
          for (var i = 0; i < count; i++) {'order_id': 'zakaz-$i'}
        ],
      };

  test('admin page validates size, duplicates and continuation', () async {
    expect((await AdminProductionOrderPage.fromJson(payload(20))).length, 20);
    for (final invalid in [
      payload(21),
      {...payload(20), 'total': 100},
      {...payload(0), 'next_cursor': 'endless'},
      {
        ...payload(2),
        'closed_orders': [
          {'order_id': 'same'},
          {'order_id': 'same'}
        ]
      },
    ]) {
      await expectLater(AdminProductionOrderPage.fromJson(invalid),
          throwsA(isA<MobileApiException>()));
    }
  });

  test('admin page forwards only its scope and accepts conditional 304',
      () async {
    await http.runWithClient(() async {
      final page = await MobileApi.instance.adminProductionOrderPage(
        const AdminProductionOrderPageRequest(
            view: 'sequence',
            apparatus: 'apparatus:default:bosma_8',
            search: 'old order',
            ifVersion: 'page-1'),
      );
      expect(page, isNull);
    },
        () => MockClient((request) async {
              expect(request.url.path,
                  '/v1/mobile/admin/production-maps/order-page');
              expect(request.url.queryParameters, {
                'view': 'sequence',
                'projection': 'sequence_list_v1',
                'apparatus': 'apparatus:default:bosma_8',
                'search': 'old order',
                'limit': '20',
                'if_version': 'page-1',
              });
              return http.Response('', 304);
            }));
  });

  test('closed detail fetches one order only', () async {
    await http.runWithClient(() async {
      final order =
          await MobileApi.instance.adminClosedProductionOrderDetail('zakaz-42');
      expect(order.orderId, 'zakaz-42');
    },
        () => MockClient((request) async {
              expect(request.url.path,
                  '/v1/mobile/admin/production-maps/closed-order');
              expect(request.url.queryParameters, {'id': 'zakaz-42'});
              return http.Response(
                  jsonEncode({'order_id': 'zakaz-42', 'logs': []}), 200);
            }));
  });

  test('audit page keeps complete counts while decoding twenty findings',
      () async {
    final page = await AdminProductionOrderPage.fromJson({
      'version': 'audit-1',
      'epoch': 'server',
      'rev': 1,
      'offset': 0,
      'total': 45,
      'next_cursor': 'next',
      'workflow_audit': {
        'ok': false,
        'checked_order_count': 1000,
        'total_violations': 45,
        'violations': [
          for (var i = 0; i < 20; i++)
            {
              'code': 'unknown_order',
              'order_id': 'zakaz-$i',
              'subject': 'queue'
            },
        ],
      },
    });
    expect(page.length, 20);
    expect(page.workflowAudit!.checkedOrderCount, 1000);
    expect(page.workflowAudit!.totalViolations, 45);
    expect(page.workflowAudit!.ok, isFalse);
  });
}
