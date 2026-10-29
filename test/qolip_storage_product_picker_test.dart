import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/navigation/app_root_navigation.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_loading_indicator.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_retry_state.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_search_field.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_order_image_thumb.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_storage_screen.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_products_screen.dart'
    show QolipCodeRow, QolipProductContainerCard;
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'order_image_test_data.dart';

const alpha = {'code': 'ITEM-A', 'name': 'Alpha product'};
const beta = {'code': 'ITEM-B', 'name': 'Beta product'};

Map<String, dynamic> mold(String code, List<Map<String, String>> products,
        {bool inUse = false, String warehouse = 'Qolip ombori'}) =>
    {
      'qolip_code': code,
      'qolip_set_id': '9501',
      'warehouse': warehouse,
      'item_name': 'Legacy name',
      'size': 40,
      'quantity': 1,
      'products': products,
      'is_in_use': inUse,
    };

http.Response jsonResponse(Map<String, dynamic> data, [int statusCode = 200]) =>
    http.Response(jsonEncode(data), statusCode,
        headers: {'content-type': 'application/json'});

Map<String, dynamic> detail([List<String> codes = const []]) => {
      'ok': true,
      'paddon': {
        'code': 'QP-00012',
        'warehouse': 'Qolip ombori',
        'locked': false,
        'archived': false,
        'revision': codes.isEmpty ? 4 : 5,
        'item_count': codes.length,
      },
      'items': [
        for (final code in codes) mold(code, [alpha])
      ],
      'history': [],
    };

void session(String ref) {
  AppSession.instance.token = 'picker-$ref';
  AppSession.instance.profile = SessionProfile(
    role: UserRole.qolipchi,
    ref: ref,
    displayName: ref,
    legalName: '',
    phone: '',
    avatarUrl: '',
    capabilities: const ['qolip.manage'],
    assignedWarehouses: const ['Qolip ombori', 'Other warehouse'],
  );
  AppSession.instance.revision.value++;
}

Future<void> openPicker(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routes: {
      AppRoutes.qolipHome: (_) =>
          const Scaffold(body: Text('Home destination')),
      AppRoutes.qolipProducts: (_) =>
          const Scaffold(body: Text('Molds destination')),
      AppRoutes.qolipTasks: (_) =>
          const Scaffold(body: Text('Tasks destination')),
      AppRoutes.chat: (_) => const Scaffold(body: Text('Chat destination')),
    },
    home: const QolipPaddonScreen(code: 'QP-00012'),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('app-primary-navigation-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add molds'));
  await tester.pumpAndSettle();
}

Finder expand(String code) => find.byKey(
    ValueKey('qolip-picker-product-expand-product:${code.toLowerCase()}'));
Finder selectProduct(String code) => find.byKey(
    ValueKey('qolip-picker-product-select-product:${code.toLowerCase()}'));
Finder moldRow(String code) => find.byKey(ValueKey('qolip-picker-mold-$code'));
Finder pickerSearch() => find.descendant(
    of: find.byType(AdminCatalogSearchField),
    matching: find.byType(EditableText));

Future<void> visibleTap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServerEndpointStore.instance.clearOverride();
    session('worker');
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    QolipCatalogStore.instance.reset();
  });

  testWidgets('pagination shows one loading indicator at the list end',
      (tester) async {
    final pending = Completer<http.Response>();
    final molds = List.generate(
        20,
        (i) => mold('M-$i', [
              {'code': 'ITEM-$i', 'name': 'Product $i'}
            ]));
    await http.runWithClient(() async {
      await openPicker(tester);
      await tester.drag(find.byKey(const ValueKey('qolip-picker-list')),
          const Offset(0, -2200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<AppShell>(find.byType(AppShell)).appBarBottomLoading,
          isFalse);
      expect(find.byType(AppLoadingIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      pending.complete(jsonResponse({'ok': true, 'molds': []}));
      await tester.pumpAndSettle();
      expect(find.byType(AppLoadingIndicator), findsNothing);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/products/page')) {
                return jsonResponse(
                    {'ok': true, 'items': [], 'has_more': false});
              }
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(detail());
              }
              if (request.url.queryParameters['offset'] == '20') {
                return pending.future;
              }
              return jsonResponse({
                'ok': true,
                'molds': molds,
                'has_more': true,
                'next_offset': 20,
              });
            }));
  });

  testWidgets('picker displays the catalog images for each linked product',
      (tester) async {
    final png = await tester.runAsync(() => orderImageTestPng(48, 48));
    final laterPage = Completer<http.Response>();
    final requests = <String>[];
    final shared = mold('M-A', [alpha, beta]);
    await http.runWithClient(() async {
      await openPicker(tester);
      final firstCard =
          find.byKey(const ValueKey('qolip-picker-product-product:item-a'));
      final secondCard =
          find.byKey(const ValueKey('qolip-picker-product-product:item-b'));
      expect(tester.widget<QolipProductContainerCard>(firstCard).imageUrl,
          contains('order_id=picker-alpha-image'));
      expect(tester.widget<QolipProductContainerCard>(secondCard).imageUrl, '');
      final firstWidget = tester.widget<QolipProductContainerCard>(firstCard);
      laterPage.complete(jsonResponse({
        'ok': true,
        'items': [
          {
            'id': qolipCatalogId('ITEM-B'),
            'name': 'Beta product',
            'order_image_order_id': 'picker-beta-image'
          },
        ],
        'has_more': false,
      }));
      await tester.pumpAndSettle();
      expect(tester.widget<QolipProductContainerCard>(secondCard).imageUrl,
          contains('order_id=picker-beta-image'));
      expect(tester.widget<QolipProductContainerCard>(firstCard),
          same(firstWidget));
      bool hasImage(Finder card) => tester
          .widgetList<RawImage>(
              find.descendant(of: card, matching: find.byType(RawImage)))
          .any((image) => image.image?.width == 48);
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 25)));
        await tester.pump();
        if (hasImage(firstCard) && hasImage(secondCard)) break;
      }
      expect(
          requests, containsAll(['picker-alpha-image', 'picker-beta-image']));
      expect(hasImage(firstCard), isTrue);
      expect(hasImage(secondCard), isTrue);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/products/page')) {
                if (request.url.queryParameters.containsKey('cursor')) {
                  return laterPage.future;
                }
                return jsonResponse({
                  'ok': true,
                  'items': [
                    {
                      'id': qolipCatalogId('ITEM-A'),
                      'name': 'Alpha product',
                      'order_image_order_id': 'picker-alpha-image'
                    },
                  ],
                  'has_more': true,
                  'next_cursor': 'next',
                });
              }
              if (request.url.path.endsWith('/order-image/view')) {
                requests.add(request.url.queryParameters['order_id']!);
                return http.Response.bytes(png!, 200,
                    headers: {'content-type': 'image/png'});
              }
              return jsonResponse(request.url.path.endsWith('/paddons/molds')
                  ? {
                      'ok': true,
                      'molds': [shared]
                    }
                  : detail());
            }));
  });

  testWidgets('late catalog image data is ignored after an account switch',
      (tester) async {
    final pending = Completer<http.Response>();
    var imageReads = 0;
    await http.runWithClient(() async {
      await openPicker(tester);
      session('another-worker');
      pending.complete(jsonResponse({
        'ok': true,
        'items': [
          {
            'id': qolipCatalogId('ITEM-A'),
            'name': 'Alpha product',
            'order_image_order_id': 'old-session-image',
          }
        ],
        'has_more': false,
      }));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Account or permissions changed'), findsWidgets);
      expect(imageReads, 0);
      expect(find.byType(QolipProductContainerCard), findsNothing);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/products/page')) {
                return pending.future;
              }
              if (request.url.path.endsWith('/order-image/view')) imageReads++;
              return jsonResponse(request.url.path.endsWith('/paddons/molds')
                  ? {
                      'ok': true,
                      'molds': [
                        mold('M-A', [alpha])
                      ]
                    }
                  : detail());
            }));
  });

  testWidgets('picker search stays in the top bar and preserves selection',
      (tester) async {
    final queries = <String>[];
    final first = mold('M-A', [alpha]);
    await http.runWithClient(() async {
      await openPicker(tester);
      await tester.binding.setSurfaceSize(const Size(320, 640));
      await tester.pumpAndSettle();
      final search = find.byType(AdminCatalogSearchField);
      expect(find.descendant(of: find.byType(AppBar), matching: search),
          findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await visibleTap(tester, selectProduct('ITEM-A'));
      expect(find.text('Confirm (1)'), findsOneWidget);

      await tester.enterText(pickerSearch(), 'Alpha');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(queries.last, 'Alpha');
      expect(find.text('Confirm (1)'), findsOneWidget);
      await visibleTap(
          tester, find.byKey(const ValueKey('qolip-picker-search-close')));
      expect(
          tester.widget<EditableText>(pickerSearch()).controller.text, 'Alpha');
      await visibleTap(
          tester,
          find.descendant(
              of: search, matching: find.byIcon(Icons.close_rounded)));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(queries.last, isEmpty);
      expect(find.text('Confirm (1)'), findsOneWidget);

      await visibleTap(
          tester,
          find.descendant(
              of: search, matching: find.byIcon(Icons.arrow_back_rounded)));
      expect(find.text('Discard the unsaved selection?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(detail());
              }
              queries.add(request.url.queryParameters['q'] ?? '');
              return jsonResponse({
                'ok': true,
                'molds': [first]
              });
            }));
  });

  testWidgets('scrolling loads more products without the removed buttons',
      (tester) async {
    final offsets = <int>[];
    final firstPage = List.generate(
        20,
        (i) => mold('M-$i', [
              {
                'code': 'ITEM-$i',
                'name': 'Product ${i.toString().padLeft(2, '0')}'
              }
            ]));
    final last = mold('M-LAST', [
      {'code': 'ITEM-LAST', 'name': 'Z last product'}
    ]);
    await http.runWithClient(() async {
      await openPicker(tester);
      expect(find.text('Select loaded'), findsNothing);
      expect(find.text('Select complete set'), findsNothing);
      expect(find.text('Load more'), findsNothing);
      final searchPosition = tester.getTopLeft(pickerSearch());
      expect(offsets, [0]);
      await visibleTap(tester, selectProduct('ITEM-0'));
      expect(find.text('Confirm (1)'), findsOneWidget);
      await tester.drag(find.byKey(const ValueKey('qolip-picker-list')),
          const Offset(0, -2200));
      await tester.pumpAndSettle();
      expect(offsets, [0, 20]);
      expect(find.text('Z last product'), findsOneWidget);
      expect(tester.getTopLeft(pickerSearch()), searchPosition);
      expect(find.text('Confirm (1)'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(detail());
              }
              final query = request.url.queryParameters['q'] ?? '';
              if (query == 'ITEM-0') {
                return jsonResponse({
                  'ok': true,
                  'molds': [firstPage.first]
                });
              }
              final offset =
                  int.parse(request.url.queryParameters['offset'] ?? '0');
              offsets.add(offset);
              return jsonResponse({
                'ok': true,
                'molds': offset == 0 ? firstPage : [last],
                'has_more': offset == 0,
                if (offset == 0) 'next_offset': 20,
              });
            }));
  });

  testWidgets('a short first page automatically loads the next page',
      (tester) async {
    final offsets = <int>[];
    await http.runWithClient(() async {
      await openPicker(tester);
      expect(offsets, [0, 1]);
      expect(find.text('Alpha product'), findsOneWidget);
      expect(find.text('Beta product'), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(detail());
              }
              final offset =
                  int.parse(request.url.queryParameters['offset'] ?? '0');
              offsets.add(offset);
              return jsonResponse({
                'ok': true,
                'molds': [
                  offset == 0 ? mold('M-A', [alpha]) : mold('M-B', [beta])
                ],
                'has_more': offset == 0,
                if (offset == 0) 'next_offset': 1,
              });
            }));
  });

  testWidgets('automatic pagination stops on an error and allows retry',
      (tester) async {
    final offsets = <int>[];
    final firstPage = List.generate(
        20,
        (i) => mold('M-$i', [
              {
                'code': 'ITEM-$i',
                'name': 'Product ${i.toString().padLeft(2, '0')}'
              }
            ]));
    var fail = true;
    await http.runWithClient(() async {
      await openPicker(tester);
      await visibleTap(tester, selectProduct('ITEM-0'));
      await tester.drag(find.byKey(const ValueKey('qolip-picker-list')),
          const Offset(0, -2200));
      await tester.pumpAndSettle();
      expect(offsets, [0, 20]);
      expect(find.text('Confirm (1)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(offsets, [0, 20]);

      fail = false;
      final retry = find.descendant(
          of: find.byType(AppRetryState), matching: find.byType(TextButton));
      await visibleTap(tester, retry);
      expect(offsets, [0, 20, 20]);
      expect(find.text('Beta product'), findsOneWidget);
      expect(find.text('Confirm (1)'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(detail());
              }
              if (request.url.queryParameters['q'] == 'ITEM-0') {
                return jsonResponse({
                  'ok': true,
                  'molds': [firstPage.first]
                });
              }
              final offset =
                  int.parse(request.url.queryParameters['offset'] ?? '0');
              offsets.add(offset);
              if (offset == 20 && fail) {
                return jsonResponse({'ok': false, 'error': 'unavailable'}, 500);
              }
              return jsonResponse({
                'ok': true,
                'molds': offset == 0
                    ? firstPage
                    : [
                        mold('M-B', [beta])
                      ],
                'has_more': offset == 0,
                if (offset == 0) 'next_offset': 20,
              });
            }));
  });

  testWidgets('automatic pagination rejects a nonadvancing offset',
      (tester) async {
    var reads = 0;
    await http.runWithClient(() async {
      await openPicker(tester);
      expect(find.byType(AppRetryState), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(reads, 1);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(detail());
              }
              reads++;
              return jsonResponse({
                'ok': true,
                'molds': [
                  mold('M-A', [alpha])
                ],
                'has_more': true,
                'next_offset': 0,
              });
            }));
  });

  testWidgets('selection and expansion only rebuild the affected product',
      (tester) async {
    final first = mold('M-A', [alpha]);
    final second = mold('M-B', [beta]);
    var moldReads = 0;
    await http.runWithClient(() async {
      await openPicker(tester);
      await visibleTap(tester, expand('ITEM-A'));
      final readsBeforeSelection = moldReads;
      final shell = tester.widget<AppShell>(find.byType(AppShell));
      final otherProduct = tester.widget<QolipProductContainerCard>(
          find.byKey(const ValueKey('qolip-picker-product-product:item-b')));

      await visibleTap(tester, moldRow('M-A'));
      expect(find.text('Confirm (1)'), findsOneWidget);
      expect(tester.widget<AppShell>(find.byType(AppShell)), same(shell));
      expect(
          tester.widget<QolipProductContainerCard>(find
              .byKey(const ValueKey('qolip-picker-product-product:item-b'))),
          same(otherProduct));

      await visibleTap(tester, selectProduct('ITEM-A'));
      expect(find.text('Confirm (0)'), findsOneWidget);
      expect(tester.widget<AppShell>(find.byType(AppShell)), same(shell));
      expect(
          tester.widget<QolipProductContainerCard>(find
              .byKey(const ValueKey('qolip-picker-product-product:item-b'))),
          same(otherProduct));

      await visibleTap(tester, expand('ITEM-A'));
      expect(moldRow('M-A'), findsNothing);
      expect(tester.widget<AppShell>(find.byType(AppShell)), same(shell));
      expect(
          tester.widget<QolipProductContainerCard>(find
              .byKey(const ValueKey('qolip-picker-product-product:item-b'))),
          same(otherProduct));
      expect(moldReads, readsBeforeSelection);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/paddons/molds')) {
                moldReads++;
                return jsonResponse({
                  'ok': true,
                  'molds': [first, second]
                });
              }
              return jsonResponse(detail());
            }));
  });

  testWidgets('product lookup keeps the screen in place while loading',
      (tester) async {
    final pending = Completer<http.Response>();
    final first = mold('M-A', [alpha]);
    await http.runWithClient(() async {
      await openPicker(tester);
      final shell = tester.widget<AppShell>(find.byType(AppShell));
      await tester.tap(selectProduct('ITEM-A'));
      await tester.pump();
      expect(tester.widget<AppShell>(find.byType(AppShell)), same(shell));
      expect(tester.widget<EditableText>(pickerSearch()).readOnly, isTrue);
      expect(find.text('Confirm (0)'), findsOneWidget);
      expect(
          tester
              .widget<QolipProductContainerCard>(find
                  .byKey(const ValueKey('qolip-picker-product-product:item-a')))
              .loading,
          isTrue);
      expect(
          tester.widget<Checkbox>(selectProduct('ITEM-A')).onChanged, isNull);
      pending.complete(jsonResponse({
        'ok': true,
        'molds': [first]
      }));
      await tester.pumpAndSettle();
      expect(tester.widget<AppShell>(find.byType(AppShell)), same(shell));
      expect(tester.widget<EditableText>(pickerSearch()).readOnly, isFalse);
      expect(find.text('Confirm (1)'), findsOneWidget);
      expect(tester.widget<Checkbox>(selectProduct('ITEM-A')).value, isTrue);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(detail());
              }
              if (request.url.queryParameters['q'] == 'ITEM-A') {
                return pending.future;
              }
              return jsonResponse({
                'ok': true,
                'molds': [first]
              });
            }));
  });

  testWidgets('selecting a mold keeps the expanded product and scroll position',
      (tester) async {
    final one = mold('M-A', [alpha]);
    final two = mold('M-B', [alpha]);
    await http.runWithClient(() async {
      await openPicker(tester);
      await visibleTap(tester, expand('ITEM-A'));
      await tester.ensureVisible(moldRow('M-A'));
      await tester.pumpAndSettle();
      final cover = find.descendant(
          of: find.byKey(const ValueKey('qolip-picker-product-product:item-a')),
          matching: find.byType(AdminOrderCoverThumb));
      final coverState = tester.state(cover);
      final before = tester.getTopLeft(moldRow('M-A'));
      await tester.tap(moldRow('M-A'));
      await tester.pumpAndSettle();
      expect(tester.state(cover), same(coverState));
      expect(tester.getTopLeft(moldRow('M-A')).dy, closeTo(before.dy, 1));
      expect(find.text('Confirm (1)'), findsOneWidget);
      expect(moldRow('M-B'), findsOneWidget);
      await tester.tap(moldRow('M-A'));
      await tester.pumpAndSettle();
      expect(tester.state(cover), same(coverState));
      expect(tester.getTopLeft(moldRow('M-A')).dy, closeTo(before.dy, 1));
      expect(find.text('Confirm (0)'), findsOneWidget);
    },
        () => MockClient((request) async => jsonResponse(
              request.url.path.endsWith('/paddons/molds')
                  ? {
                      'ok': true,
                      'molds': [one, two]
                    }
                  : detail(),
            )));
  });

  testWidgets(
      'product groups select every eligible page and deduplicate shared molds',
      (tester) async {
    final shared = mold('M-A', [alpha, beta]);
    final free = mold('M-B', [alpha]);
    final betaOnly = mold('M-C', [beta]);
    final inUse = mold('M-USED', [alpha], inUse: true);
    final otherWarehouse =
        mold('M-OTHER', [alpha], warehouse: 'Other warehouse');
    final unrelated = mold('ITEM-A-UNRELATED', [beta]);
    final requestedOffsets = <String>[];
    final writes = <Map<String, dynamic>>[];
    await http.runWithClient(() async {
      await openPicker(tester);
      expect(find.text('Alpha product'), findsOneWidget);
      expect(find.text('Beta product'), findsOneWidget);
      expect(find.byType(QolipProductContainerCard), findsNWidgets(2));
      expect(moldRow('M-A'), findsNothing);

      await visibleTap(tester, expand('ITEM-A'));
      expect(requestedOffsets, containsAll(['ITEM-A:0', 'ITEM-A:100']));
      final productReads =
          requestedOffsets.where((value) => value.startsWith('ITEM-A:')).length;
      expect(moldRow('M-A'), findsOneWidget);
      expect(moldRow('M-B'), findsOneWidget);
      expect(moldRow('ITEM-A-UNRELATED'), findsNothing);
      expect(tester.widget<QolipCodeRow>(moldRow('M-USED')).enabled, isFalse);
      expect(tester.widget<QolipCodeRow>(moldRow('M-OTHER')).enabled, isFalse);

      await visibleTap(tester, moldRow('M-A'));
      expect(tester.widget<Checkbox>(selectProduct('ITEM-A')).value, isNull);
      expect(find.text('Confirm (1)'), findsOneWidget);
      await visibleTap(tester, selectProduct('ITEM-A'));
      expect(
          requestedOffsets.where((value) => value.startsWith('ITEM-A:')).length,
          productReads);
      expect(tester.widget<Checkbox>(selectProduct('ITEM-A')).value, isTrue);
      expect(find.text('Confirm (2)'), findsOneWidget);
      expect(tester.widget<Checkbox>(selectProduct('ITEM-B')).value, isNull);

      await visibleTap(tester, selectProduct('ITEM-B'));
      expect(find.text('Confirm (3)'), findsOneWidget);
      expect(writes, isEmpty);
      await visibleTap(
          tester, find.byKey(const ValueKey('qolip-picker-confirm')));
      expect(writes, isEmpty);
      await visibleTap(tester, find.widgetWithText(FilledButton, 'Confirm'));
      expect(
          writes.single['qolip_codes'], unorderedEquals(['M-A', 'M-B', 'M-C']));
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') {
                writes.add(
                    Map<String, dynamic>.from(jsonDecode(request.body) as Map));
                return jsonResponse(detail(['M-A', 'M-B', 'M-C']));
              }
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(
                    detail(writes.isEmpty ? [] : ['M-A', 'M-B', 'M-C']));
              }
              final q = request.url.queryParameters['q'] ?? '';
              final offset =
                  int.parse(request.url.queryParameters['offset'] ?? '0');
              requestedOffsets.add('$q:$offset');
              if (q == 'ITEM-A') {
                return jsonResponse({
                  'ok': true,
                  'molds': offset == 0
                      ? [shared, inUse, otherWarehouse, unrelated]
                      : [free],
                  'has_more': offset == 0,
                  if (offset == 0) 'next_offset': 100,
                });
              }
              return jsonResponse({
                'ok': true,
                'molds':
                    q == 'ITEM-B' ? [shared, betaOnly] : [shared, betaOnly],
                'has_more': false,
              });
            }));
  });

  for (final destination in ['Home', 'Molds', 'Tasks', 'Chat']) {
    testWidgets('dock $destination asks before discarding a selection',
        (tester) async {
      final one = mold('M-A', [alpha]);
      var writes = 0;
      await http.runWithClient(() async {
        await openPicker(tester);
        final fab = find.byKey(const ValueKey('qolip-picker-confirm'));
        final dock = find.byKey(const ValueKey('app-navigation-bar-shell'));
        expect(fab, findsOneWidget);
        expect(dock, findsOneWidget);
        expect(tester.getRect(fab).bottom,
            lessThanOrEqualTo(tester.getRect(dock).top));
        await visibleTap(tester, expand('ITEM-A'));
        await visibleTap(tester, moldRow('M-A'));
        final tab = find.descendant(
            of: find.byType(NavigationBar), matching: find.text(destination));
        expect(tab, findsOneWidget);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        expect(find.text('Discard the unsaved selection?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Confirm (1)'), findsOneWidget);
        expect(moldRow('M-A'), findsOneWidget);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
        await tester.pumpAndSettle();
        expect(find.text('$destination destination'), findsOneWidget);
        expect(writes, 0);
      },
          () => MockClient((request) async {
                if (request.method == 'POST') writes++;
                return jsonResponse(request.url.path.endsWith('/paddons/molds')
                    ? {
                        'ok': true,
                        'molds': [one]
                      }
                    : detail());
              }));
    });
  }

  testWidgets('dock navigates without prompting when nothing is selected',
      (tester) async {
    await http.runWithClient(() async {
      await openPicker(tester);
      final home = find.descendant(
          of: find.byType(NavigationBar), matching: find.text('Home'));
      await tester.tap(home);
      await tester.pumpAndSettle();
      expect(find.text('Home destination'), findsOneWidget);
      expect(find.text('Discard the unsaved selection?'), findsNothing);
    },
        () => MockClient((request) async => jsonResponse(
              request.url.path.endsWith('/paddons/molds')
                  ? {
                      'ok': true,
                      'molds': [
                        mold('M-A', [alpha])
                      ]
                    }
                  : detail(),
            )));
  });

  testWidgets('dock returns to an existing root without retaining the picker',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        initialRoute: AppRoutes.qolipHome,
        navigatorObservers: [AppRootNavigation.navigatorObserver],
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) =>
                            const QolipPaddonScreen(code: 'QP-00012'))),
                child: const Text('Open pallet'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open pallet'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add molds'));
      await tester.pumpAndSettle();
      await visibleTap(tester, selectProduct('ITEM-A'));
      await tester.tap(find.descendant(
          of: find.byType(NavigationBar), matching: find.text('Home')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Open pallet'), findsOneWidget);
      expect(find.byKey(const ValueKey('qolip-picker-confirm')), findsNothing);
    },
        () => MockClient((request) async => jsonResponse(
              request.url.path.endsWith('/paddons/molds')
                  ? {
                      'ok': true,
                      'molds': [
                        mold('M-A', [alpha])
                      ]
                    }
                  : detail(),
            )));
  });

  testWidgets(
      'canceling dock navigation during a product lookup preserves selection',
      (tester) async {
    final pending = Completer<http.Response>();
    final first = mold('M-A', [alpha, beta]);
    final second = mold('M-B', [alpha]);
    await http.runWithClient(() async {
      await openPicker(tester);
      await visibleTap(tester, selectProduct('ITEM-B'));
      expect(find.text('Confirm (1)'), findsOneWidget);
      await tester.ensureVisible(selectProduct('ITEM-A'));
      await tester.tap(selectProduct('ITEM-A'));
      await tester.pump();
      final chat = find.descendant(
          of: find.byType(NavigationBar), matching: find.text('Chat'));
      await tester.tap(chat);
      await tester.pump();
      expect(find.text('Discard the unsaved selection?'), findsOneWidget);
      pending.complete(jsonResponse({
        'ok': true,
        'molds': [first, second]
      }));
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm (2)'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(detail());
              }
              if (request.url.queryParameters['q'] == 'ITEM-A') {
                return pending.future;
              }
              return jsonResponse({
                'ok': true,
                'molds': [first]
              });
            }));
  });

  testWidgets('confirmed dock navigation discards a late product lookup',
      (tester) async {
    final pending = Completer<http.Response>();
    final first = mold('M-A', [alpha, beta]);
    final second = mold('M-B', [alpha]);
    var writes = 0;
    await http.runWithClient(() async {
      await openPicker(tester);
      await visibleTap(tester, selectProduct('ITEM-B'));
      await tester.ensureVisible(selectProduct('ITEM-A'));
      await tester.tap(selectProduct('ITEM-A'));
      await tester.pump();
      await tester.tap(find.descendant(
          of: find.byType(NavigationBar), matching: find.text('Chat')));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(find.text('Chat destination'), findsOneWidget);
      pending.complete(jsonResponse({
        'ok': true,
        'molds': [first, second]
      }));
      await tester.pumpAndSettle();
      expect(find.text('Chat destination'), findsOneWidget);
      expect(find.text('Confirm (2)'), findsNothing);
      expect(writes, 0);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') writes++;
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(detail());
              }
              if (request.url.queryParameters['q'] == 'ITEM-A') {
                return pending.future;
              }
              return jsonResponse({
                'ok': true,
                'molds': [first]
              });
            }));
  });

  testWidgets('search finds products by name and groups a matching mold code',
      (tester) async {
    final shared = mold('M-A', [alpha, beta]);
    await http.runWithClient(() async {
      await openPicker(tester);
      final search = pickerSearch();
      await tester.enterText(search, 'Alpha product');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(expand('ITEM-A'), findsOneWidget);
      expect(expand('ITEM-B'), findsNothing);
      await tester.enterText(search, 'M-A');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(expand('ITEM-A'), findsOneWidget);
      expect(expand('ITEM-B'), findsOneWidget);
    },
        () => MockClient((request) async => jsonResponse(
              request.url.path.endsWith('/paddons/molds')
                  ? {
                      'ok': true,
                      'molds': [shared]
                    }
                  : detail(),
            )));
  });

  testWidgets('failed later page never partially selects the product',
      (tester) async {
    var fail = true;
    await http.runWithClient(() async {
      await openPicker(tester);
      await visibleTap(tester, selectProduct('ITEM-A'));
      expect(find.text('Confirm (0)'), findsOneWidget);
      expect(
          tester
              .widget<FloatingActionButton>(
                  find.byKey(const ValueKey('qolip-picker-confirm')))
              .onPressed,
          isNull);
      fail = false;
      await visibleTap(tester, selectProduct('ITEM-A'));
      expect(find.text('Confirm (2)'), findsOneWidget);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(detail());
              }
              final q = request.url.queryParameters['q'] ?? '';
              final offset =
                  int.parse(request.url.queryParameters['offset'] ?? '0');
              if (q == 'ITEM-A' && offset == 100 && fail) {
                return jsonResponse({'ok': false, 'error': 'temporary'}, 500);
              }
              return jsonResponse({
                'ok': true,
                'molds': [
                  mold(offset == 0 ? 'M-A' : 'M-B', [alpha])
                ],
                'has_more': q == 'ITEM-A' && offset == 0,
                if (q == 'ITEM-A' && offset == 0) 'next_offset': 100,
              });
            }));
  });

  testWidgets('bulk selection shows why unavailable molds were skipped',
      (tester) async {
    final free = mold('M-A', [alpha]);
    final inUse = mold('M-USED', [alpha], inUse: true);
    await http.runWithClient(() async {
      await openPicker(tester);
      await visibleTap(tester, selectProduct('ITEM-A'));
      expect(find.text('Confirm (1)'), findsOneWidget);
      expect(find.text('Unavailable molds: 1'), findsOneWidget);
      expect(moldRow('M-USED'), findsOneWidget);
      expect(tester.widget<QolipCodeRow>(moldRow('M-USED')).enabled, isFalse);
      expect(find.textContaining('Issued to production'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('qolip-picker-confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    },
        () => MockClient((request) async => jsonResponse(
              request.url.path.endsWith('/paddons/molds')
                  ? {
                      'ok': true,
                      'molds': [free, inUse]
                    }
                  : detail(),
            )));
  });

  testWidgets('a late search result cannot replace a newer product search',
      (tester) async {
    final oldSearch = Completer<http.Response>();
    await http.runWithClient(() async {
      await openPicker(tester);
      final search = pickerSearch();
      await tester.enterText(search, 'Alpha');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.enterText(search, 'Beta');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(expand('ITEM-B'), findsOneWidget);
      oldSearch.complete(jsonResponse({
        'ok': true,
        'molds': [
          mold('M-A', [alpha])
        ]
      }));
      await tester.pumpAndSettle();
      expect(expand('ITEM-B'), findsOneWidget);
      expect(expand('ITEM-A'), findsNothing);
    },
        () => MockClient((request) async {
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(detail());
              }
              final q = request.url.queryParameters['q'] ?? '';
              if (q == 'Alpha') return oldSearch.future;
              return jsonResponse({
                'ok': true,
                'molds': [
                  mold('M-B', [beta])
                ]
              });
            }));
  });

  testWidgets('account switch discards an unfinished product selection',
      (tester) async {
    final pending = Completer<http.Response>();
    var writes = 0;
    await http.runWithClient(() async {
      await openPicker(tester);
      await tester.ensureVisible(selectProduct('ITEM-A'));
      await tester.tap(selectProduct('ITEM-A'));
      await tester.pump();
      session('other');
      pending.complete(jsonResponse({
        'ok': true,
        'molds': [
          mold('M-A', [alpha])
        ]
      }));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('Account or permissions changed'), findsWidgets);
      expect(find.text('Confirm (1)'), findsNothing);
      expect(writes, 0);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') writes++;
              if (request.url.path.endsWith('/paddons/molds')) {
                if (request.url.queryParameters['q'] == 'ITEM-A') {
                  return pending.future;
                }
                return jsonResponse({
                  'ok': true,
                  'molds': [
                    mold('M-A', [alpha])
                  ]
                });
              }
              return jsonResponse(detail());
            }));
  });

  testWidgets('product exceeding the pallet limit is not partly selected',
      (tester) async {
    final all = List.generate(1001,
        (index) => mold('M-${index.toString().padLeft(4, '0')}', [alpha]));
    var writes = 0;
    await http.runWithClient(() async {
      await openPicker(tester);
      await visibleTap(tester, selectProduct('ITEM-A'));
      expect(find.text('Confirm (0)'), findsOneWidget);
      expect(writes, 0);
    },
        () => MockClient((request) async {
              if (request.method == 'POST') writes++;
              if (!request.url.path.endsWith('/paddons/molds')) {
                return jsonResponse(detail());
              }
              final q = request.url.queryParameters['q'] ?? '';
              final offset =
                  int.parse(request.url.queryParameters['offset'] ?? '0');
              if (q.isEmpty) {
                return jsonResponse({
                  'ok': true,
                  'molds': [all.first]
                });
              }
              final end = (offset + 100).clamp(0, all.length);
              return jsonResponse({
                'ok': true,
                'molds': all.sublist(offset, end),
                'has_more': end < all.length,
                if (end < all.length) 'next_offset': end,
              });
            }));
  });
}
