import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/security/state/security_controller.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/pin_setup_entry_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/pin_setup_purpose.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switch PIN setup does not create an app-lock PIN',
      (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    const profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Saman',
      legalName: 'Saman',
      ref: 'worker-switch-setup',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
    );
    await AppSession.instance.setSession(token: 'token', profile: profile);
    await SecurityController.instance.load();

    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(AppSession.instance.clear);
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
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PinSetupEntryScreen(
                        purpose: PinSetupPurpose.profileSwitch,
                      ),
                    ),
                  );
                },
                child: const Text('Switch PIN ochish'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Switch PIN ochish'));
    await tester.pumpAndSettle();
    expect(find.text('Switch PIN kiriting'), findsOneWidget);
    await _enterPin(tester, '2468');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Switch PINni takrorlang'), findsOneWidget);
    await _enterPin(tester, '2468');
    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(SecurityController.instance.hasSwitchPinForProfile(profile), isTrue);
    expect(
      await SecurityController.instance.verifySwitchPinForProfile(
        profile,
        '2468',
      ),
      isTrue,
    );
    expect(SecurityController.instance.hasPinForProfile(profile), isFalse);
  });
}

Future<void> _enterPin(WidgetTester tester, String pin) async {
  for (final digit in pin.characters) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
}
