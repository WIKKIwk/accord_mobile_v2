import 'dart:convert';

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
        expect(request.url.path, path);
        expect(request.headers['Authorization'], 'Bearer worker-token');
        if (offline) throw http.ClientException('offline');
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.keys.toSet(), {'apparatus', 'code'});
          expect(body['apparatus'], apparatus);
          if (rejectSave) {
            return http.Response('{"error":"paddon_not_found"}', 400);
          }
          code = body['code'] == '' ? null : body['code'] as String;
        } else {
          expect(request.method, 'GET');
          expect(request.url.queryParameters['apparatus'], apparatus);
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

Widget app() => MaterialApp(
      locale: const Locale('uz'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
          appBar: AppBar(actions: const [
        ActiveRezkaPaddonAction(apparatusId: apparatus, loader: paddons)
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
