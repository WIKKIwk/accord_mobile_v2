import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/security/state/security_controller.dart';
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

  testWidgets('app-lock PIN does not protect profile switching',
      (tester) async {
    const profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'App lock only',
      legalName: 'App lock only',
      ref: 'worker-app-lock-only',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
    );
    await _prepareSavedAccount(profile);
    await SecurityController.instance.load();
    await AppSession.instance.setSession(token: 'token', profile: profile);
    await SecurityController.instance.savePinForCurrentUser('1111');
    await AppSession.instance.clear();

    await _pumpEntry(tester);
    await tester.tap(find.text('App lock only'));
    await tester.pumpAndSettle();

    expect(find.text('switched-profile'), findsOneWidget);
  });

  testWidgets('profile-switch PIN protects profile switching', (tester) async {
    const profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Switch protected',
      legalName: 'Switch protected',
      ref: 'worker-switch-protected',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
    );
    await _prepareSavedAccount(profile);
    await SecurityController.instance.load();
    await AppSession.instance.setSession(token: 'token', profile: profile);
    await SecurityController.instance.saveSwitchPinForCurrentUser('2222');
    await AppSession.instance.clear();

    await _pumpEntry(tester);
    await tester.tap(find.text('Switch protected'));
    await tester.pumpAndSettle();

    expect(find.text('Switch protected uchun PIN kiriting'), findsOneWidget);
    expect(find.text('switched-profile'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });
}

Future<void> _prepareSavedAccount(SessionProfile profile) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final preferences = await SharedPreferences.getInstance();
  await SavedAccountRuntime.instance.initialize(
    preferences: preferences,
    secretStore: _MemoryAccountSecretStore(),
    baseUrl: MobileApi.baseUrl,
  );
  await SavedAccountRuntime.instance.store.upsertAuthenticated(
    baseUrl: MobileApi.baseUrl,
    profile: profile,
    token: 'saved-token',
    phone: '+998900000002',
    code: '402222',
    makeActive: false,
  );
  await AppSession.instance.clear();
}

Future<void> _pumpEntry(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('switched-profile')),
      ),
      home: const AppEntryScreen(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
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
