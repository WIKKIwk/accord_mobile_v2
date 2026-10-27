import 'dart:convert';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_home_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _title = 'Qolipni omborga biriktirish';
const _product = QolipProduct(
  code: 'ITEM-1',
  name: 'Ramazan makaron 5 kg',
  itemGroup: 'Tayyor mahsulot',
);

Finder _codeField() => find.byWidgetPredicate((widget) =>
    widget is TextField && widget.decoration?.labelText == 'Qolip code');

Future<void> _open(WidgetTester tester,
    {TargetPlatform platform = TargetPlatform.iOS,
    Size size = const Size(430, 932)}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true, platform: platform),
    locale: const Locale('uz'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () => showQolipProductSpecSheet(context,
                      initialProduct: _product, lockProduct: true),
                  child: const Text('Open'),
                ))),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(find.text(_title), findsOneWidget);
}

Future<void> _withClient(Future<void> Function() body) => http.runWithClient(
    body,
    () => MockClient((request) async {
          expect(request.method, 'GET');
          if (request.url.path == '/v1/mobile/qolip/sets') {
            return http.Response('{"sets":[]}', 200);
          }
          expect(request.url.path, '/v1/mobile/qolip/blocks');
          return http.Response(
              jsonEncode({
                'warehouses': ['Qolip ombori'],
                'blocks': [],
              }),
              200);
        }));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'layout-test-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'layout-test-qolipchi',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('Qolip code and set picker have separate spacing',
      (tester) async {
    await _withClient(() async {
      await _open(tester, size: const Size(375, 640));
      final picker = find.widgetWithText(OutlinedButton, 'Komplekt tanlash');
      expect(picker, findsOneWidget);
      final gap =
          tester.getTopLeft(picker).dy - tester.getBottomLeft(_codeField()).dy;
      expect(gap, greaterThanOrEqualTo(12));
      expect(tester.takeException(), isNull);
    });
  });

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('Qolip sheet dismisses by dragging its handle on $platform',
        (tester) async {
      await _withClient(() async {
        await _open(tester, platform: platform);
        final handle = find.byWidgetPredicate((widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 42 &&
            widget.constraints?.maxHeight == 5);
        expect(handle, findsOneWidget);
        await tester.drag(handle, const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(find.text(_title), findsNothing);
        expect(find.text('Open'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('Qolip form scroll keeps its draggable header visible',
      (tester) async {
    await _withClient(() async {
      await _open(tester, size: const Size(375, 640));
      await tester.enterText(_codeField(), 'DRAFT-1');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      final titleTop = tester.getTopLeft(find.text(_title)).dy;
      final form = find.ancestor(
          of: _codeField(), matching: find.byType(SingleChildScrollView));
      final scroll = tester.state<ScrollableState>(
          find.descendant(of: form, matching: find.byType(Scrollable)).first);
      await tester.drag(form, const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, greaterThan(0));
      expect(tester.getTopLeft(find.text(_title)).dy, closeTo(titleTop, 0.1));
      expect(
          tester.widget<TextField>(_codeField()).controller!.text, 'DRAFT-1');
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Qolip sheet dismisses by tapping outside the sheet',
      (tester) async {
    await _withClient(() async {
      await _open(tester, size: const Size(430, 1400));
      final top = tester.getTopLeft(find.byType(BottomSheet)).dy;
      expect(top, greaterThan(0));
      await tester.tapAt(Offset(215, top / 2));
      await tester.pumpAndSettle();
      expect(find.text(_title), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
