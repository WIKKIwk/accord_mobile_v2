import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/account_switch_controller.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_runtime.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_store.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await ServerEndpointStore.instance.clearOverride();
    await AppSession.instance.clear();
  });

  tearDown(() async {
    await AppSession.instance.clear();
    await ServerEndpointStore.instance.clearOverride();
  });

  test('detached authentication does not replace the current profile',
      () async {
    await AppSession.instance.setSession(
      token: 'current-token',
      profile: _profile(ref: 'worker-saman', name: 'Saman'),
    );
    final client = _SavedAccountHttpClient();

    await HttpOverrides.runZoned(() async {
      final authenticated = await MobileApi.instance.authenticateAccount(
        phone: '+998900000002',
        code: '402222',
      );

      expect(authenticated.token, 'new-token');
      expect(authenticated.profile.ref, 'worker-akmal');
      expect(AppSession.instance.token, 'current-token');
      expect(AppSession.instance.profile?.ref, 'worker-saman');
    }, createHttpClient: (_) => client);
  });

  test('401 reauthenticates only the active saved account and retries',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final secrets = _MemoryAccountSecretStore();
    await SavedAccountRuntime.instance.initialize(
      preferences: preferences,
      secretStore: secrets,
      baseUrl: MobileApi.baseUrl,
    );
    final profile = _profile(ref: 'worker-akmal', name: 'Akmal');
    final account =
        await SavedAccountRuntime.instance.store.upsertAuthenticated(
      baseUrl: MobileApi.baseUrl,
      profile: profile,
      token: 'expired-token',
      phone: '+998900000002',
      code: '402222',
      makeActive: true,
    );
    await AppSession.instance.setSession(
      token: 'expired-token',
      profile: profile,
    );
    final client =
        _SavedAccountHttpClient(firstProfileRequestUnauthorized: true);

    await HttpOverrides.runZoned(() async {
      final refreshed = await MobileApi.instance.profile();

      expect(refreshed.ref, 'worker-akmal');
      expect(AppSession.instance.token, 'new-token');
      final stored =
          await SavedAccountRuntime.instance.store.sessionFor(account.id);
      expect(stored?.token, 'new-token');
      expect(stored?.phone, '+998900000002');
      expect(stored?.code, '402222');
      expect(client.profileAuthorizationHeaders,
          ['Bearer expired-token', 'Bearer new-token']);
    }, createHttpClient: (_) => client);
  });

  test('failed 401 reauthentication clears the stale active marker', () async {
    final preferences = await SharedPreferences.getInstance();
    await SavedAccountRuntime.instance.initialize(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(),
      baseUrl: MobileApi.baseUrl,
    );
    final profile = _profile(ref: 'worker-akmal', name: 'Akmal');
    final account =
        await SavedAccountRuntime.instance.store.upsertAuthenticated(
      baseUrl: MobileApi.baseUrl,
      profile: profile,
      token: 'expired-token',
      phone: '+998900000002',
      code: '402222',
      makeActive: true,
    );
    await AppSession.instance.setSession(
      token: 'expired-token',
      profile: profile,
    );
    final client = _SavedAccountHttpClient(
      firstProfileRequestUnauthorized: true,
      loginUnauthorized: true,
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(MobileApi.instance.profile(), throwsException);
    }, createHttpClient: (_) => client);

    expect(AppSession.instance.isLoggedIn, isFalse);
    expect(SavedAccountRuntime.instance.store.activeAccountId, isNull);
    expect(
      SavedAccountRuntime.instance.store.accounts.map((value) => value.id),
      contains(account.id),
    );
  });

  test('invalid target account cannot partially commit a server endpoint',
      () async {
    const oldEndpoint = 'https://old.example.com';
    const newEndpoint = 'https://new.example.com';
    await ServerEndpointStore.instance.setBaseUrl(oldEndpoint);
    final preferences = await SharedPreferences.getInstance();
    await SavedAccountRuntime.instance.initialize(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(),
      baseUrl: oldEndpoint,
    );
    final profile = _profile(ref: 'worker-saman', name: 'Saman');
    final current =
        await SavedAccountRuntime.instance.store.upsertAuthenticated(
      baseUrl: oldEndpoint,
      profile: profile,
      token: 'current-token',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );
    await AppSession.instance.setSession(
      token: 'current-token',
      profile: profile,
    );
    final client = _SavedAccountHttpClient(
      supportHandshake: true,
      loginProfileRef: '',
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.switchServerEndpoint(newEndpoint),
        throwsArgumentError,
      );
    }, createHttpClient: (_) => client);

    expect(ServerEndpointStore.instance.baseUrl, oldEndpoint);
    expect(SavedAccountRuntime.instance.store.activeAccountId, current.id);
    expect(AppSession.instance.token, 'current-token');
    expect(AppSession.instance.profile?.ref, 'worker-saman');
  });

  test('endpoint rollback runs after endpoint persistence and activation fails',
      () async {
    const oldEndpoint = 'https://old.example.com';
    const newEndpoint = 'https://new.example.com';
    await ServerEndpointStore.instance.setBaseUrl(oldEndpoint);
    final preferences = await SharedPreferences.getInstance();
    var switchPersistCount = 0;
    var injectSwitchFailure = false;
    await SavedAccountRuntime.instance.initialize(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(),
      beforeMetadataPersist: () async {
        if (injectSwitchFailure && ++switchPersistCount == 2) {
          throw StateError('activation metadata failed');
        }
      },
      baseUrl: oldEndpoint,
    );
    final profile = _profile(ref: 'worker-saman', name: 'Saman');
    final current =
        await SavedAccountRuntime.instance.store.upsertAuthenticated(
      baseUrl: oldEndpoint,
      profile: profile,
      token: 'current-token',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );
    await AppSession.instance.setSession(
      token: 'current-token',
      profile: profile,
    );
    injectSwitchFailure = true;
    final client = _SavedAccountHttpClient(supportHandshake: true);

    await HttpOverrides.runZoned(() async {
      await expectLater(
        MobileApi.instance.switchServerEndpoint(newEndpoint),
        throwsStateError,
      );
    }, createHttpClient: (_) => client);

    expect(ServerEndpointStore.instance.baseUrl, oldEndpoint);
    expect(SavedAccountRuntime.instance.store.activeAccountId, current.id);
    expect(AppSession.instance.token, 'current-token');
    expect(AppSession.instance.profile?.ref, 'worker-saman');
  });

  test('401 during a profile switch cannot clear the switching session',
      () async {
    final preferences = await SharedPreferences.getInstance();
    await SavedAccountRuntime.instance.initialize(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(),
      baseUrl: MobileApi.baseUrl,
    );
    final store = SavedAccountRuntime.instance.store;
    final first = await store.upsertAuthenticated(
      baseUrl: MobileApi.baseUrl,
      profile: _profile(ref: 'worker-saman', name: 'Saman'),
      token: 'token-a',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );
    final second = await store.upsertAuthenticated(
      baseUrl: MobileApi.baseUrl,
      profile: _profile(ref: 'worker-akmal', name: 'Akmal'),
      token: 'token-b',
      phone: '+998900000002',
      code: '402222',
      makeActive: false,
    );
    await AppSession.instance.setSession(
      token: 'token-a',
      profile: first.profile,
    );
    final entered = Completer<void>();
    final release = Completer<void>();
    final switchController = AccountSwitchController(
      store: store,
      unregisterCurrentPush: () async {
        entered.complete();
        await release.future;
      },
    );
    final switching = switchController.switchTo(second.id);
    await entered.future;
    final client = _SavedAccountHttpClient(
      firstProfileRequestUnauthorized: true,
    );

    await HttpOverrides.runZoned(() async {
      await expectLater(MobileApi.instance.profile(), throwsException);
    }, createHttpClient: (_) => client);

    expect(AppSession.instance.token, 'token-a');
    expect(AppSession.instance.profile?.ref, 'worker-saman');
    release.complete();
    await switching;
    expect(AppSession.instance.token, 'token-b');
    expect(AppSession.instance.profile?.ref, 'worker-akmal');
  });
}

SessionProfile _profile({required String ref, required String name}) {
  return SessionProfile(
    role: UserRole.aparatchi,
    displayName: name,
    legalName: name,
    ref: ref,
    phone: '',
    avatarUrl: '',
    capabilities: const ['apparatus.queue.read'],
  );
}

class _MemoryAccountSecretStore implements AccountSecretStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

class _SavedAccountHttpClient implements HttpClient {
  _SavedAccountHttpClient({
    this.firstProfileRequestUnauthorized = false,
    this.loginUnauthorized = false,
    this.supportHandshake = false,
    this.loginProfileRef = 'worker-akmal',
  });

  final bool firstProfileRequestUnauthorized;
  final bool loginUnauthorized;
  final bool supportHandshake;
  final String loginProfileRef;
  final List<String> profileAuthorizationHeaders = <String>[];
  int _profileRequests = 0;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final responseBody = <String, Object?>{
      'token': 'new-token',
      'profile': {
        'role': 'aparatchi',
        'display_name': 'Akmal',
        'legal_name': 'Akmal',
        'ref': loginProfileRef,
        'phone': '+998900000002',
        'avatar_url': '',
      },
      'capabilities': ['apparatus.queue.read'],
      'assigned_apparatus': <String>[],
      'assigned_item_groups': <String>[],
      'assigned_warehouses': <String>[],
    };
    final request = _SavedAccountHttpRequest(
      responseBuilder: (headers) {
        if (method == 'GET' &&
            url.path == '/v1/mobile/server/handshake' &&
            supportHandshake) {
          return _SavedAccountHttpResponse(
            statusCode: HttpStatus.ok,
            body: jsonEncode(const <String, String>{
              'service': 'mini_rs_erp',
              'product': 'mini_rs_erp',
              'api_contract': 'v1',
              'version': 'test',
            }),
          );
        }
        if (method == 'GET' && url.path == '/v1/mobile/profile') {
          _profileRequests++;
          profileAuthorizationHeaders.add(
            headers.value(HttpHeaders.authorizationHeader) ?? '',
          );
          if (firstProfileRequestUnauthorized && _profileRequests == 1) {
            return _SavedAccountHttpResponse(
              statusCode: HttpStatus.unauthorized,
              body: jsonEncode(const {'error': 'unauthorized'}),
            );
          }
          return _SavedAccountHttpResponse(
            statusCode: HttpStatus.ok,
            body: jsonEncode(responseBody['profile']),
          );
        }
        if (method == 'POST' && url.path == '/v1/mobile/auth/login') {
          if (loginUnauthorized) {
            return _SavedAccountHttpResponse(
              statusCode: HttpStatus.unauthorized,
              body: jsonEncode(const {'error': 'unauthorized'}),
            );
          }
          return _SavedAccountHttpResponse(
            statusCode: HttpStatus.ok,
            body: jsonEncode(responseBody),
          );
        }
        return _SavedAccountHttpResponse(
          statusCode: HttpStatus.notFound,
          body: jsonEncode(const {'error': 'not found'}),
        );
      },
    );
    return request;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  void close({bool force = false}) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SavedAccountHttpRequest implements HttpClientRequest {
  _SavedAccountHttpRequest({required this.responseBuilder});

  final HttpClientResponse Function(_SavedAccountHttpHeaders headers)
      responseBuilder;
  final _SavedAccountHttpHeaders _headers = _SavedAccountHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  int contentLength = -1;

  @override
  bool bufferOutput = true;

  @override
  List<Cookie> get cookies => const <Cookie>[];

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() async => responseBuilder(_headers);

  @override
  void write(Object? object) {}

  @override
  void add(List<int> data) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding value) {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SavedAccountHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _SavedAccountHttpResponse({required this.statusCode, required this.body});

  @override
  final int statusCode;
  final String body;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(utf8.encode(body)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get contentLength => utf8.encode(body).length;

  @override
  HttpHeaders get headers => _SavedAccountHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => '';

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

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
  ]) async =>
      this;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SavedAccountHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _values = <String, List<String>>{};

  @override
  String? value(String name) => _values[name.toLowerCase()]?.firstOrNull;

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values
        .putIfAbsent(name.toLowerCase(), () => <String>[])
        .add(value.toString());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name.toLowerCase()] = <String>[value.toString()];
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }
}
