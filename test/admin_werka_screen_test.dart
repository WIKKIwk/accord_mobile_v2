import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_werka_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: 'Admin',
      ref: 'ADMIN-001',
      phone: '',
      avatarUrl: '',
    );
  });

  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('admin werka screen uses profile standard', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminWerkaScreen()),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Omborchi profili'), findsOneWidget);
    expect(find.text('Admin boshqaruv'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('admin-werka-detail-admin-toggle')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Admin boshqaruv'), findsOneWidget);
    expect(find.text('Nomi'), findsOneWidget);
    expect(find.text('Telefon'), findsOneWidget);
    expect(find.text('Kirish kodi'), findsOneWidget);
  });
}
