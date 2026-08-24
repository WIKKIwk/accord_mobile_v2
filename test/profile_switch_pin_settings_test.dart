import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/security/state/security_controller.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'profile settings shows separate app-lock and switch PIN sections',
      (tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await AppSession.instance.setSession(
      token: 'token',
      profile: const SessionProfile(
        role: UserRole.aparatchi,
        displayName: 'Saman',
        legalName: 'Saman',
        ref: 'worker-settings-pin',
        phone: '',
        avatarUrl: '',
        capabilities: ['apparatus.queue.read'],
      ),
    );
    await SecurityController.instance.load();
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
        home: ProfileScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Ilova qulfi PIN-kodi'), findsOneWidget);
    expect(find.text('Profil almashtirish PIN-kodi'), findsOneWidget);
    expect(
      find.text('Faqat ushbu profilga o‘tilayotganda so‘raladi'),
      findsOneWidget,
    );
  });
}
