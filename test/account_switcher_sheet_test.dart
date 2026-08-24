import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/accounts/saved_account_store.dart';
import 'package:accord_mobile_v2/src/features/auth/presentation/account_switcher_sheet.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unlocked profile switches directly and add action is exposed',
      (tester) async {
    final accounts = [
      _account(ref: 'worker-a', name: 'Saman', hour: 9),
      _account(ref: 'worker-b', name: 'Akmal', hour: 8),
    ];
    String? switchedId;
    var addTapped = false;

    await _pumpSheet(
      tester,
      AccountSwitcherSheet(
        accounts: accounts,
        activeAccountId: accounts.first.id,
        hasPinForProfile: (_) => false,
        verifyPinForProfile: (_, __) async => false,
        onSwitch: (account) async => switchedId = account.id,
        onAddAccount: () => addTapped = true,
      ),
    );

    expect(find.text('Profilni tanlang'), findsOneWidget);
    expect(find.text('Joriy'), findsOneWidget);
    await tester.tap(find.text('Profil qo‘shish'));
    expect(addTapped, isTrue);

    await tester.tap(find.text('Akmal'));
    await tester.pump();
    expect(switchedId, accounts.last.id);
  });

  testWidgets('locked profile verifies its own PIN before switching',
      (tester) async {
    final accounts = [
      _account(ref: 'worker-a', name: 'Saman', hour: 9),
      _account(ref: 'worker-b', name: 'Akmal', hour: 8),
    ];
    SavedAccount? verifiedAccount;
    String? verifiedPin;
    SavedAccount? switchedAccount;

    await _pumpSheet(
      tester,
      AccountSwitcherSheet(
        accounts: accounts,
        activeAccountId: accounts.first.id,
        hasPinForProfile: (profile) => profile.ref == 'worker-b',
        verifyPinForProfile: (profile, pin) async {
          verifiedAccount = accounts.last;
          verifiedPin = pin;
          return pin == '1234' && profile.ref == 'worker-b';
        },
        onSwitch: (account) async => switchedAccount = account,
        onAddAccount: () {},
      ),
    );

    await tester.tap(find.text('Akmal'));
    await tester.pumpAndSettle();

    expect(switchedAccount, isNull);
    expect(find.text('Akmal uchun PIN kiriting'), findsOneWidget);
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.text(digit));
      await tester.pump();
    }
    await tester.tap(find.byIcon(Icons.lock_open_rounded));
    await tester.pumpAndSettle();

    expect(verifiedAccount?.id, accounts.last.id);
    expect(verifiedPin, '1234');
    expect(switchedAccount?.id, accounts.last.id);
    await tester.pump(const Duration(seconds: 2));
  });
}

Future<void> _pumpSheet(WidgetTester tester, Widget child) async {
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
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

SavedAccount _account({
  required String ref,
  required String name,
  required int hour,
}) {
  final profile = SessionProfile(
    role: UserRole.aparatchi,
    displayName: name,
    legalName: name,
    ref: ref,
    phone: '',
    avatarUrl: '',
    capabilities: const ['apparatus.queue.read'],
  );
  const baseUrl = 'https://erp.example.com';
  return SavedAccount(
    id: SavedAccount.buildId(baseUrl: baseUrl, profile: profile),
    baseUrl: SavedAccount.normalizeBaseUrl(baseUrl),
    profile: profile,
    lastUsedAt: DateTime.utc(2026, 8, 24, hour),
  );
}
