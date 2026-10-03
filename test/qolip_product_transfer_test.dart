import 'dart:async';
import 'dart:convert';
import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/navigation/role_dock.dart';
import 'package:accord_mobile_v2/src/core/widgets/navigation/role_navigation_drawer.dart';
import 'package:accord_mobile_v2/src/core/widgets/navigation/native_back_button.dart';
import 'package:accord_mobile_v2/src/core/widgets/transfer/transfer_list.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_product_transfer_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const source = QolipProduct(
    code: 'DEMO-HOTLUNCH',
    name: 'Hotlunch',
    itemGroup: 'Demo tayyor mahsulotlar');
const target = QolipProduct(
    code: 'DEMO-SALAD',
    name: 'Salat set',
    itemGroup: 'Demo tayyor mahsulotlar');

SessionProfile profile(UserRole role) => SessionProfile(
      role: role,
      displayName: 'Qolipchi',
      legalName: '',
      ref: 'transfer-user',
      phone: '',
      avatarUrl: '',
      capabilities: const ['qolip.manage', 'admin.access'],
    );

Widget transferApp() => MaterialApp(
      theme: ThemeData(useMaterial3: true),
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const QolipProductTransferScreen(),
    );

Future<void> dragMoldTo(
    WidgetTester tester, Finder row, Finder destination) async {
  final handle = find.descendant(
      of: row, matching: find.byIcon(Icons.drag_handle_rounded));
  await tester.ensureVisible(handle);
  final dropPoint = tester.getCenter(destination);
  final gesture = await tester.startGesture(tester.getCenter(handle));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveTo(dropPoint);
  await tester.pump(const Duration(milliseconds: 100));
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    resetMobileApiQolipTestModeData();
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'transfer-token';
    AppSession.instance.profile = profile(UserRole.qolipchi);
  });
  tearDown(() async {
    resetMobileApiQolipTestModeData();
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await TestModeController.instance.setEnabled(false);
  });

  test('only qolipchi can open the product transfer route', () {
    expect(AppRouter.canOpenRoute(AppRoutes.qolipProductTransfer), isTrue);
    for (final role in [
      UserRole.admin,
      UserRole.aparatchi,
      UserRole.materialTaminotchi
    ]) {
      AppSession.instance.profile = profile(role);
      expect(AppRouter.canOpenRoute(AppRoutes.qolipProductTransfer), isFalse);
    }
    AppSession.instance.token = null;
    expect(AppRouter.canOpenRoute(AppRoutes.qolipProductTransfer), isFalse);
  });

  testWidgets(
      'qolipchi selects EPCs and moves to another product without changing stock',
      (tester) async {
    for (final code in ['TRANSFER-1', 'TRANSFER-2', 'TRANSFER-LOCKED']) {
      final saved = await MobileApi.instance.qolipSaveProductSpec(
        warehouse: 'Qolip ombori',
        product: source,
        qolipCode: code,
        size: 42,
        qolipColor: 'Qizil',
      );
      final location = await MobileApi.instance.qolipSaveLocation(
        block: const QolipBlock(name: 'A', warehouse: 'Qolip ombori'),
        product: saved,
        quantity: 1,
        rowLetter: 'B',
        columnNumber: 3,
      );
      if (code == 'TRANSFER-LOCKED') {
        await MobileApi.instance.qolipIssueCheckout(
            locationId: location.id, quantity: 1, workerId: 'worker');
      }
    }
    await tester.pumpWidget(transferApp());
    await tester.pumpAndSettle();
    final backButton = find.byType(NativeBackButtonSlot);
    expect(backButton, findsOneWidget);
    final appBar = find.byType(AppBar).first;
    final title = find.descendant(
        of: appBar, matching: find.text('Mahsulotga ko‘chirish'));
    expect(tester.getTopLeft(title).dx,
        greaterThanOrEqualTo(tester.getRect(backButton).right - 1));
    final dock = tester.widget<RoleDock>(find.byType(RoleDock));
    expect(
        dock.destinations
            .any((d) => d.routeName == AppRoutes.qolipProductTransfer),
        isFalse);
    await tester
        .tap(find.byKey(const ValueKey('qolip-product-transfer-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotlunch').last);
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) => widget is TransferDropZone),
        findsOneWidget);
    expect(find.byType(TransferListRow), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('qolip-transfer-transfer-1')));
    await tester.tap(find.byKey(const ValueKey('qolip-transfer-transfer-2')));
    final lockedRow =
        find.byKey(const ValueKey('qolip-transfer-transfer-locked'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TransferListRow>(find.descendant(
                of: lockedRow, matching: find.byType(TransferListRow)))
            .disabled,
        isTrue);
    expect(
        tester
            .widget<TransferDropZone>(
                find.byWidgetPredicate((widget) => widget is TransferDropZone))
            .selectedItemIds,
        {'transfer-1', 'transfer-2'});
    expect(find.byKey(const ValueKey('qolip-product-transfer-move')),
        findsNothing);
    await tester
        .tap(find.byKey(const ValueKey('qolip-product-transfer-target')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Salat set');
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await tester.tap(find.text('Salat set').last);
    await tester.pumpAndSettle();
    final zones =
        find.byWidgetPredicate((widget) => widget is TransferDropZone);
    await dragMoldTo(tester,
        find.byKey(const ValueKey('qolip-transfer-transfer-1')), zones.last);
    expect(find.textContaining('Hotlunch (DEMO-HOTLUNCH)'), findsOneWidget);
    expect(find.textContaining('Salat set (DEMO-SALAD)'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Ko‘chirish'));
    await tester.pumpAndSettle();
    for (final code in ['transfer-1', 'transfer-2']) {
      final movedRow = find.byKey(ValueKey('qolip-transfer-$code'));
      expect(
          find.descendant(of: zones.first, matching: movedRow), findsNothing);
      expect(find.descendant(of: zones.last, matching: movedRow).hitTestable(),
          findsOneWidget);
      expect(tester.getSize(movedRow).height, greaterThanOrEqualTo(48));
    }
    final molds = await MobileApi.instance
        .qolipProducts(limit: 20000, withQolipOnly: true);
    for (final code in ['TRANSFER-1', 'TRANSFER-2']) {
      final mold = molds.singleWhere((m) => m.qolipCode == code);
      expect(mold.code, target.code);
      expect(mold.name, target.name);
      expect(mold.qolipSize, 42);
      expect(mold.qolipColor, 'Qizil');
      final location = (await MobileApi.instance.qolipLocations('A'))
          .singleWhere((l) => l.qolipCode == code);
      expect(location.itemCode, target.code);
      expect(location.quantity, 1);
      expect(location.locationLabel, 'B3');
    }
    expect(molds.singleWhere((m) => m.qolipCode == 'TRANSFER-LOCKED').code,
        source.code);
    await tester.dragFrom(const Offset(1, 150), const Offset(200, 0));
    await tester.pumpAndSettle();
    final drawer =
        tester.widget<RoleNavigationDrawer>(find.byType(RoleNavigationDrawer));
    expect(
        drawer.destinations
            .singleWhere((d) => d.routeName == AppRoutes.qolipProductTransfer)
            .label,
        'Mahsulotga ko‘chirish');
  });

  testWidgets('reuses admin transfer rows and drags molds in both directions',
      (tester) async {
    for (final entry in [(source, 'TOP-MOLD'), (target, 'BOTTOM-MOLD')]) {
      await MobileApi.instance.qolipSaveProductSpec(
        warehouse: 'Qolip ombori',
        product: entry.$1,
        qolipCode: entry.$2,
        size: 42,
        qolipColor: 'Qizil',
      );
    }
    await tester.pumpWidget(transferApp());
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('qolip-product-transfer-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hotlunch').last);
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('qolip-product-transfer-target')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Salat set');
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    await tester.tap(find.text('Salat set').last);
    await tester.pumpAndSettle();
    final zones =
        find.byWidgetPredicate((widget) => widget is TransferDropZone);
    expect(zones, findsNWidgets(2));
    expect(find.byType(TransferListRow), findsNWidgets(2));
    expect(
        find.byWidgetPredicate((widget) =>
            widget is TransferItemTitle && widget.title == 'Salat set'),
        findsOneWidget);
    final row = find.byKey(const ValueKey('qolip-transfer-bottom-mold'));
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('qolip-product-transfer-move')),
        findsNothing);

    for (final (destination, expectedCode) in [
      (zones.first, source.code),
      (zones.last, target.code)
    ]) {
      await dragMoldTo(tester, row, destination);
      expect(find.textContaining('Salat set (DEMO-SALAD)'), findsOneWidget);
      expect(find.textContaining('Hotlunch (DEMO-HOTLUNCH)'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Ko‘chirish'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: destination, matching: row).hitTestable(),
          findsOneWidget);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      final molds = await MobileApi.instance
          .qolipProducts(limit: 20000, withQolipOnly: true);
      expect(molds.singleWhere((mold) => mold.qolipCode == 'BOTTOM-MOLD').code,
          expectedCode);
      expect(molds.singleWhere((mold) => mold.qolipCode == 'TOP-MOLD').code,
          source.code);
    }
  });

  testWidgets(
      'shows confirmed molds immediately in a scrolled destination and preserves failed moves',
      (tester) async {
    await TestModeController.instance.setEnabled(false);
    final products = [
      {
        'code': source.code,
        'name': source.name,
        'item_group': source.itemGroup,
        'qolip_code': 'MOVED-ONE',
        'size': 42,
        'color': 'Qizil',
        'has_qolip_spec': true,
      },
      for (var i = 0; i < 12; i++)
        {
          'code': target.code,
          'name': target.name,
          'item_group': target.itemGroup,
          'qolip_code': 'EXISTING-$i',
          'size': 42,
          'has_qolip_spec': true,
        },
    ];
    var productReads = 0;
    var transferWrites = 0;
    var failTransfer = true;
    final response = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(transferApp());
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('qolip-product-transfer-source')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(source.name).last);
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('qolip-product-transfer-target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(target.name).last);
      await tester.pumpAndSettle();
      final zones =
          find.byWidgetPredicate((widget) => widget is TransferDropZone);
      final row = find.byKey(const ValueKey('qolip-transfer-moved-one'));
      final destinationList =
          find.byKey(const ValueKey('qolip-product-transfer-target-list'));
      await tester.drag(destinationList, const Offset(0, -300));
      await tester.pumpAndSettle();
      final scroll = tester.widget<ListView>(destinationList).controller!;
      expect(scroll.offset, greaterThan(0));
      final readsBeforeMove = productReads;

      await dragMoldTo(tester, row, zones.last);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Bekor qilish'));
      await tester.pumpAndSettle();
      expect(transferWrites, 0);
      expect(find.descendant(of: zones.first, matching: row).hitTestable(),
          findsOneWidget);
      expect(find.descendant(of: zones.last, matching: row), findsNothing);

      await dragMoldTo(tester, row, zones.last);
      await tester.tap(find.widgetWithText(FilledButton, 'Ko‘chirish'));
      await tester.pumpAndSettle();
      expect(transferWrites, 1);
      expect(find.descendant(of: zones.first, matching: row).hitTestable(),
          findsOneWidget);
      expect(find.descendant(of: zones.last, matching: row), findsNothing);

      failTransfer = false;
      await dragMoldTo(tester, row, zones.last);
      await tester.tap(find.widgetWithText(FilledButton, 'Ko‘chirish'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(transferWrites, 2);
      expect(find.descendant(of: zones.first, matching: row), findsOneWidget);
      expect(find.descendant(of: zones.last, matching: row), findsNothing);
      response.complete(http.Response(
          jsonEncode({
            'ok': true,
            'specs': [
              {
                'item_code': target.code,
                'item_name': target.name,
                'item_group': target.itemGroup,
                'qolip_code': 'MOVED-ONE',
                'size': 42,
                'color': 'Qizil',
              },
            ],
          }),
          200));
      await tester.pumpAndSettle();
      expect(productReads, readsBeforeMove);
      expect(scroll.offset, 0);
      expect(find.descendant(of: zones.first, matching: row), findsNothing);
      expect(find.descendant(of: zones.last, matching: row).hitTestable(),
          findsOneWidget);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              if (request.url.path == '/v1/mobile/qolip/products') {
                ++productReads;
                return http.Response(jsonEncode({'products': products}), 200);
              }
              expect(request.url.path, '/v1/mobile/qolip/product-transfer');
              ++transferWrites;
              if (failTransfer) {
                return http.Response(
                    '{"code":"qolip_product_transfer_conflict","message":"conflict"}',
                    409);
              }
              return response.future;
            }));
  });

  test(
      'API sends stable QR identities and rejects an incomplete transfer response',
      () async {
    await TestModeController.instance.setEnabled(false);
    await http.runWithClient(() async {
      await expectLater(
          MobileApi.instance.qolipTransferProducts(
            requestId: 'same-request',
            fromItemCode: 'SOURCE',
            toItemCode: 'TARGET',
            qolipCodes: ['QR-1', 'QR-2'],
          ),
          throwsA(isA<MobileApiException>()));
    },
        () => MockClient((request) async {
              expect(request.url.path, '/v1/mobile/qolip/product-transfer');
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(body['request_id'], 'same-request');
              expect(body['from_item_code'], 'SOURCE');
              expect(body['to_item_code'], 'TARGET');
              expect(body['qolip_codes'], ['qr-1', 'qr-2']);
              return http.Response(
                  '{"ok":true,"specs":[{"item_code":"TARGET","item_name":"Product","qolip_code":"QR-1","size":42}]}',
                  200);
            }));
  });
}
