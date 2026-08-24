import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_runtime.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_store.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the active token from secure saved-account storage', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await ServerEndpointStore.instance.setBaseUrl('https://erp.example.com');
    addTearDown(ServerEndpointStore.instance.clearOverride);
    final preferences = await SharedPreferences.getInstance();
    await SavedAccountRuntime.instance.initialize(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(),
      baseUrl: 'https://erp.example.com',
    );
    const profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Saman',
      legalName: 'Saman',
      ref: 'worker-saman',
      phone: '+998900000001',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
    );
    await SavedAccountRuntime.instance.store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: profile,
      token: 'secure-token',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );
    await AppSession.instance.clear();

    await AppSession.instance.load();

    expect(AppSession.instance.token, 'secure-token');
    expect(AppSession.instance.profile?.ref, 'worker-saman');
    expect(preferences.containsKey('app_session_token'), isFalse);
    expect(preferences.containsKey('app_session_profile'), isFalse);
  });

  test('profile refresh updates active account metadata without plaintext',
      () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    await SavedAccountRuntime.instance.initialize(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(),
      baseUrl: 'https://erp.example.com',
    );
    final original = _profile('Saman');
    await SavedAccountRuntime.instance.store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: original,
      token: 'secure-token',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );
    await AppSession.instance.setSession(
      token: 'secure-token',
      profile: original,
    );

    await AppSession.instance.updateProfile(_profile('Saman Updated'));

    expect(AppSession.instance.profile?.displayName, 'Saman Updated');
    expect(
      SavedAccountRuntime.instance.store.activeAccount?.profile.displayName,
      'Saman Updated',
    );
    expect(preferences.containsKey('app_session_profile'), isFalse);
  });

  test('failed profile persistence does not mutate the in-memory profile',
      () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    await SavedAccountRuntime.instance.initialize(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(),
      baseUrl: 'https://erp.example.com',
    );
    final original = _profile('Saman');
    await SavedAccountRuntime.instance.store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: original,
      token: 'secure-token',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );
    await AppSession.instance.setSession(
      token: 'secure-token',
      profile: original,
    );
    final wrongIdentity = SessionProfile(
      role: original.role,
      displayName: 'Wrong identity',
      legalName: 'Wrong identity',
      ref: 'another-worker',
      phone: original.phone,
      avatarUrl: '',
      capabilities: original.capabilities,
    );

    await expectLater(
      AppSession.instance.updateProfile(wrongIdentity),
      throwsArgumentError,
    );

    expect(AppSession.instance.profile?.ref, original.ref);
    expect(AppSession.instance.profile?.displayName, original.displayName);
  });

  test('does not load an active account belonging to another endpoint',
      () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    await ServerEndpointStore.instance.setBaseUrl(
      'https://current.example.com',
    );
    addTearDown(ServerEndpointStore.instance.clearOverride);
    await SavedAccountRuntime.instance.initialize(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(),
      baseUrl: ServerEndpointStore.instance.baseUrl,
    );
    await SavedAccountRuntime.instance.store.upsertAuthenticated(
      baseUrl: 'https://other.example.com',
      profile: _profile('Saman'),
      token: 'other-token',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );
    await AppSession.instance.clear();

    await AppSession.instance.load();

    expect(AppSession.instance.isLoggedIn, isFalse);
    expect(SavedAccountRuntime.instance.store.activeAccountId, isNull);
  });
}

SessionProfile _profile(String name) {
  return SessionProfile(
    role: UserRole.aparatchi,
    displayName: name,
    legalName: name,
    ref: 'worker-saman',
    phone: '+998900000001',
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
