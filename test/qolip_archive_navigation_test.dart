import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/navigation/app_root_navigation.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_search_field.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_home_screen.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_storage_screen.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Route<void> _route(RouteSettings settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => switch (settings.name) {
        AppRoutes.qolipHome => const QolipHomeScreen(),
        AppRoutes.qolipPaddons => const QolipStorageScreen(),
        AppRoutes.qolipArchive => const QolipStorageScreen(archive: true),
        _ => const Scaffold(body: Text('Unexpected route')),
      },
    );

Widget _app(String initialRoute) => MaterialApp(
      initialRoute: initialRoute,
      onGenerateInitialRoutes: (route) => [_route(RouteSettings(name: route))],
      onGenerateRoute: _route,
      navigatorObservers: [AppRootNavigation.navigatorObserver],
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );

Future<void> _withClient(Future<void> Function() body) => http.runWithClient(
      body,
      () => MockClient((request) async {
        final path = request.url.path;
        final json = path.endsWith('/qolip/archive')
            ? {
                'ok': true,
                'entries': [
                  {
                    'id': 'visit-1',
                    'kind': 'paddon',
                    'code': 'QP-00003',
                    'warehouse': 'Mold store',
                    'archived_at': '2026-10-29T10:00:00Z',
                    'snapshot': {
                      'paddon': {'item_count': 0},
                      'items': [],
                    },
                  }
                ],
                'has_more': false,
              }
            : path.endsWith('/qolip/paddons')
                ? {'ok': true, 'paddons': [], 'has_more': false}
                : path.endsWith('/qolip/blocks')
                    ? {
                        'warehouses': ['Mold store'],
                        'blocks': []
                      }
                    : {'ok': true, 'items': []};
        return http.Response(jsonEncode(json), 200,
            headers: {'content-type': 'application/json'});
      }),
    );

Finder get _archiveBack => find.descendant(
      of: find.byType(AdminCatalogSearchField),
      matching: find.byIcon(Icons.arrow_back_rounded),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.token = 'archive-navigation';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.qolipchi,
      ref: 'worker',
      displayName: 'Worker',
      legalName: '',
      phone: '',
      avatarUrl: '',
      capabilities: ['qolip.manage'],
      assignedWarehouses: ['Mold store'],
    );
    AppSession.instance.revision.value++;
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('drawer archive returns to home instead of a prior pallet page',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _withClient(() async {
      await tester.pumpWidget(_app(AppRoutes.qolipPaddons));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(NavigationBar), matching: find.text('Home')));
      await tester.pumpAndSettle();
      expect(find.byType(QolipHomeScreen), findsOneWidget);
      final homeState = tester.state(find.byType(QolipHomeScreen));

      await tester.tap(find.descendant(
          of: find.byType(AdminCatalogSearchField),
          matching: find.byIcon(Icons.menu_rounded)));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(NavigationDrawer), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qolip-archive-list')), findsOneWidget);

      await tester
          .tap(find.byKey(const ValueKey('qolip-archive-paddon-visit-1')));
      await tester.pumpAndSettle();
      expect(find.byType(QolipArchiveDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qolip-archive-list')), findsOneWidget);

      await tester.tap(_archiveBack);
      await tester.pumpAndSettle();
      expect(find.byType(QolipHomeScreen), findsOneWidget);
      expect(tester.state(find.byType(QolipHomeScreen)), same(homeState));
      expect(find.byType(NavigationDrawer), findsNothing);
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      expect(navigator.canPop(), isFalse);
      expect(AppRootNavigation.containsRoute(AppRoutes.qolipPaddons), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('system back from a root archive opens the home page',
      (tester) async {
    await _withClient(() async {
      await tester.pumpWidget(_app(AppRoutes.qolipArchive));
      await tester.pumpAndSettle();
      expect(_archiveBack, findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(QolipHomeScreen), findsOneWidget);
      expect(
          tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
          isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('system back closes the open archive drawer before leaving',
      (tester) async {
    await _withClient(() async {
      await tester.pumpWidget(_app(AppRoutes.qolipArchive));
      await tester.pumpAndSettle();
      final fieldContext = tester.element(find.byType(AdminCatalogSearchField));
      AppShellDrawerScope.maybeOf(fieldContext)!.openDrawer();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationDrawer), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('qolip-archive-list')), findsOneWidget);
      expect(find.byType(NavigationDrawer), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(QolipHomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
