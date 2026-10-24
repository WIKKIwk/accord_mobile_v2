import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_retry_state.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response page(int start, int count, {String? next, String? name}) =>
    http.Response(
        jsonEncode({
          'ok': true,
          'items': [
            for (var n = start; n < start + count; n++)
              {
                'id': 'row-$n',
                'name': name ?? 'Product ${n.toString().padLeft(3, '0')}'
              }
          ],
          'has_more': next != null,
          'next_cursor': next,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'});

http.Response detail() => http.Response(
    jsonEncode({
      'ok': true,
      'products': [
        {
          'code': 'ITEM-0',
          'name': 'Product 000',
          'item_group': 'Tayyor mahsulot',
          'qolip_code': 'MOLD-001',
          'qolip_set_id': 'set-1',
          'warehouse': 'Molds',
          'size': 40,
          'color': 'Panton 1',
          'has_qolip_spec': true
        },
      ]
    }),
    200);

Future<void> pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    locale: Locale('uz'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ],
    home: QolipProductsScreen(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'catalog-token';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        displayName: 'Qolipchi',
        legalName: '',
        ref: 'catalog-test',
        phone: '',
        avatarUrl: '');
    AppSession.instance.revision.value++;
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('catalog requests are bounded, scoped and reject a stuck continuation',
      () async {
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      final first = await MobileApi.instance
          .qolipCatalogPage(query: 'Product', limit: 20000);
      expect(first.items.length, 200);
      expect(first.nextCursor, 'next');
      expect(requests.single.url.queryParameters,
          {'limit': '200', 'q': 'Product'});
      expect(requests.single.headers['Authorization'], 'Bearer catalog-token');
      await expectLater(
          MobileApi.instance.qolipCatalogPage(query: 'Product', cursor: 'next'),
          throwsFormatException);
    },
        () => MockClient((request) async {
              requests.add(request);
              expectSync(request.url.path, '/v1/mobile/qolip/products/page');
              return page(0, 200, next: 'next');
            }));
  });

  testWidgets(
      'only names load initially; tapping loads and reuses one product detail',
      (tester) async {
    var detailReads = 0;
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await pumpScreen(tester);
      expect(find.text('Product 000'), findsOneWidget);
      expect(find.text('MOLD-001'), findsNothing);
      expect(detailReads, 0);
      await tester.tap(find.text('Product 000'));
      await tester.pump();
      expect(detailReads, 1);
      await tester.tap(find.text('Product 000'));
      await tester.tap(find.text('Product 000'));
      await tester.pump();
      expect(detailReads, 1);
      pending.complete(detail());
      await tester.pumpAndSettle();
      expect(find.text('MOLD-001'), findsOneWidget);
      await tester.tap(find.text('Product 000'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Product 000'));
      await tester.pumpAndSettle();
      expect(detailReads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/page')) return page(0, 2);
              expect(request.url.path, '/v1/mobile/qolip/products/detail');
              expect(request.url.queryParameters, {'id': 'row-0'});
              detailReads++;
              return pending.future;
            }));
  });

  testWidgets(
      'scroll appends the next page once and retries without losing the list',
      (tester) async {
    var nextReads = 0;
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      await pumpScreen(tester);
      final list = find.byKey(const ValueKey('qolip-catalog-list'));
      await tester.drag(list, const Offset(0, -16000));
      await tester.pump();
      expect(nextReads, 1);
      await tester.drag(list, const Offset(0, -500));
      await tester.pump();
      expect(nextReads, 1);
      pending.complete(http.Response('{"error":"qolip_store_failed"}', 500));
      await tester.pumpAndSettle();
      expect(find.byType(AppRetryState), findsOneWidget);
      expect(find.text('Product 199'), findsOneWidget);
      final retry = find.descendant(
          of: find.byType(AppRetryState), matching: find.byType(TextButton));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(nextReads, 2);
      await tester.drag(list, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('Product 201'), findsOneWidget);
      expect(nextReads, 2);
      final state = tester.state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first);
      expect(state.position.pixels, greaterThan(10000));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              expectSync(request.url.path, '/v1/mobile/qolip/products/page');
              expect(request.url.queryParameters['limit'], '200');
              if (!request.url.queryParameters.containsKey('cursor')) {
                return page(0, 200, next: 'page-2');
              }
              expect(request.url.queryParameters['cursor'], 'page-2');
              return ++nextReads == 1 ? pending.future : page(200, 2);
            }));
  });

  testWidgets('server search ignores a late response from the previous query',
      (tester) async {
    final old = Completer<http.Response>();
    final queries = <String?>[];
    await http.runWithClient(() async {
      await pumpScreen(tester);
      final input = find.byType(EditableText).first;
      await tester.enterText(input, 'old');
      await tester.pump(const Duration(milliseconds: 300));
      expect(queries, [null, 'old']);
      await tester.enterText(input, 'remote');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Remote product'), findsOneWidget);
      old.complete(page(10, 1, name: 'Obsolete product'));
      await tester.pumpAndSettle();
      expect(find.text('Obsolete product'), findsNothing);
      expect(find.text('Remote product'), findsOneWidget);
      await tester.enterText(input, '');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Product 000'), findsOneWidget,
          reason: queries.toString());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              expectSync(request.url.path, '/v1/mobile/qolip/products/page');
              final query = request.url.queryParameters['q'];
              queries.add(query);
              if (query == 'old') return old.future;
              if (query == 'remote') {
                return page(401, 1, name: 'Remote product');
              }
              return page(0, 1);
            }));
  });

  testWidgets('a detail error retries only that row', (tester) async {
    var details = 0;
    var pages = 0;
    await http.runWithClient(() async {
      await pumpScreen(tester);
      await tester.tap(find.text('Product 000'));
      await tester.pumpAndSettle();
      expect(find.text('Product 001'), findsOneWidget);
      expect(find.byType(AppRetryState), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byType(AppRetryState), matching: find.byType(TextButton)));
      await tester.pumpAndSettle();
      expect(details, 2);
      expect(pages, 1);
      expect(find.text('MOLD-001'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/page')) {
                pages++;
                return page(0, 2);
              }
              return ++details == 1
                  ? http.Response('{"error":"qolip_store_failed"}', 500)
                  : detail();
            }));
  });
}
