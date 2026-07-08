import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/features/gscale/presentation/gscale_mode_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

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
    expect(find.text('Tarozilar rejimi'), findsOneWidget);
    expect(find.text('Homashyo biriktirish'), findsOneWidget);
    expect(find.text('Omborlarim'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Materialchi'), findsNothing);
    expect(find.text('Rulon'), findsNothing);
    expect(find.text('Kley'), findsNothing);
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

    await tester.tap(find.text('Homashyo biriktirish'));
    await tester.pumpAndSettle();

    expect(
      find.text('Avval material guruhlari biriktirilishi kerak'),
      findsOneWidget,
    );
    expect(find.text('Material ta’minotchisi'), findsWidgets);
  });

  testWidgets('material gscale mode reuses material shell without gscale tabs',
      (
    tester,
  ) async {
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

    expect(find.text('Tarozilar rejimi'), findsWidgets);
    expect(find.byKey(const ValueKey('control-section')), findsOneWidget);
    expect(find.text('Tarozi'), findsOneWidget);
    expect(find.text('Qurilma tanlash'), findsOneWidget);
    expect(find.text('Mahsulot tanlang'), findsOneWidget);
    expect(find.text('Babina'), findsOneWidget);
    expect(find.text('Joriy kg'), findsNothing);
    expect(find.text('Boshqaruv'), findsNothing);
    expect(find.text('Arxiv'), findsNothing);
    expect(find.text('Server'), findsNothing);
  });
}
