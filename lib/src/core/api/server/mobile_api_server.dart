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

    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(MobileApi._lastPhoneKey)?.trim() ?? '';
    final code = prefs.getString(MobileApi._lastCodeKey)?.trim() ?? '';
    if (phone.isEmpty || code.isEmpty) {
      return MobileServerSwitchResult(
        status: MobileServerSwitchStatus.credentialsNotFound,
        baseUrl: normalized,
        version: handshake.version,
      );
    }

    late final _MobileLoginResult loginResult;
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
    required _MobileLoginResult loginResult,
    required String phone,
    required String code,
  }) async {
    await NativeIrohTransport.resetEndpoint();
    await ServerEndpointStore.instance.setBaseUrl(baseUrl);
    await AppSession.instance.setSession(
      token: loginResult.token,
      profile: loginResult.profile,
      werkaHomeBootstrap: loginResult.werkaHome,
      forceResetSessionScopedState: true,
    );
    await _storeLoginCredentials(phone: phone, code: code);
  }
}
