import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await AppSession.instance.clear();
  });

  tearDown(() async {
    await AppSession.instance.clear();
  });

  test('login stores material assigned item groups from response', () async {
    final seenRequests = <String>[];

    await HttpOverrides.runZoned(() async {
      final profile = await MobileApi.instance.login(
        phone: '+998901112233',
        code: '70ABCDEF1234',
      );

      expect(profile.role, UserRole.materialTaminotchi);
      expect(profile.assignedItemGroups, ['Kraska', 'Kley']);
      expect(AppSession.instance.profile?.assignedItemGroups, [
        'Kraska',
        'Kley',
      ]);
      expect(AppSession.instance.can('gscale.print'), isTrue);
    }, createHttpClient: (_) => _AuthProfileHttpClient(seenRequests));

    expect(
      seenRequests,
      contains(
        'BODY POST /v1/mobile/auth/login '
        '{"phone":"+998901112233","code":"70ABCDEF1234"}',
      ),
    );
  });

  test('profile refresh replaces material assigned item groups', () async {
    final seenRequests = <String>[];
    await AppSession.instance.setSession(
      token: 'token',
      profile: const SessionProfile(
        role: UserRole.materialTaminotchi,
        displayName: 'Materialchi',
        legalName: '',
        ref: 'material_taminotchi',
        phone: '',
        avatarUrl: '',
        capabilities: ['gscale.print'],
        assignedItemGroups: ['Eski'],
      ),
    );

    await HttpOverrides.runZoned(() async {
      final profile = await MobileApi.instance.profile();

      expect(profile.assignedItemGroups, ['Kraska', 'Kley']);
      expect(AppSession.instance.profile?.assignedItemGroups, [
        'Kraska',
        'Kley',
      ]);
    }, createHttpClient: (_) => _AuthProfileHttpClient(seenRequests));

    expect(seenRequests, contains('GET /v1/mobile/profile'));
  });
}

class _AuthProfileHttpClient implements HttpClient {
  _AuthProfileHttpClient(this.seenRequests);

  final List<String> seenRequests;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final key =
        '$method ${url.path}${url.query.isEmpty ? '' : '?${url.query}'}';
    seenRequests.add(key);

    final Object body = switch (key) {
      'POST /v1/mobile/auth/login' => const {
          'token': 'token',
          'profile': {
            'role': 'material_taminotchi',
            'display_name': 'Materialchi',
            'legal_name': 'Materialchi',
            'ref': 'material_taminotchi',
            'phone': '+998901112233',
            'avatar_url': '',
          },
          'capabilities': [
            'gscale.catalog.read',
            'gscale.print',
            'raw_material.assign',
          ],
          'assigned_item_groups': ['Kraska', 'Kley'],
        },
      'GET /v1/mobile/profile' => const {
          'role': 'material_taminotchi',
          'display_name': 'Materialchi',
          'legal_name': 'Materialchi',
          'ref': 'material_taminotchi',
          'phone': '+998901112233',
          'avatar_url': '',
          'capabilities': [
            'gscale.catalog.read',
            'gscale.print',
            'raw_material.assign',
          ],
          'assigned_item_groups': ['Kraska', 'Kley'],
        },
      _ => {'error': 'Unhandled request: $key'},
    };
    final statusCode =
        key == 'POST /v1/mobile/auth/login' || key == 'GET /v1/mobile/profile'
            ? HttpStatus.ok
            : HttpStatus.notFound;
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
