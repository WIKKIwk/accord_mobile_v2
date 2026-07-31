part of '../mobile_api.dart';

extension MobileApiAuthProfile on MobileApi {
  String get baseUrl => MobileApi.baseUrl;

  Future<SessionProfile> login({
    required String phone,
    required String code,
  }) async {
    return _performLogin(phone: phone, code: code);
  }

  Future<SessionProfile> _performLogin({
    required String phone,
    required String code,
  }) async {
    final result = await _loginAt(
      targetBaseUrl: baseUrl,
      phone: phone,
      code: code,
    );
    await AppSession.instance.setSession(
      token: result.token,
      profile: result.profile,
      werkaHomeBootstrap: result.werkaHome,
    );
    await _storeLoginCredentials(phone: phone, code: code);
    return result.profile;
  }

  Future<_MobileLoginResult> _loginAt({
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

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final String token = json['token'] as String? ?? '';
    final profileJson = Map<String, dynamic>.from(
      json['profile'] as Map<String, dynamic>,
    );
    profileJson['capabilities'] = json['capabilities'] as List<dynamic>? ?? [];
    profileJson['assigned_apparatus'] =
        json['assigned_apparatus'] as List<dynamic>? ?? [];
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
    if (token.trim().isEmpty) {
      throw _MobileLoginException(response.statusCode);
    }
    return _MobileLoginResult(
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
    final String? token = AppSession.instance.token;
    if (token != null) {
      try {
        await PushMessagingService.instance.unregisterCurrentToken();
      } catch (_) {}
      try {
        await _post(
          Uri.parse('$baseUrl/v1/mobile/auth/logout'),
          headers: _headers(token),
        );
      } catch (_) {}
    }
    await AppSession.instance.clear();
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
    if (!json.containsKey('capabilities')) {
      json = Map<String, dynamic>.from(json);
      json['capabilities'] = AppSession.instance.profile?.capabilities ?? [];
    }
    if (!json.containsKey('assigned_apparatus')) {
      json = Map<String, dynamic>.from(json);
      json['assigned_apparatus'] =
          AppSession.instance.profile?.assignedApparatus ?? [];
    }
    if (!json.containsKey('assigned_item_groups')) {
      json = Map<String, dynamic>.from(json);
      json['assigned_item_groups'] =
          AppSession.instance.profile?.assignedItemGroups ?? [];
    }
    if (!json.containsKey('assigned_warehouses')) {
      json = Map<String, dynamic>.from(json);
      json['assigned_warehouses'] =
          AppSession.instance.profile?.assignedWarehouses ?? [];
    }
    return SessionProfile.fromJson(json);
  }
}

class _MobileLoginResult {
  const _MobileLoginResult({
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
