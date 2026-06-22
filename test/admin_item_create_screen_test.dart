import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

Future<void> _pumpAdminItemCreateScreen(
  WidgetTester tester, {
  bool waitForItems = false,
}) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  final deadline = waitForItems ? 30 : 10;
  for (var i = 0; i < deadline; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (waitForItems && find.text('Item 001').evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> _openCreateItemTab(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(Tab, 'Item yaratish'));
  await tester.pump();
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text('All Item Groups').evaluate().isNotEmpty) {
      return;
    }
  }
}

Future<void> _openItemsTab(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(Tab, 'Itemlar'));
  await tester.pump();
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text('Item 001').evaluate().isNotEmpty) {
      return;
    }
  }
}

Finder _appBarSearchEditable() {
  return find.descendant(
    of: find.byType(AdminCatalogSearchField),
    matching: find.byType(EditableText),
  );
}

Finder _createTabTextFieldAt(int index) {
  return find.byKey(
    index == 0
        ? const ValueKey('admin-item-create-code')
        : const ValueKey('admin-item-create-name'),
  );
}

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

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

      expect(find.widgetWithText(Tab, 'Item yaratish'), findsOneWidget);
      expect(find.text('Itemlar'), findsOneWidget);
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
      expect(find.widgetWithText(Tab, 'Item yaratish'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('admin-item-search-close')));
      await tester.pumpAndSettle();

      expect(
          find.byKey(const ValueKey('admin-item-search-close')), findsNothing);
      expect(find.widgetWithText(Tab, 'Item yaratish'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('admin-item-create-code')), findsOneWidget);

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
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
}

class _AdminItemCreateHttpClient implements HttpClient {
  _AdminItemCreateHttpClient(this.seenRequests);

  final List<String> seenRequests;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final key =
        '$method ${url.path}${url.query.isEmpty ? '' : '?${url.query}'}';
    seenRequests.add(key);

    if (key == 'GET /v1/mobile/admin/items?limit=80') {
      return _FakeHttpClientRequest(
        response: _FakeHttpClientResponse(
          body: jsonEncode(_itemsPage(1, 80)),
          statusCode: HttpStatus.ok,
        ),
      );
    }
    if (key == 'GET /v1/mobile/admin/items?limit=80&offset=80') {
      return _FakeHttpClientRequest(
        response: _FakeHttpClientResponse(
          body: jsonEncode(_itemsPage(81, 5)),
          statusCode: HttpStatus.ok,
        ),
      );
    }

    final Object body = switch (key) {
      'GET /v1/mobile/admin/settings' => {'default_uom': 'Kg'},
      'GET /v1/mobile/admin/item-groups' => const [
          'All Item Groups',
          'Group A',
          'Group B',
        ],
      'GET /v1/mobile/admin/item-groups/tree' => const [
          {
            'name': 'Metal',
            'item_group_name': 'Metal',
            'parent_item_group': 'Homashyo',
            'is_group': false,
          },
          {
            'name': 'Group B',
            'item_group_name': 'Group B',
            'parent_item_group': 'All Item Groups',
            'is_group': false,
          },
          {
            'name': 'All Item Groups',
            'item_group_name': 'All Item Groups',
            'parent_item_group': '',
            'is_group': true,
          },
          {
            'name': 'Homashyo',
            'item_group_name': 'Homashyo',
            'parent_item_group': 'All Item Groups',
            'is_group': true,
          },
          {
            'name': 'Plastic',
            'item_group_name': 'Plastic',
            'parent_item_group': 'Homashyo',
            'is_group': false,
          },
        ],
      'GET /v1/mobile/admin/items?q=test&limit=5' => const [
          {
            'code': 'test',
            'name': 'test',
            'uom': 'Kg',
            'warehouse': 'Stores - A',
            'item_group': 'All Item Groups',
          },
        ],
      'POST /v1/mobile/admin/items' => {'error': 'admin item create failed'},
      _ => throw StateError('Unhandled request: $key'),
    };

    return _FakeHttpClientRequest(
      response: _FakeHttpClientResponse(
        body: jsonEncode(body),
        statusCode: key == 'POST /v1/mobile/admin/items'
            ? HttpStatus.internalServerError
            : HttpStatus.ok,
      ),
    );
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Map<String, String>> _itemsPage(int start, int count) {
  return List<Map<String, String>>.generate(count, (index) {
    final number = start + index;
    final padded = number.toString().padLeft(3, '0');
    return {
      'code': 'ITEM-$padded',
      'name': 'Item $padded',
      'uom': 'Kg',
      'warehouse': 'Stores - A',
      'item_group': number.isEven ? 'Tayyor Mahsulot' : 'Homashyo',
    };
  });
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({required this.response});

  final _FakeHttpClientResponse response;
  final _FakeHttpHeaders _headers = _FakeHttpHeaders();
  final Completer<HttpClientResponse> _done = Completer<HttpClientResponse>();

  @override
  HttpHeaders get headers => _headers;

  @override
  bool persistentConnection = true;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = -1;

  @override
  bool bufferOutput = true;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  Future<HttpClientResponse> get done => _done.future;

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  void writeln([Object? object = '']) {}

  @override
  Future<void> flush() async {}

  @override
  Future<HttpClientResponse> close() {
    if (!_done.isCompleted) {
      _done.complete(response);
    }
    return _done.future;
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    if (!_done.isCompleted) {
      _done.completeError(
        exception ?? const HttpException('aborted'),
        stackTrace ?? StackTrace.empty,
      );
    }
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({required String body, required this.statusCode})
      : _bytes = utf8.encode(body),
        _headers = _FakeHttpHeaders(),
        super(Stream<List<int>>.value(utf8.encode(body))) {
    _headers.set('content-type', 'application/json; charset=utf-8');
    _headers.contentLength = _bytes.length;
  }

  final List<int> _bytes;
  final _FakeHttpHeaders _headers;

  @override
  final int statusCode;

  @override
  String get reasonPhrase => statusCode == HttpStatus.ok ? 'OK' : 'ERROR';

  @override
  int get contentLength => _bytes.length;

  @override
  HttpHeaders get headers => _headers;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get persistentConnection => false;

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) async {
    return this;
  }

  @override
  Future<Socket> detachSocket() {
    return Future<Socket>.error(
      UnsupportedError('detachSocket is not supported in tests'),
    );
  }

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = <String, List<String>>{};
  int _contentLength = -1;
  ContentType? _contentType;

  String _normalize(String name) => name.toLowerCase();

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values
        .putIfAbsent(_normalize(name), () => <String>[])
        .add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[_normalize(name)] = <String>[value.toString()];
  }

  @override
  void removeAll(String name, {bool preserveHeaderCase = false}) {
    _values.remove(_normalize(name));
  }

  @override
  String? value(String name) {
    final values = _values[_normalize(name)];
    if (values == null || values.isEmpty) {
      return null;
    }
    return values.first;
  }

  @override
  List<String> operator [](String name) {
    return List<String>.unmodifiable(
      _values[_normalize(name)] ?? const <String>[],
    );
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  ContentType? get contentType => _contentType;

  @override
  set contentType(ContentType? value) {
    _contentType = value;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
