import 'dart:convert';
import 'dart:typed_data';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_stub.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/display/order_image_provider.dart';
import 'package:accord_mobile_v2/src/core/widgets/display/image_fade.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_order_image_thumb.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/widgets/profile_avatar_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'order_image_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List thumb;
  late Uint8List full;
  setUpAll(() async {
    thumb = await orderImageTestPng(256, 128);
    full = await orderImageTestPng(1200, 600);
  });
  setUp(() async {
    OrderImageCache.debugOverride =
        OrderImageCache(disk: createOrderImageDiskStore());
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    await OrderImageCache.instance.clear();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    AppSession.instance.token = 'image-test-token';
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Worker',
        legalName: '',
        ref: 'image-worker',
        phone: '',
        avatarUrl: '');
  });
  tearDown(() async {
    await OrderImageCache.instance.clear();
    OrderImageCache.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  for (final cover in [false, true]) {
    testWidgets(
        '${cover ? 'cover' : 'thumbnail'} keeps its providers on rebuild and replaces them for source or session changes',
        (tester) async {
      var url = MobileApi.instance.adminProductionMapOrderImageUrl('order-1');
      var height = 70.0;
      final providerCache = cover ? OrderImageThumbCache(maxEntries: 2) : null;
      late StateSetter rebuild;
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
          home: StatefulBuilder(builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: SizedBox(
                width: 80,
                height: height,
                child: cover
                    ? AdminOrderCoverThumb(
                        imageUrl: url,
                        displayName: 'Order',
                        heroTag: 'stable',
                        providerCache: providerCache)
                    : AdminOrderImageThumb(
                        imageUrl: url,
                        dimension: height,
                        displayName: 'Order',
                        heroTag: 'stable'),
              ),
            );
          }),
        ));
        await tester.pumpAndSettle();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
        final provider = tester.widget<ImageFade>(find.byType(ImageFade)).image;
        final fullProvider = tester
            .widget<ProfileAvatarPreview>(find.byType(ProfileAvatarPreview))
            .avatarImage;
        final pixels = tester.widget<RawImage>(find.byType(RawImage)).image;
        expect(pixels, isNotNull);
        for (var index = 0; index < 6; index++) {
          rebuild(() => height = index.isEven ? 400 : 70);
          await tester.pumpAndSettle();
          expect(tester.widget<ImageFade>(find.byType(ImageFade)).image,
              same(provider));
          expect(
              tester
                  .widget<ProfileAvatarPreview>(
                      find.byType(ProfileAvatarPreview))
                  .avatarImage,
              same(fullProvider));
          expect(tester.widget<RawImage>(find.byType(RawImage)).image,
              same(pixels));
        }
        expect(requests, hasLength(1));

        rebuild(() => url =
            MobileApi.instance.adminProductionMapOrderImageUrl('order-2'));
        await tester.pumpAndSettle();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
        final replacement =
            tester.widget<ImageFade>(find.byType(ImageFade)).image;
        expect(identical(replacement, provider), isFalse);
        expect(requests, hasLength(2));
        expect(requests.last.url.queryParameters['order_id'], 'order-2');

        AppSession.instance.token = 'different-image-session';
        rebuild(() {});
        await tester.pumpAndSettle();
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
        expect(
            identical(tester.widget<ImageFade>(find.byType(ImageFade)).image,
                replacement),
            isFalse);
        expect(requests, hasLength(3));
        expect(requests.last.headers['Authorization'],
            'Bearer different-image-session');
        if (cover) {
          Future<ImageProvider> show(String order) async {
            rebuild(() => url =
                MobileApi.instance.adminProductionMapOrderImageUrl(order));
            await tester.pumpAndSettle();
            return tester.widget<ImageFade>(find.byType(ImageFade)).image;
          }

          final second = tester.widget<ImageFade>(find.byType(ImageFade)).image;
          final third = await show('order-3');
          expect(await show('order-2'), same(second));
          await show('order-4');
          expect(identical(await show('order-3'), third), isFalse,
              reason: 'The two-entry metadata cache evicts the least recent');
          final beforeClear =
              tester.widget<ImageFade>(find.byType(ImageFade)).image;
          providerCache!.clear();
          expect(identical(await show('order-3'), beforeClear), isFalse,
              reason: 'Explicit page refresh creates a fresh provider');
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                requests.add(request);
                return http.Response.bytes(thumb, 200,
                    headers: {'content-type': 'image/png'});
              }));
    });

    testWidgets(
        'order image ${cover ? 'cover' : 'thumbnail'} loads full pixels only on zoom',
        (tester) async {
      final requests = <http.Request>[];
      const url = '/v1/mobile/calculate/orders/image/view?id=quality-image';
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: Center(
                  child: SizedBox(
                      width: 80,
                      height: 100,
                      child: cover
                          ? const AdminOrderCoverThumb(
                              imageUrl: url,
                              displayName: 'Quality',
                              heroTag: 'quality')
                          : const AdminOrderImageThumb(
                              imageUrl: url,
                              displayName: 'Quality',
                              heroTag: 'quality')))),
        ));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
        expect(requests, hasLength(1));
        expect(requests.single.url.queryParameters['variant'], 'thumb-v1');
        expect(requests.single.headers['Authorization'],
            'Bearer image-test-token');
        final preview = tester
            .widget<ProfileAvatarPreview>(find.byType(ProfileAvatarPreview));
        expect((preview.avatarImage as OrderImageProvider).thumbnail, isFalse);
        await tester.longPress(find.byType(ProfileAvatarPreview));
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pumpAndSettle();
        expect(requests, hasLength(2));
        expect(
            requests.last.url.queryParameters.containsKey('variant'), isFalse);
        final fullImages = tester.widgetList<RawImage>(find.descendant(
            of: find.byKey(const ValueKey('order-image-viewport')),
            matching: find.byType(RawImage)));
        expect(fullImages.any((image) => image.image?.width == 1200), isTrue,
            reason:
                'zoom must decode the full 1200px image, not stretch the 256px thumbnail');
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        await tester.longPress(find.byType(ProfileAvatarPreview));
        await tester.pumpAndSettle();
        expect(requests, hasLength(2),
            reason: 'reopening uses the full-image cache');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
          () => MockClient((request) async {
                requests.add(request);
                return http.Response.bytes(
                    request.url.queryParameters['variant'] == 'thumb-v1'
                        ? thumb
                        : full,
                    200,
                    headers: {
                      'content-type': 'image/png',
                      'etag': '"test-image"'
                    });
              }));
    });
  }

  testWidgets('opening and closing a tall product keeps recycled cover streams',
      (tester) async {
    QolipCatalogStore.instance.reset();
    addTearDown(QolipCatalogStore.instance.reset);
    AppSession.instance.profile = const SessionProfile(
        role: UserRole.qolipchi,
        displayName: 'Qolipchi',
        legalName: '',
        ref: 'image-clerk',
        phone: '',
        avatarUrl: '',
        capabilities: ['qolip.manage']);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var imageReads = 0;
    var detailReads = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        locale: Locale('uz'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: QolipProductsScreen(),
      ));
      await tester.pumpAndSettle();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      final initialProviders = tester
          .widgetList<AdminOrderCoverImage>(find.byType(AdminOrderCoverImage))
          .map((cover) => cover.image)
          .toList();
      final initialPixels = tester
          .widgetList<RawImage>(find.byType(RawImage))
          .map((image) => image.image)
          .toList();
      expect(initialProviders, hasLength(12));
      expect(initialPixels, hasLength(12));
      expect(initialPixels.every((image) => image != null), isTrue);
      expect(imageReads, 12);
      for (var index = 0; index < 6; index++) {
        await tester.tap(find.text('Image Product 0'));
        await tester.pumpAndSettle();
        if (index.isEven) {
          expect(find.byType(AdminOrderCoverImage).evaluate().length,
              lessThan(initialProviders.length),
              reason: 'The tall card must recycle lower rows for this test');
          continue;
        }
        final providers = tester
            .widgetList<AdminOrderCoverImage>(find.byType(AdminOrderCoverImage))
            .map((cover) => cover.image)
            .toList();
        final pixels = tester
            .widgetList<RawImage>(find.byType(RawImage))
            .map((image) => image.image)
            .toList();
        expect(providers, hasLength(12));
        expect(pixels, hasLength(12));
        for (var image = 0; image < 12; image++) {
          expect(providers[image], same(initialProviders[image]));
          expect(pixels[image]!.isCloneOf(initialPixels[image]!), isTrue,
              reason: 'Recycled rows reuse decoded pixels without fading');
        }
        expect(imageReads, 12);
      }
      expect(detailReads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              final path = request.url.path;
              if (path.endsWith('/order-image/view')) {
                imageReads++;
                expectSync(request.url.queryParameters['variant'], 'thumb-v1');
                return http.Response.bytes(thumb, 200,
                    headers: {'content-type': 'image/png'});
              }
              if (path.endsWith('/qolip/reworks')) {
                return http.Response('{"ok":true,"reworks":[]}', 200);
              }
              if (path.endsWith('/products/page')) {
                return http.Response(
                    jsonEncode({
                      'items': [
                        for (var index = 0; index < 12; index++)
                          {
                            'id': qolipCatalogId('ITEM-$index'),
                            'name': 'Image Product $index',
                            'order_image_order_id': 'order-$index',
                          },
                      ],
                      'has_more': false,
                    }),
                    200);
              }
              expectSync(path, '/v1/mobile/qolip/products/detail');
              detailReads++;
              return http.Response(
                  jsonEncode({
                    'products': [
                      for (var index = 0; index < 10; index++)
                        {
                          'code': 'ITEM-0',
                          'name': 'Image Product 0',
                          'item_group': 'Finished',
                          'qolip_code': 'MOLD-$index',
                          'qolip_set_id': '950100000001',
                          'warehouse': 'Molds',
                          'size': 800,
                          'color': '#212121',
                          'has_qolip_spec': true,
                        },
                    ],
                  }),
                  200);
            }));
  });

  test(
      'provider identity separates accounts and image variants and preserves full URLs',
      () {
    final url = MobileApi.instance
        .adminProductionMapOrderImageUrl('order&1', imageId: 'image&1');
    expect(Uri.parse(url).queryParameters['order_id'], 'order&1');
    final thumbnail = OrderImageProvider(url, thumbnail: true);
    final full = OrderImageProvider(thumbnail.url);
    expect(thumbnail, isNot(full));
    expect(Uri.parse(full.url).queryParameters.containsKey('variant'), isFalse);
    AppSession.instance.token = 'other-session';
    expect(full, isNot(OrderImageProvider(url)));
    expect(
        MobileApi.instance
            .orderImageRequestUri('https://external.example/photo.webp',
                thumbnail: true)
            .toString(),
        'https://external.example/photo.webp');
  });
}
