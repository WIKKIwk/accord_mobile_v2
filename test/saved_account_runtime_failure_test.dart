import 'dart:convert';

import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_runtime.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_store.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('default storage persists accounts when no native channel exists',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    await SavedAccountRuntime.instance.initialize(
      preferences: preferences,
      baseUrl: 'https://erp.example.com',
    );
    final account =
        await SavedAccountRuntime.instance.store.upsertAuthenticated(
      baseUrl: 'https://erp.example.com',
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Saman',
        legalName: 'Saman',
        ref: 'worker-saman',
        phone: '+998900000001',
        avatarUrl: '',
      ),
      token: 'web-token',
      phone: '+998900000001',
      code: '401111',
      makeActive: true,
    );

    await SavedAccountRuntime.instance.initialize(
      preferences: preferences,
      baseUrl: 'https://erp.example.com',
    );

    final restored =
        await SavedAccountRuntime.instance.store.sessionFor(account.id);
    expect(restored?.token, 'web-token');
    expect(restored?.code, '401111');
  });

  test('secure migration failure leaves legacy data but fails closed',
      () async {
    const profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Saman',
      legalName: 'Saman',
      ref: 'worker-saman',
      phone: '+998900000001',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
    );
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_session_token': 'legacy-token',
      'app_session_profile': jsonEncode(profile.toJson()),
      'last_login_phone': '+998900000001',
      'last_login_code': '401111',
    });
    final preferences = await SharedPreferences.getInstance();

    await expectLater(
      SavedAccountRuntime.instance.initialize(
        preferences: preferences,
        secretStore: _FailingSecretStore(),
        baseUrl: 'https://erp.example.com',
      ),
      throwsStateError,
    );

    expect(SavedAccountRuntime.instance.isInitialized, isFalse);
    expect(SavedAccountRuntime.instance.hasInitializationFailure, isTrue);

    await AppSession.instance.load();

    expect(AppSession.instance.isLoggedIn, isFalse);
    expect(preferences.getString('app_session_token'), 'legacy-token');
    expect(preferences.getString('last_login_code'), '401111');
  });
}

class _FailingSecretStore implements AccountSecretStore {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {
    throw StateError('secure storage unavailable');
  }
}
