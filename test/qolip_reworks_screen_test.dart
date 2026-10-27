import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_loading_indicator.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_reworks_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const product = QolipProduct(
    code: 'DEMO-HOTLUNCH',
    name: 'Hotlunch',
    itemGroup: 'Demo tayyor mahsulotlar',
    warehouse: 'Qolip ombori');

Future<void> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('uz'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ],
    onGenerateRoute: AppRouter.onGenerateRoute,
    home: page,
  ));
  await tester.pumpAndSettle();
}

Future<void> openFab(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('app-primary-navigation-button')));
  await tester.pumpAndSettle();
}

void expectFabActions(WidgetTester tester, List<String> titles) {
  const prefix = 'admin-hub-custom-';
  final actions = find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> && key.value.startsWith(prefix);
  });
  expect(
      tester.widgetList(actions).map((widget) =>
          (widget.key! as ValueKey<String>).value.substring(prefix.length)),
      orderedEquals(titles));
  for (var index = 1; index < titles.length; index++) {
    expect(tester.getTopLeft(find.text(titles[index - 1])).dy,
        lessThan(tester.getTopLeft(find.text(titles[index])).dy));
  }
}

Future<void> closeFab(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('admin-hub-toggle-button')));
  await tester.pumpAndSettle();
}

Future<void> sendFromFab(WidgetTester tester, String label) async {
  await openFab(tester);
  expectFabActions(tester, ['Qolip qo‘shish', label]);
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Berish'));
  await tester.pumpAndSettle();
}

Map<String, dynamic> retryEntry(String code, {bool returned = false}) => {
      'id': 'retry-$code',
      'qolip_code': code,
      'qolip_set_id': '950100000001',
      'warehouse': product.warehouse,
      'item_code': product.code,
      'item_name': product.name,
      'color': 'Panton 1',
      'size': 40,
      'sent_at': '2026-10-24T10:00:00Z',
      'returned_at': returned ? '2026-10-24T11:00:00Z' : null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    QolipCatalogStore.instance.reset();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'rework-widget-token';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        displayName: 'Qolipchi',
        legalName: '',
        ref: 'rework-clerk',
        phone: '',
        avatarUrl: '',
        capabilities: ['qolip.manage']);
    await MobileApi.instance.qolipSaveProductSpecsBatch(
        product: product,
        warehouse: product.warehouse,
        specs: const [
          QolipProductSpecBatchItem(qolipCode: 'RW-A1', size: 40),
          QolipProductSpecBatchItem(qolipCode: 'RW-A2', size: 40),
        ]);
  });
  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    resetMobileApiTestModeData();
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('canceling selection restores the normal FAB and add action',
      (tester) async {
    const normalActions = ['Komplektlar', 'Qolip qo‘shish', 'Qarz daftari'];
    await pumpPage(tester, const QolipProductsScreen());
    await openFab(tester);
    expectFabActions(tester, normalActions);
    await closeFab(tester);

    await tester.longPress(find.text('Hotlunch'));
    await tester.pumpAndSettle();
    await openFab(tester);
    expectFabActions(
        tester, ['Qolip qo‘shish', 'Komplektni peredelkaga berish']);
    await closeFab(tester);
    await tester.tap(find.byTooltip('Tanlashni bekor qilish'));
    await tester.pumpAndSettle();
    await openFab(tester);
    expectFabActions(tester, normalActions);
    await tester.tap(find.text('Qolip qo‘shish'));
    await tester.pumpAndSettle();
    expect(find.text('Qolipni omborga biriktirish'), findsOneWidget);
    Navigator.of(tester.element(find.text('Qolipni omborga biriktirish')))
        .pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'mold long press exposes individual send and marks only that code away',
      (tester) async {
    await pumpPage(tester, const QolipProductsScreen());
    await tester.tap(find.text('Hotlunch'));
    await tester.pumpAndSettle();
    final row = find.widgetWithText(QolipCodeRow, 'RW-A1');
    await tester.longPressAt(tester.getTopLeft(row) + const Offset(16, 16));
    await tester.pumpAndSettle();
    await sendFromFab(tester, 'Qolipni peredelkaga berish');
    expect((await MobileApi.instance.qolipReworks()).single.qolipCode, 'RW-A1');
    expect(find.text('Peredelkada'), findsOneWidget);
    expect(find.text('Peredelkada: 1'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'product long press sends every alternative and extension with shared codes once',
      (tester) async {
    await MobileApi.instance.qolipSaveProductSpecsBatch(
        product: product,
        warehouse: product.warehouse,
        specs: const [
          QolipProductSpecBatchItem(qolipCode: 'RW-B1', size: 40),
          QolipProductSpecBatchItem(qolipCode: 'RW-B2', size: 40),
        ]);
    const second = QolipProduct(
        code: 'DEMO-SALAD',
        name: 'Salat set',
        itemGroup: 'Demo tayyor mahsulotlar',
        warehouse: 'Qolip ombori');
    final firstSet = await MobileApi.instance.qolipResolveSet('RW-A1');
    await MobileApi.instance.qolipReuseSet(set: firstSet!, product: second);
    await MobileApi.instance.qolipAddProductMold(product,
        const QolipMoldDraft(code: 'RW-EXTRA', size: 40, color: 'Panton 9'));
    await pumpPage(tester, const QolipProductsScreen());
    await tester.longPress(find.text('Hotlunch'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Salat set'));
    await tester.pumpAndSettle();
    await sendFromFab(tester, 'Komplektni peredelkaga berish');
    final away = await MobileApi.instance.qolipReworks();
    expect(away.map((row) => row.qolipCode).toSet(),
        {'RW-A1', 'RW-A2', 'RW-B1', 'RW-B2', 'RW-EXTRA'});
    expect(away, hasLength(5));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'rework page returns selected subset and exposes its mileage history',
      (tester) async {
    await MobileApi.instance.qolipSendToRework(
        requestId: 'whole-set', qolipCodes: ['RW-A1', 'RW-A2']);
    await pumpPage(tester, const QolipReworksScreen());
    expect(find.text('Hotlunch'), findsOneWidget);
    expect(find.text('RW-A1'), findsOneWidget);
    expect(find.text('RW-A2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qolip-rework-select-RW-A1')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('qolip-rework-return-selected')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Qaytdi'));
    await tester.pumpAndSettle();
    expect((await MobileApi.instance.qolipReworks()).single.qolipCode, 'RW-A2');
    expect(find.text('RW-A1'), findsNothing);
    expect((await MobileApi.instance.qolipMileage('RW-A1')).currentMeter, 0);
    expect((await MobileApi.instance.qolipMileage('RW-A2')).trackingEnabled,
        isFalse);
    await tester.tap(find.text('Qaytganlar'));
    await tester.pumpAndSettle();
    expect(find.text('RW-A1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('qolip-mileage-RW-A1')));
    await tester.pumpAndSettle();
    expect(find.text('Joriy probeg: 0 m'), findsOneWidget);
    expect(find.text('0 m'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'return patches only its rows without reloading or losing search and scroll',
      (tester) async {
    await TestModeController.instance.setEnabled(false);
    final rows = [
      for (var index = 0; index < 12; index++)
        for (final suffix in ['A', 'B'])
          {
            ...retryEntry('KEEP-$index-$suffix'),
            'qolip_set_id': 'set-$index',
            'item_name': 'Keep group $index',
          },
    ];
    final submitted = Completer<http.Response>();
    var listReads = 0;
    await http.runWithClient(() async {
      await pumpPage(tester, const QolipReworksScreen());
      expect(listReads, 1);
      await tester.enterText(find.byType(EditableText).first, 'Keep');
      await tester.pumpAndSettle();
      final list = find.byKey(const PageStorageKey('qolip-reworks-list'));
      final scrollable =
          find.descendant(of: list, matching: find.byType(Scrollable));
      final target = find.byKey(const ValueKey('qolip-rework-select-KEEP-3-A'));
      final unaffected =
          find.byKey(const ValueKey('qolip-rework-retry-KEEP-3-B'));
      await tester.scrollUntilVisible(target, 250, scrollable: scrollable);
      await Scrollable.ensureVisible(tester.element(target), alignment: 0.35);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
      final controller = tester.widget<ListView>(list).controller!;
      final offset = controller.offset;
      expect(offset, greaterThan(0));
      final unaffectedElement = tester.element(unaffected);
      await tester
          .tap(find.byKey(const ValueKey('qolip-rework-return-selected')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Qaytdi'));
      await tester.pump();
      expect(find.byType(AppLoadingIndicator), findsNothing);
      final updated = {
        ...rows.singleWhere((row) => row['qolip_code'] == 'KEEP-3-A'),
        'returned_at': '2026-10-24T11:00:00Z',
      };
      rows[rows.indexWhere((row) => row['qolip_code'] == 'KEEP-3-A')] = updated;
      submitted.complete(http.Response(
          jsonEncode({
            'ok': true,
            'reworks': [updated],
          }),
          200));
      await tester.pump();
      expect(find.byType(AppLoadingIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(listReads, 1,
          reason: 'The successful return response already contains the update');
      expect(tester.widget<ListView>(list).controller, same(controller));
      expect(controller.offset, closeTo(offset, 0.1));
      expect(tester.element(unaffected), same(unaffectedElement));
      expect(find.byKey(const ValueKey('qolip-rework-retry-KEEP-3-A')),
          findsNothing);
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText).first)
              .controller
              .text,
          'Keep');
      await tester.tap(find.text('Qaytganlar'));
      await tester.pumpAndSettle();
      expect(find.text('KEEP-3-A'), findsOneWidget);
      expect(listReads, 1);
      final refresh =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      final reload = refresh.onRefresh();
      await tester.pumpAndSettle();
      await reload;
      expect(listReads, 2,
          reason: 'Explicit refresh still fetches server state');
      expect(find.text('KEEP-3-A'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                expectSync(request.url.path, '/v1/mobile/qolip/reworks');
                listReads++;
                return http.Response(
                    jsonEncode({'ok': true, 'reworks': rows}), 200);
              }
              expectSync(request.url.path, '/v1/mobile/qolip/reworks/return');
              expectSync((jsonDecode(request.body) as Map)['rework_ids'],
                  ['retry-KEEP-3-A']);
              return submitted.future;
            }));
  });

  testWidgets('a pending refresh cannot undo a successful return',
      (tester) async {
    await TestModeController.instance.setEnabled(false);
    final rows = [retryEntry('RW-A1'), retryEntry('RW-A2')];
    final returnResponse = Completer<http.Response>();
    final refreshResponse = Completer<http.Response>();
    var listReads = 0;
    await http.runWithClient(() async {
      await pumpPage(tester, const QolipReworksScreen());
      await tester.tap(find.byKey(const ValueKey('qolip-rework-select-RW-A1')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('qolip-rework-return-selected')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Qaytdi'));
      await tester.pump();

      final refresh =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      final refreshing = refresh.onRefresh();
      await tester.pump();
      expect(listReads, 2);
      returnResponse.complete(http.Response(
          jsonEncode({
            'ok': true,
            'reworks': [retryEntry('RW-A1', returned: true)],
          }),
          200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('1 ta qolip qaytdi'), findsOneWidget);

      // This response was captured while both molds were still away.
      refreshResponse.complete(
          http.Response(jsonEncode({'ok': true, 'reworks': rows}), 200));
      await tester.pumpAndSettle();
      await refreshing;
      expect(find.text('RW-A1'), findsNothing);
      expect(find.text('RW-A2'), findsOneWidget);
      await tester.tap(find.text('Qaytganlar'));
      await tester.pumpAndSettle();
      expect(find.text('RW-A1'), findsOneWidget);
      expect(find.text('RW-A2'), findsNothing);
      expect(listReads, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
        () => MockClient((request) async {
              if (request.method == 'GET') {
                expectSync(request.url.path, '/v1/mobile/qolip/reworks');
                listReads++;
                if (listReads == 2) return refreshResponse.future;
                return http.Response(
                    jsonEncode({'ok': true, 'reworks': rows}), 200);
              }
              expectSync(request.url.path, '/v1/mobile/qolip/reworks/return');
              return returnResponse.future;
            }));
  });

  for (final returning in [false, true]) {
    testWidgets(
        '${returning ? 'return' : 'send'} retry keeps the request ID after a lost response',
        (tester) async {
      await TestModeController.instance.setEnabled(false);
      final submissions = <Map<String, dynamic>>[];
      var committed = false;
      final codes = returning ? ['RW-A1'] : ['RW-A1', 'RW-A2'];
      await http.runWithClient(() async {
        await pumpPage(
            tester,
            returning
                ? const QolipReworksScreen()
                : const QolipProductsScreen());
        if (returning) {
          await tester
              .tap(find.byKey(const ValueKey('qolip-rework-select-RW-A1')));
          await tester.pumpAndSettle();
        } else {
          await tester.longPress(find.text('Hotlunch'));
          await tester.pumpAndSettle();
        }
        for (var attempt = 0; attempt < 2; attempt++) {
          if (returning) {
            await tester.tap(
                find.byKey(const ValueKey('qolip-rework-return-selected')));
            await tester.pumpAndSettle();
            await tester.tap(find.widgetWithText(FilledButton, 'Qaytdi'));
            await tester.pumpAndSettle();
          } else {
            await sendFromFab(tester, 'Komplektni peredelkaga berish');
          }
          expect(submissions, hasLength(attempt + 1));
          if (attempt == 0) {
            expect(find.text('Peredelka amali bajarilmadi'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
          }
        }
        final requestId = submissions.first['request_id'] as String;
        expect(requestId, matches(RegExp(r'^qolip-rework-\d+-[0-9a-f]{32}$')));
        expect(requestId.length, lessThanOrEqualTo(128));
        expect(submissions.last, submissions.first);
        expect(submissions.first[returning ? 'rework_ids' : 'qolip_codes'],
            returning ? ['retry-RW-A1'] : ['rw-a1', 'rw-a2']);
        expect(
            find.text(returning
                ? '1 ta qolip qaytdi'
                : '2 ta qolip peredelkaga berildi'),
            findsOneWidget);
        if (returning) {
          expect(find.text('RW-A1'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
          () => MockClient((request) async {
                if (request.method == 'POST') {
                  expect(request.url.path,
                      '/v1/mobile/qolip/reworks/${returning ? 'return' : 'send'}');
                  submissions.add((jsonDecode(request.body) as Map)
                      .cast<String, dynamic>());
                  committed = true;
                  if (submissions.length == 1) {
                    // The server committed, but the client did not receive its
                    // response. A retry must replay the same operation ID.
                    throw http.ClientException('Response lost', request.url);
                  }
                  return http.Response(
                      jsonEncode({
                        'ok': true,
                        'reworks': [
                          for (final code in codes)
                            retryEntry(code, returned: returning)
                        ],
                      }),
                      200);
                }
                if (request.url.path == '/v1/mobile/qolip/reworks') {
                  return http.Response(
                      jsonEncode({
                        'ok': true,
                        'reworks': [
                          if (returning || committed)
                            for (final code in codes)
                              retryEntry(code, returned: returning && committed)
                        ],
                      }),
                      200);
                }
                if (request.url.path == '/v1/mobile/qolip/products/page') {
                  return http.Response(
                      jsonEncode({
                        'ok': true,
                        'items': [
                          {'id': 'retry-hotlunch', 'name': product.name}
                        ],
                        'has_more': false,
                      }),
                      200);
                }
                expect(request.url.path, '/v1/mobile/qolip/products/detail');
                return http.Response(
                    jsonEncode({
                      'ok': true,
                      'products': [
                        for (final code in codes)
                          {
                            'code': product.code,
                            'name': product.name,
                            'item_group': product.itemGroup,
                            'qolip_code': code,
                            'qolip_set_id': '950100000001',
                            'warehouse': product.warehouse,
                            'size': 40,
                            'color': 'Panton 1',
                            'has_qolip_spec': true,
                          }
                      ],
                    }),
                    200);
              }));
    });
  }

  for (final returning in [false, true]) {
    testWidgets(
        'changing account during ${returning ? 'return' : 'send'} confirmation cancels the mutation',
        (tester) async {
      if (returning) {
        await MobileApi.instance.qolipSendToRework(
            requestId: 'before-switch', qolipCodes: ['RW-A1']);
        await pumpPage(tester, const QolipReworksScreen());
        await tester
            .tap(find.byKey(const ValueKey('qolip-rework-select-RW-A1')));
        await tester.pumpAndSettle();
        await tester
            .tap(find.byKey(const ValueKey('qolip-rework-return-selected')));
      } else {
        await pumpPage(tester, const QolipProductsScreen());
        await tester.longPress(find.text('Hotlunch'));
        await tester.pumpAndSettle();
        await openFab(tester);
        await tester.tap(find.text('Komplektni peredelkaga berish'));
      }
      await tester.pumpAndSettle();
      AppSession.instance.profile = const SessionProfile(
          role: UserRole.qolipchi,
          displayName: 'Other',
          legalName: '',
          ref: 'other-clerk',
          phone: '',
          avatarUrl: '',
          capabilities: ['qolip.manage']);
      AppSession.instance.revision.value++;
      await tester.tap(
          find.widgetWithText(FilledButton, returning ? 'Qaytdi' : 'Berish'));
      await tester.pumpAndSettle();
      expect(
          find.text('Sessiya o‘zgardi. Sahifani yangilang.'), findsOneWidget);
      final rows = await MobileApi.instance.qolipReworks();
      expect(rows, hasLength(returning ? 1 : 0));
      expect((await MobileApi.instance.qolipMileage('RW-A1')).trackingEnabled,
          isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('qolip drawer opens the new page through its guarded route',
      (tester) async {
    await pumpPage(tester, const QolipProductsScreen());
    await tester.tap(find.byIcon(Icons.menu_rounded).first);
    await tester.pumpAndSettle();
    final destination = find.text('Peredelkadagi qoliplar');
    await tester.drag(
        find.descendant(
            of: find.byType(NavigationDrawer), matching: find.byType(ListView)),
        const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(destination);
    await tester.pumpAndSettle();
    expect(find.byType(QolipReworksScreen), findsOneWidget);
    expect(find.text('Peredelkada qolip yo‘q'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
