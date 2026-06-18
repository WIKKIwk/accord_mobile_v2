import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/theme/theme_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_raw_material_assignment_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'raw_material.assign'],
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('assignment screen only asks for scan and order', (tester) async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeVariant.earthy),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminRawMaterialAssignmentScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(seenRequests, contains('GET /v1/mobile/admin/production-maps'));
      expect(
        seenRequests,
        contains('GET /v1/mobile/admin/raw-material-assignments'),
      );
      expect(seenRequests, isNot(contains('GET /v1/mobile/admin/items')));
      expect(find.text('Zakaz'), findsOneWidget);
      expect(find.text('QR skanerlash'), findsOneWidget);
      expect(find.text('Homashyo QR / barcode'), findsNothing);
      expect(find.text('Homashyo'), findsNothing);
      expect(find.text('Item code'), findsNothing);
      expect(find.text('Item nomi'), findsNothing);
      expect(find.text('Item group'), findsNothing);
    }, createHttpClient: (_) => _RawMaterialAssignmentHttpClient(seenRequests));
  });

  testWidgets('assignment screen shows scanned raw material details', (
    tester,
  ) async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeVariant.earthy),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminRawMaterialAssignmentScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('QR skanerlash'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '30AA');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        seenRequests,
        contains(
          'GET /v1/mobile/admin/raw-material-assignments/lookup?barcode=30AA',
        ),
      );
      expect(find.text('Homashyo ma’lumoti'), findsOneWidget);
      expect(find.text('Ombor'), findsOneWidget);
      expect(find.text('Kalidor'), findsOneWidget);
      expect(find.text('Turi'), findsOneWidget);
      expect(find.text('Kraska'), findsOneWidget);
      expect(find.text('Nomi'), findsOneWidget);
      expect(find.text('Black ink'), findsOneWidget);
      expect(find.text('Miqdori'), findsOneWidget);
      expect(find.text('12 Kg'), findsOneWidget);
      expect(find.text('Item code'), findsOneWidget);
      expect(find.text('INK-BLACK'), findsOneWidget);
    }, createHttpClient: (_) => _RawMaterialAssignmentHttpClient(seenRequests));
  });

  testWidgets('assignment screen clears scanned detail after save', (
    tester,
  ) async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(AppThemeVariant.earthy),
          locale: const Locale('uz'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AdminRawMaterialAssignmentScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('QR skanerlash'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '30AA');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Homashyo ma’lumoti'), findsOneWidget);

      await tester.tap(find.text('Ulash'));
      await tester.pumpAndSettle();

      expect(
        seenRequests,
        contains(
          'BODY POST /v1/mobile/admin/raw-material-assignments '
          '{"order_id":"zakaz-1","barcode":"30AA"}',
        ),
      );
      expect(find.text('Homashyo ma’lumoti'), findsNothing);
      expect(find.text('zakaz-1 · 30AA'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    }, createHttpClient: (_) => _RawMaterialAssignmentHttpClient(seenRequests));
  });
}

class _RawMaterialAssignmentHttpClient implements HttpClient {
  _RawMaterialAssignmentHttpClient(this.seenRequests);

  final List<String> seenRequests;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final key =
        '$method ${url.path}${url.query.isEmpty ? '' : '?${url.query}'}';
    seenRequests.add(key);

    Object body;
    switch (key) {
      case 'GET /v1/mobile/admin/production-maps':
        body = const [
          {
            'map': {
              'id': 'zakaz-1',
              'product_code': 'PR-1',
              'title': 'Zakaz 1',
              'code': 'Z-1',
              'nodes': [],
              'edges': [],
            },
            'program': {
              'map_id': 'zakaz-1',
              'product_code': 'PR-1',
              'operations': [],
            },
          },
        ];
      case 'GET /v1/mobile/admin/raw-material-assignments':
        body = const [];
      case 'GET /v1/mobile/admin/raw-material-assignments/lookup?barcode=30AA':
        body = const {
          'barcode': '30AA',
          'warehouse': 'Kalidor',
          'item_code': 'INK-BLACK',
          'item_name': 'Black ink',
          'item_group': 'Kraska',
          'qty': 12,
          'uom': 'Kg',
        };
      case 'POST /v1/mobile/admin/raw-material-assignments':
        body = const {
          'order_id': 'zakaz-1',
          'apparatus': 'Pechat',
          'barcode': '30AA',
          'item_code': 'INK-BLACK',
          'item_name': 'Black ink',
          'item_group': 'Kraska',
          'assigned_by_ref': 'admin',
          'assigned_by_display_name': 'Admin',
          'assigned_at': '2026-06-18T08:00:00Z',
          'stock_status': 'available',
          'reserved_order_id': '',
          'stock_warehouse': 'Kalidor',
        };
      case 'GET /v1/mobile/admin/items':
        body = const [];
      default:
        body = {'error': 'Unhandled request: $key'};
        return _FakeHttpClientRequest(
          response: _FakeHttpClientResponse(
            body: jsonEncode(body),
            statusCode: HttpStatus.notFound,
            requestKey: key,
            seenRequests: seenRequests,
          ),
        );
    }

    return _FakeHttpClientRequest(
      response: _FakeHttpClientResponse(
        body: jsonEncode(body),
        statusCode: HttpStatus.ok,
        requestKey: key,
        seenRequests: seenRequests,
      ),
    );
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({required this.response});

  final _FakeHttpClientResponse response;
  final BytesBuilder _body = BytesBuilder();
  final _headers = _FakeHttpHeaders();

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
  HttpHeaders get headers => _headers;

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
  Future<Socket> detachSocket() => throw UnsupportedError('detachSocket');

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

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _values = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name, () => <String>[]).add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name] = [value.toString()];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }
}
