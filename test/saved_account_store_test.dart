import 'dart:convert';

import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_store.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  test('stores independent authenticated accounts for the active endpoint',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final secrets = _MemoryAccountSecretStore();
    final store = SavedAccountStore(
      preferences: preferences,
      secretStore: secrets,
    );
    await store.load();

    await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com/',
      profile: _profile(ref: 'worker-a', name: 'Saman'),
      token: 'token-a',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
      lastUsedAt: DateTime.utc(2026, 8, 24, 8),
    );
    await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-b', name: 'Akmal'),
      token: 'token-b',
      phone: '+998900000002',
      code: '402222',
      makeActive: false,
      lastUsedAt: DateTime.utc(2026, 8, 24, 9),
    );
    await store.upsertAuthenticated(
      baseUrl: 'https://other.example.com',
      profile: _profile(ref: 'worker-c', name: 'Sardor'),
      token: 'token-c',
      phone: '+998900000003',
      code: '403333',
      makeActive: false,
      lastUsedAt: DateTime.utc(2026, 8, 24, 10),
    );

    final currentEndpointAccounts =
        store.accountsForEndpoint('https://erp.example.com/');
    expect(
      currentEndpointAccounts.map((account) => account.profile.ref),
      ['worker-b', 'worker-a'],
    );
    expect(store.activeAccount?.profile.ref, 'worker-a');

    final akmalSession = await store.sessionFor(
      currentEndpointAccounts.first.id,
    );
    expect(akmalSession?.token, 'token-b');
    expect(akmalSession?.phone, '+998900000002');
    expect(akmalSession?.code, '402222');
  });

  test('relogin updates one account without duplicating or changing active',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SavedAccountStore(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(),
    );
    await store.load();

    final first = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-a', name: 'Saman'),
      token: 'old-token',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
      lastUsedAt: DateTime.utc(2026, 8, 24, 8),
    );
    final updated = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com/',
      profile: _profile(ref: 'worker-a', name: 'Saman Updated'),
      token: 'new-token',
      phone: '+998900000001',
      code: '409999',
      makeActive: false,
      lastUsedAt: DateTime.utc(2026, 8, 24, 11),
    );

    expect(updated.id, first.id);
    expect(store.accounts, hasLength(1));
    expect(store.activeAccountId, first.id);
    expect(store.accounts.single.profile.displayName, 'Saman Updated');
    final session = await store.sessionFor(first.id);
    expect(session?.token, 'new-token');
    expect(session?.code, '409999');
  });

  test('removing one account preserves every other account', () async {
    final preferences = await SharedPreferences.getInstance();
    final secrets = _MemoryAccountSecretStore();
    final store = SavedAccountStore(
      preferences: preferences,
      secretStore: secrets,
    );
    await store.load();

    final first = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-a', name: 'Saman'),
      token: 'token-a',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );
    final second = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-b', name: 'Akmal'),
      token: 'token-b',
      phone: '+998900000002',
      code: '402222',
      makeActive: false,
    );

    await store.remove(first.id);

    expect(store.accounts.map((account) => account.id), [second.id]);
    expect(store.activeAccountId, isNull);
    expect(await store.sessionFor(first.id), isNull);
    expect((await store.sessionFor(second.id))?.token, 'token-b');
  });

  test('activating an account updates its recency and keeps its secret',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SavedAccountStore(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(),
    );
    await store.load();

    final first = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-a', name: 'Saman'),
      token: 'token-a',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
      lastUsedAt: DateTime.utc(2026, 8, 24, 8),
    );
    final second = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-b', name: 'Akmal'),
      token: 'token-b',
      phone: '+998900000002',
      code: '402222',
      makeActive: false,
      lastUsedAt: DateTime.utc(2026, 8, 24, 9),
    );

    await store.activate(
      first.id,
      usedAt: DateTime.utc(2026, 8, 24, 10),
    );

    expect(store.activeAccountId, first.id);
    expect(store.accounts.map((account) => account.id), [first.id, second.id]);
    expect((await store.sessionFor(first.id))?.token, 'token-a');
  });

  test('updating an account profile preserves its credentials', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SavedAccountStore(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(),
    );
    await store.load();

    final account = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-a', name: 'Saman'),
      token: 'token-a',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );

    await store.updateProfile(
      account.id,
      _profile(ref: 'worker-a', name: 'Saman Updated'),
    );

    expect(store.activeAccount?.profile.displayName, 'Saman Updated');
    final session = await store.sessionFor(account.id);
    expect(session?.token, 'token-a');
    expect(session?.phone, '+998900000001');
    expect(session?.code, '401111');
  });

  test('migrates the existing active session without asking for login again',
      () async {
    final legacyProfile = _profile(ref: 'worker-a', name: 'Saman');
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_session_token': 'legacy-token',
      'app_session_profile': jsonEncode(legacyProfile.toJson()),
      'last_login_phone': '+998900000001',
      'last_login_code': '401111',
    });
    final preferences = await SharedPreferences.getInstance();
    final secrets = _MemoryAccountSecretStore();
    final store = SavedAccountStore(
      preferences: preferences,
      secretStore: secrets,
    );
    await store.load();

    final migrated = await store.migrateLegacySession(
      baseUrl: 'https://erp.example.com',
    );

    expect(migrated, isTrue);
    expect(store.accounts, hasLength(1));
    expect(store.activeAccount?.profile.ref, 'worker-a');
    final session = await store.sessionFor(store.activeAccountId!);
    expect(session?.token, 'legacy-token');
    expect(session?.phone, '+998900000001');
    expect(session?.code, '401111');
    expect(preferences.containsKey('last_login_phone'), isFalse);
    expect(preferences.containsKey('last_login_code'), isFalse);

    final reloaded = SavedAccountStore(
      preferences: preferences,
      secretStore: secrets,
    );
    await reloaded.load();
    expect(reloaded.activeAccount?.profile.ref, 'worker-a');
    expect((await reloaded.sessionFor(reloaded.activeAccountId!))?.token,
        'legacy-token');
  });

  test('rejects persisted metadata whose id is not canonical', () {
    final profile = _profile(ref: 'worker-a', name: 'Saman');

    expect(
      () => SavedAccount.fromJson(<String, dynamic>{
        'id': 'forged-account-id',
        'base_url': 'https://erp.example.com',
        'profile': profile.toJson(),
        'last_used_at': DateTime.utc(2026, 8, 24).toIso8601String(),
      }),
      throwsFormatException,
    );
    expect(
      () => SavedAccount.fromJson(<String, dynamic>{
        'base_url': 'file:///tmp/not-a-server',
        'profile': profile.toJson(),
        'last_used_at': DateTime.utc(2026, 8, 24).toIso8601String(),
      }),
      throwsFormatException,
    );
  });

  test('secure migration failure is surfaced and keeps legacy credentials',
      () async {
    final legacyProfile = _profile(ref: 'worker-a', name: 'Saman');
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_session_token': 'legacy-token',
      'app_session_profile': jsonEncode(legacyProfile.toJson()),
      'last_login_phone': '+998900000001',
      'last_login_code': '401111',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = SavedAccountStore(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(failWrites: true),
    );
    await store.load();

    await expectLater(
      store.migrateLegacySession(baseUrl: 'https://erp.example.com'),
      throwsStateError,
    );

    expect(preferences.getString('app_session_token'), 'legacy-token');
    expect(preferences.getString('last_login_phone'), '+998900000001');
    expect(preferences.getString('last_login_code'), '401111');
    expect(store.accounts, isEmpty);
  });

  test('failed secure deletion is retried after metadata is disconnected',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final secrets = _MemoryAccountSecretStore(failDeletes: 1);
    final store = SavedAccountStore(
      preferences: preferences,
      secretStore: secrets,
    );
    await store.load();
    final account = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-a', name: 'Saman'),
      token: 'token-a',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );

    await store.remove(account.id);

    expect(store.accounts, isEmpty);
    expect(store.activeAccountId, isNull);
    expect(secrets.valuesCount, 1);

    final reloaded = SavedAccountStore(
      preferences: preferences,
      secretStore: secrets,
    );
    await reloaded.load();

    expect(secrets.valuesCount, 0);
    expect(reloaded.accounts, isEmpty);
  });

  test('upsert rolls metadata active id and secret back on persistence failure',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final secrets = _MemoryAccountSecretStore();
    var failNextPersist = false;
    final store = SavedAccountStore(
      preferences: preferences,
      secretStore: secrets,
      beforeMetadataPersist: () async {
        if (failNextPersist) {
          failNextPersist = false;
          throw StateError('metadata persist failed');
        }
      },
    );
    await store.load();
    final first = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-a', name: 'Saman'),
      token: 'token-a',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );
    failNextPersist = true;

    await expectLater(
      store.upsertAuthenticated(
        baseUrl: 'https://erp.example.com',
        profile: _profile(ref: 'worker-b', name: 'Akmal'),
        token: 'token-b',
        phone: '+998900000002',
        code: '402222',
        makeActive: true,
      ),
      throwsStateError,
    );

    expect(store.activeAccountId, first.id);
    expect(store.accounts.map((value) => value.id), [first.id]);
    expect((await store.sessionFor(first.id))?.token, 'token-a');
    expect(secrets.valuesCount, 1);

    final reloaded = SavedAccountStore(
      preferences: preferences,
      secretStore: secrets,
    );
    await reloaded.load();
    expect(reloaded.activeAccountId, first.id);
    expect(reloaded.accounts.map((value) => value.id), [first.id]);
  });

  test('metadata removal failure still deletes the restorable secret',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final secrets = _MemoryAccountSecretStore();
    var failNextPersist = false;
    final store = SavedAccountStore(
      preferences: preferences,
      secretStore: secrets,
      beforeMetadataPersist: () async {
        if (failNextPersist) {
          failNextPersist = false;
          throw StateError('metadata persist failed');
        }
      },
    );
    await store.load();
    final account = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-a', name: 'Saman'),
      token: 'token-a',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );
    failNextPersist = true;

    await expectLater(store.remove(account.id), throwsStateError);

    expect(store.activeAccountId, account.id);
    expect(await store.sessionFor(account.id), isNull);
    final reloaded = SavedAccountStore(
      preferences: preferences,
      secretStore: secrets,
    );
    await reloaded.load();
    expect(reloaded.activeAccountId, account.id);
    expect(await reloaded.sessionFor(account.id), isNull);
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
  _MemoryAccountSecretStore({this.failWrites = false, this.failDeletes = 0});

  final Map<String, String> _values = <String, String>{};
  final bool failWrites;
  int failDeletes;

  int get valuesCount => _values.length;

  @override
  Future<void> delete(String key) async {
    if (failDeletes > 0) {
      failDeletes--;
      throw StateError('secure delete failed');
    }
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) {
      throw StateError('secure write failed');
    }
    _values[key] = value;
  }
}
