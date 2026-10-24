import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/session/session_read_scope.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> product(String code, {String mold = 'M1'}) => {
      'code': code,
      'name': code,
      'item_group': 'Tayyor mahsulot',
      'qolip_code': mold,
      'warehouse': 'Molds',
      'qolip_set_id': 'set-1',
      'size': 40,
      'has_qolip_spec': true,
    };
Map<String, dynamic> row(String code, {List<String> molds = const ['M1']}) => {
      'id': qolipCatalogId(code),
      'name': code,
      'order_image_order_id': '',
      'products': [for (final mold in molds) product(code, mold: mold)],
    };
http.Response page(List<String> codes, {String? next}) => http.Response(
    jsonEncode({
      'items': [
        for (final code in codes) {'id': qolipCatalogId(code), 'name': code}
      ],
      'has_more': next != null,
      'next_cursor': next,
    }),
    200);
Map<String, dynamic> delta(
        {List<String> removed = const [],
        List<Map<String, dynamic>> upserts = const []}) =>
    {
      'catalog_delta': {
        'upserts': upserts,
        'removed_ids': removed.map(qolipCatalogId).toList()
      },
    };
void profile(
    {String ref = 'store-test', List<String> warehouses = const ['Molds']}) {
  AppSession.instance.profile = SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: ref,
      phone: '',
      avatarUrl: '',
      assignedWarehouses: warehouses);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = QolipCatalogStore.instance;
  setUp(() async {
    store.reset();
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'store-token';
    profile();
  });
  tearDown(() {
    store.reset();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('preparation and entry share the first 200; following pages stay cached',
      () async {
    final pending = Completer<http.Response>();
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      final warming = store.prepare();
      final opening = store.first();
      await Future<void>.delayed(Duration.zero);
      expect(requests, hasLength(1));
      expect(requests.single.url.queryParameters, {'limit': '200'});
      pending.complete(page(
          List.generate(200, (i) => 'P${i.toString().padLeft(3, '0')}'),
          next: 'next'));
      await warming;
      final window = await opening;
      expect(window.items, hasLength(200));
      window.scrollOffset = 500;
      await Future.wait([store.more(''), store.more('')]);
      expect(window.items, hasLength(201));
      expect(requests, hasLength(2));
      expect(identical(await store.first(), window), isTrue);
      expect(window.scrollOffset, 500);
      expect(requests, hasLength(2));
    },
        () => MockClient((request) async {
              requests.add(request);
              expectSync(request.url.path, '/v1/mobile/qolip/products/page');
              return request.url.queryParameters['cursor'] == null
                  ? pending.future
                  : page(['P200']);
            }));
  });

  test(
      'write replies update additions, remaining molds and last-mold removal without reads',
      () async {
    var reads = 0;
    var writes = 0;
    await http.runWithClient(() async {
      final window = await store.first();
      await MobileApi.instance.qolipAddProductMold(
          const QolipProduct(
              code: 'B',
              name: 'B',
              itemGroup: 'Tayyor mahsulot',
              warehouse: 'Molds'),
          const QolipMoldDraft(code: 'M2', size: 40));
      expect(window.items.map((item) => item.name), ['A', 'B']);
      expect((await store.loadDetails(qolipCatalogId('B'))).length, 2);
      await MobileApi.instance.qolipRemoveProductMolds(
          [QolipProduct.fromJson(product('B', mold: 'M2'))]);
      expect(window.items.map((item) => item.name), ['A', 'B']);
      expect(store.details(qolipCatalogId('B'))!.single.qolipCode, 'M1');
      await MobileApi.instance
          .qolipRemoveProductMolds([QolipProduct.fromJson(product('B'))]);
      expect(window.items.map((item) => item.name), ['A']);
      expect(store.details(qolipCatalogId('B')), isNull);
      expect(reads, 1);
      expect(writes, 3);
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                reads++;
                return page(['A']);
              }
              writes++;
              return http.Response(
                  jsonEncode(switch (writes) {
                    1 => delta(upserts: [
                        row('B', molds: ['M1', 'M2'])
                      ]),
                    2 => delta(upserts: [row('B')]),
                    _ => delta(removed: ['B']),
                  }),
                  200);
            }));
  });

  test('a rejected write leaves the cached catalog untouched', () async {
    await http.runWithClient(() async {
      final window = await store.first();
      await expectLater(
          MobileApi.instance
              .qolipRemoveProductMolds([QolipProduct.fromJson(product('A'))]),
          throwsA(isA<MobileApiException>()));
      expect(window.items.single.name, 'A');
      expect(identical(await store.first(), window), isTrue);
    },
        () => MockClient((request) async => request.method == 'GET'
            ? page(['A'])
            : http.Response('{"error":"qolip_in_use"}', 409)));
  });

  test(
      'a late first page cannot resurrect a removed product or erase an addition',
      () async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      final initial = store.first();
      await Future<void>.delayed(Duration.zero);
      store.applyResponse(delta(removed: ['A'], upserts: [row('B')]),
          currentSessionReadScope());
      pending.complete(page(['A']));
      expect((await initial).items.map((item) => item.name), ['B']);
    }, () => MockClient((_) => pending.future));
  });

  test('a late detail uses the newer write result and never revives a deletion',
      () async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      final initial = store.loadDetails(qolipCatalogId('A'));
      await Future<void>.delayed(Duration.zero);
      store.applyResponse(
          delta(upserts: [
            row('A', molds: ['M2'])
          ]),
          currentSessionReadScope());
      pending.complete(http.Response(
          jsonEncode({
            'products': [product('A')]
          }),
          200));
      expect((await initial).single.qolipCode, 'M2');
      store.applyResponse(delta(removed: ['A']), currentSessionReadScope());
      expect(store.details(qolipCatalogId('A')), isNull);
    }, () => MockClient((_) => pending.future));
  });

  test(
      'account and warehouse changes reject old reads and old mutation responses',
      () async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      final scope = currentSessionReadScope();
      final initial = store.first();
      final failure = expectLater(initial, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      profile(warehouses: ['Other']);
      expect(store.window('').loaded, isFalse);
      store.applyResponse(delta(upserts: [row('Secret')]), scope);
      pending.complete(page(['Secret']));
      await failure;
      expect(store.window('').items, isEmpty);
    }, () => MockClient((_) => pending.future));
  });
}
