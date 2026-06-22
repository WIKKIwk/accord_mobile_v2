import 'dart:async';
import 'dart:convert';
import 'dart:io' hide BytesBuilder;
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_user_create_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
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

  tearDown(() async {
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('admin user create screen picks role from bottom sheet', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminUserCreateHttpClient(seenRequests);

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
          home: const AdminUserCreateScreen(),
        ),
      );

      await _pumpUi(tester);

      expect(find.text('Role tanlash'), findsOneWidget);
      expect(find.text('Role tanlang'), findsOneWidget);
      expect(find.text('Omborchi'), findsNothing);
      expect(find.byType(TabBar), findsNothing);
      expect(seenRequests, contains('GET /v1/mobile/admin/roles'));

      await tester.tap(find.text('Role tanlang').first);
      await _pumpUi(tester);
      expect(find.text('Role tanlang'), findsWidgets);
      expect(find.text('Item yaratuvchi'), findsOneWidget);
      await _selectPickerItem(tester, 'Item yaratuvchi');
      expect(find.text('Code'), findsNothing);
      expect(find.text('Omborchi saqlash'), findsNothing);
      expect(find.text('Foydalanuvchi saqlash'), findsOneWidget);

      await tester.tap(find.text('Item yaratuvchi').first);
      await _pumpUi(tester);
      expect(find.text('Role tanlang'), findsWidgets);
      await _selectPickerItem(tester, 'Haridor');

      await tester.enterText(find.byType(TextField).at(0), 'Ali Market');
      await tester.enterText(find.byType(TextField).at(1), '+998900001111');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(seenRequests, contains('POST /v1/mobile/admin/customers'));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2200));
      await _pumpUi(tester);
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin user create screen assigns aparatchi role', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminUserCreateHttpClient(seenRequests);

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
          home: const AdminUserCreateScreen(),
        ),
      );

      await _pumpUi(tester);
      await tester.tap(find.text('Role tanlang').first);
      await _pumpUi(tester);
      await _selectPickerItem(tester, 'Aparatchi');

      expect(find.text('Foydalanuvchi saqlash'), findsOneWidget);
      for (var i = 0;
          i < 20 && find.text('7 ta rangli pechat').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(find.text('7 ta rangli pechat'));
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'Aparatchi');
      await tester.enterText(find.byType(TextField).at(1), '110000011');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(seenRequests, contains('POST /v1/mobile/admin/customers'));
      expect(seenRequests, contains('PUT /v1/mobile/admin/role-assignments'));
      expect(
        seenRequests.any(
          (request) => request.contains('"role_id":"aparatchi"'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2200));
      await _pumpUi(tester);
    }, createHttpClient: (_) => client);
  });

  testWidgets('admin user create screen creates qolipchi as worker', (
    tester,
  ) async {
    final seenRequests = <String>[];
    final client = _AdminUserCreateHttpClient(seenRequests);

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
          home: const AdminUserCreateScreen(),
        ),
      );

      await _pumpUi(tester);
      await tester.tap(find.text('Role tanlang').first);
      await _pumpUi(tester);
      await _selectPickerItem(tester, 'Qolipchi');

      await tester.enterText(find.byType(TextField).at(0), 'Qolipchi');
      await tester.enterText(find.byType(TextField).at(1), '110000050');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Foydalanuvchi saqlash'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(seenRequests, contains('POST /v1/mobile/admin/workers'));
      expect(seenRequests, contains('PUT /v1/mobile/admin/workers'));
      expect(seenRequests, contains('PUT /v1/mobile/admin/role-assignments'));
      expect(
        seenRequests,
        contains('POST /v1/mobile/admin/workers/code/regenerate?id=worker-q'),
      );
      expect(seenRequests, isNot(contains('POST /v1/mobile/admin/customers')));
      expect(
        seenRequests.any((request) => request.contains('"role_id":"qolipchi"')),
        isTrue,
      );
      expect(
        seenRequests.any(
          (request) => request.contains('"principal_role":"qolipchi"'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 2200));
      await _pumpUi(tester);
    }, createHttpClient: (_) => client);
  });
}

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _selectPickerItem(WidgetTester tester, String label) async {
  await tester.enterText(find.byType(TextField).last, label);
  await _pumpUi(tester);
  await tester.tap(find.text(label).last);
  await _pumpUi(tester);
}

class _AdminUserCreateHttpClient implements HttpClient {
  _AdminUserCreateHttpClient(this.seenRequests);

  final List<String> seenRequests;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final key =
        '$method ${url.path}${url.query.isEmpty ? '' : '?${url.query}'}';
    seenRequests.add(key);

    Object body;
    var statusCode = HttpStatus.ok;
    switch (key) {
      case 'GET /v1/mobile/admin/settings':
        body = const {
          'werka_name': 'Werka',
          'werka_phone': '+998',
          'werka_code': 'WERKA-1',
        };
      case 'GET /v1/mobile/admin/roles':
        body = const [
          {
            'id': 'werka',
            'label': 'Werka',
            'base_role': 'werka',
            'capability_codes': ['werka.access'],
            'system': true,
          },
          {
            'id': 'customer',
            'label': 'Customer',
            'base_role': 'customer',
            'capability_codes': ['customer.access'],
            'system': true,
          },
          {
            'id': 'supplier',
            'label': 'Supplier',
            'base_role': 'supplier',
            'capability_codes': ['supplier.access'],
            'system': true,
          },
          {
            'id': 'item_creator',
            'label': 'Item yaratuvchi',
            'capability_codes': ['catalog.item.read', 'catalog.item.create'],
            'system': false,
          },
          {
            'id': 'aparatchi',
            'label': 'Aparatchi',
            'capability_codes': ['apparatus.queue.read'],
            'system': true,
          },
          {
            'id': 'qolipchi',
            'label': 'Qolipchi',
            'base_role': 'qolipchi',
            'capability_codes': ['qolip.manage'],
            'system': true,
          },
        ];
      case 'GET /v1/mobile/admin/warehouses?parent=aparat+-+A&limit=200':
        body = const [
          {
            'warehouse': '7 ta rangli pechat',
            'parent_warehouse': 'aparat - A',
          },
        ];
      case 'POST /v1/mobile/admin/workers':
        body = const {
          'id': 'worker-q',
          'name': 'Qolipchi',
          'phone': '',
          'level': 'Brigader',
        };
      case 'PUT /v1/mobile/admin/workers':
        body = const {
          'id': 'worker-q',
          'name': 'Qolipchi',
          'phone': '110000050',
          'level': 'Brigader',
        };
      case 'POST /v1/mobile/admin/workers/code/regenerate?id=worker-q':
        body = const {
          'id': 'worker-q',
          'name': 'Qolipchi',
          'phone': '110000050',
          'level': 'Brigader',
          'code': '501234567890',
          'code_locked': false,
          'code_retry_after_sec': 0,
        };
      case 'POST /v1/mobile/admin/customers':
        body = const {
          'ref': 'CUS-1',
          'name': 'Ali Market',
          'phone': '+998900001111',
        };
      case 'PUT /v1/mobile/admin/role-assignments':
        body = const {
          'principal_role': 'customer',
          'principal_ref': 'CUS-1',
          'role_id': 'item_creator',
        };
      default:
        statusCode = HttpStatus.notFound;
        body = {'error': 'Unhandled request: $key'};
    }

    return _FakeHttpClientRequest(
      response: _FakeHttpClientResponse(
        body: jsonEncode(body),
        statusCode: statusCode,
        requestKey: key,
        seenRequests: seenRequests,
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

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({required this.response});

  final _FakeHttpClientResponse response;
  final BytesBuilder _body = BytesBuilder();

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
  void write(Object? object) {
    if (object != null) {
      _body.add(utf8.encode(object.toString()));
    }
  }

  @override
  void add(List<int> data) {
    _body.add(data);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final data in stream) {
      _body.add(data);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    final body = utf8.decode(_body.takeBytes());
    if (body.isNotEmpty) {
      response.seenRequests.add('BODY ${response.requestKey} $body');
    }
    return response;
  }

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse({
    required this.body,
    required this.statusCode,
    required this.requestKey,
    required this.seenRequests,
  });

  final String body;
  final String requestKey;
  final List<String> seenRequests;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([utf8.encode(body)]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get contentLength => utf8.encode(body).length;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => '';

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  Future<Socket> detachSocket() {
    return Future<Socket>.error(
      UnsupportedError('detachSocket is not supported in tests'),
    );
  }

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) =>
      Future<HttpClientResponse>.value(this);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _values = <String, List<String>>{};

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name] = <String>[value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name, () => <String>[]).add(value.toString());
  }

  @override
  List<String>? operator [](String name) => _values[name];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
