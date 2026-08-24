import 'dart:convert';

import '../../../features/shared/models/app_models.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AccountSecretStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

typedef SavedAccountPersistenceHook = Future<void> Function();

class SavedAccount {
  const SavedAccount({
    required this.id,
    required this.baseUrl,
    required this.profile,
    required this.lastUsedAt,
  });

  final String id;
  final String baseUrl;
  final SessionProfile profile;
  final DateTime lastUsedAt;

  static String buildId({
    required String baseUrl,
    required SessionProfile profile,
  }) {
    return '${normalizeBaseUrl(baseUrl)}|${userRoleToJson(profile.role)}|${profile.ref.trim()}';
  }

  static String normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.trim().isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FormatException(
        'Saved account endpoint must be an http(s) origin',
      );
    }
    return Uri(
      scheme: uri.scheme.toLowerCase(),
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'base_url': baseUrl,
      'profile': profile.toJson(),
      'last_used_at': lastUsedAt.toUtc().toIso8601String(),
    };
  }

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    if (profileJson is! Map) {
      throw const FormatException('Saved account profile is missing');
    }
    final profile = SessionProfile.fromJson(
      Map<String, dynamic>.from(profileJson),
    );
    if (profile.ref.trim().isEmpty) {
      throw const FormatException('Saved account profile ref is missing');
    }
    final baseUrl = normalizeBaseUrl(json['base_url']?.toString() ?? '');
    final canonicalId = buildId(baseUrl: baseUrl, profile: profile);
    final storedId = json['id']?.toString().trim() ?? '';
    if (storedId.isNotEmpty && storedId != canonicalId) {
      throw const FormatException('Saved account id is not canonical');
    }
    return SavedAccount(
      id: canonicalId,
      baseUrl: baseUrl,
      profile: profile,
      lastUsedAt:
          DateTime.parse(json['last_used_at']?.toString() ?? '').toUtc(),
    );
  }
}

class SavedAccountSession {
  const SavedAccountSession({
    required this.account,
    required this.token,
    required this.phone,
    required this.code,
  });

  final SavedAccount account;
  final String token;
  final String phone;
  final String code;
}

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

  Future<T> runAccountOperation<T>(Future<T> Function() operation) async {
    if (_accountOperationInProgress) {
      throw StateError('An account operation is already in progress');
    }
    _accountOperationInProgress = true;
    try {
      return await operation();
    } finally {
      _accountOperationInProgress = false;
    }
  }

  Future<void> load() async {
    _accounts.clear();
    final encoded = _preferences.getString(_accountsKey);
    if (encoded != null && encoded.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is List) {
          for (final raw in decoded) {
            if (raw is! Map) {
              continue;
            }
            try {
              final account = SavedAccount.fromJson(
                Map<String, dynamic>.from(raw),
              );
              _accounts[account.id] = account;
            } on Object {
              // Skip only the malformed account; keep every valid account.
            }
          }
        }
      } on Object {
        // A malformed metadata payload must not prevent the app from starting.
      }
    }
    final storedActiveId =
        _preferences.getString(_activeAccountKey)?.trim() ?? '';
    _activeAccountId =
        _accounts.containsKey(storedActiveId) ? storedActiveId : null;
    await _retryPendingSecretDeletions();
  }

  List<SavedAccount> accountsForEndpoint(String baseUrl) {
    final normalized = SavedAccount.normalizeBaseUrl(baseUrl);
    return accounts
        .where((account) => account.baseUrl == normalized)
        .toList(growable: false);
  }

  Future<SavedAccount> upsertAuthenticated({
    required String baseUrl,
    required SessionProfile profile,
    required String token,
    required String phone,
    required String code,
    required bool makeActive,
    DateTime? lastUsedAt,
  }) async {
    final normalizedBaseUrl = SavedAccount.normalizeBaseUrl(baseUrl);
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw ArgumentError.value(token, 'token', 'must not be empty');
    }
    if (profile.ref.trim().isEmpty) {
      throw ArgumentError.value(
        profile.ref,
        'profile.ref',
        'must not be empty',
      );
    }
    final id = SavedAccount.buildId(
      baseUrl: normalizedBaseUrl,
      profile: profile,
    );
    final account = SavedAccount(
      id: id,
      baseUrl: normalizedBaseUrl,
      profile: profile,
      lastUsedAt: (lastUsedAt ?? DateTime.now()).toUtc(),
    );
    final secretKey = _secretKey(id);
    final previousSecret = await _secretStore.read(secretKey);
    final previousAccount = _accounts[id];
    final previousActiveId = _activeAccountId;
    await _secretStore.write(
      secretKey,
      jsonEncode(<String, String>{
        'token': normalizedToken,
        'phone': phone.trim(),
        'code': code.trim(),
      }),
    );
    _accounts[id] = account;
    if (makeActive) {
      _activeAccountId = id;
    }
    try {
      await _persistMetadata();
    } catch (error, stackTrace) {
      if (previousAccount == null) {
        _accounts.remove(id);
      } else {
        _accounts[id] = previousAccount;
      }
      _activeAccountId = previousActiveId;
      final rollbackErrors = <Object>[];
      try {
        await _persistMetadata();
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      try {
        if (previousSecret == null) {
          await _secretStore.delete(secretKey);
        } else {
          await _secretStore.write(secretKey, previousSecret);
        }
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      if (rollbackErrors.isNotEmpty) {
        Error.throwWithStackTrace(
          StateError(
            'Saved account upsert failed and rollback was incomplete: '
            '$error; ${rollbackErrors.join('; ')}',
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    return account;
  }

  Future<bool> migrateLegacySession({required String baseUrl}) async {
    final token = _preferences.getString(_legacyTokenKey)?.trim() ?? '';
    final encodedProfile =
        _preferences.getString(_legacyProfileKey)?.trim() ?? '';
    if (token.isEmpty || encodedProfile.isEmpty) {
      return false;
    }
    late final SessionProfile profile;
    try {
      final decodedProfile = jsonDecode(encodedProfile);
      if (decodedProfile is! Map) {
        return false;
      }
      profile = SessionProfile.fromJson(
        Map<String, dynamic>.from(decodedProfile),
      );
      if (profile.ref.trim().isEmpty) {
        return false;
      }
    } on Object {
      return false;
    }
    await upsertAuthenticated(
      baseUrl: baseUrl,
      profile: profile,
      token: token,
      phone: _preferences.getString(_legacyPhoneKey)?.trim().isNotEmpty == true
          ? _preferences.getString(_legacyPhoneKey)!.trim()
          : profile.phone.trim(),
      code: _preferences.getString(_legacyCodeKey)?.trim() ?? '',
      makeActive: true,
    );
    await _preferences.remove(_legacyPhoneKey);
    await _preferences.remove(_legacyCodeKey);
    return true;
  }

  Future<SavedAccountSession?> sessionFor(String accountId) async {
    final account = _accounts[accountId];
    if (account == null) {
      return null;
    }
    final encoded = await _secretStore.read(_secretKey(accountId));
    if (encoded == null || encoded.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return null;
      }
      final token = decoded['token']?.toString().trim() ?? '';
      if (token.isEmpty) {
        return null;
      }
      return SavedAccountSession(
        account: account,
        token: token,
        phone: decoded['phone']?.toString().trim() ?? '',
        code: decoded['code']?.toString().trim() ?? '',
      );
    } on Object {
      return null;
    }
  }

  Future<void> setActive(String accountId) async {
    await activate(accountId);
  }

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

  Future<void> clearActive() async {
    final previousActiveId = _activeAccountId;
    if (previousActiveId == null) {
      return;
    }
    _activeAccountId = null;
    try {
      await _persistMetadata();
    } catch (error, stackTrace) {
      _activeAccountId = previousActiveId;
      await _rollbackMetadataOrThrow(error, stackTrace);
    }
  }

  Future<void> updateProfile(
    String accountId,
    SessionProfile profile,
  ) async {
    final account = _accounts[accountId];
    if (account == null) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'account does not exist',
      );
    }
    final nextId = SavedAccount.buildId(
      baseUrl: account.baseUrl,
      profile: profile,
    );
    if (nextId != accountId) {
      throw ArgumentError.value(
        profile.ref,
        'profile.ref',
        'must preserve the saved account identity',
      );
    }
    final nextAccount = SavedAccount(
      id: account.id,
      baseUrl: account.baseUrl,
      profile: profile,
      lastUsedAt: account.lastUsedAt,
    );
    _accounts[accountId] = nextAccount;
    try {
      await _persistMetadata();
    } catch (error, stackTrace) {
      _accounts[accountId] = account;
      await _rollbackMetadataOrThrow(error, stackTrace);
    }
  }

  Future<void> remove(String accountId) async {
    final account = _accounts[accountId];
    if (account == null) {
      return;
    }
    final previousActiveId = _activeAccountId;
    final secretKey = _secretKey(accountId);
    _accounts.remove(accountId);
    if (_activeAccountId == accountId) {
      _activeAccountId = null;
    }
    try {
      await _persistMetadata();
    } catch (error, stackTrace) {
      _accounts[accountId] = account;
      _activeAccountId = previousActiveId;
      final rollbackErrors = <Object>[];
      try {
        await _persistMetadata();
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      try {
        await _secretStore.delete(secretKey);
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      if (rollbackErrors.isNotEmpty) {
        Error.throwWithStackTrace(
          StateError(
            'Saved account removal failed and cleanup was incomplete: '
            '$error; ${rollbackErrors.join('; ')}',
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    try {
      await _secretStore.delete(secretKey);
    } on Object {
      try {
        await _queuePendingSecretDeletion(accountId, secretKey);
      } on Object {
        // Metadata is already disconnected, so the orphaned encrypted secret
        // cannot restore or expose an account even if tombstoning also fails.
      }
    }
  }

  Future<void> _rollbackMetadataOrThrow(
    Object originalError,
    StackTrace originalStackTrace,
  ) async {
    try {
      await _persistMetadata();
    } catch (rollbackError) {
      Error.throwWithStackTrace(
        StateError(
          'Saved account metadata rollback failed after $originalError: '
          '$rollbackError',
        ),
        originalStackTrace,
      );
    }
    Error.throwWithStackTrace(originalError, originalStackTrace);
  }

  Future<void> _queuePendingSecretDeletion(
    String accountId,
    String secretKey,
  ) async {
    final pending = _readPendingSecretDeletions();
    pending[accountId] = secretKey;
    await _persistPendingSecretDeletions(pending);
  }

  Future<void> _retryPendingSecretDeletions() async {
    final pending = _readPendingSecretDeletions();
    if (pending.isEmpty) {
      return;
    }
    var changed = false;
    for (final entry in pending.entries.toList(growable: false)) {
      if (_accounts.containsKey(entry.key)) {
        continue;
      }
      try {
        await _secretStore.delete(entry.value);
        pending.remove(entry.key);
        changed = true;
      } on Object {
        // Keep the tombstone for a later retry.
      }
    }
    if (changed) {
      await _persistPendingSecretDeletions(pending);
    }
  }

  Map<String, String> _readPendingSecretDeletions() {
    final encoded = _preferences.getString(_pendingSecretDeletionsKey);
    if (encoded == null || encoded.trim().isEmpty) {
      return <String, String>{};
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return <String, String>{};
      }
      return <String, String>{
        for (final entry in decoded.entries)
          if (entry.key.toString().trim().isNotEmpty &&
              entry.value.toString().trim().isNotEmpty)
            entry.key.toString(): entry.value.toString(),
      };
    } on Object {
      return <String, String>{};
    }
  }

  Future<void> _persistPendingSecretDeletions(
    Map<String, String> pending,
  ) async {
    if (pending.isEmpty) {
      await _preferences.remove(_pendingSecretDeletionsKey);
      return;
    }
    await _preferences.setString(
      _pendingSecretDeletionsKey,
      jsonEncode(pending),
    );
  }

  Future<void> _persistMetadata() async {
    await _beforeMetadataPersist?.call();
    await _preferences.setString(
      _accountsKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
    final activeId = _activeAccountId;
    if (activeId == null) {
      await _preferences.remove(_activeAccountKey);
    } else {
      await _preferences.setString(_activeAccountKey, activeId);
    }
  }

  String _secretKey(String accountId) {
    final digest = sha256.convert(utf8.encode(accountId)).toString();
    return '$_secretKeyPrefix$digest';
  }
}
