import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/admin_raw_material_assignment_screen.dart';
import 'package:accord_mobile_v2/src/features/gscale/presentation/gscale_mode_screen.dart';
import 'package:accord_mobile_v2/src/features/material_taminotchi/presentation/material_taminotchi_home_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/werka/presentation/widgets/m3_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('material taminotchi home exposes only action cards', (
    tester,
  ) async {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'MAT-001',
      phone: '+998901112233',
      avatarUrl: '',
      capabilities: [
        'gscale.catalog.read',
        'gscale.print',
        'rps.batch.manage',
        'catalog.item.create',
        'raw_material.assign',
        'inventory.movement.manage',
      ],
      assignedItemGroups: ['Rulon', 'Kley'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: AppRoutes.materialHome,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Material ta’minotchisi'), findsWidgets);
    expect(find.text('Kirim'), findsWidgets);
    expect(find.text('Homashyo biriktirish').first, findsOneWidget);
    expect(find.text('Joylashuvlarim'), findsNothing);
    expect(find.text('Joylashtirish va transfer').first, findsOneWidget);
    expect(find.text('Profil'), findsNothing);
    expect(find.text('Materialchi'), findsNothing);
    expect(find.text('Rulon'), findsNothing);
    expect(find.text('Kley'), findsNothing);
    expect(
      find.byKey(const ValueKey('material-raw-material-scan-fab')),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsLabel('Amallar'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-fab-menu-Kirim')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-fab-menu-QR skanerlash')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('admin-fab-menu-Homashyo biriktirish')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('admin-fab-menu-Joylashtirish va transfer'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('material scan fab opens scanner and forwards barcode', (
    tester,
  ) async {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'MAT-SCAN',
      phone: '+998901112266',
      avatarUrl: '',
      capabilities: ['raw_material.assign'],
      assignedItemGroups: ['Kraska'],
    );
    Object? assignmentArguments;

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        initialRoute: AppRoutes.materialHome,
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.materialHome) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const MaterialTaminotchiHomeScreen(),
            );
          }
          if (settings.name == AppRoutes.adminRawMaterialAssignments) {
            assignmentArguments = settings.arguments;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(
                body: Center(child: Text('Biriktirish destination')),
              ),
            );
          }
          return null;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Amallar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('admin-fab-menu-QR skanerlash')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Homashyo QR'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '30AA');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Biriktirish destination'), findsOneWidget);
    expect(assignmentArguments, isA<AdminRawMaterialAssignmentArgs>());
    expect(
      (assignmentArguments! as AdminRawMaterialAssignmentArgs).initialBarcode,
      '30AA',
    );
  });

  testWidgets('material taminotchi home explains missing item group scope', (
    tester,
  ) async {
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'MAT-002',
      phone: '+998901112244',
      avatarUrl: '',
      capabilities: [
        'gscale.catalog.read',
        'gscale.print',
        'rps.batch.manage',
        'catalog.item.create',
        'raw_material.assign',
      ],
      assignedItemGroups: [],
    );

    await tester.pumpWidget(
      const MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        onGenerateRoute: AppRouter.onGenerateRoute,
        initialRoute: AppRoutes.materialHome,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mahsulot guruhi biriktirilmagan'), findsOneWidget);

    await tester.tap(find.text('Homashyo biriktirish').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Avval material guruhlari biriktirilishi kerak'),
      findsOneWidget,
    );
    expect(find.text('Material ta’minotchisi'), findsWidgets);
  });

  testWidgets('material gscale mode shows print and print history tabs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'test_mode_enabled': true});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.materialTaminotchi,
      displayName: 'Materialchi',
      legalName: '',
      ref: 'MAT-003',
      phone: '+998901112255',
      avatarUrl: '',
      capabilities: [
        'gscale.catalog.read',
        'gscale.print',
        'rps.batch.manage',
        'catalog.item.create',
        'raw_material.assign',
      ],
      assignedItemGroups: ['Rulon'],
    );

    await tester.pumpWidget(
      const MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: GScaleModeScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Homashyo kirimi'), findsWidgets);
    expect(find.widgetWithText(Tab, 'Print'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Print tarixi'), findsOneWidget);
    expect(find.byKey(const ValueKey('control-section')), findsOneWidget);
    expect(find.text('Kirim'), findsOneWidget);
    expect(
      find.byTooltip('Printer yoki tarozi tanlash'),
      findsOneWidget,
    );
    expect(find.text('Mahsulot tanlang'), findsOneWidget);
    expect(find.text('Babina'), findsOneWidget);
    expect(find.text('Joriy kg'), findsNothing);
    expect(find.text('Boshqaruv'), findsNothing);
    expect(find.text('Arxiv'), findsNothing);
    expect(find.text('Server'), findsNothing);

    await tester.tap(find.text('Mahsulot tanlang'), warnIfMissed: false);
    await tester.pump();

    final picker = tester.widget<M3AsyncPickerSheet<SupplierItem>>(
      find.byType(M3AsyncPickerSheet<SupplierItem>),
    );
    expect(picker.pageSize, 50);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(Tab, 'Print tarixi'));
    await tester.pumpAndSettle();

    expect(
      find.text("Print tarixi hali bo'sh.").hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Qurilma tanlash'), findsNothing);
  });
}
