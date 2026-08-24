part of '../mobile_api.dart';

enum MobileServerSwitchStatus {
  switched,
  alreadyActive,
  invalidEndpoint,
  unavailable,
  notMiniRsErp,
  credentialsNotFound,
}

class MobileServerSwitchResult {
  const MobileServerSwitchResult({
    required this.status,
    required this.baseUrl,
    this.version = '',
  });

  final MobileServerSwitchStatus status;
  final String baseUrl;
  final String version;
}

class MobileServerHandshake {
  const MobileServerHandshake({
    required this.service,
    required this.product,
    required this.apiContract,
    required this.version,
  });

  final String service;
  final String product;
  final String apiContract;
  final String version;

  bool get isMiniRsErp =>
      service == 'mini_rs_erp' &&
      product == 'mini_rs_erp' &&
      apiContract == 'v1';

  factory MobileServerHandshake.fromJson(Map<String, dynamic> json) {
    return MobileServerHandshake(
      service: json['service']?.toString().trim() ?? '',
      product: json['product']?.toString().trim() ?? '',
      apiContract: json['api_contract']?.toString().trim() ?? '',
      version: json['version']?.toString().trim() ?? '',
    );
  }
}

extension MobileApiServer on MobileApi {
  Future<MobileServerSwitchResult> switchServerEndpoint(String raw) async {
    final normalized = ServerEndpointStore.normalize(raw);
    if (normalized == null) {
      return const MobileServerSwitchResult(
        status: MobileServerSwitchStatus.invalidEndpoint,
        baseUrl: '',
      );
    }
    if (normalized == MobileApi.baseUrl) {
      return MobileServerSwitchResult(
        status: MobileServerSwitchStatus.alreadyActive,
        baseUrl: normalized,
      );
    }

    final handshake = await _probeServerEndpoint(normalized);
    if (handshake == null) {
      return MobileServerSwitchResult(
        status: MobileServerSwitchStatus.unavailable,
        baseUrl: normalized,
      );
    }
    if (!handshake.isMiniRsErp) {
      return MobileServerSwitchResult(
        status: MobileServerSwitchStatus.notMiniRsErp,
        baseUrl: normalized,
        version: handshake.version,
      );
    }

    String phone = '';
    String code = '';
    final savedAccounts = SavedAccountRuntime.instance;
    if (savedAccounts.isInitialized) {
      final activeId = savedAccounts.store.activeAccountId;
      final activeSession = activeId == null
          ? null
          : await savedAccounts.store.sessionFor(activeId);
      phone = activeSession?.phone ?? '';
      code = activeSession?.code ?? '';
    } else {
      final prefs = await SharedPreferences.getInstance();
      phone = prefs.getString(MobileApi._lastPhoneKey)?.trim() ?? '';
      code = prefs.getString(MobileApi._lastCodeKey)?.trim() ?? '';
    }
    if (phone.isEmpty || code.isEmpty) {
      return MobileServerSwitchResult(
        status: MobileServerSwitchStatus.credentialsNotFound,
        baseUrl: normalized,
        version: handshake.version,
      );
    }

    late final AuthenticatedMobileAccount loginResult;
    try {
      loginResult = await _loginAt(
        targetBaseUrl: normalized,
        phone: phone,
        code: code,
        directTransport: true,
      );
    } on _MobileLoginException catch (error) {
      return MobileServerSwitchResult(
        status: error.statusCode == 401 || error.statusCode == 403
            ? MobileServerSwitchStatus.credentialsNotFound
            : MobileServerSwitchStatus.unavailable,
        baseUrl: normalized,
        version: handshake.version,
      );
    } catch (_) {
      return MobileServerSwitchResult(
        status: MobileServerSwitchStatus.unavailable,
        baseUrl: normalized,
        version: handshake.version,
      );
    }

    if (AppSession.instance.can('admin.access') &&
        !loginResult.profile.hasCapability('admin.access')) {
      return MobileServerSwitchResult(
        status: MobileServerSwitchStatus.credentialsNotFound,
        baseUrl: normalized,
        version: handshake.version,
      );
    }

    await _activateLoggedInEndpoint(
      baseUrl: normalized,
      loginResult: loginResult,
      phone: phone,
      code: code,
    );
    return MobileServerSwitchResult(
      status: MobileServerSwitchStatus.switched,
      baseUrl: normalized,
      version: handshake.version,
    );
  }

  Future<void> confirmServerEndpointWithoutLogin(String raw) async {
    final normalized = ServerEndpointStore.normalize(raw);
    if (normalized == null) {
      throw const FormatException('Domen noto‘g‘ri kiritilgan');
    }
    await logout();
    await NativeIrohTransport.resetEndpoint();
    await ServerEndpointStore.instance.setBaseUrl(normalized);
  }

  Future<MobileServerHandshake?> _probeServerEndpoint(String baseUrl) async {
    try {
      final response = await _directGet(
        Uri.parse('$baseUrl/v1/mobile/server/handshake'),
      );
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return MobileServerHandshake.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _activateLoggedInEndpoint({
    required String baseUrl,
    required AuthenticatedMobileAccount loginResult,
    required String phone,
    required String code,
  }) async {
    final savedAccounts = SavedAccountRuntime.instance;
    if (savedAccounts.isInitialized) {
      await savedAccounts.store.runAccountOperation(
        () => _activateLoggedInEndpointUnlocked(
          baseUrl: baseUrl,
          loginResult: loginResult,
          phone: phone,
          code: code,
        ),
      );
      return;
    }
    await _activateLoggedInEndpointUnlocked(
      baseUrl: baseUrl,
      loginResult: loginResult,
      phone: phone,
      code: code,
    );
  }

  Future<void> _activateLoggedInEndpointUnlocked({
    required String baseUrl,
    required AuthenticatedMobileAccount loginResult,
    required String phone,
    required String code,
  }) async {
    final endpointStore = ServerEndpointStore.instance;
    final previousBaseUrl = endpointStore.baseUrl;
    final previousWasRuntimeOverride = endpointStore.isRuntimeOverride;
    final savedAccounts = SavedAccountRuntime.instance;
    final previousActiveId = savedAccounts.isInitialized
        ? savedAccounts.store.activeAccountId
        : null;
    final previousSession = AppSession.instance.snapshot();
    try {
      String? targetAccountId;
      if (savedAccounts.isInitialized) {
        final target = await savedAccounts.store.upsertAuthenticated(
          baseUrl: baseUrl,
          profile: loginResult.profile,
          token: loginResult.token,
          phone: phone,
          code: code,
          makeActive: false,
        );
        targetAccountId = target.id;
      }

      await NativeIrohTransport.resetEndpoint();
      await endpointStore.setBaseUrl(baseUrl);
      if (savedAccounts.isInitialized) {
        await savedAccounts.store.activate(targetAccountId!);
      } else {
        await _storeLoginCredentials(phone: phone, code: code);
      }
      await AppSession.instance.setSession(
        token: loginResult.token,
        profile: loginResult.profile,
        werkaHomeBootstrap: loginResult.werkaHome,
        forceResetSessionScopedState: true,
      );
    } catch (error, stackTrace) {
      final rollbackErrors = <Object>[];
      if (savedAccounts.isInitialized) {
        try {
          if (previousActiveId == null) {
            await savedAccounts.store.clearActive();
          } else if (savedAccounts.store.activeAccountId != previousActiveId) {
            await savedAccounts.store.activate(previousActiveId);
          }
        } catch (rollbackError) {
          rollbackErrors.add(rollbackError);
        }
      }
      try {
        await NativeIrohTransport.resetEndpoint();
        if (previousWasRuntimeOverride) {
          await endpointStore.setBaseUrl(previousBaseUrl);
        } else {
          await endpointStore.clearOverride();
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
            'Server endpoint switch failed and rollback was incomplete: '
            '$error; ${rollbackErrors.join('; ')}',
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
