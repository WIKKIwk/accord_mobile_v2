part of '../mobile_api.dart';

extension MobileApiAuthProfile on MobileApi {
  String get baseUrl => MobileApi.baseUrl;

  Future<SessionProfile> login({
    required String phone,
    required String code,
  }) async {
    return _performLogin(phone: phone, code: code);
  }

  Future<AuthenticatedMobileAccount> authenticateAccount({
    required String phone,
    required String code,
  }) {
    return _loginAt(
      targetBaseUrl: baseUrl,
      phone: phone,
      code: code,
    );
  }

  Future<SessionProfile> _performLogin({
    required String phone,
    required String code,
  }) async {
    final result = await authenticateAccount(phone: phone, code: code);
    final savedAccounts = SavedAccountRuntime.instance;
    if (savedAccounts.isInitialized) {
      final store = savedAccounts.store;
      await store.runAccountOperation(() async {
        final previousActiveId = store.activeAccountId;
        final previousSession = AppSession.instance.snapshot();
        try {
          final account = await store.upsertAuthenticated(
            baseUrl: baseUrl,
            profile: result.profile,
            token: result.token,
            phone: phone,
            code: code,
            makeActive: false,
          );
          await store.activate(account.id);
          await AppSession.instance.setSession(
            token: result.token,
            profile: result.profile,
            werkaHomeBootstrap: result.werkaHome,
          );
        } catch (error, stackTrace) {
          final rollbackErrors = <Object>[];
          try {
            if (previousActiveId == null) {
              await store.clearActive();
            } else if (store.activeAccountId != previousActiveId) {
              await store.activate(previousActiveId);
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
                'Login failed and account rollback was incomplete: $error; '
                '${rollbackErrors.join('; ')}',
              ),
              stackTrace,
            );
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
      });
    } else {
      await _storeLoginCredentials(phone: phone, code: code);
      await AppSession.instance.setSession(
        token: result.token,
        profile: result.profile,
        werkaHomeBootstrap: result.werkaHome,
      );
    }
    return result.profile;
  }

  Future<AuthenticatedMobileAccount> _loginAt({
    required String targetBaseUrl,
    required String phone,
    required String code,
    bool directTransport = false,
  }) async {
    final uri = Uri.parse('$targetBaseUrl/v1/mobile/auth/login');
    final request = directTransport ? _directPost : _post;
    final http.Response response = await request(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code}),
    );

    if (response.statusCode != 200) {
      throw _MobileLoginException(response.statusCode);
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw _MobileLoginException(response.statusCode);
    }
    final json = Map<String, dynamic>.from(decoded);
    final rawToken = json['token'];
    if (rawToken is! String || rawToken.trim().isEmpty) {
      throw _MobileLoginException(response.statusCode);
    }
    final rawProfile = json['profile'];
    if (rawProfile is! Map) {
      throw _MobileLoginException(response.statusCode);
    }
    final String token = rawToken.trim();
    final profileJson = Map<String, dynamic>.from(rawProfile);
    profileJson['capabilities'] = json['capabilities'] as List<dynamic>? ?? [];
    profileJson['assigned_apparatus'] =
        json['assigned_apparatus'] as List<dynamic>? ?? [];
    profileJson['assigned_apparatus_labels'] =
        json['assigned_apparatus_labels'] as List<dynamic>? ?? [];
    profileJson['assigned_item_groups'] =
        json['assigned_item_groups'] as List<dynamic>? ?? [];
    final rawAssignedWarehouses = json['assigned_warehouses'];
    if (rawAssignedWarehouses is List<dynamic>) {
      profileJson['assigned_warehouses'] = rawAssignedWarehouses;
    } else {
      profileJson['assigned_warehouses'] ??= [];
    }
    final SessionProfile profile = SessionProfile.fromJson(profileJson);
    final WerkaHomeData? werkaHome = profile.role == UserRole.werka &&
            json['werka_home'] is Map<String, dynamic>
        ? WerkaHomeData.fromJson(json['werka_home'] as Map<String, dynamic>)
        : null;
    return AuthenticatedMobileAccount(
      token: token,
      profile: profile,
      werkaHome: werkaHome,
    );
  }

  Future<void> _storeLoginCredentials({
    required String phone,
    required String code,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(MobileApi._lastPhoneKey, phone);
    await prefs.setString(MobileApi._lastCodeKey, code);
  }

  Future<void> registerPushToken({
    required String tokenValue,
    required String platform,
  }) async {
    final trimmedToken = tokenValue.trim();
    final profile = AppSession.instance.profile;
    debugPrint(
      'push register request role=${profile?.role.name ?? 'none'} '
      'ref=${profile?.ref ?? ''} '
      'platform=${platform.trim()} '
      'token=${maskPushToken(trimmedToken)}',
    );
    final response = await _sendAuthorized(
      () => _post(
        Uri.parse('$baseUrl/v1/mobile/push/token'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'token': trimmedToken, 'platform': platform}),
      ),
    );
    debugPrint(
      'push register response status=${response.statusCode} '
      'token=${maskPushToken(trimmedToken)}',
    );
    if (response.statusCode != 200) {
      throw Exception('Push token register failed');
    }
  }

  Future<void> unregisterPushToken(String tokenValue) async {
    final token = AppSession.instance.token;
    if (token == null || token.isEmpty) {
      return;
    }
    debugPrint(
      'push unregister request token=${maskPushToken(tokenValue.trim())}',
    );
    await _delete(
      Uri.parse(
        '$baseUrl/v1/mobile/push/token',
      ).replace(queryParameters: {'token': tokenValue}),
      headers: _headers(token),
    );
  }

  Future<void> logout() async {
    final savedAccounts = SavedAccountRuntime.instance;
    if (savedAccounts.isInitialized) {
      final store = savedAccounts.store;
      await store.runAccountOperation(() async {
        try {
          final activeId = store.activeAccountId;
          final savedSession =
              activeId == null ? null : await store.sessionFor(activeId);
          if (AppSession.instance.token != null) {
            try {
              await PushMessagingService.instance.unregisterCurrentToken();
            } catch (_) {}
          }
          if (savedSession != null) {
            try {
              await logoutSavedSession(
                token: savedSession.token,
                baseUrl: savedSession.account.baseUrl,
              );
            } catch (_) {}
          }
          if (activeId != null) {
            await store.remove(activeId);
          }
        } finally {
          await AppSession.instance.clear();
        }
      });
      return;
    }
    final String? token = AppSession.instance.token;
    if (token != null) {
      try {
        await PushMessagingService.instance.unregisterCurrentToken();
      } catch (_) {}
      try {
        await logoutSavedSession(token: token, baseUrl: baseUrl);
      } catch (_) {}
    }
    await AppSession.instance.clear();
  }

  Future<void> logoutSavedSession({
    required String token,
    required String baseUrl,
  }) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      return;
    }
    await _post(
      Uri.parse('$baseUrl/v1/mobile/auth/logout'),
      headers: _headers(normalizedToken),
    );
  }

  Future<SessionProfile> profile() async {
    final http.Response response = await _sendAuthorized(
      () => _get(
        Uri.parse('$baseUrl/v1/mobile/profile'),
        headers: _headers(requireToken()),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Profile fetch failed');
    }
    final SessionProfile profile = _profilePreservingCapabilities(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await AppSession.instance.updateProfile(profile);
    return profile;
  }

  Future<SessionProfile> updateNickname(String nickname) async {
    final http.Response response = await _sendAuthorized(
      () => _put(
        Uri.parse('$baseUrl/v1/mobile/profile'),
        headers: _headers(requireToken())
          ..['Content-Type'] = 'application/json',
        body: jsonEncode({'nickname': nickname}),
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Nickname update failed');
    }
    final SessionProfile profile = _profilePreservingCapabilities(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await AppSession.instance.updateProfile(profile);
    return profile;
  }

  Future<SessionProfile> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final streamed = await _sendMultipartAuthorized(() {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/v1/mobile/profile/avatar'),
      );
      request.headers.addAll(_headers(requireToken()));
      request.files.add(
        http.MultipartFile.fromBytes('avatar', bytes, filename: filename),
      );
      return request.send();
    });
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Avatar upload failed');
    }
    final SessionProfile profile = _profilePreservingCapabilities(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await AppSession.instance.updateProfile(profile);
    return profile;
  }

  SessionProfile _profilePreservingCapabilities(Map<String, dynamic> json) {
    final profileJson = Map<String, dynamic>.from(json);
    profileJson['capabilities'] =
        json['capabilities'] is List ? json['capabilities'] : const <dynamic>[];
    profileJson['assigned_apparatus'] = json['assigned_apparatus'] is List
        ? json['assigned_apparatus']
        : const <dynamic>[];
    profileJson['assigned_item_groups'] = json['assigned_item_groups'] is List
        ? json['assigned_item_groups']
        : const <dynamic>[];
    profileJson['assigned_warehouses'] = json['assigned_warehouses'] is List
        ? json['assigned_warehouses']
        : const <dynamic>[];
    return SessionProfile.fromJson(profileJson);
  }
}

class AuthenticatedMobileAccount {
  const AuthenticatedMobileAccount({
    required this.token,
    required this.profile,
    required this.werkaHome,
  });

  final String token;
  final SessionProfile profile;
  final WerkaHomeData? werkaHome;
}

class _MobileLoginException implements Exception {
  const _MobileLoginException(this.statusCode);

  final int statusCode;
}
