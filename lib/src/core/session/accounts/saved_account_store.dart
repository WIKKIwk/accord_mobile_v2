import 'dart:convert';

import '../../../features/shared/models/app_models.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'saved_account_store_SavedAccountStore_methods_01.dart';
part 'saved_account_store_declarations_part_01.dart';

class SavedAccountStore {
  SavedAccountStore({
    required SharedPreferences preferences,
    required AccountSecretStore secretStore,
    SavedAccountPersistenceHook? beforeMetadataPersist,
  })  : _preferences = preferences,
        _secretStore = secretStore,
        _beforeMetadataPersist = beforeMetadataPersist;

  static const String _accountsKey = 'saved_accounts_v1';
  static const String _activeAccountKey = 'saved_accounts_active_id_v1';
  static const String _pendingSecretDeletionsKey =
      'saved_account_pending_secret_deletions_v1';
  static const String _secretKeyPrefix = 'saved_account_secret_v1:';
  static const String _legacyTokenKey = 'app_session_token';
  static const String _legacyProfileKey = 'app_session_profile';
  static const String _legacyPhoneKey = 'last_login_phone';
  static const String _legacyCodeKey = 'last_login_code';

  final SharedPreferences _preferences;
  final AccountSecretStore _secretStore;
  final SavedAccountPersistenceHook? _beforeMetadataPersist;
  final Map<String, SavedAccount> _accounts = <String, SavedAccount>{};
  String? _activeAccountId;
  bool _accountOperationInProgress = false;

  List<SavedAccount> get accounts {
    final values = _accounts.values.toList(growable: false);
    values.sort((left, right) => right.lastUsedAt.compareTo(left.lastUsedAt));
    return values;
  }

  String? get activeAccountId => _activeAccountId;

  SavedAccount? get activeAccount {
    final id = _activeAccountId;
    return id == null ? null : _accounts[id];
  }

  bool get accountOperationInProgress => _accountOperationInProgress;

  Future<void> activate(String accountId, {DateTime? usedAt}) async {
    final account = _accounts[accountId];
    if (account == null) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'account does not exist',
      );
    }
    final previousActiveId = _activeAccountId;
    final nextAccount = SavedAccount(
      id: account.id,
      baseUrl: account.baseUrl,
      profile: account.profile,
      lastUsedAt: (usedAt ?? DateTime.now()).toUtc(),
    );
    _accounts[accountId] = nextAccount;
    _activeAccountId = accountId;
    try {
      await _persistMetadata();
    } catch (error, stackTrace) {
      _accounts[accountId] = account;
      _activeAccountId = previousActiveId;
      await _rollbackMetadataOrThrow(error, stackTrace);
    }
  }
}
