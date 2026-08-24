import 'platform_account_secret_store.dart';
import 'saved_account_store.dart';
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
    AccountSecretStore secretStore = const PlatformAccountSecretStore(),
    SavedAccountPersistenceHook? beforeMetadataPersist,
    required String baseUrl,
  }) async {
    _store = null;
    _hasInitializationFailure = false;
    try {
      final nextStore = SavedAccountStore(
        preferences: preferences ?? await SharedPreferences.getInstance(),
        secretStore: secretStore,
        beforeMetadataPersist: beforeMetadataPersist,
      );
      await nextStore.load();
      await nextStore.migrateLegacySession(baseUrl: baseUrl);
      _store = nextStore;
    } catch (_) {
      _hasInitializationFailure = true;
      rethrow;
    }
  }
}
