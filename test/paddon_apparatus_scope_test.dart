import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_detail_screen.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_scope.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddon_transfer_screen.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/aparatchi_paddons_screen.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/widgets/aparatchi_navigation_drawer.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const rezka = 'apparatus:default:asset-010';
const rezka2 = 'apparatus:default:asset-011';
const laminate = 'apparatus:default:asset-004';

Map<String, dynamic> _apparatus(String id, String name, String operation) => {
      'apparatus_id': id,
      'display': {'display_name': name},
      'source_revision': 1,
      'source_aasx_sha256': 'a' * 64,
      'execution_profile': {'operation': operation, 'technology': 'slitting'},
    };

final _catalog = [
  _apparatus(rezka, 'Rezka', 'cut'),
  _apparatus(rezka2, 'Rezka 2', 'cut'),
  _apparatus(laminate, 'Laminatsiya', 'laminate'),
];

Map<String, dynamic> _paddon(String code, String apparatus) => {
      'id': 'paddon-$code',
      'code': code,
      'apparatus_id': apparatus,
      'created_by_ref': 'worker-1',
      'item_count': 0,
    };

Widget _app(Widget home, {RouteFactory? onGenerateRoute}) => MaterialApp(
      locale: const Locale('uz'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      onGenerateRoute: onGenerateRoute,
      home: home,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSession.instance.token = 'token';
    AppSession.instance.profile = const SessionProfile(
      role: UserRole.aparatchi,
      ref: 'worker-1',
      displayName: 'Operator',
      legalName: '',
      phone: '',
      avatarUrl: '',
      assignedApparatus: [rezka, rezka2, laminate],
      capabilities: ['apparatus.queue.read', 'apparatus.queue.manage'],
    );
  });

  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  test('assigned paddon apparatus uses operation and assignment', () {
    final catalog = _catalog.map(AdminApparatus.fromJson);
    expect(
        assignedPaddonApparatus(catalog, [rezka2, laminate]).map((a) => a.id),
        [rezka2]);
    expect(AppRouter.canOpenRoute(apparatusPaddonsRoute(rezka2)), isTrue);
  });

  testWidgets('drawer has a distinct paddon destination per assigned rezka',
      (tester) async {
    final scaffold = GlobalKey<ScaffoldState>();
    String? destination;
    await tester.pumpWidget(_app(Scaffold(
      key: scaffold,
      drawer: AparatchiNavigationDrawer(
        selectedIndex: 0,
        selectedRouteName: AppRoutes.apparatusQueue,
        apparatusLoader: () async =>
            _catalog.map(AdminApparatus.fromJson).toList(),
        onNavigate: (route) => destination = route,
      ),
    )));
    await tester.pumpAndSettle();
    scaffold.currentState!.openDrawer();
    await tester.pumpAndSettle();
    expect(find.text('Paddon Rezka'), findsOneWidget);
    expect(find.text('Paddon Rezka 2'), findsOneWidget);
    expect(find.text('Paddon Laminatsiya'), findsNothing);
    expect(find.text('Paddonlar'), findsNothing);
    await tester.tap(find.text('Paddon Rezka 2'));
    await tester.pumpAndSettle();
    final uri = Uri.parse(destination!);
    expect(uri.path, AppRoutes.apparatusPaddons);
    expect(uri.queryParameters['apparatus'], rezka2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('scoped route lists and creates only its apparatus paddons',
      (tester) async {
    final listScopes = <String?>[];
    Map<String, dynamic>? createBody;
    AparatchiPaddonDetailArgs? opened;
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/admin/apparatus')) {
        return http.Response(jsonEncode(_catalog), 200);
      }
      if (path.endsWith('/paddons')) {
        listScopes.add(request.url.queryParameters['apparatus']);
        return http.Response(
            jsonEncode({
              'ok': true,
              'paddons': [
                _paddon('0011', rezka),
                _paddon('4234', rezka2),
              ]
            }),
            200);
      }
      if (path.endsWith('/paddons/create')) {
        createBody = (jsonDecode(request.body) as Map).cast<String, dynamic>();
        return http.Response(
            jsonEncode({'ok': true, 'paddon': _paddon('4235', rezka2)}), 200);
      }
      throw StateError('Unexpected request $request');
    });
    await http.runWithClient(() async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        locale: const Locale('uz'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: const Scaffold(),
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.apparatusPaddonDetail) {
            opened = settings.arguments as AparatchiPaddonDetailArgs;
            return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const Scaffold(body: Text('Created detail')));
          }
          return AppRouter.onGenerateRoute(settings);
        },
      ));
      await tester.pumpAndSettle();
      navigator.currentState!
          .pushNamed(apparatusPaddonsRoute(rezka2, apparatusName: 'Rezka 2'));
      await tester.pumpAndSettle();
      expect(listScopes, [rezka2]);
      expect(find.byKey(const ValueKey('paddon-card-4234')), findsOneWidget);
      expect(find.byKey(const ValueKey('paddon-card-0011')), findsNothing);
      await tester
          .tap(find.byKey(const ValueKey('app-primary-navigation-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yangi paddon qo‘shish'));
      await tester.pumpAndSettle();
      expect(createBody?['apparatus'], rezka2);
      expect(opened?.apparatusId, rezka2);
      expect(opened?.code, '4235');
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('unscoped multi apparatus page asks for apparatus before listing',
      (tester) async {
    var listReads = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/admin/apparatus')) {
        return http.Response(jsonEncode(_catalog), 200);
      }
      listReads++;
      throw StateError('Unscoped list must not load');
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(_app(const AparatchiPaddonsScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paddon-apparatus-$rezka')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('paddon-apparatus-$rezka2')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('paddon-apparatus-$laminate')),
          findsNothing);
      expect(listReads, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('scoped transfer excludes paddons from other rezka apparatus',
      (tester) async {
    String? listScope;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/paddons')) {
        listScope = request.url.queryParameters['apparatus'];
        return http.Response(
            jsonEncode({
              'ok': true,
              'paddons': [
                _paddon('0011', rezka),
                _paddon('4234', rezka2),
              ]
            }),
            200);
      }
      if (request.url.path.endsWith('/qr/report')) {
        expect(request.url.queryParameters['code'], '4234');
        return http.Response(
            jsonEncode({
              'ok': true,
              'paddon': _paddon('4234', rezka2),
              'items': [],
              'can_manage_items': true
            }),
            200);
      }
      throw StateError('Unexpected request $request');
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(
          _app(const AparatchiPaddonTransferScreen(apparatusId: rezka2)));
      await tester.pumpAndSettle();
      expect(listScope, rezka2);
      expect(find.text('4234'), findsOneWidget);
      expect(find.text('0011'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });
}
