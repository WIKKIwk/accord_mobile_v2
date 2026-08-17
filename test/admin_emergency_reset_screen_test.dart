import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_emergency_reset_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('emergency reset route is admin-only', () {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.supplier,
      displayName: 'Supplier',
      legalName: '',
      ref: 'supplier-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['supplier.access'],
    );
    expect(AppRouter.canOpenRoute(AppRoutes.adminEmergencyReset), isFalse);

    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access'],
    );
    expect(AppRouter.canOpenRoute(AppRoutes.adminEmergencyReset), isTrue);
  });

  testWidgets('shows reset scopes without an enabled backend action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminEmergencyResetScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Favqulodda reset'), findsOneWidget);
    expect(find.text('Training ma’lumotlari'), findsOneWidget);
    expect(find.text('Barcha orderlar'), findsOneWidget);
    expect(find.text('Backend ulanmagan'), findsWidgets);
    expect(find.text('Backend ulangan'), findsOneWidget);
    final orderAction = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Orderlarni tozalash'),
    );
    expect(orderAction.onPressed, isNotNull);
  });
}
