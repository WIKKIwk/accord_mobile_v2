import 'dart:convert';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_stub.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_calculate_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_production_map_orders_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/pending_order_widgets.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_order_image_thumb.dart';
import 'package:accord_mobile_v2/src/core/widgets/lists/m3_segmented_list.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'order_image_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    OrderImageCache.debugOverride =
        OrderImageCache(disk: createOrderImageDiskStore());
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'pending-token';
  });
  tearDown(() async {
    await OrderImageCache.instance.clear();
    OrderImageCache.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });
  final pending = {
    'id': 'zakaz-9011',
    'manager_name': 'Manager',
    'template': {
      'order_number': '9011',
      'customer_ref': 'CUST-1',
      'customer': 'Mijoz',
      'item_code': 'ITEM-1',
      'product': 'Mahsulot',
      'image_id': 'pending-image-9011',
      'status': 'rulon',
      'kg': 500,
      'frame_product_size_mm': 300,
      'frame_count': 2,
      'waste_percent': 5,
      'layers': [
        {'material': 'pet', 'micron': '12'}
      ],
    }
  };
  const snapshot = AdminApparatusQueueSnapshot(
      sequences: {},
      visibleOrderIds: {},
      queueStates: {},
      queuePolicies: {},
      orderControls: {},
      revision: 1,
      epoch: 'pending-test');

  for (final (worker, brightness) in [
    (false, Brightness.light),
    (false, Brightness.dark),
    (true, Brightness.light),
  ]) {
    testWidgets(
        worker
            ? 'worker list never requests or renders incomplete orders'
            : 'admin pending order is purple with a cover and opens completion ($brightness)',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      AppSession.instance.profile = SessionProfile(
          role: worker ? UserRole.aparatchi : UserRole.admin,
          displayName: 'User',
          legalName: '',
          ref: 'USER',
          phone: '',
          avatarUrl: '');
      final image = await tester.runAsync(() => orderImageTestPng(100, 80));
      var pendingReads = 0;
      var imageReads = 0;
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(useMaterial3: true, brightness: brightness),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminProductionMapOrdersScreen(
              workerMode: worker,
              readOnly: worker,
              apparatusLoader: () async => [],
              queueSnapshotLoader: () async => snapshot,
              closedOrdersLoader: () async => [],
              completionRequestsLoader: () async => [],
              liveEventsLoader: () => const Stream.empty()),
        ));
        await tester.pumpAndSettle();
        if (worker) {
          await tester.pump(const Duration(seconds: 11));
          expect(pendingReads, 0);
          expect(find.byType(PendingOrderCard), findsNothing);
        } else {
          expect(pendingReads, 1);
          await tester.tap(find.text('Buyurtmalar').last);
          await tester.pumpAndSettle();
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('pending-order-zakaz-9011')),
              findsOneWidget);
          final card = tester.widget<M3SegmentFilledSurface>(find.descendant(
              of: find.byType(PendingOrderCard),
              matching: find.byType(M3SegmentFilledSurface)));
          expect(
              card.backgroundColor,
              brightness == Brightness.dark
                  ? const Color(0xFF3D2859)
                  : const Color(0xFFEDE0FF));
          final cover = find.descendant(
              of: find.byType(PendingOrderCard),
              matching: find.byType(AdminOrderCoverThumb));
          expect(cover, findsOneWidget);
          final coverRect = tester.getRect(cover);
          final cardRect = tester.getRect(find.byType(PendingOrderCard));
          expect(coverRect.topLeft, cardRect.topLeft);
          expect(coverRect.height, cardRect.height);
          expect(coverRect.width, kAdminOrderCoverWidth);
          final pixels = tester.widget<RawImage>(find.descendant(
              of: cover, matching: find.byType(RawImage)));
          expect(pixels.image?.width, 100,
              reason: 'the list must show the uploaded image, not an icon');
          expect(pixels.fit, BoxFit.cover);
          expect(imageReads, 1);
          await tester
              .tap(find.byKey(const ValueKey('pending-order-zakaz-9011')));
          await tester.pumpAndSettle();
          expect(find.byType(PendingOrderDetailSheet), findsOneWidget);
          expect(find.text('500.0 kg'), findsOneWidget);
          expect(find.text('300.0 mm'), findsOneWidget);
          expect(find.text('2.0 ta'), findsOneWidget);
          expect(imageReads, 2);
          await tester.tap(find.text('Order ochishni tugallash'));
          await tester.pumpAndSettle();
          expect(find.byType(AdminCalculateScreen), findsOneWidget);
          expect(
              tester
                  .widget<TextFormField>(find.widgetWithText(TextFormField, 'KG'))
                  .controller!
                  .text,
              '500');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 11));
      },
          () => MockClient((request) async {
                if (request.url.path.endsWith('/pending-orders')) {
                  pendingReads++;
                  return http.Response(jsonEncode([pending]), 200);
                }
                if (request.url.path.endsWith('/pending-orders/image')) {
                  imageReads++;
                  expect(request.url.queryParameters['id'], 'zakaz-9011');
                  if (imageReads == 1) {
                    expect(request.url.queryParameters['image_id'],
                        'pending-image-9011');
                  }
                  expect(
                      request.headers['authorization'], 'Bearer pending-token');
                  return http.Response.bytes(image!, 200,
                      headers: {'content-type': 'image/png'});
                }
                return http.Response('[]', 200);
              }));
    });
  }
}
