import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_runtime.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_store.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/features/auth/presentation/account_switcher_sheet.dart';
import 'package:accord_mobile_v2/src/features/auth/presentation/login_screen.dart';
import 'package:accord_mobile_v2/src/features/auth/presentation/welcome_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('holding the top profile action opens account switcher',
      (tester) async {
    await _pumpProfileAction(tester);

    await tester.longPress(find.byType(AppShellProfileAction));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Profilni tanlang'), findsOneWidget);
    expect(find.text('Saman'), findsOneWidget);
  });

  testWidgets('account switcher sizes to one profile instead of fixed height',
      (tester) async {
    await _pumpProfileAction(tester);

    await tester.longPress(find.byType(AppShellProfileAction));
    await tester.pump(const Duration(milliseconds: 300));

    final viewportHeight = tester.getSize(find.byType(Navigator)).height;
    final sheetHeight =
        tester.getSize(find.byType(AccountSwitcherSheet)).height;
    expect(sheetHeight, lessThan(viewportHeight * 0.6));
  });

  testWidgets(
      'add profile login keeps ambient animation outside shell clipping',
      (tester) async {
    await _pumpProfileAction(tester);

    await tester.longPress(find.byType(AppShellProfileAction));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Profil qo‘shish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final login = tester.widget<LoginScreen>(find.byType(LoginScreen));
    expect(login.addAccountMode, isTrue);
    expect(login.useSharedBackground, isTrue);
    expect(find.byType(AuthAmbientOutlineBackground), findsOneWidget);
    final routeStack = find.byWidgetPredicate(
      (widget) =>
          widget is Stack &&
          widget.fit == StackFit.expand &&
          widget.children.length == 2 &&
          widget.children.first is DecoratedBox &&
          widget.children.last is LoginScreen,
    );
    expect(routeStack, findsOneWidget);
    expect(
      tester.getSize(find.byType(AuthAmbientOutlineBackground)),
      tester.getSize(routeStack),
    );
    expect(tester.getSize(routeStack), tester.getSize(find.byType(Navigator)));
    expect(
      find.ancestor(
        of: find.byType(AuthAmbientOutlineBackground),
        matching: find.byType(LoginScreen),
      ),
      findsNothing,
    );
  });
}

Future<void> _pumpProfileAction(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final preferences = await SharedPreferences.getInstance();
  await SavedAccountRuntime.instance.initialize(
    preferences: preferences,
    secretStore: _MemoryAccountSecretStore(),
    baseUrl: MobileApi.baseUrl,
  );
  const profile = SessionProfile(
    role: UserRole.aparatchi,
    displayName: 'Saman',
    legalName: 'Saman',
    ref: 'worker-saman',
    phone: '',
    avatarUrl: '',
    capabilities: ['apparatus.queue.read'],
  );
  await SavedAccountRuntime.instance.store.upsertAuthenticated(
    baseUrl: MobileApi.baseUrl,
    profile: profile,
    token: 'token-saman',
    phone: '+998900000001',
    code: '401111',
    makeActive: true,
  );
  await AppSession.instance.setSession(token: 'token-saman', profile: profile);
  addTearDown(AppSession.instance.clear);

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
      home: Scaffold(body: AppShellProfileAction()),
    ),
  );
  await tester.pump();
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
