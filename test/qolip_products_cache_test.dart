import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_loading_indicator.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _api = MobileApi.instance;

Future<List<QolipProduct>> _load() =>
    _api.qolipProducts(limit: 20000, withQolipOnly: true);

http.Response _catalog({String name = 'Product', String etag = '"v1"'}) =>
    http.Response(
        jsonEncode({
          'products': [
            {
              'code': 'ITEM',
              'name': name,
              'item_group': 'Tayyor mahsulot',
              'qolip_code': 'Q-1',
              'warehouse': 'Qolip ombori',
              'size': 40,
              'has_qolip_spec': true,
              'is_in_use': false,
              'customer_names': ['Customer'],
            }
          ],
        }),
        200,
        headers: {'etag': etag});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'qolip-cache-test';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'qolip-cache-test',
      phone: '',
      avatarUrl: '',
    );
    AppSession.instance.revision.value++;
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('concurrent full reads share one request; 304 reuses parsed products',
      () async {
    var calls = 0;
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      final first = _load();
      final second = _load();
      await started.future;
      gate.complete(_catalog());
      final results = await Future.wait([first, second]);
      expect(calls, 1);
      expect(identical(results[0], results[1]), isTrue);
      expect(identical(_api.cachedQolipProducts, results[0]), isTrue);
      final unchanged = await _load();
      expect(
          calls, 2); // Every entry still revalidates current permissions/data.
      expect(identical(unchanged, results[0]), isTrue);
    },
        () => MockClient((request) {
              calls++;
              if (calls == 1) {
                expect(request.headers['if-none-match'], isNull);
                started.complete();
                return gate.future;
              }
              expect(request.headers['if-none-match'], '"v1"');
              return Future.value(
                  http.Response('', 304, headers: {'etag': '"v1"'}));
            }));
  });

  test('partial searches cannot overwrite the full catalog snapshot', () async {
    await http.runWithClient(() async {
      final full = await _load();
      final partial =
          await _api.qolipProducts(query: 'missing', withQolipOnly: true);
      expect(partial, isEmpty);
      expect(identical(_api.cachedQolipProducts, full), isTrue);
    },
        () => MockClient((request) async {
              if (request.url.queryParameters.containsKey('q')) {
                expect(request.headers['if-none-match'], isNull);
                return http.Response('{"products":[]}', 200);
              }
              return _catalog();
            }));
  });

  test('mutations invalidate the snapshot and its conditional validator',
      () async {
    var reads = 0;
    await http.runWithClient(() async {
      await _load();
      await _api.qolipDeleteProductSpecs(['Q-1']);
      expect(_api.cachedQolipProducts, isNull);
      expect(await _load(), isEmpty);
    },
        () => MockClient((request) async {
              if (request.method == 'DELETE') {
                return http.Response('{"deleted_count":1}', 200);
              }
              expect(request.headers['if-none-match'], isNull);
              return ++reads == 1
                  ? _catalog()
                  : http.Response('{"products":[]}', 200);
            }));
  });

  test('a read finishing after a mutation cannot publish pre-mutation data',
      () async {
    var reads = 0;
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      final pending = _load();
      await started.future;
      await _api.qolipDeleteProductSpecs(['Q-1']);
      gate.complete(_catalog());
      expect(await pending, isEmpty);
      expect(_api.cachedQolipProducts, isEmpty);
      expect(reads, 2);
    },
        () => MockClient((request) {
              if (request.method == 'DELETE') {
                return Future.value(http.Response('{"deleted_count":1}', 200));
              }
              if (++reads == 1) {
                started.complete();
                return gate.future;
              }
              expect(request.headers['if-none-match'], isNull);
              return Future.value(http.Response('{"products":[]}', 200));
            }));
  });

  test('session changes isolate snapshots and validators', () async {
    await http.runWithClient(() async {
      await _load();
      AppSession.instance.token = 'another-session';
      expect(_api.cachedQolipProducts, isNull);
      await _load();
      AppSession.instance.revision.value++;
      expect(_api.cachedQolipProducts, isNull);
    },
        () => MockClient((request) async {
              expect(request.headers['if-none-match'], isNull);
              return _catalog();
            }));
  });

  test('late response after logout is rejected and cannot refill cache',
      () async {
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    await http.runWithClient(() async {
      final pending = _load();
      final assertion = expectLater(pending, throwsStateError);
      await started.future;
      AppSession.instance.token = null;
      AppSession.instance.profile = null;
      gate.complete(_catalog());
      await assertion;
      expect(_api.cachedQolipProducts, isNull);
    },
        () => MockClient((request) {
              started.complete();
              return gate.future;
            }));
  });

  test('server switch rejects late responses and clears the old validator',
      () async {
    final originalUrl = MobileApi.baseUrl;
    final gate = Completer<http.Response>();
    final started = Completer<void>();
    var calls = 0;
    try {
      await http.runWithClient(() async {
        final pending = _load();
        final assertion = expectLater(pending, throwsStateError);
        await started.future;
        await ServerEndpointStore.instance
            .setBaseUrl('https://qolip-cache.example');
        expect(_api.cachedQolipProducts, isNull);
        gate.complete(_catalog());
        await assertion;
        await _load();
        expect(calls, 2);
      },
          () => MockClient((request) {
                expect(request.headers['if-none-match'], isNull);
                if (++calls == 1) {
                  started.complete();
                  return gate.future;
                }
                expect(request.url.host, 'qolip-cache.example');
                return Future.value(_catalog());
              }));
    } finally {
      await ServerEndpointStore.instance.setBaseUrl(originalUrl);
    }
  });

  for (final status in [403, 500]) {
    test('failed refresh ($status) removes reusable cached data', () async {
      var calls = 0;
      await http.runWithClient(() async {
        await _load();
        await expectLater(_load(), throwsA(isA<MobileApiException>()));
        expect(_api.cachedQolipProducts, isNull);
      },
          () => MockClient((request) async =>
              ++calls == 1 ? _catalog() : http.Response('{}', status)));
    });
  }

  test('old servers without ETag still return fresh data', () async {
    var calls = 0;
    await http.runWithClient(() async {
      final first = await _load();
      final second = await _load();
      expect(identical(first, second), isFalse);
      expect(second.single.name, 'New product');
    },
        () => MockClient((request) async {
              expect(request.headers['if-none-match'], isNull);
              final response =
                  _catalog(name: ++calls == 1 ? 'Product' : 'New product');
              return http.Response(response.body, 200);
            }));
  });

  testWidgets('warm entry shows the list while fresh data is still pending',
      (tester) async {
    var calls = 0;
    final gate = Completer<http.Response>();
    await http.runWithClient(() async {
      await _load();
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: QolipProductsScreen(),
      ));
      await tester.pump();
      expect(calls, 2);
      expect(find.text('Product'), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);
      gate.complete(_catalog(name: 'Updated product', etag: '"v2"'));
      await tester.pumpAndSettle();
      expect(find.text('Product'), findsNothing);
      expect(find.text('Updated product'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient(
            (request) async => ++calls == 1 ? _catalog() : gate.future));
  });
}
