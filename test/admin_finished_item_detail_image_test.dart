import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_stub.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/display/image_fade.dart';
import 'package:accord_mobile_v2/src/core/widgets/display/order_image_provider.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_item_detail_screen.dart';
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
    OrderImageCache.debugOverride =
        OrderImageCache(disk: createOrderImageDiskStore());
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-FINISHED',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access'],
    );
  });

  tearDown(() async {
    await OrderImageCache.instance.clear();
    OrderImageCache.debugOverride = null;
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('finished item requests and displays its order image',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image =
        await rootBundle.load('assets/branding/accord_pdf_wordmark.png');
    final requests = <Uri>[];
    await http.runWithClient(() async {
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
        home: const AdminItemDetailScreen(itemCode: 'ITEM-FG'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ITEM-FG'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_rounded), findsNothing);
      final badge = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('admin-finished-item-badge')));
      final decoration = badge.decoration as BoxDecoration;
      expect(decoration.border, isNull);
      expect((decoration.borderRadius as BorderRadius).topLeft.x,
          greaterThan(100));

      final photo = find.byKey(const ValueKey('admin-finished-item-image'));
      final imageFade = tester.widget<ImageFade>(
          find.descendant(of: photo, matching: find.byType(ImageFade)));
      final provider = imageFade.image as OrderImageProvider;
      final uri = Uri.parse(provider.url);
      expect(uri.queryParameters['order_id'], 'order-42');
      expect(uri.queryParameters['variant'], 'thumb-v1');
      await tester.runAsync(() async {
        final resolved = Completer<void>();
        final stream = provider.resolve(ImageConfiguration.empty);
        final listener = ImageStreamListener(
          (_, __) {
            if (!resolved.isCompleted) resolved.complete();
          },
          onError: (error, stack) {
            if (!resolved.isCompleted) resolved.completeError(error, stack);
          },
        );
        stream.addListener(listener);
        try {
          await resolved.future.timeout(const Duration(seconds: 5));
        } finally {
          stream.removeListener(listener);
        }
      });
      await tester.pumpAndSettle();
      expect(
        find.descendant(
            of: photo, matching: find.byKey(const ValueKey('image'))),
        findsOneWidget,
      );
      final detailRequests = requests
          .where((uri) => uri.path.endsWith('/admin/items/detail'))
          .toList();
      expect(detailRequests, hasLength(1));
      expect(detailRequests.single.queryParameters['include_image'], 'true');
      expect(
          requests.where((uri) =>
              uri.path.endsWith('/admin/production-maps/order-image/view')),
          hasLength(1));
      await tester.binding.setSurfaceSize(const Size(320, 640));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              requests.add(request.url);
              if (request.url.path.endsWith('/admin/items/detail')) {
                return http.Response(
                    jsonEncode({
                      'code': 'ITEM-FG',
                      'name': 'ITEM-FG',
                      'uom': 'Kg',
                      'item_group': 'Tayyor mahsulot',
                      'is_finished_goods': true,
                      'created_at_unix': 1720000000,
                      'updated_at_unix': 1720000060,
                      'order_image_order_id': 'order-42',
                    }),
                    200);
              }
              if (request.url.path
                  .endsWith('/admin/production-maps/order-image/view')) {
                return http.Response.bytes(
                  image.buffer
                      .asUint8List(image.offsetInBytes, image.lengthInBytes),
                  200,
                  headers: {'content-type': 'image/png'},
                );
              }
              return http.Response('', 404);
            }));
  });
}
