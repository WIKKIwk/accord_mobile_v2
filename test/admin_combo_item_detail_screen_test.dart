import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/cache/order_image_cache.dart';
import 'package:accord_mobile_v2/src/core/cache/order_image_disk_store_stub.dart';
import 'package:accord_mobile_v2/src/core/formatters/date_time_formatters.dart';
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

const _item = AdminItemDetail(
  code: 'COMBO-001',
  name: 'Shashoqcha · v1',
  uom: 'Kg',
  itemGroup: 'Kombo',
  isFinishedGoods: true,
  createdAtUnix: 1720000000,
  updatedAtUnix: 1720000060,
  customers: [
    CustomerDirectoryEntry(
      ref: 'CUSTOMER-1',
      name: 'Kukuruz',
      phone: '+998901234567',
    ),
  ],
);

Map<String, dynamic> _comboPayload(
        {String imageId = '', bool includeCodeOnly = false}) =>
    {
      'ok': true,
      'combo': {
        'id': 'combo-1',
        'item_code': _item.code,
        'name': 'Shashoqcha',
        'revision': 1,
        'layout_fingerprint': 'layout',
      },
      'template': {
        'image_id': imageId,
        'products': [
          {
            'id': 'p1',
            'item_code': 'SKU-SECRET-A',
            'product': 'Yashil',
            'frame_product_size_mm': 120,
            'frame_count': 2,
          },
          {
            'id': 'p2',
            'item_code': 'SKU-SECRET-B',
            'product': 'Kukuruz qora',
            'frame_product_size_mm': 120,
            'frame_count': 1,
          },
          if (includeCodeOnly)
            {
              'id': 'p3',
              'item_code': 'SKU-SECRET-C',
              'product': 'SKU-SECRET-C',
              'frame_product_size_mm': 80,
              'frame_count': 1,
            },
        ],
      },
    };

Widget _screen() => MaterialApp(
      theme: ThemeData(useMaterial3: true),
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: AdminItemDetailScreen(
        itemCode: _item.code,
        loadDetail: (_) async => _item,
      ),
    );

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
      ref: 'ADMIN-COMBO',
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

  testWidgets('combo item shows its photo, product names and consolidated info',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image =
        await rootBundle.load('assets/branding/accord_pdf_wordmark.png');
    final requests = <Uri>[];
    await http.runWithClient(() async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();

      expect(find.text(_item.name), findsOneWidget);
      expect(find.text(_item.code), findsOneWidget);
      expect(find.text('Yashil'), findsOneWidget);
      expect(find.text('Kukuruz qora'), findsOneWidget);
      expect(find.text('Oq paket'), findsOneWidget);
      expect(find.textContaining('SKU-SECRET'), findsNothing);
      expect(find.text('120 mm × 2'), findsOneWidget);
      expect(find.text('120 mm × 1'), findsOneWidget);
      expect(find.text('Kg'), findsOneWidget);
      expect(find.text(formatUnixSecondsLocalDateTime(_item.createdAtUnix)),
          findsOneWidget);
      expect(find.text(formatUnixSecondsLocalDateTime(_item.updatedAtUnix)),
          findsOneWidget);
      expect(find.text('Kukuruz'), findsOneWidget);
      expect(find.text('CUSTOMER-1 • +998901234567'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_rounded), findsNothing);
      expect(
          find.byKey(const ValueKey('admin-item-detail-edit')), findsNothing);
      expect(
          find.byKey(const ValueKey('admin-item-detail-delete')), findsNothing);

      final badge = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('admin-combo-item-badge')));
      final decoration = badge.decoration as BoxDecoration;
      expect(decoration.border, isNull);
      expect((decoration.borderRadius as BorderRadius).topLeft.x,
          greaterThan(100));
      final components = find.byKey(const ValueKey('admin-combo-components'));
      final information = find.byKey(const ValueKey('admin-combo-information'));
      final componentCard = tester.widget<Card>(
          find.descendant(of: components, matching: find.byType(Card)));
      final informationCard = tester.widget<Card>(
          find.descendant(of: information, matching: find.byType(Card)));
      expect(componentCard.color, informationCard.color);
      expect(componentCard.shape, informationCard.shape);

      final photo = find.byKey(const ValueKey('admin-combo-item-image'));
      final imageFade = tester.widget<ImageFade>(
          find.descendant(of: photo, matching: find.byType(ImageFade)));
      final provider = imageFade.image as OrderImageProvider;
      final uri = Uri.parse(provider.url);
      expect(uri.queryParameters['id'], 'artwork-1');
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
          findsOneWidget);
      expect(requests.where((uri) => uri.path.endsWith('/admin/combos')),
          hasLength(1));
      expect(requests.where((uri) => uri.path.endsWith('/admin/items/detail')),
          hasLength(1));
      expect(
          requests.where(
              (uri) => uri.path.endsWith('/calculate/orders/image/view')),
          hasLength(1));
      await tester.binding.setSurfaceSize(const Size(320, 844));
      await tester.pumpAndSettle();
      final actions = find.byKey(const ValueKey('admin-combo-item-actions'));
      expect(actions, findsOneWidget);
      await tester.tap(actions);
      await tester.pumpAndSettle();
      expect(find.text('Kombo amallari'), findsOneWidget);
      expect(
          find.text(
              'Kombo o‘zgarmas versiya sifatida saqlangani uchun bu amallar hozircha mavjud emas.'),
          findsOneWidget);
      for (final label in [
        'Nomni o‘zgartirish',
        'Customerlarni boshqarish',
        'Guruhini o‘zgartirish',
        'Itemni o‘chirish',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      for (final action in ['rename', 'customers', 'group', 'delete']) {
        final tile = tester.widget<ListTile>(
            find.byKey(ValueKey('admin-combo-action-$action')));
        expect(tile.enabled, isFalse);
        expect(tile.onTap, isNull);
      }
      Navigator.of(tester.element(find.text('Kombo amallari'))).pop();
      await tester.pumpAndSettle();
      expect(find.text(_item.name), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              requests.add(request.url);
              if (request.url.path.endsWith('/admin/combos')) {
                return http.Response(
                    jsonEncode(_comboPayload(
                        imageId: 'artwork-1', includeCodeOnly: true)),
                    200);
              }
              if (request.url.path.endsWith('/admin/items/detail')) {
                return http.Response(
                    jsonEncode({'code': 'SKU-SECRET-C', 'name': 'Oq paket'}),
                    200);
              }
              if (request.url.path.endsWith('/calculate/orders/image/view')) {
                return http.Response.bytes(
                    image.buffer
                        .asUint8List(image.offsetInBytes, image.lengthInBytes),
                    200,
                    headers: {'content-type': 'image/png'});
              }
              return http.Response('', 404);
            }));
  });

  testWidgets('combo item keeps its details and retries a failed catalog read',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var calls = 0;
    await http.runWithClient(() async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      expect(find.text('Kombo tarkibi yuklanmadi'), findsOneWidget);
      expect(find.text(_item.name), findsOneWidget);
      expect(find.text('Kg'), findsOneWidget);
      await tester.tap(find.text('Kombo tarkibi yuklanmadi'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Yashil'), findsOneWidget);
      expect(find.byType(ImageFade), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              calls++;
              return calls == 1
                  ? http.Response('{"error":"failed"}', 500)
                  : http.Response(jsonEncode(_comboPayload()), 200);
            }));
  });
}
