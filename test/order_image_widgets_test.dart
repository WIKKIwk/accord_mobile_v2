import 'dart:typed_data';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_stub.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/display/order_image_provider.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_order_image_thumb.dart';
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
            of: find.byType(InteractiveViewer),
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
