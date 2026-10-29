import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/navigation/app_root_navigation.dart';
import 'package:accord_mobile_v2/src/core/session/state/app_session.dart';
import 'package:accord_mobile_v2/src/core/test_mode/test_mode_controller.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_create_hub_sheet.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_navigation.dart';
import 'package:accord_mobile_v2/src/features/preparation/presentation/preparation_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:accord_mobile_v2/src/features/shared/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TestModeController.instance.setEnabled(false);
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.tayyorlovMasteri,
      displayName: 'Ibrohim',
      legalName: 'Ibrohim',
      ref: 'prep-1',
      phone: '',
      avatarUrl: '',
      capabilities: ['preparation.access'],
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('preparation dock selects the current home, profile and chat',
      (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('uz'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: AppRoutes.preparation,
        navigatorObservers: [AppRootNavigation.navigatorObserver],
        routes: {
          '/': (_) => const SizedBox.shrink(),
          AppRoutes.preparation: (_) => const PreparationScreen(),
          AppRoutes.profile: (_) => const ProfileScreen(),
          AppRoutes.chat: (_) => const Scaffold(
                body: Text('Chat sahifasi'),
                bottomNavigationBar: PreparationDock(),
              ),
        },
      ));
      await tester.pumpAndSettle();

      int selectedIndex() =>
          tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;
      Future<void> tapTab(String label) async {
        await tester.tap(find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ));
        await tester.pumpAndSettle();
      }

      expect(selectedIndex(), 0);
      await tapTab('Profil');
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(selectedIndex(), 1);
      await tapTab('Chat');
      expect(find.text('Chat sahifasi'), findsOneWidget);
      expect(selectedIndex(), 2);
      await tapTab('Profil');
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(selectedIndex(), 1);
      await tapTab('Tayyorlov');
      expect(find.byType(PreparationScreen), findsOneWidget);
      expect(selectedIndex(), 0);
      expect(tester.takeException(), isNull);
    }, () => MockClient((request) async {
          expect(request.url.path, '/v1/mobile/preparation/snapshot');
          return http.Response(
            jsonEncode({
              'warehouses': ['Ombor'],
              'assigned_warehouses': ['Ombor'],
              'material_warehouses': ['Ombor'],
              'materials': [],
              'orders': [],
              'history': [],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }));
  });

  testWidgets('profile remains selected when the primary action is present',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        bottomNavigationBar: PreparationDock(
          profile: true,
          primaryFabActions: [
            AdminFabMenuAction(
              title: 'Amal',
              icon: Icons.add,
              onTap: () {},
            ),
          ],
        ),
      ),
    ));
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
    expect(bar.destinations.map((item) => (item as NavigationDestination).label),
        ['Tayyorlov', 'Profil', 'Chat']);
  });
}
