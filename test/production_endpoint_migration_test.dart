import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_runtime.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const oldOrigin = 'https://mini-rs-erp-dev.wspace.sbs';
const newOrigin = 'https://accord.confi.uz';
const profile = SessionProfile(
  role: UserRole.aparatchi,
  displayName: 'Worker',
  legalName: 'Worker',
  ref: 'worker-1',
  phone: '+998900000001',
  avatarUrl: '',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('moves the production endpoint while keeping the active session', () async {
    expect(ServerEndpointStore.compiledBaseUrl, newOrigin);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final secrets = _MemorySecrets();
    final store = SavedAccountStore(preferences: prefs, secretStore: secrets);
    await store.load();
    final oldAccount = await store.upsertAuthenticated(
      baseUrl: oldOrigin,
      profile: profile,
      token: 'session-token',
      phone: profile.phone,
      code: '1234',
      makeActive: true,
    );
    await ServerEndpointStore.instance.setBaseUrl(oldOrigin);
    await SavedAccountRuntime.instance.initialize(
      preferences: prefs,
      secretStore: secrets,
      baseUrl: ServerEndpointStore.instance.baseUrl,
    );
    expect(ServerEndpointStore.instance.baseUrl, newOrigin);
    expect(SavedAccountRuntime.instance.store.activeAccount?.baseUrl, newOrigin);
    await AppSession.instance.load();
    expect(AppSession.instance.token, 'session-token');
    expect((await SavedAccountRuntime.instance.store.sessionFor(oldAccount.id))?.token,
        'session-token');
    await SavedAccountRuntime.instance.initialize(
      preferences: prefs,
      secretStore: secrets,
      baseUrl: ServerEndpointStore.instance.baseUrl,
    );
    await AppSession.instance.load();
    expect(AppSession.instance.token, 'session-token');
  });

  test('keeps an unrelated custom endpoint and its account unchanged', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final secrets = _MemorySecrets();
    const custom = 'https://custom.example.com';
    await ServerEndpointStore.instance.setBaseUrl(custom);
    final store = SavedAccountStore(preferences: prefs, secretStore: secrets);
    await store.load();
    final account = await store.upsertAuthenticated(
      baseUrl: custom,
      profile: profile,
      token: 'custom-token',
      phone: profile.phone,
      code: '',
      makeActive: true,
    );
    await SavedAccountRuntime.instance.initialize(
      preferences: prefs,
      secretStore: secrets,
      baseUrl: custom,
    );
    expect(ServerEndpointStore.instance.baseUrl, custom);
    expect(SavedAccountRuntime.instance.store.activeAccountId, account.id);
  });

  test('preserves a saved session when the previous endpoint was the default',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final secrets = _MemorySecrets();
    await ServerEndpointStore.instance.clearOverride();
    final store = SavedAccountStore(preferences: prefs, secretStore: secrets);
    await store.load();
    await store.upsertAuthenticated(
      baseUrl: oldOrigin,
      profile: profile,
      token: 'default-token',
      phone: profile.phone,
      code: '',
      makeActive: true,
    );
    await SavedAccountRuntime.instance.initialize(
      preferences: prefs,
      secretStore: secrets,
      baseUrl: ServerEndpointStore.instance.baseUrl,
    );
    await AppSession.instance.load();
    expect(AppSession.instance.token, 'default-token');
    expect(SavedAccountRuntime.instance.store.activeAccount?.baseUrl, newOrigin);
  });
}

class _MemorySecrets implements AccountSecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}
