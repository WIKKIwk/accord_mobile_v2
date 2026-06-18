import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_warehouses_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(true);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'catalog.item.read'],
    );
  });

  tearDown(() async {
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('admin warehouses page groups catalog items by warehouse', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
        home: const AdminWarehousesScreen(),
      ),
    );

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Tayyor mahsulot ombori - DEMO').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Ombor'), findsOneWidget);
    expect(find.text('Tayyor mahsulot ombori - DEMO'), findsOneWidget);
    expect(find.text('Hotlunch'), findsNothing);

    await tester.tap(find.text('Tayyor mahsulot ombori - DEMO'));
    await tester.pumpAndSettle();

    expect(find.text('Ombor ma’lumoti'), findsOneWidget);
    expect(find.text('Hotlunch'), findsOneWidget);
    expect(find.text('DEMO-HOTLUNCH'), findsNothing);
    expect(find.textContaining('DEMO-HOTLUNCH'), findsWidgets);
    expect(find.text('Demo ichimlik'), findsOneWidget);
    expect(find.textContaining('Dona'), findsWidgets);

    await tester.tap(find.text('Omborlar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xomashyo ombori - DEMO'));
    await tester.pumpAndSettle();

    expect(find.text('Mahsulotlar'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('Demo kraska'), findsOneWidget);
    expect(find.textContaining('DEMO-RAW-001'), findsWidgets);
    expect(find.textContaining('30AA'), findsWidgets);
  });

  testWidgets('admin warehouses page has list and create tabs with detail', (
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
        home: const AdminWarehousesScreen(),
      ),
    );

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Omborlar').evaluate().isNotEmpty) {
        break;
      }
    }

    expect(find.text('Omborlar'), findsOneWidget);
    expect(find.text('Ombor ma’lumoti'), findsOneWidget);
    expect(find.text('Ombor yaratish'), findsOneWidget);

    await tester.tap(find.text('Tayyor mahsulot ombori - DEMO'));
    await tester.pumpAndSettle();

    expect(find.text('Mahsulotlar'), findsOneWidget);
    expect(find.text('Band qilingan'), findsOneWidget);
    expect(find.text('Assign'), findsOneWidget);
    expect(find.text('yo‘q'), findsOneWidget);

    await tester.tap(find.text('Ombor yaratish'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Tanlash uchun bosing'), findsOneWidget);
    expect(find.text('Demo ta’minotchi'), findsNothing);

    await tester.tap(find.text('Tanlash uchun bosing'));
    await tester.pumpAndSettle();
    expect(find.text('Demo ta’minotchi'), findsOneWidget);

    await tester.tap(find.text('Demo ta’minotchi'));
    await tester.pumpAndSettle();
    expect(find.text('Demo ta’minotchi'), findsOneWidget);
    expect(find.text('Assign qilish'), findsOneWidget);
  });

  test('admin warehouse live url uses websocket scheme and session token', () {
    final uri = MobileApi.instance.adminWarehouseLiveUri();

    expect(uri.scheme, 'wss');
    expect(uri.path, '/v1/mobile/admin/warehouses/live');
    expect(uri.queryParameters['token'], 'token');
  });
}
