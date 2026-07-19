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
      expect(profile.assignedWarehouses, ['Xomashyo ombori - DEMO']);
      expect(AppSession.instance.profile?.assignedItemGroups, [
        'Kraska',
        'Kley',
      ]);
      expect(AppSession.instance.profile?.assignedWarehouses, [
        'Xomashyo ombori - DEMO',
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
      expect(profile.assignedWarehouses, ['Xomashyo ombori - DEMO']);
      expect(AppSession.instance.profile?.assignedItemGroups, [
        'Kraska',
        'Kley',
      ]);
      expect(AppSession.instance.profile?.assignedWarehouses, [
        'Xomashyo ombori - DEMO',
      ]);
    }, createHttpClient: (_) => _AuthProfileHttpClient(seenRequests));

    expect(seenRequests, contains('GET /v1/mobile/profile'));
  });

  test('admin material detail hydrates scopes from legacy assignment APIs',
      () async {
    final seenRequests = <String>[];
    await AppSession.instance.setSession(
      token: 'admin-token',
      profile: _adminProfile(),
    );

    await HttpOverrides.runZoned(() async {
      final detail =
          await MobileApi.instance.adminMaterialTaminotchiDetail('MAT-LEGACY');

      expect(detail.assignedItemGroups, ['Rulon']);
      expect(detail.assignedWarehouses, ['Kalidor']);
    }, createHttpClient: (_) => _AuthProfileHttpClient(seenRequests));

    expect(
      seenRequests,
      contains('GET /v1/mobile/admin/role-assignments'),
    );
    expect(
      seenRequests,
      contains('GET /v1/mobile/admin/warehouses/assignments'),
    );
  });

  test('admin material groups fall back when dedicated endpoint is missing',
      () async {
    final seenRequests = <String>[];
    final client = _AuthProfileHttpClient(seenRequests);
    await AppSession.instance.setSession(
      token: 'admin-token',
      profile: _adminProfile(),
    );

    await HttpOverrides.runZoned(() async {
      final detail =
          await MobileApi.instance.adminUpdateMaterialTaminotchiItemGroups(
        ref: 'MAT-LEGACY',
        assignedItemGroups: const ['Rulon', 'Kley', 'Rulon'],
      );

      expect(detail.assignedItemGroups, ['Kley', 'Rulon']);
      expect(detail.assignedWarehouses, ['Kalidor']);
    }, createHttpClient: (_) => client);

    expect(
      seenRequests,
      contains(
        'PUT /v1/mobile/admin/material-taminotchilar/item-groups?ref=MAT-LEGACY',
      ),
    );
    expect(
      seenRequests,
      contains('PUT /v1/mobile/admin/role-assignments'),
    );
    expect(
      seenRequests,
      contains(
        'BODY PUT /v1/mobile/admin/role-assignments '
        '{"principal_role":"material_taminotchi","principal_ref":"MAT-LEGACY",'
        '"role_id":"material_taminotchi","assigned_item_groups":["Kley","Rulon"]}',
      ),
    );
  });
}

SessionProfile _adminProfile() {
  return const SessionProfile(
    role: UserRole.admin,
    displayName: 'Admin',
    legalName: 'Admin',
    ref: 'admin',
    phone: '+998900000000',
    avatarUrl: '',
    capabilities: [
      'admin.access',
      'role.capability.read',
      'role.capability.manage',
    ],
  );
}

class _AuthProfileHttpClient implements HttpClient {
  _AuthProfileHttpClient(this.seenRequests);

  final List<String> seenRequests;
  List<String> materialGroups = ['Rulon'];

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
          'assigned_warehouses': ['Xomashyo ombori - DEMO'],
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
          'assigned_warehouses': ['Xomashyo ombori - DEMO'],
        },
      'GET /v1/mobile/admin/material-taminotchilar/detail?ref=MAT-LEGACY' =>
        const {
          'ref': 'MAT-LEGACY',
          'name': 'Materialchi',
          'phone': '+998901112233',
          'avatar_url': '',
          'code': '70ABCDEF1234',
          'code_locked': false,
          'code_retry_after_sec': 0,
          'assigned_items': [],
        },
      'GET /v1/mobile/admin/role-assignments' => [
          {
            'principal_role': 'material_taminotchi',
            'principal_ref': 'MAT-LEGACY',
            'role_id': 'material_taminotchi',
            'assigned_item_groups': materialGroups,
          },
        ],
      'GET /v1/mobile/admin/warehouses/assignments' => const [
          {
            'warehouse': 'Kalidor',
            'principal_role': 'material_taminotchi',
            'principal_ref': 'MAT-LEGACY',
            'display_name': 'Materialchi',
          },
        ],
      'PUT /v1/mobile/admin/material-taminotchilar/item-groups?ref=MAT-LEGACY' =>
        const {'error': 'not found'},
      'PUT /v1/mobile/admin/role-assignments' => const {
          'principal_role': 'material_taminotchi',
          'principal_ref': 'MAT-LEGACY',
          'role_id': 'material_taminotchi',
          'assigned_item_groups': ['Kley', 'Rulon'],
        },
      _ => {'error': 'Unhandled request: $key'},
    };
    final statusCode = switch (key) {
      'POST /v1/mobile/auth/login' ||
      'GET /v1/mobile/profile' ||
      'GET /v1/mobile/admin/material-taminotchilar/detail?ref=MAT-LEGACY' ||
      'GET /v1/mobile/admin/role-assignments' ||
      'GET /v1/mobile/admin/warehouses/assignments' ||
      'PUT /v1/mobile/admin/role-assignments' =>
        HttpStatus.ok,
      _ => HttpStatus.notFound,
    };
    return _FakeHttpClientRequest(
      response: _FakeHttpClientResponse(
        body: jsonEncode(body),
        statusCode: statusCode,
        requestKey: key,
        seenRequests: seenRequests,
      ),
      onBody: key == 'PUT /v1/mobile/admin/role-assignments'
          ? (raw) {
              final payload = jsonDecode(raw) as Map<String, dynamic>;
              materialGroups = (payload['assigned_item_groups'] as List)
                  .map((item) => item.toString())
                  .toList(growable: false);
            }
          : null,
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
  _FakeHttpClientRequest({required this.response, this.onBody});

  final _FakeHttpClientResponse response;
  final void Function(String body)? onBody;
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
      onBody?.call(body);
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
