import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/core/theme/app_theme.dart';
import 'package:accord_mobile_v2/src/core/theme/theme_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_factory_locations_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    resetMobileApiFactoryLocationTestData();
    await TestModeController.instance.setEnabled(true);
  });

  tearDown(() async {
    resetMobileApiFactoryLocationTestData();
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('factory location parser accepts backend apparatus snapshots', () {
    const compactApparatus = {
      'id': 'apparatus:default:asset-007',
      'name': 'Laminatsiya 1',
      'source_revision': 4,
      'equipment_class_id': 'equipment-class:lamination',
      'physical_asset_id': 'physical-asset:lamination-1',
      'active': true,
    };

    expect(
      () => AdminApparatus.fromJson(compactApparatus),
      throwsFormatException,
    );

    final location = AdminFactoryLocation.fromJson(const {
      'id': 'state_lamination_1',
      'name': 'Laminatsiya 1',
      'active': true,
      'apparatus': [compactApparatus],
      'created_at_unix': 100,
      'updated_at_unix': 200,
    });

    expect(location.isApparatusState, isTrue);
    expect(location.apparatus.single.id, 'apparatus:default:asset-007');
    expect(location.apparatus.single.name, 'Laminatsiya 1');
    expect(location.apparatus.single.sourceRevision, 4);
    expect(location.apparatus.single.isActive, isTrue);
  });

  test('apparatus parser preserves backend catalog metadata', () {
    final item = AdminApparatus.fromJson(const {
      'apparatus_id': 'apparatus:default:rezka',
      'source_revision': 3,
      'source_aasx_sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'display': {'display_name': 'Rezka', 'catalog_order': 9},
      'execution_profile': {
        'operation': 'cut',
        'technology': 'slitting',
      },
    });

    expect(item.id, 'apparatus:default:rezka');
    expect(item.isDefault, isTrue);
    expect(item.sortOrder, 9);
  });

  test('apparatus replacement preserves state identity and name', () async {
    final created = await MobileApi.instance.adminCreateFactoryLocation(
      name: 'Bosma oldi',
      apparatusIds: const ['apparatus:default:bosma_7'],
    );

    final updated =
        await MobileApi.instance.adminReplaceFactoryLocationApparatus(
      id: created.id,
      apparatusIds: const ['apparatus:default:asset-007'],
    );

    expect(updated.id, created.id);
    expect(updated.name, created.name);
    expect(updated.isApparatusState, isTrue);
    expect(updated.apparatus.single.name, 'Laminatsiya 1');
  });

  test('ordinary state has no apparatus and duplicate name is rejected',
      () async {
    final created = await MobileApi.instance.adminCreateFactoryLocation(
      name: 'Vaqtinchalik qolip ombori',
    );

    expect(created.isApparatusState, isFalse);
    await expectLater(
      MobileApi.instance.adminCreateFactoryLocation(
        name: ' vaqtinchalik QOLIP ombori ',
      ),
      throwsA(
        isA<MobileApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          409,
        ),
      ),
    );
  });

  test('factory state route requires its dedicated capability', () {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.customer,
      displayName: 'State manager',
      legalName: '',
      ref: 'state-manager',
      phone: '',
      avatarUrl: '',
      capabilities: ['factory.location.manage'],
    );

    expect(AppSession.instance.homeRoute, AppRoutes.adminHome);
    expect(AppRouter.canOpenRoute(AppRoutes.adminFactoryLocations), isTrue);
    expect(AppRouter.canOpenRoute(AppRoutes.adminWarehouses), isFalse);
  });

  testWidgets('state editor selects apparatus from a bottom sheet', (
    tester,
  ) async {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.admin,
      displayName: 'Admin',
      legalName: '',
      ref: 'admin',
      phone: '',
      avatarUrl: '',
      capabilities: ['admin.access', 'factory.location.manage'],
    );
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
        home: const AdminFactoryLocationsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'State ochish'));
    await tester.pumpAndSettle();
    expect(find.text('Aparat ulanmagan — oddiy state'), findsOneWidget);
    expect(find.text('Default aparatlar'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Aparat ulash'));
    await tester.pumpAndSettle();
    expect(find.text('Default aparatlar'), findsOneWidget);
    await tester.tap(find.text('7 ta rangli bosma aparat'));
    await tester.scrollUntilVisible(
      find.text('Custom aparatlar'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Custom aparatlar'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, 'Tanlash (1)'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tanlash (1)'));
    await tester.pumpAndSettle();
    expect(find.text('7 ta rangli bosma aparat'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'State nomi'),
      'Bosma oldi',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Saqlash'));
    await tester.pumpAndSettle();

    expect(find.text('Bosma oldi'), findsOneWidget);
    expect(find.text('Aparat state'), findsOneWidget);
    expect(find.textContaining('state_'), findsOneWidget);
  });
}
