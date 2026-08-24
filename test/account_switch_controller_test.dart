import 'dart:async';

import 'package:accord_mobile_v2/src/core/session/accounts/account_switch_controller.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_store.dart';
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

  test('switches session between saved accounts in push-safe order', () async {
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
    );
    final second = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-b', name: 'Akmal'),
      token: 'token-b',
      phone: '+998900000002',
      code: '402222',
      makeActive: false,
    );
    await AppSession.instance.setSession(
      token: 'token-a',
      profile: first.profile,
    );
    final events = <String>[];
    final controller = AccountSwitchController(
      store: store,
      unregisterCurrentPush: () async {
        events.add('unregister:${AppSession.instance.profile?.ref}');
      },
      syncCurrentPush: () async {
        events.add('sync:${AppSession.instance.profile?.ref}');
      },
      unlockAfterSwitch: () async {
        events.add('unlock:${AppSession.instance.profile?.ref}');
      },
    );

    final profile = await controller.switchTo(second.id);

    expect(profile.ref, 'worker-b');
    expect(store.activeAccountId, second.id);
    expect(AppSession.instance.token, 'token-b');
    expect(AppSession.instance.profile?.ref, 'worker-b');
    expect(events, [
      'unregister:worker-a',
      'unlock:worker-b',
      'sync:worker-b',
    ]);
  });

  test('missing secure session never changes the active account', () async {
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
    await AppSession.instance.setSession(
      token: 'token-a',
      profile: first.profile,
    );
    secrets.clear();
    final controller = AccountSwitchController(store: store);

    await expectLater(controller.switchTo(second.id), throwsStateError);

    expect(store.activeAccountId, first.id);
    expect(AppSession.instance.profile?.ref, 'worker-a');
  });

  test('adds an authenticated profile without discarding the current one',
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
    );
    await AppSession.instance.setSession(
      token: 'token-a',
      profile: first.profile,
    );
    final controller = AccountSwitchController(store: store);

    final profile = await controller.addAndSwitch(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-b', name: 'Akmal'),
      token: 'token-b',
      phone: '+998900000002',
      code: '402222',
    );

    expect(profile.ref, 'worker-b');
    expect(store.accounts, hasLength(2));
    expect(store.activeAccount?.profile.ref, 'worker-b');
    expect(AppSession.instance.profile?.ref, 'worker-b');
    expect(
      (await store.sessionFor(first.id))?.token,
      'token-a',
    );
  });

  test('logout removes only the active profile and clears its session',
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
    );
    final second = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-b', name: 'Akmal'),
      token: 'token-b',
      phone: '+998900000002',
      code: '402222',
      makeActive: false,
    );
    await AppSession.instance.setSession(
      token: 'token-a',
      profile: first.profile,
    );
    final events = <String>[];
    final controller = AccountSwitchController(
      store: store,
      unregisterCurrentPush: () async => events.add('unregister'),
      logoutSavedSession: (session) async {
        events.add('logout:${session.token}');
      },
      clearAfterLogout: () async => events.add('security-clear'),
    );

    await controller.logoutCurrent();

    expect(events, ['unregister', 'logout:token-a', 'security-clear']);
    expect(AppSession.instance.isLoggedIn, isFalse);
    expect(store.activeAccountId, isNull);
    expect(store.accounts.map((account) => account.id), [second.id]);
    expect(await store.sessionFor(first.id), isNull);
    expect((await store.sessionFor(second.id))?.token, 'token-b');
  });

  test('controllers sharing one store serialize account operations', () async {
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
    );
    final second = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-b', name: 'Akmal'),
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
    final firstController = AccountSwitchController(
      store: store,
      unregisterCurrentPush: () async {
        entered.complete();
        await release.future;
      },
    );
    final secondController = AccountSwitchController(store: store);

    final firstSwitch = firstController.switchTo(second.id);
    await entered.future;

    await expectLater(
      secondController.switchTo(second.id),
      throwsStateError,
    );

    release.complete();
    await firstSwitch;
    expect(store.activeAccountId, second.id);
  });

  test('failed session activation rolls store and AppSession back together',
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
    );
    final second = await store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: _profile(ref: 'worker-b', name: 'Akmal'),
      token: 'token-b',
      phone: '+998900000002',
      code: '402222',
      makeActive: false,
    );
    await AppSession.instance.setSession(
      token: 'token-a',
      profile: first.profile,
    );
    final controller = AccountSwitchController(
      store: store,
      activateSavedSession: (session, bootstrap) async {
        await AppSession.instance.setSession(
          token: session.token,
          profile: session.account.profile,
          werkaHomeBootstrap: bootstrap,
          forceResetSessionScopedState: true,
        );
        throw StateError('activation failed after mutating AppSession');
      },
    );

    await expectLater(controller.switchTo(second.id), throwsStateError);

    expect(store.activeAccountId, first.id);
    expect(AppSession.instance.token, 'token-a');
    expect(AppSession.instance.profile?.ref, 'worker-a');
  });

  test('logout clears AppSession even when account removal fails', () async {
    final preferences = await SharedPreferences.getInstance();
    final secrets = _MemoryAccountSecretStore(failDeletes: true);
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
    await AppSession.instance.setSession(
      token: 'token-a',
      profile: account.profile,
    );
    final controller = AccountSwitchController(store: store);

    await controller.logoutCurrent();

    expect(AppSession.instance.isLoggedIn, isFalse);
    expect(store.activeAccountId, isNull);
    expect(store.accounts, isEmpty);
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
  _MemoryAccountSecretStore({this.failDeletes = false});

  final Map<String, String> _values = <String, String>{};
  final bool failDeletes;

  void clear() => _values.clear();

  @override
  Future<void> delete(String key) async {
    if (failDeletes) {
      throw StateError('secure delete failed');
    }
    _values.remove(key);
  }

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
