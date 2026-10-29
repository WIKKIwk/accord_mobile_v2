import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
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
  await tester.pumpWidget(const MaterialApp(
    locale: Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: QolipPaddonScreen(code: 'QP-00012'),
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
      expect(moldRow('M-A'), findsOneWidget);
      expect(moldRow('M-B'), findsOneWidget);
      expect(moldRow('ITEM-A-UNRELATED'), findsNothing);
      expect(tester.widget<QolipCodeRow>(moldRow('M-USED')).enabled, isFalse);
      expect(tester.widget<QolipCodeRow>(moldRow('M-OTHER')).enabled, isFalse);

      await visibleTap(tester, moldRow('M-A'));
      expect(tester.widget<Checkbox>(selectProduct('ITEM-A')).value, isNull);
      expect(find.text('Confirm (1)'), findsOneWidget);
      await visibleTap(tester, selectProduct('ITEM-A'));
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

  testWidgets('search finds products by name and groups a matching mold code',
      (tester) async {
    final shared = mold('M-A', [alpha, beta]);
    await http.runWithClient(() async {
      await openPicker(tester);
      final search = find.byType(TextField);
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
              .widget<FilledButton>(
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
      final search = find.byType(TextField);
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
