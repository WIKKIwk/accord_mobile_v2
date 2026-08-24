import '../../../features/shared/models/app_models.dart';
import '../state/app_session.dart';
import 'saved_account_store.dart';

typedef AccountSwitchHook = Future<void> Function();
typedef SavedAccountSessionHook = Future<void> Function(
  SavedAccountSession session,
);
typedef SavedAccountActivationHook = Future<void> Function(
  SavedAccountSession session,
  WerkaHomeData? werkaHomeBootstrap,
);

class AccountSwitchController {
  AccountSwitchController({
    required SavedAccountStore store,
    AccountSwitchHook? unregisterCurrentPush,
    AccountSwitchHook? syncCurrentPush,
    AccountSwitchHook? unlockAfterSwitch,
    SavedAccountSessionHook? logoutSavedSession,
    AccountSwitchHook? clearAfterLogout,
    SavedAccountActivationHook? activateSavedSession,
  })  : _store = store,
        _unregisterCurrentPush = unregisterCurrentPush,
        _syncCurrentPush = syncCurrentPush,
        _unlockAfterSwitch = unlockAfterSwitch,
        _logoutSavedSession = logoutSavedSession,
        _clearAfterLogout = clearAfterLogout,
        _activateSavedSession = activateSavedSession;

  final SavedAccountStore _store;
  final AccountSwitchHook? _unregisterCurrentPush;
  final AccountSwitchHook? _syncCurrentPush;
  final AccountSwitchHook? _unlockAfterSwitch;
  final SavedAccountSessionHook? _logoutSavedSession;
  final AccountSwitchHook? _clearAfterLogout;
  final SavedAccountActivationHook? _activateSavedSession;

  bool get switching => _store.accountOperationInProgress;

  Future<SessionProfile> addAndSwitch({
    required String baseUrl,
    required SessionProfile profile,
    required String token,
    required String phone,
    required String code,
    WerkaHomeData? werkaHomeBootstrap,
  }) async {
    return _runExclusive(() async {
      final account = await _store.upsertAuthenticated(
        baseUrl: baseUrl,
        profile: profile,
        token: token,
        phone: phone,
        code: code,
        makeActive: false,
      );
      return _switchToUnlocked(
        account.id,
        werkaHomeBootstrap: werkaHomeBootstrap,
      );
    });
  }

  Future<SessionProfile> switchTo(String accountId) {
    return _runExclusive(
      () => _switchToUnlocked(accountId),
    );
  }

  Future<void> logoutCurrent() async {
    await _runExclusive(() async {
      Object? operationError;
      StackTrace? operationStackTrace;
      try {
        final accountId = _store.activeAccountId;
        final savedSession =
            accountId == null ? null : await _store.sessionFor(accountId);
        await _runBestEffort(_unregisterCurrentPush);
        if (savedSession != null) {
          await _runSessionBestEffort(_logoutSavedSession, savedSession);
        }
        if (accountId != null) {
          await _store.remove(accountId);
        }
      } catch (error, stackTrace) {
        operationError = error;
        operationStackTrace = stackTrace;
      }

      try {
        await AppSession.instance.clear();
      } catch (clearError, clearStackTrace) {
        if (operationError == null) {
          Error.throwWithStackTrace(clearError, clearStackTrace);
        }
        Error.throwWithStackTrace(
          StateError(
            'Logout failed and AppSession cleanup also failed: '
            '$operationError; $clearError',
          ),
          operationStackTrace!,
        );
      }
      await _runBestEffort(_clearAfterLogout);
      if (operationError != null) {
        Error.throwWithStackTrace(operationError, operationStackTrace!);
      }
    });
  }

  Future<SessionProfile> _switchToUnlocked(
    String accountId, {
    WerkaHomeData? werkaHomeBootstrap,
  }) async {
    final target = await _store.sessionFor(accountId);
    if (target == null) {
      throw StateError('Saved account session is unavailable');
    }
    final currentId = _store.activeAccountId;
    if (currentId == accountId &&
        AppSession.instance.isLoggedIn &&
        AppSession.instance.profile?.ref == target.account.profile.ref &&
        AppSession.instance.token == target.token) {
      return target.account.profile;
    }

    final previousSession = AppSession.instance.snapshot();
    try {
      await _runBestEffort(_unregisterCurrentPush);
      await _store.activate(accountId);
      final activation = _activateSavedSession;
      if (activation == null) {
        await AppSession.instance.setSession(
          token: target.token,
          profile: target.account.profile,
          werkaHomeBootstrap: werkaHomeBootstrap,
          forceResetSessionScopedState: true,
        );
      } else {
        await activation(target, werkaHomeBootstrap);
      }
      await _runBestEffort(_unlockAfterSwitch);
      await _runBestEffort(_syncCurrentPush);
      return target.account.profile;
    } catch (error, stackTrace) {
      final rollbackErrors = <Object>[];
      try {
        if (currentId == null) {
          await _store.clearActive();
        } else if (_store.activeAccountId != currentId) {
          await _store.activate(currentId);
        }
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      try {
        await AppSession.instance.restore(previousSession);
      } catch (rollbackError) {
        rollbackErrors.add(rollbackError);
      }
      if (rollbackErrors.isNotEmpty) {
        Error.throwWithStackTrace(
          StateError(
            'Account switch failed and rollback was incomplete: $error; '
            '${rollbackErrors.join('; ')}',
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<T> _runExclusive<T>(Future<T> Function() operation) async {
    return _store.runAccountOperation(operation);
  }

  Future<void> _runBestEffort(AccountSwitchHook? hook) async {
    if (hook == null) {
      return;
    }
    try {
      await hook();
    } on Object {
      // Push registration must not make a locally valid account unusable.
    }
  }

  Future<void> _runSessionBestEffort(
    SavedAccountSessionHook? hook,
    SavedAccountSession session,
  ) async {
    if (hook == null) {
      return;
    }
    try {
      await hook(session);
    } on Object {
      // Server logout failure must not keep an account on this device.
    }
  }
}
