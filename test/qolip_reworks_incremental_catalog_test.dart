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

const _targetCode = 'ITEM-08';
const _targetName = 'Product 08';
final _targetId = qolipCatalogId(_targetCode);

class _CatalogFixture {
  final reads = <String, int>{};
  final writes = <http.Request>[];
  Completer<http.Response>? sendReply;
  Completer<http.Response>? reworkRefreshReply;

  Map<String, dynamic> entry({bool returned = false}) => {
        'id': 'visit-1',
        'qolip_code': 'TARGET-1',
        'qolip_set_id': '950100000001',
        'warehouse': 'Qolip ombori',
        'item_code': _targetCode,
        'item_name': _targetName,
        'color': 'Panton 1',
        'size': 40,
        'sent_at': '2026-10-24T10:00:00Z',
        'returned_at': returned ? '2026-10-24T11:00:00Z' : null,
      };

  http.Response mutation({bool returned = false}) => http.Response(
      jsonEncode({
        'ok': true,
        'reworks': [entry(returned: returned)]
      }),
      200);

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'POST') {
      writes.add(request);
      if (path.endsWith('/send')) {
        final pending = sendReply;
        if (pending != null) return pending.future;
        return mutation();
      }
      expect(path, '/v1/mobile/qolip/reworks/return');
      return mutation(returned: true);
    }
    reads.update(path, (count) => count + 1, ifAbsent: () => 1);
    if (path == '/v1/mobile/qolip/reworks') {
      final pending = reworkRefreshReply;
      if (pending != null && reads[path]! > 1) return pending.future;
      return http.Response('{"ok":true,"reworks":[]}', 200);
    }
    if (path == '/v1/mobile/qolip/products/page') {
      return http.Response(
          jsonEncode({
            'items': [
              for (var i = 0; i < 24; i++)
                {
                  'id': qolipCatalogId('ITEM-${i.toString().padLeft(2, '0')}'),
                  'name': 'Product ${i.toString().padLeft(2, '0')}',
                },
            ],
            'has_more': false,
          }),
          200);
    }
    expect(path, '/v1/mobile/qolip/products/detail');
    expect(request.url.queryParameters['id'], _targetId);
    return http.Response(
        jsonEncode({
          'products': [
            for (final mold in ['TARGET-1', 'TARGET-2'])
              {
                'code': _targetCode,
                'name': _targetName,
                'item_group': 'Tayyor mahsulot',
                'qolip_code': mold,
                'qolip_set_id': '950100000001',
                'warehouse': 'Qolip ombori',
                'size': 40,
                'color': 'Panton 1',
                'has_qolip_spec': true,
              },
          ],
        }),
        200);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = QolipCatalogStore.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    store.reset();
    await TestModeController.instance.setEnabled(false);
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = 'incremental-rework-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'incremental-rework-clerk',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
    );
    AppSession.instance.revision.value++;
  });
  tearDown(() async {
    store.reset();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    resetMobileApiTestModeData();
    await ServerEndpointStore.instance.clearOverride();
  });

  test('send and return preserve cached name pages, details and scroll',
      () async {
    final fixture = _CatalogFixture();
    await http.runWithClient(() async {
      final window = await store.first();
      final details = await store.loadDetails(_targetId);
      window.scrollOffset = 480;
      final readsBefore = Map<String, int>.of(fixture.reads);
      var catalogNotifications = 0;
      void changed() => catalogNotifications++;
      store.addListener(changed);
      addTearDown(() => store.removeListener(changed));

      final sent = await MobileApi.instance.qolipSendToRework(
          requestId: newQolipReworkRequestId(), qolipCodes: ['TARGET-1']);
      await MobileApi.instance.qolipReturnFromRework(
          requestId: newQolipReworkRequestId(), reworkIds: [sent.single.id]);

      expect(catalogNotifications, 0);
      expect(identical(store.window(''), window), isTrue);
      expect(window.loaded, isTrue);
      expect(window.items, hasLength(24));
      expect(window.scrollOffset, 480);
      expect(identical(store.details(_targetId), details), isTrue);
      expect(identical(await store.first(), window), isTrue);
      expect(identical(await store.loadDetails(_targetId), details), isTrue);
      expect(fixture.reads, readsBefore);
      expect(fixture.writes, hasLength(2));
    }, () => MockClient(fixture.handle));
  });

  testWidgets('sending updates the opened mold without reloading or scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _CatalogFixture()..sendReply = Completer<http.Response>();

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: QolipProductsScreen(),
      ));
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('qolip-catalog-list'));
      await tester.scrollUntilVisible(find.text(_targetName), 250,
          scrollable:
              find.descendant(of: list, matching: find.byType(Scrollable)));
      await tester.tap(find.text(_targetName));
      await tester.pumpAndSettle();
      final mold = find.widgetWithText(QolipCodeRow, 'TARGET-1');
      await tester.ensureVisible(mold);
      await tester.pumpAndSettle();
      await tester.longPressAt(tester.getTopLeft(mold) + const Offset(16, 16));
      await tester.pumpAndSettle();
      final listElement = tester.element(list);
      final controller = tester.widget<ListView>(list).controller!;
      final offset = controller.offset;
      expect(offset, greaterThan(0));
      final readsBefore = Map<String, int>.of(fixture.reads);
      final cachedDetails = store.details(_targetId);

      await tester
          .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qolipni peredelkaga berish'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Berish'));
      await tester.pump();
      expect(fixture.writes, hasLength(1));
      fixture.sendReply!.complete(fixture.mutation());
      await tester.pump();
      await tester.pump();
      expect(find.byType(AppLoadingIndicator), findsNothing);
      await tester.pumpAndSettle();

      expect(fixture.reads, readsBefore);
      expect(tester.element(list), same(listElement));
      expect(tester.widget<ListView>(list).controller, same(controller));
      expect(controller.offset, closeTo(offset, 0.1));
      expect(identical(store.details(_targetId), cachedDetails), isTrue);
      expect(find.widgetWithText(QolipCodeRow, 'TARGET-1'), findsOneWidget);
      expect(find.widgetWithText(QolipCodeRow, 'TARGET-2'), findsOneWidget);
      expect(find.text('Peredelkada'), findsOneWidget);
      expect(find.text('Peredelkada: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient(fixture.handle));
  });

  testWidgets('a pre-send manual refresh cannot clear the new away status',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = _CatalogFixture()
      ..sendReply = Completer<http.Response>()
      ..reworkRefreshReply = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: QolipProductsScreen(),
      ));
      await tester.pumpAndSettle();
      final list = find.byKey(const ValueKey('qolip-catalog-list'));
      Future<void> openTarget() async {
        await tester.scrollUntilVisible(find.text(_targetName), 250,
            scrollable:
                find.descendant(of: list, matching: find.byType(Scrollable)));
        await tester.tap(find.text(_targetName));
        await tester.pumpAndSettle();
      }

      await openTarget();
      final mold = find.widgetWithText(QolipCodeRow, 'TARGET-1');
      await tester.ensureVisible(mold);
      await tester.pumpAndSettle();
      await tester.longPressAt(tester.getTopLeft(mold) + const Offset(16, 16));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Qolipni peredelkaga berish'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Berish'));
      await tester.pump();
      expect(fixture.writes, hasLength(1));

      // Only this explicit user refresh issues another read. Its response was
      // produced before the server completed the pending send.
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pump();
      expect(fixture.reads['/v1/mobile/qolip/reworks'], 2);
      fixture.sendReply!.complete(fixture.mutation());
      await tester.pump();
      await tester.pump();
      expect(find.text('1 ta qolip peredelkaga berildi'), findsOneWidget);

      fixture.reworkRefreshReply!
          .complete(http.Response('{"ok":true,"reworks":[]}', 200));
      await refresh;
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await openTarget();
      expect(find.text('Peredelkada'), findsOneWidget);
      expect(find.text('Peredelkada: 1'), findsOneWidget);
      await tester.ensureVisible(mold);
      await tester.pumpAndSettle();
      await tester.longPressAt(tester.getTopLeft(mold) + const Offset(16, 16));
      await tester.pumpAndSettle();
      expect(find.text('1 ta tanlandi'), findsNothing);
      expect(fixture.reads['/v1/mobile/qolip/products/page'], 2);
      expect(fixture.reads['/v1/mobile/qolip/reworks'], 2);
      expect(fixture.writes, hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient(fixture.handle));
  });
}
