import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_home_screen.dart';
import 'package:accord_mobile_v2/src/features/qolip/state/qolip_data_revision.dart';
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
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      displayName: 'Qolipchi',
      legalName: 'Qolipchi',
      ref: 'QOLIPCHI-001',
      phone: '',
      avatarUrl: '',
    );
    final product = await MobileApi.instance.qolipSaveProductSpec(
      product: const QolipProduct(
        code: 'DEMO-HOTLUNCH',
        name: 'Hotlunch',
        itemGroup: 'Demo tayyor mahsulotlar',
      ),
      qolipCode: 'Q-DELETE-REFRESH',
      size: 40,
    );
    await MobileApi.instance.qolipSaveLocation(
      block: const QolipBlock(name: 'A', warehouse: 'Qolip ombori'),
      product: product,
      quantity: 1,
      rowLetter: 'A',
      columnNumber: 1,
    );
  });

  tearDown(() async {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
    await TestModeController.instance.setEnabled(false);
  });

  testWidgets('home reloads cached cells after product spec deletion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const QolipHomeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 ta joy band'), findsOneWidget);
    expect(find.text('1 ta qolip'), findsOneWidget);

    await MobileApi.instance.qolipDeleteProductSpecs(
      const ['Q-DELETE-REFRESH'],
    );
    QolipDataRevision.notifyLocationsChanged();
    await tester.pumpAndSettle();

    expect(find.text('0 ta joy band'), findsOneWidget);
    expect(find.text('0 ta qolip'), findsOneWidget);
    expect(find.textContaining('Hotlunch'), findsNothing);
  });
}
