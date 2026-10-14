import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_stub.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/feedback/rps_qr_reprint_sheet.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_order_image_thumb.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/widgets/worker_wip_details.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/widgets/worker_wip_details_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_image_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List thumbnail;
  late Uint8List fullImage;
  setUpAll(() async {
    thumbnail = await orderImageTestPng(128, 64);
    fullImage = await orderImageTestPng(800, 400);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    OrderImageCache.debugOverride =
        OrderImageCache(disk: createOrderImageDiskStore());
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    AppSession.instance.token = 'paddon-image-token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Operator',
      legalName: '',
      ref: 'paddon-image-worker',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
      assignedApparatus: ['apparatus:default:asset-010'],
    );
  });
  tearDown(() async {
    await OrderImageCache.instance.clear();
    OrderImageCache.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('production history uses the shared versioned product thumbnail',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = <http.Request>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
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
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (_) => WorkerWipDetailsSheet(
                          batch: AdminProgressBatch.fromJson(
                              _batch('history-wip', 'zakaz-0038', 'Old title')),
                          apparatusCatalog: const [
                            AdminApparatus(
                                id: 'apparatus:default:asset-010',
                                name: 'Rezka'),
                          ],
                          orderNumber: '0038',
                          productName: 'Bosma paket',
                          orderImageId: 'image-38',
                          viewer: AppSession.instance.profile,
                          onReprint: null,
                          errorMessage: (error) => error.toString(),
                        ),
                      ),
                      child: const Text('WIP'),
                    ))),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('WIP'));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.text('0038 • Bosma paket'), findsOneWidget);
      expect(find.byType(WorkerWipDetailsSheet), findsOneWidget);
      expect(find.byKey(const ValueKey('worker-wip-order-image-history-wip')),
          findsOneWidget);
      expect(find.text('12.5 kg'), findsOneWidget);
      expect(find.text('12 kg'), findsOneWidget);
      expect(find.text('Nasir'), findsOneWidget);
      expect(requests, hasLength(1));
      expect(requests.single.url.queryParameters['image_id'], 'image-38');
      expect(requests.single.url.queryParameters['variant'], 'thumb-v1');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
        () => MockClient((request) async {
              requests.add(request);
              return http.Response.bytes(thumbnail, 200,
                  headers: {'content-type': 'image/png'});
            }));
  });

  for (final available in [false, true]) {
    for (final hasImage in [false, true]) {
      testWidgets('paddon WIP sheet: available=$available, image=$hasImage',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final requests = <http.Request>[];
        final orderId = available ? 'zakaz-0024' : 'zakaz-0038';
        final orderSummary =
            available ? '0024 • Shaffof paket' : '0038 • Bosma paket';
        final batchId = available ? 'free-wip' : 'assigned-wip';
        await http.runWithClient(() async {
          await tester.pumpWidget(MaterialApp(
            locale: const Locale('uz'),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: AparatchiPaddonDetailScreen(
              code: '00007',
              apparatus: const [
                AdminApparatus(
                    id: 'apparatus:default:asset-010', name: 'Rezka'),
              ],
              snapshot: AdminPaddonSnapshot.fromJson({
                'paddon': {'code': '00007', 'item_count': 1},
                'items': [_batch('assigned-wip', 'zakaz-0038', 'Bosma paket')],
                'available_items': [
                  _batch('free-wip', 'zakaz-0024', 'Shaffof paket')
                ],
              }),
            ),
          ));
          await tester.pumpAndSettle();
          expect(requests, isEmpty);
          if (available) {
            await tester.tap(
              find.byKey(const ValueKey('app-primary-navigation-button')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byIcon(Icons.playlist_add_rounded));
            await tester.pumpAndSettle();
          }
          final card = find.byKey(ValueKey(available
              ? 'paddon-available-wip-card-$batchId'
              : 'paddon-wip-card-$batchId'));
          for (final value in [
            '1 450 m',
            'Brutto',
            '12.5 kg',
            'Netto',
            '12 kg',
            '0.5 kg',
            'Nasir',
            'Rezka',
            'EPC kodi',
            '4001 1234 5678 90AB CDEF 0001',
          ]) {
            expect(find.descendant(of: card, matching: find.text(value)),
                findsOneWidget);
          }
          await tester.ensureVisible(card);
          await tester.longPress(card);
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pumpAndSettle();

          final sheet =
              tester.widget<RpsQrReprintSheet>(find.byType(RpsQrReprintSheet));
          expect(find.byType(WorkerWipDetailsSheet), findsOneWidget);
          expect(sheet.itemName, orderSummary);
          expect(sheet.detailsContent, isA<WorkerWipDetails>());
          for (final value in [
            '1 450 m',
            '12.5 kg',
            '12 kg',
            '0.5 kg',
            'Nasir',
            'Rezka',
            '4001 1234 5678 90AB CDEF 0001'
          ]) {
            expect(
                find.descendant(
                    of: find.byType(WorkerWipDetailsSheet),
                    matching: find.text(value)),
                findsOneWidget);
          }
          expect(sheet.onReprint, isNotNull);
          expect(find.textContaining('zakaz-'), findsNothing);
          expect(find.textContaining('Order:'), findsNothing);
          expect(requests, hasLength(1));
          expect(requests.single.url.path,
              '/v1/mobile/admin/production-maps/order-image/view');
          expect(requests.single.url.queryParameters['order_id'], orderId);
          expect(requests.single.url.queryParameters['variant'], 'thumb-v1');
          expect(requests.single.headers['Authorization'],
              'Bearer paddon-image-token');

          final title = find.descendant(
            of: find.byType(RpsQrReprintSheet),
            matching: find.text(orderSummary),
          );
          final header =
              find.byKey(ValueKey('worker-wip-order-header-$batchId'));
          final image = find.byKey(ValueKey('worker-wip-order-image-$batchId'));
          expect(tester.widget<Text>(title).textAlign, TextAlign.start);
          if (hasImage) {
            expect(image, findsOneWidget);
            expect(tester.getSize(image), const Size(40, 40));
            expect(tester.getRect(image).left, tester.getRect(header).left);
            expect(tester.getRect(image).right,
                lessThan(tester.getRect(title).left));
            expect(tester.getCenter(image).dy,
                closeTo(tester.getCenter(title).dy, 0.1));
            expect(
                tester.widget<AdminOrderImageThumb>(image).previewOnLongPress,
                isFalse);
            await tester.tap(image);
            await tester.pump();
            await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 100)));
            await tester.pumpAndSettle();
            expect(find.byKey(const ValueKey('order-image-viewport')),
                findsOneWidget);
            expect(requests, hasLength(2));
            expect(requests.last.url.queryParameters['order_id'], orderId);
            expect(requests.last.url.queryParameters.containsKey('variant'),
                isFalse);
            final pixels = tester.widgetList<RawImage>(find.descendant(
              of: find.byKey(const ValueKey('order-image-viewport')),
              matching: find.byType(RawImage),
            ));
            expect(pixels.any((image) => image.image?.width == 800), isTrue);
            await tester.tap(find.byIcon(Icons.close_rounded).last);
            await tester.pumpAndSettle();
            expect(find.byType(RpsQrReprintSheet), findsOneWidget);
          } else {
            expect(image, findsNothing);
            expect(tester.getRect(title).left, tester.getRect(header).left);
            expect(find.byType(AdminOrderImageThumb), findsNothing);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
            () => MockClient((request) async {
                  requests.add(request);
                  if (!hasImage) {
                    return http.Response('{"error":"not_found"}', 404);
                  }
                  return http.Response.bytes(
                    request.url.queryParameters['variant'] == 'thumb-v1'
                        ? thumbnail
                        : fullImage,
                    200,
                    headers: {
                      'content-type': 'image/png',
                      'etag': '"paddon-image"'
                    },
                  );
                }));
      });
    }
  }
}

Map<String, dynamic> _batch(String id, String orderId, String title) => {
      'batch_id': id,
      'order_id': orderId,
      'apparatus': 'apparatus:default:asset-010',
      'qr_payload': '40011234567890ABCDEF0001',
      'produced_qty': 1450,
      'uom': 'm',
      'finished_goods_kg': 12,
      'bobina_kg': 0.5,
      'worker_ref': 'workerispdaduio0242304203480239',
      'worker_display_name': 'Nasir',
      'completed_at_unix': 1700000000,
      'wip_status': 'processed',
      'payload_json': {'order_title': title, 'gross_qty': 12.5},
    };
