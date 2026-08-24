import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_runtime.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_store.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/auth/presentation/app_entry_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('logged-out app offers remaining saved profiles', (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    await SavedAccountRuntime.instance.initialize(
      preferences: preferences,
      secretStore: _MemoryAccountSecretStore(),
      baseUrl: MobileApi.baseUrl,
    );
    await SavedAccountRuntime.instance.store.upsertAuthenticated(
      baseUrl: MobileApi.baseUrl,
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Akmal',
        legalName: 'Akmal',
        ref: 'worker-akmal',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read'],
      ),
      token: 'token-akmal',
      phone: '+998900000002',
      code: '402222',
      makeActive: false,
    );
    await AppSession.instance.clear();

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('uz'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppEntryScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Profilni tanlang'), findsOneWidget);
    expect(find.text('Akmal'), findsOneWidget);
    expect(find.text('Profil qo‘shish'), findsOneWidget);
  });
}

class _MemoryAccountSecretStore implements AccountSecretStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}
