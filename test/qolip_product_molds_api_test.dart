import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSession.instance.setSession(
      token: 'token',
      profile: const SessionProfile(
        role: UserRole.admin,
        ref: 'admin',
        displayName: 'Admin',
        legalName: '',
        phone: '',
        avatarUrl: '',
        capabilities: ['admin.access'],
      ),
    );
  });
  tearDown(() => AppSession.instance.clear());

  test('product molds sends the exact code and keeps every returned mold',
      () async {
    await http.runWithClient(() async {
      final products = await MobileApi.instance.qolipProductMolds(' Zizi ');
      expect(products, hasLength(150));
      expect(products.every((product) => product.code == 'Zizi'), isTrue);
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer token');
              expect(request.url.path, '/v1/mobile/qolip/shared-sets');
              expect(request.url.queryParameters, {'item_code': 'Zizi'});
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'products': List.generate(
                        150,
                        (n) => {
                              'code': 'Zizi',
                              'name': 'Zizi sponge',
                              'item_group': 'Tayyor mahsulot',
                              'qolip_code': 'ZIZI-$n',
                              'warehouse': 'Molds A',
                              'size': 40,
                              'has_qolip_spec': true,
                            }),
                  }),
                  200);
            }));
  });

  for (final failure in [
    (
      404,
      'product_not_found',
      'Mahsulot topilmadi. Mahsulot kodini tekshiring.'
    ),
    (
      500,
      'qolip_store_failed',
      'Qoliplarni yuklashda server xatosi. Qayta urinib ko‘ring.'
    ),
  ]) {
    test('product molds preserves ${failure.$2} and its server message',
        () async {
      await http.runWithClient(() async {
        await expectLater(
          MobileApi.instance.qolipProductMolds('Zizi'),
          throwsA(isA<MobileApiException>()
              .having((e) => e.code, 'code', failure.$2)
              .having((e) => e.statusCode, 'status', failure.$1)
              .having((e) => e.message, 'message', failure.$3)),
        );
      },
          () => MockClient((_) async => http.Response(
                jsonEncode(
                    {'ok': false, 'error': failure.$2, 'message': failure.$3}),
                failure.$1,
                headers: {'content-type': 'application/json; charset=utf-8'},
              )));
    });
  }
}
