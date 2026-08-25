import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/security/state/security_controller.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stores app-lock and profile-switch PINs independently per profile',
      () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final security = SecurityController.instance;
    await security.load();

    const saman = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Saman',
      legalName: 'Saman',
      ref: 'worker-saman',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
    );
    const akmal = SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Akmal',
      legalName: 'Akmal',
      ref: 'worker-akmal',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
    );
    const sardor = SessionProfile(
      role: UserRole.boyoqchi,
      displayName: 'Sardor',
      legalName: 'Sardor',
      ref: 'worker-sardor',
      phone: '',
      avatarUrl: '',
      capabilities: ['boyoqchi.access'],
    );

    await AppSession.instance.setSession(token: 'token-saman', profile: saman);
    await security.savePinForCurrentUser('1111');
    await security.saveSwitchPinForCurrentUser('2222');
    await AppSession.instance.setSession(token: 'token-akmal', profile: akmal);
    await security.saveSwitchPinForCurrentUser('3333');
    await AppSession.instance
        .setSession(token: 'token-sardor', profile: sardor);

    expect(security.hasPinForProfile(saman), isTrue);
    expect(security.hasPinForProfile(akmal), isFalse);
    expect(security.hasPinForProfile(sardor), isFalse);
    expect(security.hasSwitchPinForProfile(saman), isTrue);
    expect(security.hasSwitchPinForProfile(akmal), isTrue);
    expect(security.hasSwitchPinForProfile(sardor), isFalse);
    expect(await security.verifyPinForProfile(saman, '1111'), isTrue);
    expect(await security.verifyPinForProfile(saman, '2222'), isFalse);
    expect(await security.verifySwitchPinForProfile(saman, '2222'), isTrue);
    expect(await security.verifySwitchPinForProfile(saman, '1111'), isFalse);
    expect(await security.verifySwitchPinForProfile(akmal, '3333'), isTrue);
    expect(await security.verifySwitchPinForProfile(akmal, '2222'), isFalse);
    expect(AppSession.instance.profile?.ref, 'worker-sardor');

    await AppSession.instance.setSession(token: 'token-saman', profile: saman);
    await security.clearSwitchPinForCurrentUser();
    expect(security.hasSwitchPinForProfile(saman), isFalse);
    expect(security.hasPinForProfile(saman), isTrue);
    expect(await security.verifyPinForProfile(saman, '1111'), isTrue);

    await AppSession.instance.clear();
  });

  test('switch-only PIN never activates the app lifecycle lock', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final security = SecurityController.instance;
    await security.load();
    await security.clearForLogout();
    const profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Switch only',
      legalName: 'Switch only',
      ref: 'worker-switch-only',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
    );
    await AppSession.instance
        .setSession(token: 'token-switch', profile: profile);
    await security.saveSwitchPinForCurrentUser('4444');

    security.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect(security.privacyShieldVisible, isFalse);
    security.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(security.locked, isFalse);

    await AppSession.instance.clear();
  });

  test('logout clears only the current profile local security', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final security = SecurityController.instance;
    await security.load();
    const current = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Current worker',
      legalName: 'Current worker',
      ref: 'worker-logout-current',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
    );
    const other = SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Other worker',
      legalName: 'Other worker',
      ref: 'worker-logout-other',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
    );

    await AppSession.instance
        .setSession(token: 'token-current', profile: current);
    await security.savePinForCurrentUser('1111');
    await security.saveSwitchPinForCurrentUser('2222');
    await AppSession.instance.setSession(token: 'token-other', profile: other);
    await security.saveSwitchPinForCurrentUser('3333');
    await AppSession.instance
        .setSession(token: 'token-current', profile: current);

    await security.clearForLogout();

    expect(security.hasPinForProfile(current), isFalse);
    expect(security.hasSwitchPinForProfile(current), isFalse);
    expect(security.hasSwitchPinForProfile(other), isTrue);

    await AppSession.instance.clear();
  });

  test('switch PIN storage is isolated by server endpoint', () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final security = SecurityController.instance;
    final endpoints = ServerEndpointStore.instance;
    await security.load();
    await security.clearForLogout();
    addTearDown(() async {
      await AppSession.instance.clear();
      await endpoints.clearOverride();
    });
    const profile = SessionProfile(
      role: UserRole.aparatchi,
      displayName: 'Same worker',
      legalName: 'Same worker',
      ref: 'worker-same-ref',
      phone: '',
      avatarUrl: '',
      capabilities: ['apparatus.queue.read'],
    );
    await AppSession.instance.setSession(token: 'token-a', profile: profile);

    await endpoints.setBaseUrl('https://erp-a.example.com');
    await security.saveSwitchPinForCurrentUser('1357');
    expect(security.hasSwitchPinForCurrentUser, isTrue);

    await endpoints.setBaseUrl('https://erp-b.example.com');
    expect(security.hasSwitchPinForCurrentUser, isFalse);
    expect(await security.verifySwitchPinForProfile(profile, '1357'), isFalse);
    await security.saveSwitchPinForCurrentUser('2468');

    await endpoints.setBaseUrl('https://erp-a.example.com');
    expect(await security.verifySwitchPinForProfile(profile, '1357'), isTrue);
    expect(await security.verifySwitchPinForProfile(profile, '2468'), isFalse);
  });
}
