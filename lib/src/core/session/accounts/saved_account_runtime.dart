import 'platform_account_secret_store.dart';
import 'saved_account_store.dart';
import '../../network/server_endpoint_store.dart';
export 'saved_account_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAccountRuntime {
  SavedAccountRuntime._();

  static final SavedAccountRuntime instance = SavedAccountRuntime._();

  SavedAccountStore? _store;
  bool _hasInitializationFailure = false;

  bool get isInitialized => _store != null;
  bool get hasInitializationFailure => _hasInitializationFailure;

  SavedAccountStore get store {
    final current = _store;
    if (current == null) {
      throw StateError('Saved account runtime is not initialized');
    }
    return current;
  }

  Future<void> initialize({
    SharedPreferences? preferences,
    AccountSecretStore? secretStore,
    SavedAccountPersistenceHook? beforeMetadataPersist,
    required String baseUrl,
  }) async {
    _store = null;
    _hasInitializationFailure = false;
    try {
      final resolvedPreferences =
          preferences ?? await SharedPreferences.getInstance();
      final nextStore = SavedAccountStore(
        preferences: resolvedPreferences,
        secretStore:
            secretStore ?? createDefaultAccountSecretStore(resolvedPreferences),
        beforeMetadataPersist: beforeMetadataPersist,
      );
      await nextStore.load();
      await nextStore.migrateLegacySession(baseUrl: baseUrl);
      await _migrateProductionEndpoint(nextStore, baseUrl);
      _store = nextStore;
    } catch (_) {
      _hasInitializationFailure = true;
      rethrow;
    }
  }

  Future<void> _migrateProductionEndpoint(
    SavedAccountStore store,
    String baseUrl,
  ) async {
    const previous = 'https://mini-rs-erp-dev.wspace.sbs';
    const current = 'https://accord.confi.uz';
    final endpoint = ServerEndpointStore.normalize(baseUrl);
    if (ServerEndpointStore.normalize(ServerEndpointStore.compiledBaseUrl) !=
            current ||
        (endpoint != previous && endpoint != current)) {
      return;
    }

    final activeId = store.activeAccountId;
    String? replacementActiveId;
    for (final account in store.accountsForEndpoint(previous)) {
      final session = await store.sessionFor(account.id);
      if (session == null) {
        // Do not switch an active account whose credentials could not be read.
        if (account.id == activeId) return;
        continue;
      }
      final newId = SavedAccount.buildId(baseUrl: current, profile: account.profile);
      if (await store.sessionFor(newId) == null) {
        await store.upsertAuthenticated(
          baseUrl: current,
          profile: account.profile,
          token: session.token,
          phone: session.phone,
          code: session.code,
          makeActive: false,
          lastUsedAt: account.lastUsedAt,
        );
      }
      if (account.id == activeId) replacementActiveId = newId;
    }
    if (replacementActiveId != null) {
      await store.activate(replacementActiveId);
    }
    if (endpoint == previous) {
      await ServerEndpointStore.instance.setBaseUrl(current);
    }
  }
}
