import 'package:accord_mobile_v2/src/core/security/state/security_controller.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('checks each saved profile against only its own optional PIN', () async {
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
    await AppSession.instance.setSession(token: 'token-akmal', profile: akmal);
    await security.savePinForCurrentUser('2222');
    await AppSession.instance
        .setSession(token: 'token-sardor', profile: sardor);

    expect(security.hasPinForProfile(saman), isTrue);
    expect(security.hasPinForProfile(akmal), isTrue);
    expect(security.hasPinForProfile(sardor), isFalse);
    expect(await security.verifyPinForProfile(saman, '1111'), isTrue);
    expect(await security.verifyPinForProfile(saman, '2222'), isFalse);
    expect(await security.verifyPinForProfile(akmal, '2222'), isTrue);
    expect(await security.verifyPinForProfile(akmal, '1111'), isFalse);
    expect(AppSession.instance.profile?.ref, 'worker-sardor');

    await AppSession.instance.clear();
  });
}
