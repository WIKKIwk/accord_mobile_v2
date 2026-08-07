import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/theme/theme_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_calculate_materials_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestModeController.instance.setEnabled(true);
    resetMobileApiCalculateTestModeData();
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

  testWidgets('shows and edits material density and microns', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppThemeVariant.kalmar),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AdminCalculateMaterialsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Xomashyo mikronlari'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('PET'), 200);
    expect(find.textContaining('1.4 g/cm³'), findsOneWidget);

    await tester.tap(find.text('PET'));
    await tester.pumpAndSettle();

    expect(find.text('Xomashyoni tahrirlash'), findsOneWidget);
    expect(find.text('Boshqa nomlari'), findsNothing);
    expect(find.widgetWithText(TextFormField, 'Mikron'), findsWidgets);
    final density = find.widgetWithText(TextFormField, 'Zichlik');
    await tester.enterText(density, '1.38');
    final save = find.widgetWithText(FilledButton, 'Saqlash');
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final materials = await MobileApi.instance.calculateMaterials();
    final pet = materials.firstWhere((item) => item.id == 'builtin-pet');
    expect(pet.densityGCm3, 1.38);
    expect(pet.variants.any((variant) => variant.micron == 12), isTrue);
  });
}
