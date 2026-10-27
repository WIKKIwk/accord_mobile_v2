import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/rps_qr_reprint_sheet.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _code = 'MOLD-QR';
const _distance = 'Aylangan masofa:';

class _QrFixture {
  bool tracked = true;
  double? meter = 0;
  int mileageReads = 0;
  Future<http.Response> Function()? mileageReply;

  http.Response mileage() => http.Response(
      jsonEncode({
        'ok': true,
        'mileage': {
          'qolip_code': _code,
          'tracking_enabled': tracked,
          'current_meter': meter,
          'cycles': [],
        },
      }),
      200);

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (path == '/v1/mobile/qolip/mileage') {
      expectSync(request.method, 'GET');
      expectSync(request.url.queryParameters, {'qolip_code': _code});
      expectSync(request.headers['Authorization'], 'Bearer mileage-qr-token');
      mileageReads++;
      return mileageReply?.call() ?? mileage();
    }
    if (path == '/v1/mobile/qolip/reworks') {
      return http.Response('{"ok":true,"reworks":[]}', 200);
    }
    if (path == '/v1/mobile/qolip/products/page') {
      return http.Response(
          jsonEncode({
            'items': [
              {'id': qolipCatalogId('ITEM-QR'), 'name': 'QR product'}
            ],
            'has_more': false,
          }),
          200);
    }
    expectSync(path, '/v1/mobile/qolip/products/detail');
    return http.Response(
        jsonEncode({
          'products': [
            {
              'code': 'ITEM-QR',
              'name': 'QR product',
              'item_group': 'Tayyor mahsulot',
              'qolip_code': _code,
              'qolip_set_id': '950100000001',
              'warehouse': 'Qolip ombori',
              'size': 800,
              'color': '#212121',
              'has_qolip_spec': true,
              'customer_names': ['QR customer'],
            }
          ],
        }),
        200);
  }
}

Future<void> _pumpProduct(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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
  await tester.tap(find.text('QR product'));
  await tester.pumpAndSettle();
}

Future<void> _openQr(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.qr_code_2_rounded).first);
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('qolip-code-qr-preview-$_code')),
      findsOneWidget);
}

RpsQrReprintSheet _sheet(WidgetTester tester) =>
    tester.widget<RpsQrReprintSheet>(find.byType(RpsQrReprintSheet));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String? clipboard;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiTestModeData();
    QolipCatalogStore.instance.reset();
    await TestModeController.instance.setEnabled(false);
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = 'mileage-qr-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'mileage-qr-clerk',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
    );
    AppSession.instance.revision.value++;
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
  });
  tearDown(() async {
    QolipCatalogStore.instance.reset();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await ServerEndpointStore.instance.clearOverride();
  });

  for (final meter in [0.0, 1234.5]) {
    testWidgets('tracked mileage $meter is placed below the customer',
        (tester) async {
      final fixture = _QrFixture()..meter = meter;
      await http.runWithClient(() async {
        await _pumpProduct(tester);
        expect(fixture.mileageReads, 0,
            reason: 'Expanding products must not query mileage');
        await _openQr(tester);
        final details = _sheet(tester).details;
        final customer = details.indexWhere((row) => row.label == 'Mijoz');
        expect(customer, greaterThanOrEqualTo(0));
        expect(details[customer + 1].label, _distance);
        expect(details[customer + 1].value, meter == 0 ? '0 m' : '1234.5 m');
        expect(fixture.mileageReads, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }, () => MockClient(fixture.handle));
    });
  }

  testWidgets('untracked molds do not display a misleading zero distance',
      (tester) async {
    final fixture = _QrFixture()
      ..tracked = false
      ..meter = null;
    await http.runWithClient(() async {
      await _pumpProduct(tester);
      await _openQr(tester);
      expect(
          _sheet(tester).details.any((row) => row.label == _distance), isFalse);
      expect(find.text(_distance), findsNothing);
      expect(find.byKey(const ValueKey('qolip-code-qr-reprint-$_code')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient(fixture.handle));
  });

  testWidgets('pending mileage keeps QR usable and reopening reads fresh data',
      (tester) async {
    final response = Completer<http.Response>();
    final fixture = _QrFixture()..mileageReply = () => response.future;
    await http.runWithClient(() async {
      await _pumpProduct(tester);
      await _openQr(tester);
      expect(fixture.mileageReads, 1);
      expect(
          _sheet(tester).details.any((row) => row.label == _distance), isFalse);
      expect(_sheet(tester).onReprint, isNotNull);
      tester.element(find.byType(BottomSheet)).markNeedsBuild();
      await tester.pumpAndSettle();
      expect(fixture.mileageReads, 1,
          reason: 'Sheet rebuilds reuse the same in-flight mileage read');
      fixture.meter = 12.5;
      response.complete(fixture.mileage());
      await tester.pumpAndSettle();
      expect(_sheet(tester).details.last.value, '12.5 m');
      expect(fixture.mileageReads, 1);
      Navigator.of(tester.element(find.byType(RpsQrReprintSheet))).pop();
      await tester.pumpAndSettle();
      fixture
        ..mileageReply = null
        ..meter = 25;
      await _openQr(tester);
      expect(_sheet(tester).details.last.value, '25 m');
      expect(fixture.mileageReads, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient(fixture.handle));
  });

  testWidgets('a mileage failure preserves QR and copy without inventing zero',
      (tester) async {
    final fixture = _QrFixture()
      ..mileageReply =
          () async => http.Response('{"error":"qolip_store_failed"}', 500);
    await http.runWithClient(() async {
      await _pumpProduct(tester);
      await _openQr(tester);
      expect(
          _sheet(tester).details.any((row) => row.label == _distance), isFalse);
      expect(_sheet(tester).onReprint, isNotNull);
      await tester
          .tap(find.byKey(const ValueKey('qolip-code-qr-payload-$_code')));
      await tester.pumpAndSettle();
      expect(clipboard, _code);
      expect(fixture.mileageReads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }, () => MockClient(fixture.handle));
  });
}
