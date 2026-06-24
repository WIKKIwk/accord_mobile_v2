import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/theme/theme_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_raw_material_rules_screen.dart';
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
      capabilities: ['admin.access', 'raw_material.rule.manage'],
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('raw material group field lists homashyo child groups', (
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
          home: const AdminRawMaterialRulesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(seenRequests, contains('GET /v1/mobile/admin/item-groups/tree'));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(find.text('Kraska'), findsOneWidget);
      expect(find.text('Tayyor mahsulot'), findsNothing);
    }, createHttpClient: (_) => _RawMaterialRulesHttpClient(seenRequests));
  });

  testWidgets('raw material group picker saves alternative requirement groups',
      (
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
          home: const AdminRawMaterialRulesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const Key('raw-material-group-checkbox-Kley')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('raw-material-group-expand-Kley')));
      await tester.pumpAndSettle();
      expect(find.text('Alternativlar'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('raw-material-alternative-checkbox-Kley-Kraska')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tanlash'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saqlash'));
      await tester.pumpAndSettle();

      expect(
        seenRequests,
        contains(
          'BODY PUT /v1/mobile/admin/raw-material-rules '
          '{"apparatus":"Pechat","requires_material":false,'
          '"item_groups":["Kley","Kraska"],'
          '"requirement_groups":[{"name":"Kley",'
          '"item_groups":["Kley","Kraska"],"min_required_count":1}]}',
        ),
      );
      await tester.pump(const Duration(seconds: 2));
    }, createHttpClient: (_) => _RawMaterialRulesHttpClient(seenRequests));
  });

  testWidgets('required switch does not fake success when backend ignores flag',
      (
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
          home: const AdminRawMaterialRulesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Majburiylik').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.text('Backend majburiylikni saqlamadi'), findsOneWidget);
      expect(find.text('Majburiylik saqlandi'), findsNothing);
      expect(
        seenRequests,
        contains(
          'BODY PUT /v1/mobile/admin/raw-material-rules '
          '{"apparatus":"Pechat","requires_material":true,'
          '"item_groups":["Kraska"],"requirement_groups":[]}',
        ),
      );
      await tester.pump(const Duration(seconds: 2));
    },
        createHttpClient: (_) => _RawMaterialRulesHttpClient(
              seenRequests,
              initialRules: const [
                {
                  'apparatus': 'Pechat',
                  'requires_material': false,
                  'item_groups': ['Kraska'],
                },
              ],
            ));
  });
}

class _RawMaterialRulesHttpClient implements HttpClient {
  _RawMaterialRulesHttpClient(
    this.seenRequests, {
    this.initialRules = const [],
  });

  final List<String> seenRequests;
  final List<Map<String, Object>> initialRules;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final key = '$method ${url.path}';
    seenRequests.add(key);

    Object body;
    switch (key) {
      case 'GET /v1/mobile/admin/warehouses':
        body = const [
          {
            'warehouse': 'Pechat',
            'parent_warehouse': 'aparat - A',
            'is_group': false,
          },
        ];
      case 'GET /v1/mobile/admin/raw-material-rules':
        body = initialRules;
      case 'PUT /v1/mobile/admin/raw-material-rules':
        body = {
          'apparatus': 'Pechat',
          'requires_material': false,
          'item_groups': ['Kley', 'Kraska'],
          'requirement_groups': [
            {
              'name': 'Kley',
              'item_groups': ['Kley', 'Kraska'],
              'min_required_count': 1,
            },
          ],
        };
      case 'GET /v1/mobile/admin/item-groups/tree':
        body = const [
          {
            'name': 'Kley',
            'item_group_name': 'Kley',
            'parent_item_group': 'homashyo',
            'is_group': true,
          },
          {
            'name': 'Kraska',
            'item_group_name': 'Kraska',
            'parent_item_group': 'homashyo',
            'is_group': true,
          },
          {
            'name': 'Tayyor mahsulot',
            'item_group_name': 'Tayyor mahsulot',
            'parent_item_group': 'mahsulot',
            'is_group': true,
          },
        ];
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
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

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
