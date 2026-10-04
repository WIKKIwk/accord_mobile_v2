import 'dart:convert';
import 'dart:async';

import 'package:accord_mobile_v2/src/core/api/mobile_api.dart';
import 'package:accord_mobile_v2/src/core/localization/app_localizations.dart';
import 'package:accord_mobile_v2/src/core/network/server_endpoint_store.dart';
import 'package:accord_mobile_v2/src/core/production/active_rezka_paddon_store.dart';
import 'package:accord_mobile_v2/src/core/session/session.dart';
import 'package:accord_mobile_v2/src/features/aparatchi/presentation/widgets/active_rezka_paddon_action.dart';
import 'package:accord_mobile_v2/src/features/shared/models/app_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apparatus = 'apparatus:default:asset-010';
const path = '/v1/mobile/admin/production-maps/paddons/active';

SessionProfile profile(String ref) => SessionProfile(
    role: UserRole.aparatchi,
    ref: ref,
    displayName: ref,
    legalName: '',
    phone: '',
    avatarUrl: '',
    capabilities: const ['apparatus.queue.read', 'apparatus.queue.manage'],
    assignedApparatus: const [apparatus]);

class Server {
  String? code;
  bool offline = false;
  bool rejectSave = false;
  final requests = <http.Request>[];

  http.Client client() => MockClient((request) async {
        requests.add(request);
        expectSync(request.url.path, path);
        expectSync(request.headers['Authorization'], 'Bearer worker-token');
        if (offline) throw http.ClientException('offline');
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expectSync(body.keys.toSet(), {'apparatus', 'code'});
          expectSync(body['apparatus'], apparatus);
          if (rejectSave) {
            return http.Response('{"error":"paddon_not_found"}', 400);
          }
          code = body['code'] == '' ? null : body['code'] as String;
        } else {
          expectSync(request.method, 'GET');
          expectSync(request.url.queryParameters['apparatus'], apparatus);
        }
        return http.Response(
            jsonEncode({'ok': true, 'apparatus': apparatus, 'code': code}),
            200);
      });
}

Future<List<AdminPaddon>> paddons() async => [
      for (final code in ['00001', '00002'])
        AdminPaddon(
            id: code,
            code: code,
            location: '',
            note: '',
            createdByRef: 'worker-1',
            createdByDisplayName: 'Rezka',
            createdAtUnix: 1,
            updatedAtUnix: 1,
            itemCount: 2)
    ];

Widget app({String apparatusId = apparatus}) => MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          appBar: AppBar(actions: [
        ActiveRezkaPaddonAction(apparatusId: apparatusId, loader: paddons)
      ])),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ServerEndpointStore.instance.clearOverride();
    AppSession.instance.profile = profile('worker-1');
    AppSession.instance.token = 'worker-token';
  });
  tearDown(() async {
    AppSession.instance.profile = null;
    AppSession.instance.token = null;
    await ServerEndpointStore.instance.clearOverride();
  });

  test(
      'two independent clients use server selection and ignore stale local data',
      () async {
    final server = Server();
    final prefs = await SharedPreferences.getInstance();
    final key = ActiveRezkaPaddonStore.scopeKey(apparatus)!;
    await prefs.setString(key, 'stale-device-choice');
    await http.runWithClient(() async {
      expect(await ActiveRezkaPaddonStore.load(apparatus), isNull);
      expect(await ActiveRezkaPaddonStore.save(apparatus, '00001'), '00001');
    }, server.client);
    SharedPreferences.setMockInitialValues({});
    await http.runWithClient(() async {
      expect(await ActiveRezkaPaddonStore.load(apparatus), '00001');
      await ActiveRezkaPaddonStore.save(apparatus, '00002');
    }, server.client);
    await http.runWithClient(() async {
      expect(await ActiveRezkaPaddonStore.load(apparatus), '00002');
      server.code = null;
      expect(await ActiveRezkaPaddonStore.load(apparatus), isNull);
    }, server.client);
    expect(
        (await SharedPreferences.getInstance())
            .getKeys()
            .where((key) => key.startsWith('rezka.active_paddon.')),
        isEmpty);
  });

  test('failed reads and rejected writes never fall back to local selection',
      () async {
    final server = Server()..code = '00001';
    await http.runWithClient(() async {
      server.offline = true;
      await expectLater(ActiveRezkaPaddonStore.load(apparatus),
          throwsA(isA<http.ClientException>()));
      server.offline = false;
      server.rejectSave = true;
      await expectLater(ActiveRezkaPaddonStore.save(apparatus, '00002'),
          throwsA(isA<MobileApiException>()));
      expect(await ActiveRezkaPaddonStore.load(apparatus), '00001');
    }, server.client);
    expect(
        (await SharedPreferences.getInstance())
            .getKeys()
            .where((key) => key.startsWith('rezka.active_paddon.')),
        isEmpty);
  });

  test('missing code or mismatched apparatus is not treated as no selection',
      () async {
    for (final payload in [
      {'ok': true, 'apparatus': apparatus},
      {'ok': true, 'apparatus': 'another', 'code': null},
      {'ok': true, 'apparatus': apparatus, 'code': 123},
    ]) {
      await http.runWithClient(() async {
        await expectLater(ActiveRezkaPaddonStore.load(apparatus),
            throwsA(isA<MobileApiException>()));
      },
          () =>
              MockClient((_) async => http.Response(jsonEncode(payload), 200)));
    }
  });

  testWidgets('polling pauses under another route and in background', (
    tester,
  ) async {
    final server = Server()..code = '00001';
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(server.requests.length, 1);
      final navigator = Navigator.of(
        tester.element(find.byType(ActiveRezkaPaddonAction)),
      );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Another route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      expect(server.requests.length, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      navigator.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      expect(server.requests.length, 1);
      server.code = '00002';
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(server.requests.length, 2);
      expect(find.byTooltip('Faol paddon: 00002'), findsOneWidget);
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Another route')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(server.requests.length, 2); // Resume while still covered is quiet.
      navigator.pop();
      await tester.pumpAndSettle();
      expect(server.requests.length, 3); // Uncover refreshes immediately.
      expect(
        server.requests.every((request) => request.method == 'GET'),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }, server.client);
  });

  testWidgets('late old-apparatus response cannot replace current selection', (
    tester,
  ) async {
    final delayed = Completer<http.Response>();
    var reads = 0;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(app());
        await tester.pump();
        expect(reads, 1);
        await tester.pumpWidget(app(apparatusId: 'apparatus:new'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Faol paddon: 00002'), findsOneWidget);
        delayed.complete(
          http.Response(
            jsonEncode({'ok': true, 'apparatus': apparatus, 'code': '00001'}),
            200,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Faol paddon: 00002'), findsOneWidget);
        expect(reads, 2);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient((request) async {
        reads++;
        final requested = request.url.queryParameters['apparatus'];
        if (requested == apparatus) return delayed.future;
        return http.Response(
          jsonEncode({'ok': true, 'apparatus': requested, 'code': '00002'}),
          200,
        );
      }),
    );
  });

  for (final change in [
    (name: 'account', profile: profile('worker-2')),
    (
      name: 'capability',
      profile: profile('worker-1').copyWith(capabilities: const [])
    ),
    (
      name: 'assignment',
      profile: profile('worker-1')
          .copyWith(assignedApparatus: const ['apparatus:other'])
    ),
  ]) {
    testWidgets('${change.name} change while choosing cannot submit old choice',
        (
      tester,
    ) async {
      final server = Server();
      await http.runWithClient(() async {
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('rezka-active-paddon')));
        await tester.pumpAndSettle();
        final oldTile = tester.widget<ListTile>(
          find.byKey(const ValueKey('rezka-paddon-00001')),
        );
        AppSession.instance.profile = change.profile;
        AppSession.instance.revision.value++;
        // A tap queued before the account change must be harmless too.
        oldTile.onTap!();
        await tester.pumpAndSettle();
        expect(
          server.requests.where((request) => request.method == 'PUT'),
          isEmpty,
        );
        expect(server.code, isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, server.client);
    });
  }

  testWidgets('same-account 401 reauth continues picker and verifies save',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'last_login_phone': '+998900000000',
      'last_login_code': '400000',
    });
    final originalProfile = AppSession.instance.profile!;
    var reads = 0;
    var writes = 0;
    var logins = 0;
    String? selectedCode;
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rezka-active-paddon')));
      await tester.pumpAndSettle();
      expect(logins, 1);
      expect(AppSession.instance.token, 'refreshed-token');
      expect(find.byKey(const ValueKey('rezka-paddon-00001')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rezka-paddon-00001')));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(reads, 4); // Initial, rejected preflight, retry, post-write read.
      expect(find.byTooltip('Faol paddon: 00001'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
        () => MockClient((request) async {
              if (request.url.path == '/v1/mobile/auth/login') {
                expect(request.method, 'POST');
                logins++;
                return http.Response(
                    jsonEncode({
                      'token': 'refreshed-token',
                      'profile': originalProfile.toJson(),
                      'capabilities': originalProfile.capabilities,
                      'assigned_apparatus': originalProfile.assignedApparatus,
                    }),
                    200);
              }
              expect(request.url.path, path);
              if (request.method == 'GET') {
                reads++;
                if (reads == 2) {
                  return http.Response('{"error":"unauthorized"}', 401);
                }
              } else {
                expect(request.method, 'PUT');
                writes++;
                selectedCode =
                    (jsonDecode(request.body) as Map)['code'] as String;
              }
              return http.Response(
                  jsonEncode({
                    'ok': true,
                    'apparatus': apparatus,
                    'code': selectedCode,
                  }),
                  200);
            }));
  });

  testWidgets('picker selects restores changes and clears server selection',
      (tester) async {
    final server = Server();
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Faol paddonni tanlang'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rezka-active-paddon')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rezka-paddon-00001')));
      await tester.pumpAndSettle();
      expect(server.code, '00001');
      expect(find.byTooltip('Faol paddon: 00001'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byTooltip('Faol paddon: 00001'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rezka-active-paddon')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rezka-paddon-00002')));
      await tester.pumpAndSettle();
      expect(server.code, '00002');
      await tester.tap(find.byKey(const ValueKey('rezka-active-paddon')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rezka-paddon-none')));
      await tester.pumpAndSettle();
      expect(server.code, isNull);
      expect(find.byTooltip('Faol paddonni tanlang'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, server.client);
  });

  testWidgets(
      'open picker refreshes changes from another device and shows read errors',
      (tester) async {
    final server = Server()..code = '00001';
    await http.runWithClient(() async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rezka-active-paddon')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ListTile>(
                  find.byKey(const ValueKey('rezka-paddon-00001')))
              .trailing,
          isNotNull);
      server.code = '00002';
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ListTile>(
                  find.byKey(const ValueKey('rezka-paddon-00001')))
              .trailing,
          isNull);
      expect(
          tester
              .widget<ListTile>(
                  find.byKey(const ValueKey('rezka-paddon-00002')))
              .trailing,
          isNotNull);
      server.offline = true;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Paddonlar yuklanmadi. Oynani qayta oching.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('rezka-paddon-none')), findsNothing);
      server.offline = false;
      server.code = null;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ListTile>(find.byKey(const ValueKey('rezka-paddon-none')))
              .trailing,
          isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }, server.client);
  });
}
