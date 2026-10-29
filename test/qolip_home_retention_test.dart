import 'dart:async';
import 'dart:convert';

import 'package:accord_mobile_v2/src/app/app_router.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/navigation/app_root_navigation.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_loading_indicator.dart';
import 'package:accord_mobile_v2/src/core/widgets/shell/app_shell.dart';
import 'package:accord_mobile_v2/src/features/admin/presentation/widgets/admin_catalog_search_field.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_home_screen.dart';
import 'package:accord_mobile_v2/src/features/qolip/presentation/qolip_storage_screen.dart';
import 'package:accord_mobile_v2/src/features/qolip/state/qolip_data_revision.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Map<String, dynamic> data, [int status = 200]) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json'});

class _Server {
  int blockReads = 0;
  int locationReads = 0;
  String itemName = 'Old item';
  List<String> blockNames = ['A', 'B'];
  bool failNextBlocks = false;
  bool failNextLocationB = false;
  Completer<http.Response>? pendingBlocks;
  Completer<http.Response>? pendingLocationB;

  Map<String, dynamic> get blocks => {
        'warehouses': ['Mold store'],
        'blocks': [
          for (final name in blockNames)
            {'name': name, 'warehouse': 'Mold store'},
        ],
      };

  http.Response locations(String? block, {String? name}) => _json({
        'locations': [
          if (block == 'B')
            {
              'id': 'location-1',
              'block': 'B',
              'warehouse': 'Mold store',
              'item_code': 'ITEM',
              'item_name': name ?? itemName,
              'qolip_code': 'Q-ONE',
              'size': 40,
              'quantity': 1,
              'row_letter': 'A',
              'column_number': 1,
              'location_label': 'A1',
            }
        ]
      });

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    if (path.endsWith('/qolip/blocks')) {
      blockReads++;
      final pending = pendingBlocks;
      if (pending != null) {
        pendingBlocks = null;
        return pending.future;
      }
      if (failNextBlocks) {
        failNextBlocks = false;
        return _json({'error': 'offline'}, 500);
      }
      return _json(blocks);
    }
    if (path.endsWith('/qolip/locations')) {
      locationReads++;
      final block = request.url.queryParameters['block'];
      if (block == 'B' && failNextLocationB) {
        failNextLocationB = false;
        return _json({'error': 'offline'}, 500);
      }
      final pending = pendingLocationB;
      if (block == 'B' && pending != null) {
        pendingLocationB = null;
        return pending.future;
      }
      return locations(block);
    }
    if (path.endsWith('/qolip/paddons')) {
      return _json({'ok': true, 'paddons': [], 'has_more': false});
    }
    if (path.endsWith('/qolip/archive')) {
      return _json({'ok': true, 'entries': [], 'has_more': false});
    }
    return _json({'ok': true, 'items': []});
  }
}

Route<void> _route(RouteSettings settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => switch (settings.name) {
        AppRoutes.qolipHome => const QolipHomeScreen(),
        AppRoutes.qolipPaddons => const QolipStorageScreen(),
        AppRoutes.qolipArchive => const QolipStorageScreen(archive: true),
        _ => const Scaffold(body: Text('Other page')),
      },
    );

Widget _app() => MaterialApp(
      initialRoute: AppRoutes.qolipHome,
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

void _session(String ref) {
  AppSession.instance.token = 'token-$ref';
  AppSession.instance.profile = SessionProfile(
    role: UserRole.qolipchi,
    ref: ref,
    displayName: ref,
    legalName: '',
    phone: '',
    avatarUrl: '',
    capabilities: const ['qolip.manage'],
    assignedWarehouses: const ['Mold store'],
  );
  AppSession.instance.revision.value++;
}

Future<void> _openPaddons(WidgetTester tester) async {
  await tester.tap(find.descendant(
      of: find.byType(AdminCatalogSearchField),
      matching: find.byIcon(Icons.menu_rounded)));
  await tester.pumpAndSettle();
  await tester.drag(find.byType(NavigationDrawer), const Offset(0, -600));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Pallets'));
  await tester.pumpAndSettle();
}

Future<void> _returnHome(WidgetTester tester) async {
  await tester.tap(find.descendant(
      of: find.byType(NavigationBar), matching: find.text('Home')));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServerEndpointStore.instance.clearOverride();
    _session('first');
  });
  tearDown(() {
    AppSession.instance.token = null;
    AppSession.instance.profile = null;
  });

  testWidgets('home and its selected block survive leaving and returning',
      (tester) async {
    final server = _Server();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qolip-tab-b')));
      await tester.pumpAndSettle();
      final homeState = tester.state(find.byType(QolipHomeScreen));
      final grid = find.byKey(const ValueKey('qolip-home-block-b'));
      final list =
          find.descendant(of: grid, matching: find.byType(ListView)).first;
      await tester.drag(list, const Offset(0, -350));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
          find.descendant(of: list, matching: find.byType(Scrollable)).first);
      final offset = scroll.position.pixels;
      expect(offset, greaterThan(0));
      final reads = (server.blockReads, server.locationReads);

      await _openPaddons(tester);
      await _returnHome(tester);
      expect(tester.state(find.byType(QolipHomeScreen)), same(homeState));
      expect(find.byKey(const ValueKey('qolip-home-block-b')), findsOneWidget);
      expect(find.text('Old item'), findsOneWidget);
      expect(scroll.position.pixels, closeTo(offset, 0.1));
      expect((server.blockReads, server.locationReads), reads);
      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient(server.handle));
  });

  testWidgets('a stale home refreshes quietly and throttles repeated returns',
      (tester) async {
    final server = _Server();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qolip-tab-b')));
      await tester.pumpAndSettle();
      final homeState = tester.state(find.byType(QolipHomeScreen));
      await _openPaddons(tester);
      await tester.pump(const Duration(seconds: 31));
      final pending = Completer<http.Response>();
      server.pendingBlocks = pending;
      await _returnHome(tester);
      expect(server.blockReads, 2);
      expect(tester.state(find.byType(QolipHomeScreen)), same(homeState));
      expect(find.text('Old item'), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);

      server.itemName = 'New item';
      pending.complete(_json(server.blocks));
      await tester.pumpAndSettle();
      expect(find.text('New item'), findsOneWidget);
      expect(find.text('Old item'), findsNothing);
      expect(find.byKey(const ValueKey('qolip-home-block-b')), findsOneWidget);
      await _openPaddons(tester);
      await _returnHome(tester);
      expect(server.blockReads, 2);
      expect(find.text('New item'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient(server.handle));
  });

  testWidgets('drawer Home returns to the retained home page', (tester) async {
    final server = _Server();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qolip-tab-b')));
      await tester.pumpAndSettle();
      final homeState = tester.state(find.byType(QolipHomeScreen));
      await _openPaddons(tester);
      final fieldContext = tester.element(find.byType(AdminCatalogSearchField));
      AppShellDrawerScope.maybeOf(fieldContext)!.openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(NavigationDrawer), matching: find.text('Home')));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(QolipHomeScreen)), same(homeState));
      expect(find.text('Old item'), findsOneWidget);
      expect(server.blockReads, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient(server.handle));
  });

  testWidgets('background block changes keep the selected surviving block',
      (tester) async {
    final server = _Server();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qolip-tab-b')));
      await tester.pumpAndSettle();
      await _openPaddons(tester);
      await tester.pump(const Duration(seconds: 31));
      server.blockNames = ['B', 'C'];
      await _returnHome(tester);
      expect(find.byKey(const ValueKey('qolip-home-block-b')), findsOneWidget);
      expect(find.text('Old item'), findsOneWidget);
      expect(find.byKey(const ValueKey('qolip-tab-a')), findsNothing);
      expect(find.byKey(const ValueKey('qolip-tab-c')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient(server.handle));
  });

  testWidgets('a local change supersedes an older background request',
      (tester) async {
    final server = _Server();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qolip-tab-b')));
      await tester.pumpAndSettle();
      await _openPaddons(tester);
      await tester.pump(const Duration(seconds: 31));
      final pending = Completer<http.Response>();
      server.pendingLocationB = pending;
      await _returnHome(tester);
      expect(server.blockReads, 2);
      expect(find.text('Old item'), findsOneWidget);
      server.itemName = 'Newest item';
      QolipDataRevision.notifyLocationsChanged();
      pending.complete(server.locations('B', name: 'Stale item'));
      await tester.pumpAndSettle();
      expect(server.blockReads, 3);
      expect(find.text('Newest item'), findsOneWidget);
      expect(find.text('Stale item'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient(server.handle));
  });

  testWidgets('a local mold change updates retained home without waiting',
      (tester) async {
    final server = _Server();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qolip-tab-b')));
      await tester.pumpAndSettle();
      await _openPaddons(tester);
      server.itemName = 'Changed locally';
      QolipDataRevision.notifyLocationsChanged();
      await tester.pumpAndSettle();
      expect(server.blockReads, 2);
      await _returnHome(tester);
      expect(find.text('Changed locally'), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient(server.handle));
  });

  testWidgets('failed background reads keep the existing home visible',
      (tester) async {
    final server = _Server();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qolip-tab-b')));
      await tester.pumpAndSettle();
      await _openPaddons(tester);
      await tester.pump(const Duration(seconds: 31));
      server.failNextBlocks = true;
      await _returnHome(tester);
      expect(server.blockReads, 2);
      expect(find.text('Old item'), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient(server.handle));
  });

  testWidgets(
      'a failed block refresh keeps data and retries on the next return',
      (tester) async {
    final server = _Server();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qolip-tab-b')));
      await tester.pumpAndSettle();
      await _openPaddons(tester);
      await tester.pump(const Duration(seconds: 31));
      server.itemName = 'Recovered item';
      server.failNextLocationB = true;
      await _returnHome(tester);
      expect(find.text('Old item'), findsOneWidget);
      expect(find.byType(AppLoadingIndicator), findsNothing);
      await _openPaddons(tester);
      await _returnHome(tester);
      expect(server.blockReads, 3);
      expect(find.text('Recovered item'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient(server.handle));
  });

  testWidgets('account switch drops the old snapshot and late refresh',
      (tester) async {
    final server = _Server();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await http.runWithClient(() async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('qolip-tab-b')));
      await tester.pumpAndSettle();
      await _openPaddons(tester);
      await tester.pump(const Duration(seconds: 31));
      final pending = Completer<http.Response>();
      server.pendingBlocks = pending;
      await _returnHome(tester);
      expect(server.blockReads, 2);
      server.itemName = 'Second account';
      _session('second');
      await tester.pumpAndSettle();
      expect(find.text('Old item'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('qolip-tab-b')));
      await tester.pumpAndSettle();
      expect(find.text('Second account'), findsOneWidget);
      pending.complete(_json(server.blocks));
      await tester.pumpAndSettle();
      expect(find.text('Second account'), findsOneWidget);
      expect(find.text('Old item'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => MockClient(server.handle));
  });
}
