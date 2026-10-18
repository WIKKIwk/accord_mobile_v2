import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'qolip-pdf-test';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'qolip-pdf-test',
      phone: '',
      avatarUrl: '',
    );
    AppSession.instance.revision.value++;
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets(
      'long press reveals share beside the arrow and exports an exact '
      'fresh product lookup despite a mold-code search', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final temp = Directory.systemTemp.createTempSync('qolip-pdf-share-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final shared = Completer<Map<dynamic, dynamic>>();
    const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(pathChannel, (_) async => temp.path);
    messenger.setMockMethodCallHandler(shareChannel, (call) async {
      expect(call.method, 'share');
      shared.complete(call.arguments as Map);
      return '';
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(shareChannel, null);
      messenger.setMockMethodCallHandler(pathChannel, null);
    });

    final exactResponse = Completer<http.Response>();
    var exactReads = 0;
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      expect(find.byTooltip('Qoliplar PDF’ini ulashish'), findsNothing);
      await tester.enterText(find.byType(EditableText).first, 'MOLD-001');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('20 26 Skoch paket'));
      await tester.pumpAndSettle();
      final share =
          find.byKey(const ValueKey('qolip-product-share-product-001'));
      expect(share, findsOneWidget);
      expect(
          tester.getCenter(share).dx,
          lessThan(tester
              .getCenter(find.byIcon(Icons.keyboard_arrow_down_rounded))
              .dx));
      await tester.tap(share);
      await tester.pump();
      expect(exactReads, 1);
      expect(tester.widget<IconButton>(share).onPressed, isNull);
      await tester.tap(share);
      await tester.pump();
      expect(exactReads, 1);
      exactResponse.complete(_productsResponse([
        _mold('MOLD-001'),
        _mold('MOLD-002'),
        _mold('MOLD-003', extension: true),
      ]));
      for (var attempt = 0; attempt < 100 && !shared.isCompleted; attempt++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
      }
      expect(shared.isCompleted, isTrue);
      await tester.pumpAndSettle();
      final params = await shared.future;
      expect(params['title'], '20 26 Skoch paket');
      expect(params['mimeTypes'], ['application/pdf']);
      expect(params['originWidth'], greaterThan(0));
      expect(params['originHeight'], greaterThan(0));
      final file = File((params['paths'] as List).single as String);
      expect(file.path, endsWith('/qoliplar-20-26-Skoch-paket.pdf'));
      expect(file.readAsStringSync(encoding: latin1), startsWith('%PDF-'));
      expect(tester.widget<IconButton>(share).onPressed, isNotNull);
      expect(find.byTooltip('Qoliplar PDF’ini ulashish'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              expect(request.headers['Authorization'], 'Bearer qolip-pdf-test');
              if (request.url.path == '/v1/mobile/qolip/shared-sets') {
                expect(
                    request.url.queryParameters, {'item_code': 'PRODUCT-001'});
                exactReads++;
                return exactResponse.future;
              }
              expect(request.url.path, '/v1/mobile/qolip/products');
              return _productsResponse([_mold('MOLD-001'), _mold('MOLD-002')]);
            }));
  });

  testWidgets('a failed exact lookup keeps selection and allows retry',
      (tester) async {
    var exactReads = 0;
    await http.runWithClient(() async {
      await _pumpScreen(tester);
      await tester.longPress(find.text('20 26 Skoch paket'));
      await tester.pumpAndSettle();
      final share =
          find.byKey(const ValueKey('qolip-product-share-product-001'));
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(exactReads, 1);
      expect(
          find.text('Qoliplar PDF’ini tayyorlab yoki ulashib bo‘lmadi. '
              'Qayta urining.'),
          findsOneWidget);
      expect(tester.widget<IconButton>(share).onPressed, isNotNull);
      await tester.tap(share);
      await tester.pumpAndSettle();
      expect(exactReads, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.url.path == '/v1/mobile/qolip/shared-sets') {
                exactReads++;
                return http.Response('{"error":"qolip_store_failed"}', 500);
              }
              return _productsResponse([_mold('MOLD-001')]);
            }));
  });
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true),
    locale: const Locale('uz'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const QolipProductsScreen(),
  ));
  await tester.pumpAndSettle();
}

Map<String, Object> _mold(String code, {bool extension = false}) => {
      'code': 'PRODUCT-001',
      'name': '20 26 Skoch paket',
      'item_group': 'Tayyor mahsulot',
      'qolip_code': code,
      'qolip_set_id': 'set-001',
      'warehouse': 'Qolip ombori',
      'size': 750,
      'has_qolip_spec': true,
      'is_extension': extension,
    };

http.Response _productsResponse(List<Map<String, Object>> molds) =>
    http.Response(
      jsonEncode({'ok': true, 'products': molds}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
