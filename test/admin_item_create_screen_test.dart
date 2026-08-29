import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_loading_indicator.dart';
import 'package:accord_mobile_v2/src/features/admin/models/admin_item_group_tree_entry.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_item_create_screen.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_search_field.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_summary_card.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'admin_item_create_screen_test_widgets_part_01.dart';
part 'admin_item_create_screen_test_declarations_part_02.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
  });

  setUp(() {
    AdminItemsListTab.clearMemoryCache();
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('duplicate item create shows temporary top notice', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminItemCreateHttpClient(seenRequests);

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminItemCreateScreen(),
        ),
      );

      await _pumpAdminItemCreateScreen(tester, waitForItems: true);
      await _openCreateItemTab(tester);
      await tester.enterText(_createTabTextFieldAt(0), 'test');
      await tester.enterText(_createTabTextFieldAt(1), 'test');
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-item-create-submit')).first,
      );
      await tester
          .tap(find.byKey(const ValueKey('admin-item-create-submit')).first);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Item allaqachon yaratilgan').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(
        seenRequests,
        contains('GET /v1/mobile/admin/items?q=test&limit=5'),
      );
      expect(
        seenRequests.where(
          (request) => request == 'POST /v1/mobile/admin/items',
        ),
        isEmpty,
      );
      expect(find.text('Item allaqachon yaratilgan'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();

      expect(find.text('Item allaqachon yaratilgan'), findsNothing);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets('same item name with a different code is allowed', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminItemCreateHttpClient(
      seenRequests,
      sameNameDifferentCode: true,
    );

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminItemCreateScreen(),
        ),
      );

      await _pumpAdminItemCreateScreen(tester, waitForItems: true);
      await _openCreateItemTab(tester);
      await tester.enterText(_createTabTextFieldAt(0), 'ITEM-UNIQUE');
      await tester.enterText(_createTabTextFieldAt(1), 'Shared name');
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-item-create-submit')).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('admin-item-create-submit')).first,
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Item yaratildi: ITEM-UNIQUE').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(
        seenRequests,
        contains('GET /v1/mobile/admin/items?q=ITEM-UNIQUE&limit=5'),
      );
      expect(
        seenRequests,
        contains('POST /v1/mobile/admin/items'),
      );
      expect(find.text('Item yaratildi: ITEM-UNIQUE'), findsOneWidget);
      expect(find.text('Item allaqachon yaratilgan'), findsNothing);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets('server duplicate conflict wins after an empty pre-check', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminItemCreateHttpClient(
      seenRequests,
      duplicateOnPost: true,
    );

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminItemCreateScreen(),
        ),
      );

      await _pumpAdminItemCreateScreen(tester, waitForItems: true);
      await _openCreateItemTab(tester);
      await tester.enterText(_createTabTextFieldAt(0), 'ITEM-RACE');
      await tester.enterText(_createTabTextFieldAt(1), 'Race item');
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-item-create-submit')).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('admin-item-create-submit')).first,
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Bu item code allaqachon mavjud').evaluate().isNotEmpty) {
          break;
        }
      }

      expect(
        seenRequests,
        contains('GET /v1/mobile/admin/items?q=ITEM-RACE&limit=5'),
      );
      expect(
        seenRequests,
        contains('POST /v1/mobile/admin/items'),
      );
      expect(find.text('Bu item code allaqachon mavjud'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets('shows finished-goods customer invariant from backend', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminItemCreateHttpClient(
      seenRequests,
      customerRequiredOnPost: true,
    );

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminItemCreateScreen(),
        ),
      );
      await _pumpAdminItemCreateScreen(tester, waitForItems: true);
      await _openCreateItemTab(tester);
      await tester.enterText(_createTabTextFieldAt(0), 'ITEM-FG-RACE');
      await tester.enterText(_createTabTextFieldAt(1), 'Finished item');
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-item-create-submit')).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('admin-item-create-submit')).first,
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find
            .text('Tayyor mahsulot uchun kamida bitta customer kerak')
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }

      expect(
        find.text('Tayyor mahsulot uchun kamida bitta customer kerak'),
        findsOneWidget,
      );
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets('item group picker opens as bottom sheet', (tester) async {
    final seenRequests = <String>[];
    final client = _AdminItemCreateHttpClient(seenRequests);

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminItemCreateScreen(),
        ),
      );

      await _pumpAdminItemCreateScreen(tester, waitForItems: true);
      await _openCreateItemTab(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-item-create-group-picker')).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('admin-item-create-group-picker')).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Item group tanlang'), findsOneWidget);
      expect(find.text('Item group qidiring'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Group B'),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Group B'));
      await tester.pumpAndSettle();

      expect(find.text('Item group tanlang'), findsNothing);
      expect(find.text('Group B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets('UOM is selected from catalog instead of free text', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminItemCreateHttpClient(seenRequests);

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminItemCreateScreen(),
        ),
      );

      await _pumpAdminItemCreateScreen(tester, waitForItems: true);
      await _openCreateItemTab(tester);
      final picker = find.byKey(
        const ValueKey('admin-item-create-uom-picker'),
      );
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();

      expect(find.text('O‘lchov birligini tanlang'), findsOneWidget);
      expect(find.text('O‘lchov birligini qidiring'), findsOneWidget);
      await tester.tap(find.text('Dona'));
      await tester.pumpAndSettle();

      expect(find.text('Dona'), findsOneWidget);
      expect(
        seenRequests,
        contains('GET /v1/mobile/admin/items/uoms'),
      );
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets('item screen has create and paged item list modules', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminItemCreateHttpClient(seenRequests);

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminItemCreateScreen(),
        ),
      );

      await _pumpAdminItemCreateScreen(tester, waitForItems: true);

      expect(find.widgetWithText(Tab, 'Itemlar'), findsOneWidget);
      expect(find.widgetWithText(Tab, "Group ko'chirish"), findsOneWidget);
      expect(find.text('Mahsulot qidirish'), findsOneWidget);
      expect(
        tester.widget<EditableText>(_appBarSearchEditable()).textAlign,
        TextAlign.start,
      );
      expect(
          find.byKey(const ValueKey('admin-item-search-close')), findsNothing);

      await tester.tap(_appBarSearchEditable());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('admin-item-search-close')),
          findsOneWidget);
      expect(find.widgetWithText(Tab, 'Itemlar'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('admin-item-search-close')));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('admin-item-search-close')), findsNothing);
      expect(find.widgetWithText(Tab, 'Itemlar'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('admin-item-create-code')), findsNothing);

      await _openItemsTab(tester);

      expect(seenRequests, contains('GET /v1/mobile/admin/items?limit=80'));
      expect(find.text('Item 001'), findsOneWidget);
      expect(find.text('Hamma itemlar'), findsNothing);
      expect(find.text('80 item'), findsNothing);
      expect(find.byType(AdminSummaryCard), findsWidgets);

      final itemListScroll = find.descendant(
        of: find.byType(AdminItemsListTab),
        matching: find.byType(Scrollable),
      );
      final scrollableState = tester.state<ScrollableState>(
        itemListScroll.last,
      );
      scrollableState.position.jumpTo(scrollableState.position.maxScrollExtent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        seenRequests,
        contains('GET /v1/mobile/admin/items?limit=80&offset=80'),
      );
      expect(find.text('Item 085'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets('item list initial load shows one centered app loader', (
    tester,
  ) async {
    final itemsPage = Completer<List<SupplierItem>>();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: AdminItemsListTab(
            loadItemsPage: ({required query, required limit, required offset}) {
              return itemsPage.future;
            },
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    itemsPage.complete(
      _itemsPage(1, 1).map(SupplierItem.fromJson).toList(growable: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('Item 001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('item list reuses memory cache until user refreshes', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminItemCreateHttpClient(seenRequests);

    Future<void> pumpScreen() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminItemCreateScreen(),
        ),
      );
      await _pumpAdminItemCreateScreen(tester, waitForItems: true);
      await _openItemsTab(tester);
    }

    await HttpOverrides.runZoned(() async {
      await pumpScreen();
      expect(
        seenRequests
            .where(
              (request) => request == 'GET /v1/mobile/admin/items?limit=80',
            )
            .length,
        1,
      );
      expect(find.text('Item 001'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await pumpScreen();

      expect(
        seenRequests
            .where(
              (request) => request == 'GET /v1/mobile/admin/items?limit=80',
            )
            .length,
        1,
      );
      expect(find.text('Item 001'), findsOneWidget);

      final refreshIndicator = tester.state<RefreshIndicatorState>(
        find.descendant(
          of: find.byType(AdminItemsListTab),
          matching: find.byType(RefreshIndicator),
        ),
      );
      unawaited(refreshIndicator.show());
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final requestCount = seenRequests
            .where(
              (request) => request == 'GET /v1/mobile/admin/items?limit=80',
            )
            .length;
        if (requestCount >= 2) {
          break;
        }
      }

      expect(
        seenRequests
            .where(
              (request) => request == 'GET /v1/mobile/admin/items?limit=80',
            )
            .length,
        2,
      );
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  testWidgets('item list cache is not reused after session changes', (
    tester,
  ) async {
    var loadCalls = 0;
    final oldItem = SupplierItem.fromJson({
      ..._itemsPage(1, 1).single,
      'code': 'ITEM-OLD',
      'name': 'Old session item',
    });
    final newItem = SupplierItem.fromJson({
      ..._itemsPage(1, 1).single,
      'code': 'ITEM-NEW',
      'name': 'New session item',
    });

    Future<void> pumpList() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: AdminItemsListTab(
              loadItemsPage: ({
                required query,
                required limit,
                required offset,
              }) async {
                loadCalls += 1;
                return [loadCalls == 1 ? oldItem : newItem];
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpList();
    expect(find.text('Old session item'), findsOneWidget);
    expect(loadCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin B',
      legalName: 'Admin B',
      ref: 'ADMIN-002',
      phone: '',
      avatarUrl: '',
    );
    AppSession.instance.revision.value++;

    await pumpList();
    expect(find.text('New session item'), findsOneWidget);
    expect(find.text('Old session item'), findsNothing);
    expect(loadCalls, 2);
  });

  testWidgets('admin can open an item from the item list', (tester) async {
    RouteSettings? openedRoute;
    var loadCalls = 0;
    final item = SupplierItem.fromJson(_itemsPage(1, 1).single);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        onGenerateRoute: (settings) {
          openedRoute = settings;
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Item detail route')),
          );
        },
        home: Scaffold(
          body: AdminItemsListTab(
            loadItemsPage: ({required query, required limit, required offset}) {
              loadCalls += 1;
              return Future<List<SupplierItem>>.value([item]);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.widgetWithText(AdminSummaryCard, 'Item 001');
    expect(row, findsOneWidget);
    expect(tester.widget<AdminSummaryCard>(row).showChevron, isTrue);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(openedRoute?.name, AppRoutes.adminItemDetail);
    expect(openedRoute?.arguments, 'ITEM-001');
    expect(find.text('Item detail route'), findsOneWidget);

    Navigator.of(tester.element(find.text('Item detail route'))).pop(true);
    await tester.pumpAndSettle();

    expect(loadCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('item group picker orders parent groups before children', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final seenRequests = <String>[];
    final client = _AdminItemCreateHttpClient(seenRequests);

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminItemCreateScreen(),
        ),
      );

      await _pumpAdminItemCreateScreen(tester, waitForItems: true);
      await _openCreateItemTab(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-item-create-group-picker')).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('admin-item-create-group-picker')).first,
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Homashyo'),
        240,
        scrollable: find.byType(Scrollable).last,
      );

      final allTop = tester
          .getTopLeft(
            find
                .descendant(
                  of: find.byType(Scrollable).last,
                  matching: find.text('All Item Groups'),
                )
                .first,
          )
          .dy;
      final homashyoTop = tester.getTopLeft(find.text('Homashyo')).dy;

      expect(allTop, lessThan(homashyoTop));
      expect(seenRequests, contains('GET /v1/mobile/admin/item-groups/tree'));
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => client);
  });

  test(
    'item group tree keeps direct root children above deeper descendants',
    () {
      final ordered = orderAdminItemGroupsByParent(const [
        AdminItemGroupTreeEntry(
          name: 'Metal',
          itemGroupName: 'Metal',
          parentItemGroup: 'Homashyo',
          isGroup: false,
        ),
        AdminItemGroupTreeEntry(
          name: 'Tayyor Mahsulot',
          itemGroupName: 'Tayyor Mahsulot',
          parentItemGroup: 'All Item Groups',
          isGroup: false,
        ),
        AdminItemGroupTreeEntry(
          name: 'All Item Groups',
          itemGroupName: 'All Item Groups',
          parentItemGroup: '',
          isGroup: true,
        ),
        AdminItemGroupTreeEntry(
          name: 'Homashyo',
          itemGroupName: 'Homashyo',
          parentItemGroup: 'All Item Groups',
          isGroup: true,
        ),
        AdminItemGroupTreeEntry(
          name: 'Plastic',
          itemGroupName: 'Plastic',
          parentItemGroup: 'Homashyo',
          isGroup: false,
        ),
      ]);

      expect(ordered, const [
        'All Item Groups',
        'Tayyor Mahsulot',
        'Homashyo',
        'Metal',
        'Plastic',
      ]);
    },
  );

  test('finished-goods customer rule follows exact parent path', () {
    const groups = [
      AdminItemGroupTreeEntry(
        name: 'All Item Groups',
        itemGroupName: 'All Item Groups',
        parentItemGroup: '',
        isGroup: true,
      ),
      AdminItemGroupTreeEntry(
        name: 'Tayyor mahsulot',
        itemGroupName: 'Tayyor mahsulot',
        parentItemGroup: 'All Item Groups',
        isGroup: true,
      ),
      AdminItemGroupTreeEntry(
        name: 'Paketlar',
        itemGroupName: 'Paketlar',
        parentItemGroup: 'Tayyor mahsulot',
        isGroup: false,
      ),
      AdminItemGroupTreeEntry(
        name: 'Yarim tayyor mahsulot',
        itemGroupName: 'Yarim tayyor mahsulot',
        parentItemGroup: 'All Item Groups',
        isGroup: false,
      ),
    ];

    expect(adminItemGroupRequiresCustomer('Paketlar', groups), isTrue);
    expect(
      adminItemGroupRequiresCustomer('Yarim tayyor mahsulot', groups),
      isFalse,
    );
  });
}
